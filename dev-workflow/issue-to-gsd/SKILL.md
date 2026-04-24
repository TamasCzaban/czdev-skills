---
name: issue-to-gsd
description: Convert a GitHub feature-slice issue into a GSD phase with its own feature branch. Use when a developer wants to start work on a GitHub issue, grab an issue from the board, or translate a GitHub issue into a GSD plan.
---

# Issue to GSD

Converts a GitHub feature-slice issue (created by `prd-to-issues`) into a GSD phase entry and a dedicated feature branch. After this skill runs, the developer continues with `/gsd:plan-phase <N>` and `/gsd:execute-phase <N>`.

## Prerequisites

- `gh` CLI must be authenticated (`gh auth status`)
- You are on the `react_refactor` branch (or ask the user which base branch to use)
- GSD is initialized (`.planning/ROADMAP.md` and `.planning/STATE.md` must exist)

## Process

### 1. Parse input

The user provides a GitHub issue number. Extract it from the invocation (e.g. `/issue-to-gsd 51`). If not provided, ask: "Which GitHub issue number do you want to start on?"

### 2. Fetch the issue

```bash
gh issue view <N> --json number,title,body,labels,assignees,state
```

Abort with a clear message if:
- Issue does not exist
- Issue is already closed
- Issue has a label of `prd` (that is the parent PRD, not a work slice — tell the user to run `/prd-to-issues <N>` first)

**Assignee check (warn-only):** After fetching, inspect the `assignees` array.
If it is non-empty and does not contain the current GitHub login (`gh api user --jq .login`), warn:

```
⚠  Issue #<N> is already assigned to <login>. Someone may already be working
   on it. Continue scaffolding a phase for yourself anyway? (y/n)
```

Wait for confirmation. If the user says no, abort cleanly. If yes, continue.

Note: this skill does **not** assign the issue to you. GitHub ownership is
claimed later when `/gsd:plan-phase` runs (step 0). Scaffold is cheap and
reversible; a public assignment is not.

### 3. Check blockers

Parse the issue body for a "Blocked by" section. The format from `prd-to-issues` is:

```
## Blocked by
- Blocked by #<N>
```

Or: "None - can start immediately"

For each blocker issue number found, run:
```bash
gh issue view <blocker-N> --json state --jq '.state'
```

If any blocker is still `OPEN`, warn the user:
> "⚠️  Issue #<blocker-N> is still open. Starting this issue now may cause merge conflicts or require rework. Do you want to proceed anyway?"

Wait for confirmation before continuing.

### 4. Determine the next phase number

Read `.planning/ROADMAP.md`. Find the highest phase number currently defined (e.g. "Phase 08" → 8). The new phase is N+1, zero-padded to two digits (e.g. `09`).

Generate a slug from the issue title:
- Lowercase
- Replace spaces and special characters with hyphens
- Max 30 characters
- Example: "Basic text search on client list" → `client-text-search`

The full phase identifier is: `<NN>-<slug>` (e.g. `09-client-text-search`)

### 5. Confirm with user

Show a summary:
```
Phase:   09 — client-text-search
Branch:  feature/51-client-text-search
Issue:   #51 "Basic text search on client list"
Base:    react_refactor

Proceed? (y/n)
```

Wait for user confirmation.

### 6. Create the feature branch

```bash
git checkout react_refactor
git pull origin react_refactor
git checkout -b feature/<issue-N>-<slug>
```

If the branch already exists, tell the user and ask whether to switch to it or abort.

### 7. Append phase to ROADMAP.md

Append a new phase section at the end of `.planning/ROADMAP.md` following the exact format used in the existing phases. Extract:

- **Goal** — from the issue title
- **Must be TRUE** — from the "Acceptance criteria" checklist items in the issue body
- **Parent Issue** — the issue number and title

Template to append:

```markdown
---

## Phase <NN>: <Issue Title>
**Status:** NOT STARTED
**Branch:** feature/<issue-N>-<slug>
**GitHub Issue:** #<issue-N>
**Base:** react_refactor

**Goal:** <issue title>

**Must be TRUE when done:**
<one bullet per acceptance criterion from the issue body>

**Parent PRD:** #<parent-prd-number from issue body, or "N/A">
**Depends on:** <blocker issue phases if any, or "None">
```

### 8. Update STATE.md

Read `.planning/STATE.md`. Find the parallel tracks table (or create one if missing). Add a row for the new phase:

```
| Phase <NN> | feature/<issue-N>-<slug> | NOT STARTED | #<issue-N> |
```

### 9. Commit the planning files

```bash
git add .planning/ROADMAP.md .planning/STATE.md
git commit -m "plan(<NN>): scaffold phase from issue #<issue-N>"
```

### 10. Tell the user what to do next

```
✅  Phase 09 scaffolded from issue #51.
    Branch: feature/51-client-text-search

Next steps:
  1. Run: /gsd:plan-phase 09
     (generates the detailed wave-based execution plans)

  2. Run: /gsd:execute-phase 09
     (implements the work with atomic commits)

  3. When gsd:verify-work passes, create a PR:
     gh pr create --title "feat: basic text search on client list" \
       --body "Closes #51" \
       --base react_refactor
```

## Notes

- **One issue = one phase = one branch.** Never put two issues in the same phase.
- **Phase numbers are per-branch.** If both Tamas and Zsombor run this at the same time, they may pick the same phase number. On merge, simply renumber one phase. The ROADMAP.md append is clean and easy to resolve.
- **Do not modify any source files.** This skill only touches `.planning/ROADMAP.md`, `.planning/STATE.md`, and creates a git branch. All source changes happen during GSD execution.
- **Do not run gsd:plan-phase yourself.** Always ask the user to run it. The planner needs fresh context about the codebase and should be run interactively.
