---
name: gsd-classify-state
description: Classify a GSD phase's current state by inspecting disk + git + GitHub. Returns JSON {phase, classification, reasons[]} with one of 8 classifications. Used as the resume-from-disk classifier at orchestrator startup (/gsd-execute, /idea-to-ship, /idea-to-plan). Triggers on "/gsd-classify-state", "classify phase state", "what state is phase N in", "resume-from-disk check".
---

# /gsd-classify-state — Phase State Classifier

Inspects a GSD phase's current state from disk, git, and GitHub, and returns a structured classification. Called by orchestrators at startup to build a resume table before deciding whether to auto-resume or prompt the user.

## Invocation

```
/gsd-classify-state <N>
```

Or call multiple in one session:

```
/gsd-classify-state 28 29 30 31
```

## Classification table

| Branch state | PR state | REVIEW.md | Classification |
|---|---|---|---|
| No branch exists | — | — | `NOT_STARTED` |
| Branch exists, no PLAN.md in phases dir | — | — | `STARTED_NOT_PLANNED` |
| Branch exists, has PLAN.md, no commits ahead of base | — | — | `PLANNED_NOT_EXECUTED` |
| Branch exists, has commits ahead of base | No PR | No REVIEW.md | `EXECUTED_NOT_REVIEWED` |
| Branch exists, has commits ahead of base | No PR | REVIEW.md exists with REQUEST_CHANGES verdict | `NEEDS_FIX` |
| Branch exists, has commits ahead of base | PR open, CI failing | — | `AWAITING_REVIEW` |
| Branch exists, has commits ahead of base | PR open, CI green | — | `READY_TO_MERGE` |
| No branch (deleted) | PR merged | — | `DONE` |

## Detection process

For each phase N:

### 1. Read ROADMAP entry

```bash
grep -A 20 "^## Phase ${N}:" .planning/ROADMAP.md
```

Extract:
- `**Branch:**` → branch name (e.g. `feature/505-gsd-run-phase`)
- `**GitHub Issue:**` → issue number (e.g. `#505`)
- `**Base:**` → base branch (default: `dev`)

If phase not found in ROADMAP: return `classification: "NOT_FOUND"`.

### 2. Check branch existence

```bash
git branch --list "$BRANCH_NAME"
git ls-remote --heads origin "$BRANCH_NAME"
```

If no local or remote branch: `NOT_STARTED` (unless a merged PR exists — see step 4).

### 3. Check PLAN.md and commits

```bash
PLAN_PATH=".planning/phases/${NN}-${SLUG}/PLAN.md"
COMMITS_AHEAD=$(git rev-list --count "${BASE}..${BRANCH_NAME}" 2>/dev/null || echo 0)
```

- No branch AND no merged PR → `NOT_STARTED`
- Branch exists, no PLAN.md → `STARTED_NOT_PLANNED`
- Branch exists, PLAN.md exists, `$COMMITS_AHEAD == 0` → `PLANNED_NOT_EXECUTED`
- Branch exists, `$COMMITS_AHEAD > 0` → continue to step 4

### 4. Check PR state

```bash
gh pr list --head "$BRANCH_NAME" --json number,state,statusCheckRollup,mergedAt \
  --base "$BASE" 2>/dev/null
```

- No PR found → check REVIEW.md (step 5)
- PR merged → `DONE`
- PR open, CI failing → `AWAITING_REVIEW` (reasons: CI failure)
- PR open, CI green or no CI → `READY_TO_MERGE`

### 5. Check REVIEW.md (only when commits exist but no PR)

```bash
REVIEW_PATH=".planning/phases/${NN}-${SLUG}/REVIEW.md"
```

Read REVIEW.md frontmatter if it exists. Look for `verdict:` field.

- No REVIEW.md → `EXECUTED_NOT_REVIEWED`
- REVIEW.md exists, `verdict: REQUEST_CHANGES` → `NEEDS_FIX`
- REVIEW.md exists, `verdict: APPROVE` → `READY_TO_MERGE` (reviewer approved but not yet shipped)
- REVIEW.md exists, `verdict: NEEDS_DISCUSSION` → `AWAITING_REVIEW`

## Output

Return a JSON block per phase:

```json
{
  "phase": 28,
  "classification": "NEEDS_FIX",
  "branch": "feature/230-some-feature",
  "base": "dev",
  "issue": 230,
  "plan_exists": true,
  "commits_ahead": 4,
  "pr": null,
  "review_verdict": "REQUEST_CHANGES",
  "fix_iterations_used": 1,
  "reasons": [
    "Branch exists with 4 commits ahead of dev",
    "REVIEW.md exists with verdict REQUEST_CHANGES",
    "FIX-LOG.md shows 1 fix iteration already completed"
  ]
}
```

For multiple phases, return an array. For single phase invocation, return the single object.

`fix_iterations_used`: count entries in FIX-LOG.md (`## Fix iteration` headers). 0 if no FIX-LOG.md.

## Resume table format

When called by an orchestrator, print the resume table in this format:

```
Phase 28: ✅ DONE (PR #481 merged)
Phase 29: ✅ DONE (PR #482 merged)
Phase 30: 🔧 NEEDS_FIX (REVIEW.md exit 5, 1/2 fix attempts used)
Phase 31: ⏳ NOT_STARTED
```

Emoji mapping:
- `✅` — DONE, READY_TO_MERGE
- `🔧` — NEEDS_FIX
- `🔍` — AWAITING_REVIEW
- ⏳ — NOT_STARTED, PLANNED_NOT_EXECUTED
- `⚠` — STARTED_NOT_PLANNED, EXECUTED_NOT_REVIEWED, NOT_FOUND

## Orchestrator integration

Orchestrators call this classifier at startup for each requested phase:

```
Auto-resume (no user prompt):
  - All phases are DONE → nothing to do; tell user
  - All phases are NOT_STARTED → start from first; proceed immediately

Explicit confirmation required (ask [Y/n/specific phase]):
  - Any phase in STARTED_NOT_PLANNED (could mean crash or experimentation)
  - Any phase in NEEDS_FIX with fix_iterations_used ≥ 1
  - Any phase in EXECUTED_NOT_REVIEWED (commits but no PR and no review)
  - Phase numbering gaps or unexpected ordering
  - Branch has uncommitted changes (detected separately via git status)
```

On confirmation:
- `Y` or `yes` → proceed from the first non-DONE phase as classified
- `n` or `stop` → exit cleanly with resume instructions
- `<N>` → jump directly to that phase number

## Why this skill exists

In the multi-agent context architecture (PRD #500), orchestrators may be re-run after a previous run was interrupted (crashed, HITL-halted, fix-loop capped). Without a classifier, the orchestrator must either start from scratch (wasting work) or rely on the user to manually specify which phase to resume from.

This classifier answers "where are we?" from first principles — no memory of the prior session needed. The orchestrator can then auto-resume for clean states or ask a targeted question for ambiguous ones.

## Related

- `/gsd-execute` — calls this at Step 1
- `idea-to-ship` — calls this before Phase 2 Agent loop
- `idea-to-plan` — calls this before PRD subagent spawning
- `/gsd-run-phase` — per-phase pipeline (its status is what this classifier reads)
