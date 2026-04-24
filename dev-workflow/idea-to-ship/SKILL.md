---
name: idea-to-ship
description: End-to-end pipeline from raw idea to merged, shipped code. Triggers when the user says "idea-to-ship", "/idea-to-ship", "take me from idea all the way to shipped", "one command to plan and ship this whole feature", "full send this feature", or wants grill-me → PRD → issues → GSD phases → plan → execute → capture-learnings → ship with a single invocation. Chains idea-to-plan and gsd-execute. Has exactly two hard gates — the grill-me Decision Summary (inherited from idea-to-plan) and the phase-list confirmation before autonomous execution begins.
---

# idea-to-ship — Full Idea → Shipped Pipeline

You are orchestrating the complete end-to-end pipeline: raw idea → Decision Summary → PRD → slice issues → GSD phases → plan → execute → capture-learnings → ship. Two skills do the work:

1. **`idea-to-plan`** (already chains grill-me → write-a-prd → prd-to-issues → issue-to-gsd)
2. **`gsd-execute`** (already chains plan-phase → execute-phase → capture-learnings → ship for every phase)

This skill stitches them together with one additional gate between them.

## Gates (non-negotiable)

Only **two** gates exist. Both are mandatory. Never skip either.

### Gate 1 — Decision Summary (inherited from idea-to-plan)

After grill-me produces the Decision Summary, present it and ask the user to type `continue` (or equivalent) before the rest of the planning phases run. This gate is owned by `idea-to-plan` — do not short-circuit it here.

### Gate 2 — Phase-list confirmation (new; specific to this skill)

After `idea-to-plan` finishes (PRD issue + slice issues + GSD phases + feature branches all scaffolded), **stop**. Before handing off to `gsd-execute`, show the user:

```
Planning complete. About to ship end-to-end:

  PRD:    #<PRD_ISSUE>
  Slices: #<ISSUE_A>, #<ISSUE_B>, #<ISSUE_C>, ...
  Phases: <NN>, <NN+1>, <NN+2>, ...

gsd-execute will run plan → execute → capture-learnings → ship for each phase
in sequence. Each phase opens a PR against `dev` and auto-merges when CI is
green (unless a HITL gate is detected — those pause for human review but do not
block subsequent phases).

Reply one of:
  • `GO`                    — run all listed phases end-to-end
  • `<N>, <N+1>, <N+2>`     — run a specific subset
  • `<N>-<M>`               — run a range
  • `stop`                  — halt; run `/gsd-execute` manually later
```

Do not proceed until the user gives an explicit `GO`, a phase list, or a range. Silence, "sure", "ok", or an ambiguous reply is not consent — ask once more.

Rationale: this is the last point to stop before hours of autonomous code generation across multiple PRs. The user must see the blast radius and authorize it.

## Phase overview

```
Phase 1: idea-to-plan     → Decision Summary + PRD + issues + GSD phases
   ↓ GATE 2 — user confirms phase list
Phase 2: gsd-execute N-M  → plan → execute → learnings → ship, per phase
```

---

## Phase 1 — Scaffold everything (idea-to-plan)

Invoke the `idea-to-plan` skill. Follow its protocol exactly as written — do not reimplement or abbreviate. It handles its own internal gate (Gate 1, after the Decision Summary).

When `idea-to-plan` finishes, it prints a summary including `$PRD_ISSUE`, `$SLICE_ISSUES`, and the list of phase numbers created. **Capture these values** — you need them for Gate 2 and Phase 2.

If `idea-to-plan` is interrupted mid-flight (user says "stop", cancels, or an error occurs), stop here. Do not attempt to start Phase 2. Tell the user how to resume (the resume instructions are printed by `idea-to-plan` itself).

---

## Gate 2 — Phase-list confirmation

Print the block shown in the Gates section above with real values substituted. Wait for explicit input. Parse the response:

- `GO` / `ship all` / `yes all` → run all phases from Phase 1
- Comma-, space-, or dash-separated numbers → run that subset (validate each number is in the list from Phase 1; warn about unknowns)
- `stop` / `halt` / `later` → exit cleanly; print `Halted after planning. Resume with /gsd-execute <phase-list>.`

---

## Phase 2 — Autonomous execution (gsd-execute)

Invoke the `gsd-execute` skill with the confirmed phase list. It already:

- Skips blocked phases with a warning
- Runs `/gsd:plan-phase → /gsd:execute-phase → /gsd:capture-learnings → ship-phase.sh` per phase
- Handles HITL gates (exit 4) by leaving a PR open with reviewer assigned and continuing with remaining phases
- Prints a summary table at the end (DONE / AWAITING REVIEW / FAILED / BLOCKED)

Do **not** pass any flags that bypass safety (`--no-wait`, `--skip-tests`). If you feel tempted to, reject the temptation — see Common Rationalizations.

---

## Final summary

After `gsd-execute` returns, print a single consolidated report:

```
idea-to-ship complete.

Planning:
  PRD:          #<PRD_ISSUE>
  Slice issues: #X, #Y, #Z, ...
  Phases:       NN, NN+1, NN+2, ...

Execution (gsd-execute summary):
  ✅ DONE:            NN, NN+1
  🔍 AWAITING REVIEW: NN+2  → <PR URL>
  ⚠  BLOCKED:         NN+3  → reason: <blocker>
  ❌ FAILED:          NN+4  → reason: <error>

Next actions:
  • AWAITING REVIEW phases → ping reviewer / self-review PR
  • FAILED phases          → inspect error, re-run `/gsd-execute <NN>`
  • BLOCKED phases         → unblock dependency, then re-run
```

If any phase is FAILED or BLOCKED, the pipeline did NOT fully succeed — say so explicitly. Do not claim success if shipping did not complete for every authorized phase.

---

## Data passing rules

- Carry `$PRD_ISSUE`, `$SLICE_ISSUES`, and the phase number list verbatim from Phase 1 to Gate 2 to Phase 2.
- If the user edits the phase list at Gate 2 (subset or range), the edited list — not the original — is what gets passed to `gsd-execute`.
- Never paraphrase issue numbers or phase numbers.

## On interruptions

If the user breaks off ("stop", "abort", "hold on"), acknowledge and tell them the exact resume command:

- During Phase 1 (before Gate 1): "Resume with `/idea-to-plan` and paste your original idea."
- After Gate 1, during idea-to-plan sub-phases: "Resume with the specific sub-skill — see idea-to-plan's own interrupt guidance."
- After Phase 1, before Gate 2: "Resume with `/gsd-execute <phase-list>` when ready."
- During Phase 2: "gsd-execute has already started. Completed phases are merged. Resume the remaining ones with `/gsd-execute <remaining phases>`."

## Common Rationalizations

Reject all of these — they exist because they are tempting and wrong.

| Rationalization | Why it's wrong |
|---|---|
| "The user already approved the Decision Summary — I can skip Gate 2." | Gate 1 approves the *design*. Gate 2 approves the *blast radius* (hours of code generation, multiple PRs). Different authorizations. |
| "The phase list is obvious from Phase 1's output — I'll auto-proceed to gsd-execute." | Never. Gate 2 is the last stop before autonomous multi-PR execution. Always require explicit consent. |
| "The user said 'ship it' earlier — that covers Gate 2." | Consent is scoped to the moment. Unless the user literally said `GO` after seeing the actual phase list from Phase 1, it does not count. |
| "I'll pass `--no-wait` to gsd-execute to speed things up." | `--no-wait` skips CI gating. CI failing after merge is how broken code reaches `dev`. Never. |
| "I'll pass `--skip-tests` since the waves already ran tests." | Ship-phase's local test gate is the belt to execute-phase's suspenders. They catch different things (fresh venv, full suite, CI-relevant env). Keep both. |
| "If one phase FAILs, I should stop the whole pipeline." | `gsd-execute` already continues with remaining phases by design — independent slices shouldn't block each other. Let it run. Surface failures in the final summary. |
| "HITL gates are a drag — I'll edit plans to remove the HITL flag." | HITL flags exist for destructive migrations, secrets, visual UI, new dependencies. Removing them means unreviewed production changes. Never. |
| "I'll re-interview the user during Phase 1 even though they already gave context here." | grill-me inside idea-to-plan is the interview. Don't double-interview. The Decision Summary is the artifact; trust it. |

---

## Verification

Before declaring the pipeline complete, confirm every item:

- [ ] Gate 1: user typed `continue` after the Decision Summary (not assumed).
- [ ] Phase 1: `$PRD_ISSUE` created, `$SLICE_ISSUES` created in dependency order, all phases scaffolded with feature branches and ROADMAP entries.
- [ ] Gate 2: user explicitly authorized the phase list (`GO`, subset, or range) — not assumed, not inferred from earlier messages.
- [ ] Phase 2: `gsd-execute` ran for the authorized phases (no more, no less).
- [ ] Every DONE phase has a merged PR and a `docs(learnings): phase NN lessons` commit (or `NO_LEARNINGS` was genuine — no commit).
- [ ] Final summary printed with accurate status per phase, PR URLs for AWAITING REVIEW, and next-actions for non-DONE phases.
- [ ] If any phase is FAILED or BLOCKED, the report says so explicitly rather than implying full success.

## Related Skills

- `idea-to-plan` — Phase 1 of this pipeline (itself chains grill-me → write-a-prd → prd-to-issues → issue-to-gsd)
- `gsd-execute` — Phase 2 of this pipeline (itself chains plan → execute → capture-learnings → ship per phase)
- `gsd:capture-learnings` — auto-invoked inside gsd-execute; appends non-obvious lessons to `LEARNINGS.md` before each ship
