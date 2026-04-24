---
name: idea-to-plan
description: Full pipeline from raw idea to actionable GSD plan with GitHub tracking. Triggers when the user says "idea-to-plan", "/idea-to-plan", "let's kick off a new feature", "I have an idea I want to build out", "take me through the full planning pipeline", or wants to go from idea → PRD → issues → GSD phases in one session. This skill chains grill-me → write-a-prd → prd-to-issues → issue-to-gsd. Only Phase 1 (grill-me Decision Summary) has a user gate — Phases 2, 3, and 4 run automatically after approval.
---

# idea-to-plan — Full Feature Planning Pipeline

You are orchestrating a four-phase pipeline that takes a raw idea all the way to GSD-ready execution phases. **Only Phase 1 has a hard gate** — once the user approves the Decision Summary, run Phases 2, 3, and 4 automatically without pausing for confirmation.

## Phase overview

```
Phase 1: grill-me       → Decision Summary
Phase 2: write-a-prd    → PRD GitHub issue
Phase 3: prd-to-issues  → Vertical slice GitHub issues
Phase 4: issue-to-gsd   → GSD phases + feature branches
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

## Phase 4 — GSD scaffold (issue-to-gsd)

**Locate the issue-to-gsd skill** at `.claude/skills/issue-to-gsd/SKILL.md` within the project.

> **Ownership note:** `issue-to-gsd` warns if an issue is already assigned to someone else but does **not** write an assignment itself — scaffold is reversible, a public GitHub assignment is not. GitHub ownership is claimed automatically when the user later runs `/gsd:plan-phase <NN>` (step 0 of that skill).

Run issue-to-gsd **sequentially** for each issue in `$SLICE_ISSUES`, in dependency order (blockers first). For each issue:

1. Follow the full issue-to-gsd protocol (fetch issue, check blockers, determine phase number, create branch, append ROADMAP.md, update STATE.md, commit)
2. **No per-issue confirmation** — scaffold all issues automatically without pausing.
3. The issue-to-gsd protocol automatically determines a **Testing Strategy** for each phase by reading the project's CLAUDE.md and inspecting which files the issue touches. The strategy is written into each ROADMAP.md phase entry. When the strategy is None, the reason is recorded so it is explicit and reviewable, not silent.

After all issues are processed, print a final summary:

```
Pipeline complete.

PRD:    #$PRD_ISSUE
Slices: #X, #Y, #Z, ...
Phases: NN, NN+1, NN+2, ...

Next steps for each phase:
  /gsd:plan-phase <NN>
  /gsd:execute-phase <NN>
  /gsd-review            # fresh-context reviewer before opening the PR
  gh pr create ...
```

---

## Data passing rules

- Carry the Decision Summary verbatim into Phase 2 — do not paraphrase
- Carry `$PRD_ISSUE` from Phase 2 into Phase 3 and Phase 4
- Carry `$SLICE_ISSUES` from Phase 3 into Phase 4
- If the user makes changes during any gate (rewording, removing scope, etc.) — update your carried data before proceeding

## On interruptions

If the user breaks off mid-pipeline ("let's stop here", "I'll handle the rest later"), acknowledge the stopping point and tell them exactly which command to run to resume:

- Stopped after Phase 1: "Resume by running `/write-a-prd` with the Decision Summary above"
- Stopped after Phase 2: "Resume by running `/prd-to-issues $PRD_ISSUE`"
- Stopped after Phase 3: "Resume by running `/issue-to-gsd <issue-N>` for each open slice"

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
| "Phases 3 and 4 are mechanical — I'll run them in parallel or out of order." | Phase 4 depends on issue numbers from Phase 3. Phase 3 depends on the PRD issue from Phase 2. Dependency order is not optional. |

---

## Verification

Before declaring the pipeline complete, confirm every item:

- [ ] Phase 1: Decision Summary produced and user approved it explicitly (said "continue" or equivalent)
- [ ] Phase 2: PRD GitHub issue created — URL printed, `$PRD_ISSUE` recorded
- [ ] Phase 3: All slice issues created in dependency order (blockers first) — issue numbers recorded as `$SLICE_ISSUES`
- [ ] Phase 3: Each slice issue references `$PRD_ISSUE` as its parent
- [ ] Phase 4: One feature branch created per slice issue — branch names follow project convention
- [ ] Phase 4: ROADMAP.md updated with a phase entry for each issue, including Testing Strategy field (None must be explicit with reason, not silent)
- [ ] Phase 4: STATE.md updated to reflect next executable phase
- [ ] Phase 4: All scaffold commits pushed or staged — no orphaned local-only branches
- [ ] Final summary printed with PRD issue, all slice issue numbers, all phase numbers, and exact resume commands
