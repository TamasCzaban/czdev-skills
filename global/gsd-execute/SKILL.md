---
name: gsd-execute
description: "Meta pipeline: plan → execute → ship for one or more phases in sequence. Trigger when: user says /gsd-execute, /gsd execute, 'plan execute and ship phases X Y Z', 'run phases X through Y', 'do phases X Y Z end to end'. Parses a phase list, skips blocked phases, and runs the full plan→execute→ship pipeline for each unblocked phase in order."
version: 1.0.0
triggers: [/gsd-execute, gsd execute, plan execute ship, run phases end to end]
tools: [Bash, Glob, Grep, Read, Write, Agent, Skill]
---

# gsd-execute — Plan → Execute → Ship Pipeline

Runs the full `plan-phase → execute-phase → ship` cycle for a list of phases.
Skips blocked phases, handles HITL gates gracefully, and reports a summary at the end.

## Invocation

```
/gsd-execute 28, 29, 30
/gsd-execute 28-30
/gsd-execute 28 29 30
```

## Step 0 — Parse & validate the phase list

Extract all phase numbers from the args. Accept any separator (comma, space, dash range).

Examples:
- `28, 29, 30` → [28, 29, 30]
- `28-30` → [28, 29, 30]
- `28 30` → [28, 30]

Read `.planning/ROADMAP.md` to confirm each phase exists. If a phase number is not
found in the roadmap, warn and skip it — do not abort the whole run.

## Step 1 — Blocker check

For each phase, scan its ROADMAP.md entry for any of these signals:
- `Status: Blocked` or `blocked by #N`
- `Depends on: <phase>` where that dependency phase is not yet in STATE.md as shipped
- `⛔` or `🚧` emoji in the phase title

If a phase is blocked: print `⚠ Phase NN blocked — skipping` and remove it from
the run queue. Continue with the remaining phases.

If **all** phases are blocked: stop here and tell the user which blockers exist.

## Step 2 — For each unblocked phase, run the full pipeline

Process phases **sequentially** (each phase may depend on the previous one's output).

For each phase `N` in the queue:

### 2a. Plan
```
/gsd:plan-phase N
```
- Wait for the plan to complete and PLAN.md to be written.
- If planning fails (no PLAN.md produced, planner errors): mark phase N as FAILED,
  skip execute + ship for it, continue to next phase.

### 2b. Execute
```
/gsd:execute-phase N
```
- Run all waves to completion.
- `execute-phase` now **automatically invokes `/gsd:capture-learnings N` as its step 7**, before its internal ship step. No action needed here; just be aware a `docs(learnings): phase N lessons` commit may land on the feature branch.
- If execution fails: mark phase N as FAILED, do not attempt ship, continue.
- If capture-learnings fails: execute-phase will report it and NOT ship. Mark phase N as FAILED (capture), continue to next phase.

### 2c. Ship
```
bash "$HOME/.claude/skills/gsd/scripts/ship-phase.sh" --phase N
```

Handle exit codes:
- **0** → shipped. Mark phase N as DONE. Continue to next phase.
- **1** (test failure) → mark FAILED. Print the failing test output. Continue.
- **2** (CI failure) → mark FAILED. Print CI link. Continue.
- **3** (preflight failure) → mark FAILED. Explain (dirty tree, wrong branch, etc.). Continue.
- **4** (HITL gate) → mark AWAITING REVIEW. Print: `🔍 Phase NN requires human review — PR is open, reviewer assigned. Continuing with remaining phases.` Continue.

## Step 3 — Summary report

After all phases have been processed, print a compact table:

```
┌─────────┬──────────────────────────────┬─────────────────────┐
│ Phase   │ Title                        │ Status              │
├─────────┼──────────────────────────────┼─────────────────────┤
│ 28      │ Remove Facebook OAuth/CSP    │ ✅ DONE             │
│ 29      │ Settings UX polish           │ ✅ DONE             │
│ 30      │ Audit log UI                 │ 🔍 AWAITING REVIEW  │
│ 31      │ Stripe webhook hardening     │ ⚠ BLOCKED           │
└─────────┴──────────────────────────────┴─────────────────────┘
```

Then print any follow-up actions needed:
- For AWAITING REVIEW phases: list the PR URL and what the reviewer must check
- For FAILED phases: list the error and recommended next step
- For BLOCKED phases: list what unblocks them

## Rules

- Never run `git merge` directly — the ship script handles all git operations via PR.
- Never skip the ship step — a phase with local commits but no merged PR is not done.
- If the ship script is missing: fall back to the manual flow in
  `~/.claude/skills/gsd/references/git-integration/SKILL.md` but warn the user.
- HITL gate = stop shipping that phase, NOT the whole run. Other phases continue.
- After the run, update `.planning/STATE.md` for any phase not already updated by
  the ship script (e.g., FAILED phases need a failure note).

## Related Skills

@skills/gsd/commands/plan-phase — Plans a single phase
@skills/gsd/commands/execute-phase — Executes a single phase (includes ship step)
@skills/gsd/scripts/ship-phase.sh — Automated PR + merge + cleanup script
@skills/gsd/references/git-integration — Manual ship fallback
