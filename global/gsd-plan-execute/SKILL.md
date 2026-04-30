---
name: gsd-plan-execute
description: Bundle /gsd:plan-phase + /gsd:execute-phase (which auto-invokes /gsd:capture-learnings) into a single command. Commits all work to the feature branch but never pushes — orchestrator owns the push/PR/merge decision after the review gate. Designed for orchestrator subagent use; emits a parseable JSON object on completion. Use when /gsd:run-phase or another orchestrator needs to plan + execute a phase end-to-end without taking the ship step. Triggers on "/gsd-plan-execute", "plan and execute phase N without shipping", "executor subagent entry".
---

# /gsd-plan-execute — Plan + Execute Bundle

Bundles `/gsd:plan-phase` and `/gsd:execute-phase` into one invocation. The **executor subagent's entry point** in the multi-agent context architecture (PRD #500). Commits all work to the current feature branch but does **NOT push** — the orchestrator that called this skill owns the push/PR/merge decision after the review gate (`/gsd-review-phase`) runs separately.

## Invocation

```
/gsd-plan-execute <N>
```

Where `<N>` is a phase number from `.planning/ROADMAP.md`.

## Process

### Step 0 — Preflight

Verify all of:
- Currently on a feature branch (not main / master / dev / uat)
- `.planning/ROADMAP.md` has an entry for phase `N`
- The current branch matches the ROADMAP's `**Branch:**` field for phase `N`
- Working tree is clean (no uncommitted, unstashed changes that aren't part of this phase)

If any check fails, emit failure JSON and exit non-zero. Do not modify any source files.

### Step 1 — Plan

Invoke `/gsd:plan-phase <N>`. Wait for `PLAN.md` to be written to `.planning/phases/<NN>-<slug>/PLAN.md`. If no PLAN.md is produced (planner errored, no waves emitted), abort with `status: "FAILED"` and `error: "plan-phase failed: <reason>"`.

### Step 2 — Execute

Invoke `/gsd:execute-phase <N>`. The execute-phase skill auto-invokes `/gsd:capture-learnings <N>` as its step 7 before its internal ship step. **This skill must intercept and prevent the ship step from running** — the orchestrator owns shipping.

Practically: pass `--no-ship` (or equivalent flag) to `/gsd:execute-phase`, OR run only the wave-execution + capture-learnings sub-steps and skip the ship invocation. If `/gsd:execute-phase` does not support stopping before ship, this skill must catch the ship invocation and short-circuit it.

If execute-phase fails mid-wave, emit `status: "FAILED"` with whatever was committed and the failing wave/task identified.

### Step 3 — Verify clean state

After execute completes:
- Confirm feature branch has new commits relative to its base
- Confirm working tree is clean (no uncommitted changes)
- Capture diff stats: `files_changed` (count), `diff_lines` (additions + deletions), `tests_passed` (boolean from execute-phase output)

### Step 4 — Emit JSON

Final stdout must contain a fenced JSON block (no other content after this block):

```json
{
  "phase": 196,
  "status": "DONE",
  "branch": "feature/501-gsd-plan-execute",
  "files_changed": 7,
  "diff_lines": 312,
  "tests_passed": true,
  "artifacts": {
    "plan": ".planning/phases/196-gsd-plan-execute/PLAN.md",
    "exec_log": ".planning/phases/196-gsd-plan-execute/EXEC-LOG.md",
    "learnings": ".planning/phases/196-gsd-plan-execute/LEARNINGS.md"
  },
  "summary_md": "Brief recap of what changed and why. ≤5k chars target, ≤10k hard cap. No diff content, no full plan, no full review findings — pointers only."
}
```

`status` is one of: `DONE` (success), `FAILED` (any step errored), `BLOCKED` (preflight failed).

`summary_md` rules: target ≤5k chars, hard cap 10k. Describe what changed and why at a level useful to a reviewer. Do **not** include diff content, full plan content, or detailed wave-by-wave traces — those live on disk under `.planning/phases/<NN>-<slug>/` and are pointed at via `artifacts`.

## Failure modes

| Symptom | JSON status | Notes |
|---|---|---|
| Preflight fails (wrong branch, no ROADMAP entry) | `BLOCKED` | No source changes made. |
| `/gsd:plan-phase` fails | `FAILED` | `error` field gives reason. No execute attempted. |
| `/gsd:execute-phase` fails mid-wave | `FAILED` | Whatever was committed stays on the branch. Failing wave noted in `error`. |
| `/gsd:capture-learnings` fails | `FAILED` | Tree is dirty (LEARNINGS commit didn't land). User must run `/gsd:capture-learnings <N>` manually then re-run from this point. |
| Working tree dirty after execute | `FAILED` | Indicates incomplete commit; orchestrator must investigate before shipping. |
| No commits relative to base | `FAILED` | execute-phase produced no changes — likely a no-op plan. |

## Why this skill exists

In the multi-agent context architecture (PRD #500), the orchestrator's `/gsd:run-phase` helper spawns this skill as the **executor subagent** with a ≤2k prompt (role, task, pointers, return JSON schema). This skill does the heavy work — codebase exploration, plan generation, wave execution, learnings capture — entirely in its own ≤200k Sonnet context, then dies. Only the ≤10k JSON return reaches the orchestrator.

After this skill returns, the orchestrator spawns a fresh-context **reviewer subagent** (`/gsd-review-phase`) that sees only the diff + acceptance criteria — never this executor's reasoning. If the review verdict is `APPROVE`, the orchestrator runs ship. If `REQUEST_CHANGES`, the orchestrator spawns a **fixer subagent** (`/gsd-fix-phase`) and re-reviews.

For manual users: this skill is also invokable directly. Run `/gsd-plan-execute 196` to plan + execute phase 196 without shipping. Useful when you want to inspect the diff before pushing.

## Related

- `/gsd:plan-phase` — invoked as Step 1
- `/gsd:execute-phase` — invoked as Step 2 (which auto-invokes `/gsd:capture-learnings`)
- `/gsd-review-phase` — adversarial review, runs AFTER this skill
- `/gsd-fix-phase` — fixes issues raised by review
- `/gsd:run-phase` — orchestrator helper that spawns this skill as a subagent
- `/gsd:ship-phase` — runs after review APPROVE; pushes, opens PR, auto-merges
