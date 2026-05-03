---
name: idea-to-ship
description: End-to-end pipeline from raw idea to merged, shipped code. Triggers when the user says "idea-to-ship", "/idea-to-ship", "take me from idea all the way to shipped", "one command to plan and ship this whole feature", "full send this feature", or wants grill-me → PRD → issues → GSD phases → plan → execute → review → fix → ship with a single invocation. Chains idea-to-plan and a per-phase /gsd-run-phase Agent loop. Has exactly two hard gates — the grill-me Decision Summary (inherited from idea-to-plan) and the phase-list confirmation before autonomous execution begins. Tools: [Agent, Skill, Bash, Glob, Read, Write].
---

# idea-to-ship — Full Idea → Shipped Pipeline

You are orchestrating the complete end-to-end pipeline: raw idea → Decision Summary → PRD → slice issues → GSD phases → plan → execute → capture-learnings → ship. Two skills do the work:

1. **`idea-to-plan`** (chains grill-me → write-a-prd → prd-to-issues — stops at slice issues; no branches, no ROADMAP scaffold)
2. **`gsd-execute`** (accepts the slice issue numbers, scaffolds each via issue-to-gsd, then runs plan → execute → capture-learnings → ship per phase)

This skill stitches them together with one additional gate between them. The handoff between Phase 1 and Phase 2 is **slice issue numbers**, not phase numbers — `gsd-execute` does the GSD scaffolding lazily inside its own Step 0.

## Gates (non-negotiable)

Only **two** gates exist. Both are mandatory. Never skip either.

### Gate 1 — Decision Summary (inherited from idea-to-plan)

After grill-me produces the Decision Summary, present it and ask the user to type `continue` (or equivalent) before the rest of the planning phases run. This gate is owned by `idea-to-plan` — do not short-circuit it here.

### Gate 2 — Slice-list confirmation (new; specific to this skill)

After `idea-to-plan` finishes (PRD issue + slice issues on GitHub — no branches, no ROADMAP entries yet), **stop**. Before handing off to `gsd-execute`, show the user:

```
Planning complete. About to ship end-to-end:

  PRD:    #<PRD_ISSUE>
  Slices: #<ISSUE_A>, #<ISSUE_B>, #<ISSUE_C>, ...

gsd-execute will scaffold a GSD phase + feature branch for each slice (via
issue-to-gsd), then run plan → execute → capture-learnings → ship for each.
Each phase opens a PR against `dev` and auto-merges when CI is green (unless a
HITL gate is detected — those pause for human review but do not block
subsequent phases).

Reply one of:
  • `GO`                              — run all listed slices end-to-end
  • `#<ISSUE>, #<ISSUE>, #<ISSUE>`    — run a specific subset (issue numbers)
  • `stop`                            — halt; run `/gsd-execute <issues>` manually later
```

Do not proceed until the user gives an explicit `GO` or a subset of issue numbers. Silence, "sure", "ok", or an ambiguous reply is not consent — ask once more.

Rationale: this is the last point to stop before hours of autonomous code generation across multiple PRs. The user must see the blast radius and authorize it.

## Phase overview

```
Phase 1: idea-to-plan         → Decision Summary + PRD + slice issues
   ↓ GATE 2 — user confirms slice issue list
Phase 2: gsd-execute <issues> → scaffold (issue-to-gsd) + plan → execute → learnings → ship, per slice
```

---

## Phase 1 — Plan everything (idea-to-plan)

Invoke the `idea-to-plan` skill. Follow its protocol exactly as written — do not reimplement or abbreviate. It handles its own internal gate (Gate 1, after the Decision Summary).

When `idea-to-plan` finishes, it prints a summary including `$PRD_ISSUE` and `$SLICE_ISSUES`. **Capture these values** — you need them for Gate 2 and Phase 2.

`idea-to-plan` does NOT scaffold GSD phases or create branches — that's intentional. The handoff to Phase 2 is slice issue numbers; `gsd-execute` does scaffolding lazily inside its Step 0 (via `issue-to-gsd`).

If `idea-to-plan` is interrupted mid-flight (user says "stop", cancels, or an error occurs), stop here. Do not attempt to start Phase 2. Tell the user how to resume (the resume instructions are printed by `idea-to-plan` itself).

---

## Gate 2 — Slice-list confirmation

Print the block shown in the Gates section above with real values substituted. Wait for explicit input. Parse the response:

- `GO` / `ship all` / `yes all` → run all slice issues from Phase 1
- Comma- or space-separated issue numbers → run that subset (validate each number is in `$SLICE_ISSUES` from Phase 1; warn about unknowns)
- `stop` / `halt` / `later` → exit cleanly; print `Halted after planning. Resume with /gsd-execute <issue-list>.`

---

## Phase 2 — Hand off to gsd-execute

Invoke `/gsd-execute` with the confirmed slice issue numbers. `gsd-execute` owns:

1. **Step 0 — scaffold:** for each issue number that doesn't yet have a ROADMAP entry, run `issue-to-gsd` (creates branch + ROADMAP entry + STATE.md row, sequentially to avoid phase-number races)
2. **Step 1 — classify:** run `/gsd-classify-state` over the resolved phase numbers (resume table)
3. **Step 2 — execute:** spawn `/gsd-run-phase <N>` per phase as an Agent subagent (plan → execute → review → fix → ship)

Do not duplicate scaffolding or classification here — gsd-execute handles both. Just pass the confirmed list and let it run.

```
/gsd-execute <issue-N> <issue-M> ...
```

When `gsd-execute` returns, it prints a per-phase status table. Capture it for the Final Summary below. On any `FAILED` or `BLOCKED`, do not retry inside this skill — surface them in the summary and let the user decide next steps.

Do **not** pass `--no-wait` or `--skip-tests` to gsd-execute. If you feel tempted to, reject the temptation — see Common Rationalizations.

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
  ✅ DONE:            NN, NN+1 (PR #xxx, #yyy)
  🔍 AWAITING REVIEW: NN+2  → <PR URL>
  ⚠  BLOCKED:         NN+3  → reason: <blocker>
  ❌ FAILED:          NN+4  → reason: <error> | log: .planning/phases/NN+4-.../EXEC-LOG.md

Next actions:
  • AWAITING REVIEW phases → ping reviewer / self-review PR
  • FAILED phases          → inspect error, re-run `/gsd-execute <NN>`
  • BLOCKED phases         → unblock dependency, then re-run
```

If any phase is FAILED or BLOCKED, the pipeline did NOT fully succeed — say so explicitly. Do not claim success if shipping did not complete for every authorized phase.

---

## Data passing rules

- Carry `$PRD_ISSUE` and `$SLICE_ISSUES` verbatim from Phase 1 → Gate 2 → Phase 2.
- If the user edits the slice list at Gate 2 (subset), the edited list — not the original — is what gets passed to `gsd-execute`.
- Never paraphrase issue numbers.
- Phase numbers don't exist yet at the boundary between Phase 1 and Phase 2 — they're assigned by `issue-to-gsd` inside gsd-execute Step 0. Refer to slices by issue number until then.

## On interruptions

If the user breaks off ("stop", "abort", "hold on") OR a sub-skill errors mid-flight, acknowledge the stopping point, capture whatever state has been produced so far (`$PRD_ISSUE`, `$SLICE_ISSUES`, phase numbers, last successful sub-phase), and tell the user the **exact** resume command. Be specific — vague advice ("re-run from where it stopped") forces the user to reconstruct context that you already have.

### Phase 1 (`idea-to-plan`) interruptions

| Where it stopped | What's been produced | Resume command |
|---|---|---|
| Before Gate 1 (during grill-me) | Nothing committed | `/idea-to-plan` with the original idea |
| At Gate 1 (Decision Summary shown, awaiting `continue`) | Decision Summary in conversation only | Reply `continue` to this conversation; if context is lost, paste the Decision Summary back and run `/write-a-prd` |
| Phase 2 mid-run (write-a-prd errored before issue creation) | No `$PRD_ISSUE` yet | `/write-a-prd` — pass the Decision Summary as input |
| Phase 2 after PRD created, glossary sync failed | `$PRD_ISSUE` exists; glossary may be partial | `/ubiquitous-language` to finish the glossary, then `/prd-to-issues $PRD_ISSUE` |
| Phase 3 mid-run (some slice issues created, others not) | Partial `$SLICE_ISSUES` list | List the issues already created, then `/prd-to-issues $PRD_ISSUE --resume` (or paste the remaining slices manually) |
### Between Phase 1 and Gate 2

- Slice issues created on GitHub, awaiting issue-list authorization → `/gsd-execute <issue-list>` when ready. Quote the actual issue numbers from Phase 1's summary. gsd-execute will scaffold each slice into a GSD phase + branch via issue-to-gsd before running the per-phase pipeline.

### Phase 2 (`gsd-execute`) interruptions

`gsd-execute` is **resumable per-phase**. Completed phases are already shipped (PRs merged, branches deleted). Identify which phases are DONE / FAILED / BLOCKED / not-yet-started by reading `.planning/STATE.md` and the GitHub PR list, then:

| Situation | Resume command |
|---|---|
| Plan failed for phase NN | `/gsd-execute <NN, NN+1, ...>` (will re-plan from scratch) |
| Execute failed mid-phase NN (commits on feature branch, no PR) | Inspect the branch, fix the failure, then `bash "$HOME/.claude/skills/gsd/scripts/ship-phase.sh" --phase NN`; afterwards `/gsd-execute <NN+1, NN+2, ...>` for the rest |
| capture-learnings failed (dirty tree, no LEARNINGS commit) | Re-run `/gsd:capture-learnings <NN>` to land the commit, then ship as above |
| Ship failed at CI gate (PR open, CI red) | Push fixes to the same feature branch; CI re-runs; `gh pr merge <N> --squash --delete-branch` once green; then `/gsd-execute <remaining>` |
| Ship hit HITL gate (exit 4) | PR is open and assigned. Reviewer approves and merges manually; `gsd-execute` already continued with later phases |

**Never** retry a fully-shipped phase — re-running ship on a merged PR will corrupt `.planning/STATE.md` with a duplicate entry.

## Common Rationalizations

Reject all of these — they exist because they are tempting and wrong.

| Rationalization | Why it's wrong |
|---|---|
| "The user already approved the Decision Summary — I can skip Gate 2." | Gate 1 approves the *design*. Gate 2 approves the *blast radius* (hours of code generation, multiple PRs, branches in the repo). Different authorizations. |
| "The slice list is obvious from Phase 1's output — I'll auto-proceed to gsd-execute." | Never. Gate 2 is the last stop before autonomous multi-PR execution. Always require explicit consent. |
| "The user said 'ship it' earlier — that covers Gate 2." | Consent is scoped to the moment. Unless the user literally said `GO` after seeing the actual slice list from Phase 1, it does not count. |
| "While Phase 1 is running I'll have the slicer also call issue-to-gsd, so Phase 2 has less to do." | The architecture deliberately defers branch creation to gsd-execute Step 0. Scaffolding inside Phase 1 puts branches on the repo for slices the user may decline at Gate 2. Don't undermine the gate. |
| "I'll pass `--no-wait` to gsd-execute to speed things up." | `--no-wait` skips CI gating. CI failing after merge is how broken code reaches `dev`. Never. |
| "I'll pass `--skip-tests` since the waves already ran tests." | Ship-phase's local test gate is the belt to execute-phase's suspenders. They catch different things (fresh venv, full suite, CI-relevant env). Keep both. |
| "If one phase FAILs, I should stop the whole pipeline." | `gsd-execute` already continues with remaining phases by design — independent slices shouldn't block each other. Let it run. Surface failures in the final summary. |
| "HITL gates are a drag — I'll edit plans to remove the HITL flag." | HITL flags exist for destructive migrations, secrets, visual UI, new dependencies. Removing them means unreviewed production changes. Never. |
| "I'll re-interview the user during Phase 1 even though they already gave context here." | grill-me inside idea-to-plan is the interview. Don't double-interview. The Decision Summary is the artifact; trust it. |

---

## Verification

Before declaring the pipeline complete, confirm every item:

- [ ] Gate 1: user typed `continue` after the Decision Summary (not assumed).
- [ ] Phase 1: `$PRD_ISSUE` created, `$SLICE_ISSUES` created in dependency order on GitHub. **No GSD phases scaffolded, no branches created** — verify `git branch --list 'feat/*'` shows no new branches.
- [ ] Gate 2: user explicitly authorized the slice list (`GO` or subset of issue numbers) — not assumed, not inferred from earlier messages.
- [ ] Phase 2: `/gsd-execute` was invoked once with the authorized issue list. gsd-execute owns scaffolding, classification, and per-phase execution.
- [ ] Every DONE phase has a merged PR; learnings captured inside the subagent (or `NO_LEARNINGS` genuine).
- [ ] Final summary printed with accurate status per phase, PR URLs for AWAITING REVIEW, and next-actions for non-DONE phases.
- [ ] If any phase is FAILED or BLOCKED, the report says so explicitly rather than implying full success.

## Related Skills

- `idea-to-plan` — Phase 1 of this pipeline (chains grill-me → PRD subagent → slicer subagent; stops at slice issues)
- `gsd-execute` — Phase 2: scaffolds + executes the per-phase loop (issue-to-gsd → gsd-run-phase × N)
- `/gsd-run-phase` — per-phase pipeline (spawned as Agent subagent inside gsd-execute; handles plan → execute → review → fix → ship)
- `issue-to-gsd` — invoked by gsd-execute Step 0 to scaffold each slice into a GSD phase + branch
- `gsd:capture-learnings` — auto-invoked inside /gsd-plan-execute; appends non-obvious lessons before ship
