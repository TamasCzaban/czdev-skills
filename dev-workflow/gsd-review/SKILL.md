---
name: gsd-review
description: Independent code review by a fresh-context sub-agent. Runs after /gsd:execute-phase and before opening a PR. Triggers when the user says "/gsd-review", "review this phase", "review the diff", "get a second opinion on this branch", or wants an unbiased review of work-in-progress before pushing.
---

# GSD Review — Independent Phase Review

Spawn a fresh-context sub-agent to review the current feature branch against its parent issue's acceptance criteria. The reviewer never sees the implementing conversation, has no investment in the chosen approach, and is forced to re-derive understanding from the diff + changed files alone.

## When to use

- After `/gsd:execute-phase <NN>` completes and tests pass
- Before running `gh pr create`
- After making review-driven fixes, to re-check (re-run is cheap)

## Prerequisites

- `gh` CLI authenticated (`gh auth status`)
- Currently on a `feature/<issue-N>-<slug>` branch (or any branch ahead of base)
- The branch has commits ahead of base

## Process

### 1. Gather context

Auto-detect from current state:

```bash
BRANCH=$(git branch --show-current)
BASE=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null \
  || git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' \
  || echo "main")
PROJECT=$(gh repo view --json name --jq '.name' 2>/dev/null || basename $(git rev-parse --show-toplevel))
ISSUE_N=$(echo "$BRANCH" | sed -E 's|^feature/([0-9]+)-.*|\1|')
PHASE_NN=$(grep -E "^## Phase [0-9]+" .planning/ROADMAP.md 2>/dev/null | grep "#$ISSUE_N" | sed -E 's|^## Phase ([0-9]+):.*|\1|' | tail -1)
```

Abort with a clear message if:
- No commits ahead of base
- Issue number cannot be parsed and ROADMAP.md has no matching phase (warn but continue — reviewer can still check conventions and diff quality)

### 2. Build the review bundle

Collect, in order:

1. **Issue body** — `gh issue view $ISSUE_N --json title,body,labels` (skip if issue number not available)
2. **Acceptance criteria** — extract from issue body (`Must be TRUE` / `Acceptance criteria` checklist), or from the matching phase in `.planning/ROADMAP.md`
3. **Diff** — `git diff $BASE...HEAD`
4. **Changed files** — `git diff $BASE...HEAD --name-only`
5. **Full content of each changed file** — read each file in full for surrounding context. Skip: binary files, lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `poetry.lock`, `go.sum`), generated files (`dist/`, `build/`, `lib/`, `*.d.ts`, `*.pb.go`)
6. **Project conventions** — discover all `CLAUDE.md` files in the repo (`find . -name "CLAUDE.md" -not -path "*/node_modules/*" -not -path "*/.git/*"`), read them all
7. **Testing strategy** — extract the `Testing Strategy` block for this phase from `.planning/ROADMAP.md` if it exists

### 3. Spawn the reviewer

Use the `Agent` tool with `subagent_type: general-purpose`, `model: sonnet` (or `haiku` if the diff is under 200 lines — first-pass triage).

**Critical prompt rules:**
- Never mention "AI", "Claude", "generated", or "agent" in the prompt
- Frame as: *"You're reviewing a pull request from a teammate. Be critical but fair."*
- Do not include any reasoning from the implementing conversation
- Force structured output (see template below)

**Reviewer prompt template:**

```
You are reviewing a pull request from a teammate on the <PROJECT> project. The author is not in the room — your review will be read async. Be critical but fair: flag real problems, do not invent issues to look thorough, do not soften findings to be polite.

## The work

**Issue #<ISSUE_N>:** <issue title>

**Acceptance criteria (must all be TRUE):**
<bulleted list from issue body or ROADMAP.md phase>

**Testing strategy declared for this phase:**
<TDD | Integration | E2E | None — and the reason/scope, or "not declared" if absent>

## Project conventions

<paste all discovered CLAUDE.md content — conventions, architectural rules, patterns>

## The diff

<paste git diff $BASE...HEAD>

## Changed files (full content for context)

<for each changed file, paste the file path and full content>

## Your job

Produce a review with this exact structure:

### Verdict
One of: **APPROVE** | **REQUEST_CHANGES** | **NEEDS_DISCUSSION**

### Acceptance criteria coverage
| Criterion | Status | Evidence |
|---|---|---|
| <criterion 1> | ✅ met / ⚠️ partial / ❌ missing | <file:line or "not addressed"> |

### Findings
Group by severity. Each finding must include `file:line` and a concrete suggestion (not just "consider rethinking").

**[CRITICAL]** — bugs, security issues, broken acceptance criteria, data loss risks
**[SHOULD-FIX]** — convention violations, missing error handling at boundaries, missed edge cases
**[NIT]** — naming, formatting, minor clarity
**[QUESTION]** — things that look intentional but you cannot verify from the diff alone

If you find no issues in a severity bucket, write "None." Do not pad.

### Tests
- Were tests added/updated where the declared testing strategy required them?
- Do the tests verify behavior through public interfaces, or do they couple to implementation?
- Any obvious untested edge cases?

### One-line summary
<single sentence — what the author should know in 10 seconds>
```

### 4. Persist the review

Write the reviewer's output to:

```
.planning/phases/<NN>-<slug>/<NN>-REVIEW.md
```

If `.planning/phases/` doesn't exist or no phase directory matches, write to `.planning/reviews/<BRANCH>-REVIEW.md` instead.

Prepend frontmatter:

```markdown
---
phase: <NN or "unknown">
issue: #<ISSUE_N or "unknown">
branch: <BRANCH>
base: <BASE>
project: <PROJECT>
reviewed_at: <ISO timestamp>
reviewer_model: <sonnet|haiku>
diff_lines: <number>
verdict: <APPROVE|REQUEST_CHANGES|NEEDS_DISCUSSION>
---
```

### 5. Print the verdict

Show the user:

```
Review complete — Verdict: <VERDICT>

Critical:    <N> findings
Should-fix:  <N> findings
Nit:         <N> findings
Question:    <N> findings

Full review: <path to REVIEW.md>

Next steps:
  - If APPROVE: gh pr create --base <BASE> --title "..." --body "Closes #<ISSUE_N>"
  - If REQUEST_CHANGES: address findings, then re-run /gsd-review
  - If NEEDS_DISCUSSION: read the questions section, decide, then proceed
```

### 6. Do NOT auto-commit the review file

Leave it untracked. The user decides whether to commit it alongside the implementation or keep it local. Some reviews contain blunt phrasing that does not belong in the public git history.

## Anti-sycophancy guarantees

These are non-negotiable in the reviewer prompt:

1. **Hide authorship** — never reveal the code came from an AI or from the same session
2. **Force severity tags** — no ungraded "consider maybe..." findings
3. **Demand a verdict** — APPROVE / REQUEST_CHANGES / NEEDS_DISCUSSION, no fence-sitting
4. **Grade against acceptance criteria** as a separate section — checks the goal, not just the code
5. **Forbid padding** — explicit "If you find no issues in a bucket, write 'None'. Do not pad."

## Cost guidance

Typical phase (Sonnet 4.6):
- Small (1–3 files, <300 line diff): ~$0.05
- Medium (4–10 files, 300–1500 line diff): ~$0.10–$0.20
- Large (>10 files, >1500 line diff): ~$0.20–$0.40 — consider splitting the phase

For sub-200-line diffs, prefer Haiku 4.5 (~$0.02). Escalate to Sonnet if Haiku flags critical issues or the phase touches high-risk pure logic (business rules, auth, data migrations).

## Notes

- **One review per branch state.** Re-running after a fix is fine and expected.
- **Do not pre-filter findings.** Pass the reviewer's verdict through verbatim — summarising it reintroduces the bias this skill exists to avoid.
- **Skip lockfiles and generated output.** Reviewing them wastes tokens and produces no signal.
- **The reviewer is not infallible.** Treat findings as a checklist to consider, not a list of mandatory changes. The author still owns the decision.
