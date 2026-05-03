---
name: idea-to-plan
description: Full pipeline from raw idea to a board of grabbable GitHub slice issues. Triggers when the user says "idea-to-plan", "/idea-to-plan", "let's kick off a new feature", "I have an idea I want to build out", "take me through the full planning pipeline", or wants to go from idea → PRD → grabbable GitHub issues in one session. This skill chains grill-me → write-a-prd → prd-to-issues. Only Phase 1 (grill-me Decision Summary) has a user gate — Phases 2 and 3 run automatically after approval. Stops at slice issues on purpose: GSD phase scaffolding and branch creation happen later, lazily, when /gsd-execute starts work on them — keeps the repo clean of branches for slices that may sit on the board for weeks.
---

# idea-to-plan — Full Feature Planning Pipeline

You are orchestrating a three-phase pipeline that takes a raw idea all the way to a board of grabbable GitHub slice issues. **Only Phase 1 has a hard gate** — once the user approves the Decision Summary, run Phases 2 and 3 automatically without pausing for confirmation.

This skill stops at slice issues on purpose. Branches, ROADMAP entries, and STATE.md scaffolding all happen later in `/gsd-execute`'s Step 0, when work actually begins. That keeps the repo clean of branches for work that may sit on the board for days, weeks, or never start at all.

## Phase overview

```
Phase 1: grill-me       → Decision Summary
Phase 2: write-a-prd    → PRD GitHub issue
Phase 3: prd-to-issues  → Vertical slice GitHub issues

→ Hand off to /gsd-execute <issue-N> <issue-M> ... when ready to start work.
  (gsd-execute scaffolds GSD phases + branches lazily via issue-to-gsd.)
```

---

## Phase 1 — Interview (grill-me)

**Enter plan mode first** — call `EnterPlanMode` before doing anything else. This triggers Opus for the interview, which is the highest-reasoning step in the pipeline.

**Locate the grill-me skill** by searching for `grill-me/SKILL.md` in the global skills directory (`~/.claude/skills/`) or the project's `.claude/skills/` directory. Read and follow the full protocol as written. Do not abbreviate. The Decision Summary it produces is the contract that all later phases build on.

**Gate:** After the Decision Summary is produced, present it clearly and ask:

> "That covers the major decisions. Review this and flag anything that needs revisiting. When you're ready to turn this into a PRD, say **continue**."

Do not proceed to Phase 2 until the user says continue (or equivalent).

**Exit plan mode** — call `ExitPlanMode` immediately after the user says continue, before Phase 2 starts. Phases 2–4 run on Sonnet.

---

## Phase 2 — PRD (write-a-prd)

**Locate the write-a-prd skill** at `.agents/skills/write-a-prd/SKILL.md` within the project.

**Critical: skip steps 1 and 3** of write-a-prd. The user interview is already done (Phase 1). Jump directly to:

- **Step 2** — Explore the repo to verify assertions from the Decision Summary
- **Step 4** — Sketch major modules (no user confirmation needed — proceed immediately to Step 5)
- **Step 5** — Write and submit the PRD as a GitHub issue using the template

Use the Decision Summary as the source of truth for the problem statement, solution, and user stories. Do not re-interview.

**Record:** Capture the created PRD issue number as `$PRD_ISSUE`.

**No gate** — after creating the issue, print the URL and proceed immediately to Phase 3.

---

## Phase 3 — Slice issues (prd-to-issues)

**Locate the prd-to-issues skill** at `.agents/skills/prd-to-issues/SKILL.md` within the project.

**Skip step 1** — you already have `$PRD_ISSUE` from Phase 2. Pass it directly.

**Skip step 4 (quiz)** — derive granularity and dependencies from the Decision Summary and codebase exploration without asking the user. Use your judgment: prefer thin vertical slices, one per independent file or concern.

Run steps 2, 3, and 5:
- Explore codebase if not already done
- Draft vertical slices based on the Decision Summary
- Create GitHub issues in dependency order

**Record:** Capture all created slice issue numbers as `$SLICE_ISSUES` (ordered list).

**No gate** — after creating all slice issues, proceed immediately to Phase 4.

---

## Final summary

After Phase 3 finishes, print:

```
Planning complete.

PRD:    #$PRD_ISSUE
Slices: #X, #Y, #Z, ...

No GSD phases scaffolded, no branches created — the repo stays clean while
slices sit on the board. Branches are created lazily by /gsd-execute when
work actually starts.

Next step — when you're ready to start work:
  /gsd-execute X Y Z           — scaffolds + plans + executes + ships each
                                 issue end-to-end (issue numbers accepted directly)
  — or, one issue at a time —
  /issue-to-gsd <issue-N>      — manually scaffold one issue (creates branch,
                                 ROADMAP entry, STATE.md row); then
  /gsd-run-phase <phase-N>     — plan + execute + review + ship that one phase
```

---

## Data passing rules

- Carry the Decision Summary verbatim into Phase 2 — do not paraphrase
- Carry `$PRD_ISSUE` from Phase 2 into Phase 3
- If the user makes changes during the Phase 1 gate (rewording, removing scope, etc.) — update the Decision Summary before proceeding

## On interruptions

If the user breaks off mid-pipeline ("let's stop here", "I'll handle the rest later"), acknowledge the stopping point and tell them exactly which command to run to resume:

- Stopped after Phase 1: "Resume by running `/write-a-prd` with the Decision Summary above"
- Stopped after Phase 2: "Resume by running `/prd-to-issues $PRD_ISSUE`"
- Stopped after Phase 3 (some slices created, others not): "Resume by manually creating the remaining slice issues, or by re-running `/prd-to-issues $PRD_ISSUE` and skipping the ones already on the board"

---

## Common Rationalizations

These are excuses you might generate to skip or collapse pipeline phases. Reject them.

| Rationalization | Why it's wrong |
|---|---|
| "The idea is simple — I can skip the PRD and go straight to issues." | Scope creep and missing edge cases originate in undocumented assumptions. The PRD is the contract, not overhead. |
| "The Decision Summary already covers everything — I'll write a minimal PRD." | The PRD is for GitHub, not for you. It must be self-contained so future contributors (and future Claude sessions) have full context without reading this conversation. |
| "I'll combine multiple concerns into one slice issue to keep the list short." | Thin vertical slices exist so each issue maps to a reviewable PR. Fat issues produce fat PRs. Preserve granularity. |
| "I already know the codebase well enough — I'll skip the repo exploration in Phase 2." | The Decision Summary is based on what the user said, not on what the code actually does. Exploration catches contradictions before they become bad PRD assumptions. |
| "The user said continue quickly — I'll auto-approve and skip the gate." | Phase 1 has exactly one gate for a reason. The Decision Summary is the only point where the user can correct the direction before hours of downstream work are scaffolded. Never skip it. |
| "Phase 3 is mechanical — I'll run it before Phase 2 finishes." | Phase 3 depends on the PRD issue from Phase 2. Dependency order is not optional. |
| "While I'm here, I'll go ahead and run issue-to-gsd to scaffold the GSD phases too — saves the user a step." | No. The whole point of stopping at slice issues is to keep the repo clean of branches for work that may not start for weeks (or ever). Running issue-to-gsd here defeats the architecture. /gsd-execute calls issue-to-gsd lazily when work begins. |

---

## Verification

Before declaring the pipeline complete, confirm every item:

- [ ] Phase 1: Decision Summary produced and user approved it explicitly (said "continue" or equivalent)
- [ ] Phase 2: PRD GitHub issue created — URL printed, `$PRD_ISSUE` recorded
- [ ] Phase 3: All slice issues created in dependency order (blockers first) — issue numbers recorded as `$SLICE_ISSUES`
- [ ] Phase 3: Each slice issue references `$PRD_ISSUE` as its parent
- [ ] Final summary printed with PRD issue + slice issue numbers + the `/gsd-execute <slices>` resume command
- [ ] **No GSD phases scaffolded, no branches created** — verify `git branch --list 'feat/*'` shows no new branches and `git status` is clean
