---
name: gsd-execute
description: "Meta pipeline: plan → execute → review → fix → ship for one or more phases in sequence. Trigger when: user says /gsd-execute, /gsd execute, 'plan execute and ship phases X Y Z', 'run phases X through Y', 'do phases X Y Z end to end'. Parses a phase list, skips blocked phases, and for each unblocked phase spawns /gsd-run-phase as a subagent via the Agent tool. Orchestrator only sees compact JSON returns (≤10k each); full plan/execute/review transcripts live on disk."
version: 2.0.0
triggers: [/gsd-execute, gsd execute, plan execute ship, run phases end to end]
tools: [Bash, Glob, Grep, Read, Write, Agent, Skill]
---

# gsd-execute — Plan → Execute → Review → Ship Pipeline

Runs the full per-phase pipeline for a list of GSD phases by spawning `/gsd-run-phase <N>` as a subagent for each phase. The orchestrator carries only compact JSON status summaries (≤10k per phase) — it never holds plan content, execute traces, or review findings in its context.

## Invocation

```
/gsd-execute 28, 29, 30          # phase numbers (existing scaffolds)
/gsd-execute 28-30               # phase number range
/gsd-execute 591 592 593         # GitHub issue numbers (from /idea-to-plan)
```

The args may be either GSD phase numbers (already scaffolded in `.planning/ROADMAP.md`) OR raw GitHub issue numbers fresh out of `/idea-to-plan`. The skill disambiguates each input automatically — you never need to flag which kind they are.

## Step 0 — Parse, classify, and scaffold

Extract all numbers from the args. Accept any separator (comma, space, dash range). Examples:
- `28, 29, 30` → [28, 29, 30]
- `28-30` → [28, 29, 30]
- `591 592 593` → [591, 592, 593]

For each number `N`, classify it:

1. **Phase number?** Check `.planning/ROADMAP.md` for a `## Phase N:` heading. If present → already scaffolded, continue.
2. **Issue number?** Run `gh issue view <N> --json number,state` (cheap call). If the issue exists → it's an unscaffolded slice from `/idea-to-plan`.
3. **Neither?** Print `⚠ <N> not found as phase or GitHub issue — skipping` and drop it.

For each input classified as an unscaffolded issue, invoke the **`issue-to-gsd`** skill via the `Skill` tool — pass the issue number. `issue-to-gsd` creates the feature branch, appends a phase entry to `.planning/ROADMAP.md`, updates `.planning/STATE.md`, and commits the planning files. Run these scaffolding calls **sequentially** (issue-to-gsd writes to ROADMAP.md, so parallel calls would race on phase numbering). After each call returns, capture the new phase number from the resulting ROADMAP entry — that is what the rest of this skill operates on.

Why scaffolding lives here, not in `/idea-to-plan`: `/idea-to-plan` produces GitHub issues that may sit on the board for days or weeks before someone starts work. Creating branches at planning time means the repo accumulates branches for work that may never start (or get re-prioritised). Branches are cheap if created lazily at execution start, and the repo stays clean.

After Step 0, the run queue contains only resolved phase numbers, all of which now have ROADMAP entries and feature branches.

## Step 1 — Classifier (resume-from-disk)

For each phase in the validated list, classify its current state using the classifier
skill `/gsd-classify-state <N>` (if available) or by inspecting disk + git + gh directly:

| Branch state | PR state | REVIEW.md | Classification |
|---|---|---|---|
| no branch | — | — | NOT_STARTED |
| exists, no PLAN.md | — | — | STARTED_NOT_PLANNED |
| exists, has PLAN.md, no commits | — | — | PLANNED_NOT_EXECUTED |
| exists, has commits | none | none | EXECUTED_NOT_REVIEWED |
| exists, has commits | none | exists, REQUEST_CHANGES | NEEDS_FIX |
| exists, has commits | open, CI red | — | AWAITING_REVIEW (CI fail) |
| exists, has commits | open, CI green | — | READY_TO_MERGE |
| — | merged | — | DONE |

Print the resume table:

```
Phase 28: ✅ DONE (PR #481 merged)
Phase 29: ⏳ NOT_STARTED
Phase 30: 🔧 NEEDS_FIX (REVIEW.md exit 5, 1/2 fix attempts used)
Phase 31: ⏳ NOT_STARTED
```

**Auto-resume** (no user prompt) if all phases are DONE or NOT_STARTED.

**Explicit confirmation** (ask `[Y/n/specific phase]`) if any phase has ambiguous state:
- Branch exists with uncommitted changes
- Phase in STARTED_NOT_PLANNED state
- Phase in NEEDS_FIX with ≥1 fix iteration already used
- Phase numbering jumps unexpectedly

## Step 2 — Blocker check

For each NOT_STARTED or EXECUTED_NOT_REVIEWED phase, scan its ROADMAP.md entry for:
- `Status: Blocked` or `blocked by #N`
- `Depends on: <phase>` where that dependency phase is not yet shipped
- `⛔` or `🚧` emoji in the phase title

If a phase is blocked: print `⚠ Phase NN blocked — skipping` and remove it from
the run queue. Continue with the remaining phases.

If **all** phases are blocked: stop and tell the user which blockers exist.

**Dynamic re-evaluation:** After each phase reaches DONE, re-check any SKIPPED phases.
If a skipped phase was blocked only by the just-shipped phase, add it back to the end
of the run queue.

## Step 3 — Per-phase: spawn /gsd-run-phase

Process phases **sequentially** (each may depend on the previous one's output).

For each phase `N` in the run queue:

Print: `\n━━━ Phase N — Starting pipeline ━━━`

Spawn `/gsd-run-phase <N>` via the **`Agent` tool**. Prompt (keep ≤2k chars):

```
You are running the per-phase pipeline for GSD phase <N>. Your job:
1. Run /gsd-run-phase <N>
2. Return the JSON block it emits verbatim.

Context pointers (read these yourself):
- Phase ROADMAP entry: .planning/ROADMAP.md (search "## Phase <N>:")
- Project conventions: CLAUDE.md files in repo root and .claude/

Return format (JSON, ≤10k):
{"phase":<N>,"status":"DONE"|"AWAITING_REVIEW"|"FAILED"|"BLOCKED","pr_url":"...","fix_iterations":<n>,"review_verdict":"...","summary_md":"..."}
```

Wait for the return. Parse JSON. Handle:

| `status` | Action |
|---|---|
| `DONE` | Mark phase DONE. Continue to next phase. Dynamic re-eval of skipped phases. |
| `AWAITING_REVIEW` | Mark AWAITING_REVIEW. Print `summary_md` + next-step instructions. Continue to next phase. |
| `FAILED` | Mark FAILED. Dump last 2k of subagent output + log path. Ask user: `[s]kip and continue / [a]bort run`. Default: skip and continue after 30s. |
| `BLOCKED` | Mark BLOCKED. Continue to next phase. |

**On subagent failure / no JSON returned:**

```
⚠ Phase <N> — subagent returned no parseable JSON.
Last 2k of output: <tail of subagent stdout>
Full log: .planning/phases/<NN>-<slug>/EXEC-LOG.md (if it exists)
Direction: [s]kip and continue / [a]bort / inspect manually
```

Wait for input. Default to skip after 30 seconds.

## Step 4 — Summary report

After all phases have been processed:

```
┌─────────┬──────────────────────────────────────────┬─────────────────────┐
│ Phase   │ Title                                    │ Status              │
├─────────┼──────────────────────────────────────────┼─────────────────────┤
│ 28      │ Remove Facebook OAuth/CSP                │ ✅ DONE (PR #481)   │
│ 29      │ Settings UX polish                       │ ✅ DONE (PR #482)   │
│ 30      │ Audit log UI                             │ 🔍 AWAITING REVIEW  │
│ 31      │ Stripe webhook hardening                 │ ⚠ BLOCKED           │
└─────────┴──────────────────────────────────────────┴─────────────────────┘
```

Then print any follow-up actions:
- For AWAITING_REVIEW phases: PR URL + what reviewer must check
- For FAILED phases: error summary + recommended next step
- For BLOCKED phases: what unblocks them

## Rules

- Never run `git merge` directly — /gsd-run-phase handles all git operations via PR.
- Never skip the ship step — a phase with local commits but no merged PR is not done.
- HITL gate = stop shipping that phase, NOT the whole run. Other phases continue.
- After the run, update `.planning/STATE.md` for any phase not already updated by the ship script.
- Do NOT pass `--no-wait` or `--skip-tests` to underlying skills unless the user explicitly requested speed over safety.

## Related Skills

- `/gsd-run-phase` — per-phase pipeline (spawned as subagent per phase)
- `/gsd-plan-execute` — executor subagent (spawned inside /gsd-run-phase)
- `/gsd-review-phase` — reviewer subagent (spawned inside /gsd-run-phase)
- `/gsd-fix-phase` — fixer subagent (spawned inside /gsd-run-phase fix loop)
- `/gsd-ship-phase` — ship step (invoked inside /gsd-run-phase)
- `/gsd-classify-state` — resume-from-disk classifier (Step 1)
