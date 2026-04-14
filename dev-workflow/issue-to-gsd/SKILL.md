---
name: issue-to-gsd
description: Convert a GitHub feature-slice issue into a GSD phase with its own feature branch. Use when a developer wants to start work on a GitHub issue, grab an issue from the board, or translate a GitHub issue into a GSD plan.
---

# Issue to GSD

Converts a GitHub feature-slice issue (created by `prd-to-issues`) into a GSD phase entry and a dedicated feature branch. After this skill runs, the developer continues with `/gsd:plan-phase <N>` and `/gsd:execute-phase <N>`.

## Prerequisites

- `gh` CLI must be authenticated (`gh auth status`)
- GSD is initialized (`.planning/ROADMAP.md` and `.planning/STATE.md` must exist)

## Process

### 1. Parse input

The user provides a GitHub issue number. Extract it from the invocation (e.g. `/issue-to-gsd 51`). If not provided, ask: "Which GitHub issue number do you want to start on?"

### 2. Detect the base branch

```bash
BASE=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null \
  || git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' \
  || echo "main")
```

If the detected base does not match the current working branch context (e.g. project uses a long-lived integration branch like `develop` or `react_refactor`), ask the user to confirm: "Base branch detected as `$BASE` — is that correct?"

### 3. Fetch the issue

```bash
gh issue view <N> --json number,title,body,labels,assignees,state
```

Abort with a clear message if:
- Issue does not exist
- Issue is already closed
- Issue has a label of `prd` (that is the parent PRD, not a work slice — tell the user to run `/prd-to-issues <N>` first)

### 4. Check blockers

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

### 5. Determine the next phase number

Read `.planning/ROADMAP.md`. Find the highest phase number currently defined (e.g. "Phase 08" → 8). The new phase is N+1, zero-padded to two digits (e.g. `09`).

Generate a slug from the issue title:
- Lowercase
- Replace spaces and special characters with hyphens
- Max 30 characters
- Example: "Basic text search on client list" → `client-text-search`

The full phase identifier is: `<NN>-<slug>` (e.g. `09-client-text-search`)

### 6. Confirm with user

Show a summary:
```
Phase:   09 — client-text-search
Branch:  feature/51-client-text-search
Issue:   #51 "Basic text search on client list"
Base:    <BASE>

Proceed? (y/n)
```

Wait for user confirmation.

### 7. Create the feature branch

```bash
git checkout <BASE>
git pull origin <BASE>
git checkout -b feature/<issue-N>-<slug>
```

If the branch already exists, tell the user and ask whether to switch to it or abort.

### 8. Determine testing strategy

Before writing the ROADMAP entry, analyse the files this issue will touch (from the issue body's "Files to change" section, or infer from the issue title/labels if absent).

**Step 1 — Read project context.** Check for a `CLAUDE.md` in the project root and any subdirectory CLAUDE.md files. Look for a declared test framework (e.g. in `package.json`, `pyproject.toml`, `go.mod`) and any existing test conventions.

**Step 2 — Apply the universal heuristic:**

| Code type | Strategy | Reasoning |
|---|---|---|
| Pure functions / utilities with no I/O or external deps | **TDD** | Fastest feedback loop — input→output, fully deterministic |
| Backend handlers / API routes / database access / external service calls | **Integration** | Requires real or emulated external system; mocking adds no value |
| UI components / pages / user-facing flows | **E2E** | Behavior only verifiable through the rendered interface |
| Config / constants / type definitions / generated files / i18n strings | **None** | No executable behavior to test |

**Step 3 — Fill in the tool.** Once the strategy is known, name the specific tool from the project's stack:
- TDD → the unit test runner in `package.json`/`pyproject.toml` (e.g. Vitest, Jest, pytest, Go test)
- Integration → the project's integration test setup (e.g. Firebase Emulator, Docker Compose, test database)
- E2E → the project's E2E tool (e.g. Playwright, Cypress, Selenium)
- None → write a one-sentence reason

If the issue touches **multiple layers**, list a strategy per layer.

Record the result as `$TESTING_STRATEGY` to embed in the ROADMAP entry.

### 9. Append phase to ROADMAP.md

Append a new phase section at the end of `.planning/ROADMAP.md` following the exact format used in the existing phases. Extract:

- **Goal** — from the issue title
- **Must be TRUE** — from the "Acceptance criteria" checklist items in the issue body
- **Parent Issue** — the issue number and title
- **Testing Strategy** — from step 8

Template to append:

```markdown
---

## Phase <NN>: <Issue Title>
**Status:** NOT STARTED
**Branch:** feature/<issue-N>-<slug>
**GitHub Issue:** #<issue-N>
**Base:** <BASE>

**Goal:** <issue title>

**Must be TRUE when done:**
<one bullet per acceptance criterion from the issue body>

**Testing Strategy:** <TDD | Integration | E2E | None>
<If TDD: list the specific behaviors/functions to cover>
<If Integration: list which handlers/endpoints/hooks to exercise>
<If E2E: list the user flows to cover (golden path + key edge cases)>
<If None: one-sentence reason>

**Parent PRD:** #<parent-prd-number from issue body, or "N/A">
**Depends on:** <blocker issue phases if any, or "None">
```

### 10. Update STATE.md

Read `.planning/STATE.md`. Find the parallel tracks table (or create one if missing). Add a row for the new phase:

```
| Phase <NN> | feature/<issue-N>-<slug> | NOT STARTED | #<issue-N> |
```

### 11. Commit the planning files

```bash
git add .planning/ROADMAP.md .planning/STATE.md
git commit -m "plan(<NN>): scaffold phase from issue #<issue-N>"
```

### 12. Tell the user what to do next

```
✅  Phase <NN> scaffolded from issue #<issue-N>.
    Branch: feature/<issue-N>-<slug>

Next steps:
  1. Run: /gsd:plan-phase <NN>
     (generates the detailed wave-based execution plans)

  2. Run: /gsd:execute-phase <NN>
     (implements the work with atomic commits)

  3. Run: /gsd-review
     (independent fresh-context reviewer — checks acceptance criteria + flags issues)

  4. Address any CRITICAL or SHOULD-FIX findings, then:
     gh pr create --title "feat: <slug>" \
       --body "Closes #<issue-N>" \
       --base <BASE>
```

## Notes

- **One issue = one phase = one branch.** Never put two issues in the same phase.
- **Phase numbers are per-branch.** If two developers run this simultaneously, they may pick the same number. On merge, renumber one phase — the ROADMAP.md append is clean and easy to resolve.
- **Do not modify any source files.** This skill only touches `.planning/ROADMAP.md`, `.planning/STATE.md`, and creates a git branch. All source changes happen during GSD execution.
- **Do not run gsd:plan-phase yourself.** Always ask the user to run it. The planner needs fresh context about the codebase and should be run interactively.
