#!/usr/bin/env bash
# ship-phase.sh — GSD automated ship helper
#
# Runs: local tests → push → PR (with Closes #N) → CI gate → merge → issue close → STATE.md
#
# Usage:
#   bash "$HOME/.claude/skills/gsd/scripts/ship-phase.sh" --phase <N> [options]
#
# Options:
#   --phase <N>          Phase number (required; used to find PLAN.md and ROADMAP entry)
#   --base <branch>      Integration branch to PR against (default: dev)
#   --no-wait            Skip CI polling; merge immediately after push (dangerous — warn)
#   --skip-tests         Bypass local test gate (emergency only)
#   --dry-run            Print every command without executing
#   --stop-after-tests   Run preflight + HITL gate + tests, then exit 0 before pushing.
#                        Used by /gsd-ship-phase as the first half of the pipeline so a
#                        reviewer subagent can run between tests and push. Mutually
#                        exclusive with --from-push.
#   --from-push          Skip HITL gate detection and tests; jump straight to push.
#                        Caller MUST have already run preflight + tests (e.g. via a
#                        prior --stop-after-tests invocation). Preflight (branch +
#                        dirty-tree checks) still runs as a safety net. Mutually
#                        exclusive with --stop-after-tests.
#
# Exit codes:
#   0  shipped successfully (or --stop-after-tests stage gate reached)
#   1  test failure
#   2  CI failure
#   3  preflight failure (or invalid flag combination)
#   4  user abort (HITL gate detected)
#   5  reviewer verdict REQUEST_CHANGES   (emitted by /gsd-ship-phase, not this script)
#   6  reviewer verdict NEEDS_DISCUSSION  (emitted by /gsd-ship-phase, not this script)

set -euo pipefail

# ─── colours ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[ship]${NC} $*"; }
ok()    { echo -e "${GREEN}[ship]${NC} $*"; }
warn()  { echo -e "${YELLOW}[ship]${NC} $*"; }
die()   { echo -e "${RED}[ship] FATAL:${NC} $*" >&2; exit "${1:-1}"; }

# ─── arg parsing ────────────────────────────────────────────────────────────
PHASE=""
BASE="dev"
NO_WAIT=false
SKIP_TESTS=false
DRY_RUN=false
STOP_AFTER_TESTS=false
FROM_PUSH=false
TEST_LOG="/tmp/ship-phase-tests.log"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)             PHASE="$2"; shift 2 ;;
    --base)              BASE="$2"; shift 2 ;;
    --no-wait)           NO_WAIT=true; shift ;;
    --skip-tests)        SKIP_TESTS=true; shift ;;
    --dry-run)           DRY_RUN=true; shift ;;
    --stop-after-tests)  STOP_AFTER_TESTS=true; shift ;;
    --from-push)         FROM_PUSH=true; shift ;;
    *) die 3 "Unknown flag: $1" ;;
  esac
done

# Mutual exclusivity: stage flags cannot both be on
if $STOP_AFTER_TESTS && $FROM_PUSH; then
  die 3 "--stop-after-tests and --from-push are mutually exclusive."
fi

# Dry-run wrapper — prints without executing
run() {
  if $DRY_RUN; then
    echo -e "${YELLOW}[dry-run]${NC} $*"
  else
    "$@"
  fi
}

# ─── preflight ──────────────────────────────────────────────────────────────
info "Preflight checks…"

for cmd in git gh; do
  command -v "$cmd" &>/dev/null || die 3 "'$cmd' not found on PATH. Install it and retry."
done

# jq is optional — we fall back to grep-based parsing if absent
JQ_AVAILABLE=false
command -v jq &>/dev/null && JQ_AVAILABLE=true

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 3 "Not inside a git repository."
cd "$REPO_ROOT"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
for protected in main master dev uat; do
  [[ "$CURRENT_BRANCH" == "$protected" ]] && die 3 "Refusing to ship from protected branch '$CURRENT_BRANCH'. Checkout a feature branch first."
done

# Dirty working tree check
if ! git diff --quiet || ! git diff --cached --quiet; then
  die 3 "Working tree has uncommitted changes. Commit or stash them before shipping."
fi

# Phase arg is required — try to infer from branch name if missing
if [[ -z "$PHASE" ]]; then
  # Branch names like feat/42-some-thing or feature/042-thing → extract leading digits
  PHASE=$(echo "$CURRENT_BRANCH" | grep -oP '(?<=/|^)\d+' | head -1 || true)
  if [[ -z "$PHASE" ]]; then
    die 3 "--phase not provided and could not be inferred from branch name '$CURRENT_BRANCH'."
  fi
  info "Inferred --phase $PHASE from branch name."
fi

# Pad phase to 2 digits for directory matching
PHASE_PAD=$(printf "%02d" "$PHASE")

ok "Preflight passed. Branch: $CURRENT_BRANCH → $BASE | Phase: $PHASE_PAD"
$DRY_RUN && warn "DRY RUN — no commands will execute."

# ─── HITL gate detection ────────────────────────────────────────────────────
HITL_FOUND=false
HITL_REASONS=()

# PLAN_FILE lookup is needed by both HITL detection AND the PR body builder
# below, so always resolve it. HITL detection itself is skipped when --from-push
# is set (caller already cleared the gate before invoking the second half).
PLAN_FILE=$(find .planning/phases -name "*PLAN.md" 2>/dev/null | grep -E "/${PHASE_PAD}[^/]*/" | head -1 || true)

if $FROM_PUSH; then
  info "Skipping HITL gate detection (--from-push: caller cleared the gate)."
else
  info "Checking for HITL gates…"

  if [[ -n "$PLAN_FILE" ]] && grep -qiE "(HITL|human.in.the.loop|needs.review)" "$PLAN_FILE" 2>/dev/null; then
    HITL_FOUND=true
    HITL_REASONS+=("HITL flag in $PLAN_FILE")
  fi

  # Check open issues with Status: Needs Review label linked to this phase
  # (light check — full label check happens after issue extraction below)
  if [[ -z "$PLAN_FILE" ]]; then
    warn "No PLAN.md found for phase $PHASE_PAD — skipping file-based HITL check."
  fi
fi

# ─── extract linked GitHub issues ───────────────────────────────────────────
info "Detecting linked GitHub issues…"

LINKED_ISSUES=()

# Helper: extract bare issue numbers from a string like "**GitHub Issue:** #42"
# Uses grep -oE (POSIX ERE) to stay compatible with Windows Git Bash grep
_extract_issue_nums() {
  # Match patterns: #123, Closes #123, Fixes #123, Resolves #123, **GitHub Issue:** #123
  grep -oE '(Closes?|Fixes?|Resolves?|GitHub Issue:)\s*#[0-9]+|#[0-9]+' 2>/dev/null \
    | grep -oE '[0-9]+' || true
}

# Source 1: PLAN.md / ROADMAP.md — **GitHub Issue:** #N
if [[ -n "$PLAN_FILE" ]]; then
  while IFS= read -r num; do
    LINKED_ISSUES+=("$num")
  done < <(grep -i "GitHub Issue" "$PLAN_FILE" 2>/dev/null | _extract_issue_nums)
fi

ROADMAP_FILE=".planning/ROADMAP.md"
if [[ -f "$ROADMAP_FILE" ]]; then
  while IFS= read -r num; do
    LINKED_ISSUES+=("$num")
  done < <(grep -A5 -E "Phase $PHASE[^0-9]|^## $PHASE_PAD" "$ROADMAP_FILE" 2>/dev/null \
           | grep -i "GitHub Issue" | _extract_issue_nums)
fi

# Source 2: ROADMAP.md — find phase block by current branch name (handles
# feature/51-slug branches where phase NN ≠ issue 51)
if [[ -f "$ROADMAP_FILE" ]]; then
  while IFS= read -r num; do
    LINKED_ISSUES+=("$num")
  done < <(grep -B10 -E "Branch.*${CURRENT_BRANCH}($|[^-])" "$ROADMAP_FILE" 2>/dev/null \
           | grep -i "GitHub Issue" | _extract_issue_nums)
fi

# Source 3: commit messages on this branch — #N / Fixes #N / Closes #N
while IFS= read -r num; do
  LINKED_ISSUES+=("$num")
done < <(git log "origin/$BASE..HEAD" --pretty=format:"%s %b" 2>/dev/null \
         | _extract_issue_nums)

# De-duplicate
IFS=$'\n' LINKED_ISSUES=($(printf '%s\n' "${LINKED_ISSUES[@]}" | sort -u))
unset IFS

if [[ ${#LINKED_ISSUES[@]} -gt 0 ]]; then
  ok "Linked issues: ${LINKED_ISSUES[*]/#/#}"
  # Check if any linked issue has 'Needs Review' label (skipped on --from-push:
  # caller already cleared the HITL gate before invoking the push half).
  if ! $FROM_PUSH; then
    for iss in "${LINKED_ISSUES[@]}"; do
      LABELS=$(gh issue view "$iss" --json labels --jq '.labels[].name' 2>/dev/null || true)
      if echo "$LABELS" | grep -qi "needs.review\|needs-review"; then
        HITL_FOUND=true
        HITL_REASONS+=("Issue #$iss has 'Needs Review' label")
      fi
    done
  fi
else
  warn "No linked GitHub issues found. PR will have no Closes #N lines."
fi

# HITL gate: stop here if human review is required (skipped on --from-push)
if ! $FROM_PUSH && $HITL_FOUND; then
  warn "HITL gate(s) detected — cannot auto-merge:"
  for reason in "${HITL_REASONS[@]}"; do
    warn "  • $reason"
  done
  warn ""
  warn "Action: push the branch, open the PR manually with 'Closes #N' in the body,"
  warn "assign a reviewer, and wait for human approval before merging."
  warn ""
  warn "Quick commands:"
  warn "  git push -u origin $CURRENT_BRANCH"
  CLOSES_LINES=""
  for iss in "${LINKED_ISSUES[@]}"; do CLOSES_LINES+="Closes #$iss\n"; done
  warn "  gh pr create --base $BASE --title \"feat($PHASE_PAD): <summary>\" --body $'...\n${CLOSES_LINES}'"
  exit 4
fi

# ─── local tests ────────────────────────────────────────────────────────────
if $FROM_PUSH; then
  info "Skipping local tests (--from-push: caller already ran them)."
elif $SKIP_TESTS; then
  warn "SKIP_TESTS set — bypassing local test gate."
else
  info "Running local tests…"
  TEST_FAILED=false

  run_test() {
    local label="$1"; shift
    info "  → $label"
    if $DRY_RUN; then
      echo -e "${YELLOW}[dry-run]${NC} $*"
      return
    fi
    if ! "$@" >> "$TEST_LOG" 2>&1; then
      TEST_FAILED=true
      echo -e "${RED}[ship] FAILED:${NC} $label"
      echo "--- $TEST_LOG ---"
      cat "$TEST_LOG"
      echo "---"
    fi
  }

  > "$TEST_LOG"  # clear log

  # Frontend
  if [[ -f "frontend/package.json" ]]; then
    run_test "frontend build (tsc + vite)" npm --prefix frontend run build

    if [[ -d "frontend/tests" ]] && grep -q '"@playwright/test"' frontend/package.json 2>/dev/null; then
      run_test "playwright e2e" bash -c "cd frontend && npx playwright test --reporter=line"
    fi

    if grep -q '"vitest"' frontend/package.json 2>/dev/null; then
      run_test "vitest unit tests" bash -c "cd frontend && npx vitest run"
    fi
  fi

  # Functions
  if [[ -f "functions/package.json" ]]; then
    run_test "functions build (tsc)" npm --prefix functions run build
  fi

  # Python (legacy)
  if [[ -f "requirements.txt" ]] && command -v pytest &>/dev/null; then
    run_test "pytest" pytest tests/ -q
  fi

  if $TEST_FAILED; then
    die 1 "Local tests failed — ship aborted. Fix failures and retry."
  fi

  ok "All local tests passed."
fi

# ─── stage gate ─────────────────────────────────────────────────────────────
if $STOP_AFTER_TESTS; then
  ok "✅ Preflight + tests OK — stopping at stage gate (--stop-after-tests)."
  exit 0
fi

# ─── push branch ────────────────────────────────────────────────────────────
info "Pushing branch $CURRENT_BRANCH…"
run git push -u origin HEAD

# ─── build PR body ───────────────────────────────────────────────────────────
info "Building PR body…"

# Phase summary from PLAN.md first non-frontmatter heading
PHASE_SUMMARY=""
if [[ -n "$PLAN_FILE" ]]; then
  PHASE_SUMMARY=$(grep -m1 "^# " "$PLAN_FILE" 2>/dev/null | sed 's/^# //' || true)
fi
[[ -z "$PHASE_SUMMARY" ]] && PHASE_SUMMARY=$(git log --oneline -1 | cut -d' ' -f2-)

# Commit list since base
COMMIT_LIST=$(git log "origin/$BASE..HEAD" --pretty=format:"- %s" 2>/dev/null || echo "- (commits not yet pushed)")

# Closes #N lines
CLOSES_BLOCK=""
for iss in "${LINKED_ISSUES[@]}"; do
  CLOSES_BLOCK+=$'\n'"Closes #$iss"
done

PR_BODY="## Summary
${PHASE_SUMMARY}

## Changes
${COMMIT_LIST}

## Test plan
- [x] Local build passes
- [x] Local test suite passes
- [ ] Manual checks (see phase UAT if applicable)
${CLOSES_BLOCK}

🤖 Generated with [Claude Code](https://claude.com/claude-code)"

# PR title: use most recent commit subject or phase summary
PR_TITLE="feat(${PHASE_PAD}): ${PHASE_SUMMARY}"

# ─── create PR ──────────────────────────────────────────────────────────────
info "Creating PR → $BASE…"
if $DRY_RUN; then
  echo -e "${YELLOW}[dry-run]${NC} gh pr create --base $BASE --title \"$PR_TITLE\" --body \"...\""
  echo "Body preview (truncated):"
  echo "$PR_BODY" | head -20
  PR_NUM="DRY-RUN"
  PR_URL="https://github.com/dry-run/pr/0"
else
  PR_URL=$(gh pr create --base "$BASE" --title "$PR_TITLE" --body "$PR_BODY" 2>&1)
  # gh pr create outputs the URL on the last line
  PR_URL=$(echo "$PR_URL" | tail -1)
  PR_NUM=$(echo "$PR_URL" | grep -oP '\d+$' || true)
  ok "PR created: $PR_URL"
fi

# ─── CI gate ────────────────────────────────────────────────────────────────
if $NO_WAIT; then
  warn "--no-wait set — skipping CI polling. Merging immediately."
elif $DRY_RUN; then
  echo -e "${YELLOW}[dry-run]${NC} gh pr checks $PR_NUM --watch"
else
  info "Waiting for CI checks on PR #$PR_NUM…"
  if ! gh pr checks "$PR_NUM" --watch --interval 10; then
    die 2 "CI checks failed on PR #$PR_NUM. Fix the failures and re-run ship-phase.sh (the PR is already open)."
  fi
  ok "CI passed."
fi

# ─── merge + cleanup ────────────────────────────────────────────────────────
info "Squash-merging PR #$PR_NUM…"
run gh pr merge "$PR_NUM" --squash --delete-branch

info "Switching to $BASE and pulling…"
run git checkout "$BASE"
run git pull --ff-only

# Delete local feature branch (remote already gone via --delete-branch above)
if [[ "$CURRENT_BRANCH" != "$BASE" ]]; then
  info "Deleting local branch $CURRENT_BRANCH…"
  run git branch -d "$CURRENT_BRANCH" 2>/dev/null \
    || run git branch -D "$CURRENT_BRANCH" 2>/dev/null \
    || warn "Could not delete local branch $CURRENT_BRANCH — delete manually with: git branch -D $CURRENT_BRANCH"
fi

# Close linked issues (safety net — 'Closes #N' in PR body handles the common
# case on merge, but if the repo has that feature disabled this ensures closure)
for iss in "${LINKED_ISSUES[@]}"; do
  info "Closing issue #$iss…"
  run gh issue close "$iss" --comment "Shipped in #${PR_NUM} — ${PR_URL}" 2>/dev/null || true
done

# ─── update STATE.md ────────────────────────────────────────────────────────
STATE_FILE=".planning/STATE.md"
TODAY=$(date +%Y-%m-%d)
ISSUES_STR=""
for iss in "${LINKED_ISSUES[@]}"; do ISSUES_STR+="#$iss "; done

if [[ -f "$STATE_FILE" ]]; then
  SHIPPED_LINE="- Phase ${PHASE_PAD} — PR #${PR_NUM} merged ${TODAY}${ISSUES_STR:+ — issues: ${ISSUES_STR%% }}"
  if $DRY_RUN; then
    echo -e "${YELLOW}[dry-run]${NC} Append to $STATE_FILE: $SHIPPED_LINE"
  else
    # Append to a '## Shipped' section; create the section if absent
    if grep -q "^## Shipped" "$STATE_FILE"; then
      sed -i "/^## Shipped/a $SHIPPED_LINE" "$STATE_FILE"
    else
      printf '\n## Shipped\n%s\n' "$SHIPPED_LINE" >> "$STATE_FILE"
    fi
    git add "$STATE_FILE"
    git commit -m "docs(state): phase ${PHASE_PAD} shipped — PR #${PR_NUM}" --no-verify 2>/dev/null || true
    git push || true
  fi
fi

# ─── done ───────────────────────────────────────────────────────────────────
echo ""
ok "═══════════════════════════════════════════════════════"
ok "  Phase ${PHASE_PAD} shipped."
ok "  PR:     ${PR_URL}"
[[ ${#LINKED_ISSUES[@]} -gt 0 ]] && ok "  Closed: ${LINKED_ISSUES[*]/#/#}"
ok "═══════════════════════════════════════════════════════"
echo ""
