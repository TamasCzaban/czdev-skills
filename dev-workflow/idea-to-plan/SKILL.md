---
name: idea-to-plan
description: Full pipeline from raw idea to actionable GSD plan with GitHub tracking. Triggers when the user says "idea-to-plan", "/idea-to-plan", "let's kick off a new feature", "I have an idea I want to build out", "take me through the full planning pipeline", or wants to go from idea → PRD → issues → GSD phases in one session. Phase 1 (grill-me Decision Summary) has a user gate. Phase 2 (write-a-prd) runs inside an Opus PRD-writer subagent (high-reasoning translation from Decision Summary to formal PRD). Phases 3-4 (prd-to-issues + issue-to-gsd) run inside a Sonnet slicer-scaffolder subagent (mechanical decomposition). Glossary updates are batched into a single commit at the end. Tools: [Agent, Skill, Bash, Glob, Read, Write].
---

# idea-to-plan — Full Feature Planning Pipeline

You are orchestrating a four-phase pipeline that takes a raw idea all the way to GSD-ready execution phases. **Only Phase 1 has a hard gate** — once the user approves the Decision Summary, Phase 2 (PRD-writer subagent on Opus) and Phases 3-4 (slicer-scaffolder subagent on Sonnet) run automatically without pausing for confirmation.

## Phase overview

```
Phase 1: grill-me       → Decision Summary  [GATE — user says "continue"]   (orchestrator: Opus)
Phase 2: write-a-prd    → PRD GitHub issue   PRD-writer subagent (Opus, fresh context)
Phase 3: prd-to-issues  → Vertical slices    ↑  Slicer-scaffolder subagent
Phase 4: issue-to-gsd   → GSD phases         ↓  (Sonnet, fresh context)
                        + Glossary batch commit (if new_terms non-empty)
```

**Two-tier subagent split** (since the post-Phase-205 model alignment): write-a-prd is reasoning-heavy (translating a high-level Decision Summary into a self-contained PRD with 20+ user stories, deep-module sketch, edge cases, testing decisions, codebase reconciliation) — run on **Opus**. prd-to-issues and issue-to-gsd are mechanical decomposition (PRD → vertical slices → branches + ROADMAP entries) — run on **Sonnet**. The split prevents Opus from doing tedious GitHub scaffolding while keeping the high-leverage conceptual work on the strongest model.

Flags:
- `--parallel` — spawn all per-feature PRD pipelines concurrently (multi-feature ideas only). Each pipeline is still two subagents internally.

---

## Phase 1 — Interview (grill-me)

**Enter plan mode first** — call `EnterPlanMode` before doing anything else. This triggers Opus for the interview, which is the highest-reasoning step in the pipeline.

**Locate the grill-me skill** by searching for `grill-me/SKILL.md` in the global skills directory (`~/.claude/skills/`) or the project's `.claude/skills/` directory. Read and follow the full protocol as written. Do not abbreviate. The Decision Summary it produces is the contract that all later phases build on.

**Gate:** After the Decision Summary is produced, present it clearly and ask:

> "That covers the major decisions. Review this and flag anything that needs revisiting. When you're ready to turn this into a PRD, say **continue**."

Do not proceed to Phase 2 until the user says continue (or equivalent).

**Exit plan mode** — call `ExitPlanMode` immediately after the user says continue, before Phase 2 starts. Phase 2 runs on **Opus** inside the PRD-writer subagent; Phases 3-4 run on **Sonnet** inside the slicer-scaffolder subagent.

---

## Phase 1.5 — Resume check (classifier)

Between Gate 1 and Stage 1 (PRD-writer) spawning: run `/gsd-classify-state` for any phases that the Decision Summary implies already exist in `.planning/ROADMAP.md`. This detects partial planning runs.

If phases for this feature already exist in ROADMAP.md:
- All show `PLANNED_NOT_EXECUTED` or later → planning is complete; tell user and exit. Resume with `/gsd-run-phase <N>` or `/gsd-execute <phases>`.
- Some show `PLANNED_NOT_EXECUTED`, others `NOT_STARTED` → partial scaffold; print the resume table, ask user `[Y to resume remaining / N to skip / stop]`.
- None exist → planning is fresh; proceed to Stage 1 (PRD-writer) spawning.

Auto-proceed to Stage 1 spawning (no prompt) if no classifier hit (phases not yet in ROADMAP).

## Phase 2-4 — Two-stage subagent pipeline (per feature)

After the user approves the Decision Summary (and classifier confirms no prior scaffold exists), identify the features to build from the Decision Summary. In most cases this is a single feature → one PRD-writer + one slicer-scaffolder, run sequentially. Multi-feature ideas produce multiple per-feature pipelines (each still two subagents).

**Check for parallel-safe label** (multi-feature case only): If a seed PRD issue was pre-created on GitHub with a `parallel-safe` label, run `gh issue view <N> --json labels` to detect it. If the label is present (or if `--parallel` flag was passed), spawn the per-feature pipelines concurrently. Otherwise, run them sequentially (default). Within a single pipeline, the slicer-scaffolder subagent ALWAYS runs after the PRD-writer subagent returns (the slicer needs `$PRD_ISSUE`).

### Stage 1: Spawn the PRD-writer subagent

Use the `Agent` tool. **Model: Opus.** Prompt (must be ≤2k chars):

```
You are the PRD author for a feature. Decision Summary:

<paste the Decision Summary verbatim — trim to ≤1200 chars if needed to stay under 2k total>

Your job (no user input needed):
Locate write-a-prd skill at .claude/skills/write-a-prd/SKILL.md — follow it:
- Skip steps 1 and 3 (interview already done — use Decision Summary above)
- Run steps 2, 4, 5: explore the repo to verify Decision Summary assertions, sketch deep modules with narrow interfaces, write and submit the PRD as a GitHub issue

The PRD must be self-contained — a future Claude session reading only this issue (no Decision Summary, no this-conversation context) must have everything needed to slice and scaffold. Cover problem statement, solution, 20+ user stories, implementation decisions, testing decisions, out-of-scope, further notes.

After the PRD issue is created, return:

{"prd_issue":<n>,"new_terms":["term1",...],"summary_md":"≤3k: PRD title, problem, key implementation decisions, any deviations from the Decision Summary"}

new_terms: domain terms flagged by write-a-prd as not yet in Ubiquitous Language.md.
Mark terms as "architecture" if they are layer/infra terms (not domain nouns).
Return [] if write-a-prd found no new terms to formalize.
```

Wait for the PRD-writer to return. Parse the JSON. Capture `$PRD_ISSUE` and `$NEW_TERMS`.

### Stage 2: Spawn the slicer-scaffolder subagent

Use the `Agent` tool. **Model: Sonnet.** Prompt (must be ≤2k chars):

```
You are the issue-slicer + GSD-scaffolder for PRD #$PRD_ISSUE.

Your job (run in order, no user input needed):
1. Read the PRD: gh issue view $PRD_ISSUE --json title,body,labels --jq '{title,body,labels:[.labels[].name]}'
2. Locate prd-to-issues skill at .claude/skills/prd-to-issues/SKILL.md — follow it:
   - Skip step 1 (you have $PRD_ISSUE)
   - Skip step 4 (quiz) — derive granularity and dependencies from the PRD body alone (prefer thin vertical slices, one per independent file or concern)
   - Run steps 2, 3, 5: optional codebase verification, draft slices, create slice issues in dependency order
3. Locate issue-to-gsd skill at .claude/skills/issue-to-gsd/SKILL.md — follow it:
   - Run sequentially for each slice issue (dependency order, blockers first)
   - Determine the next phase number, generate a branch slug, create the branch, append to ROADMAP.md, update STATE.md, commit

After all slice issues and GSD phases are scaffolded, return:

{"prd_issue":$PRD_ISSUE,"slice_issues":[<n>,...],"phases":[<n>,...],"branches":["feat/N-slug",...],"summary_md":"≤3k: slice count, phase range, dependency order, any deviations from the PRD's implementation decisions"}
```

Wait for the slicer-scaffolder to return. Parse the JSON. Merge `prd_issue`, `slice_issues`, `phases`, `branches` from this return with `new_terms` captured in Stage 1 — that is the per-feature pipeline result.

---

## Glossary batch commit

After ALL per-feature pipelines have returned (i.e., every PRD-writer + slicer-scaffolder pair has finished):

1. Collect `new_terms` from each PRD-writer's Stage-1 JSON return.
2. Remove terms tagged "architecture" (they don't belong in the domain glossary).
3. If the merged list is non-empty: invoke the `ubiquitous-language` skill with the merged terms list. Single commit:
   ```
   git commit -m "docs(glossary): formalize terms from PRDs #X, #Y, ..."
   ```
4. If all terms were architecture-layer (or the list is empty): skip silently — no commit.

Rationale: glossary drift accumulates if each PRD updates it inline. Batching once at the end avoids write conflicts and produces a single, reviewable commit.

---

## Final summary

```
Pipeline complete.

PRD:    #$PRD_ISSUE
Slices: #X, #Y, #Z, ...
Phases: NN, NN+1, NN+2, ...

Next steps for each phase:
  /gsd-run-phase <NN>      — plan, execute, review, and ship in one command
  — or —
  /gsd:plan-phase <NN>     — plan only
  /gsd:execute-phase <NN>  — execute only
  /gsd-ship-phase <NN>     — ship with review gate (use --skip-review for doc-only PRs)
```

---

## Data passing rules

- Carry the Decision Summary verbatim into each PRD-writer subagent — do not paraphrase
- $PRD_ISSUE flows from Stage 1 (PRD-writer) → Stage 2 (slicer-scaffolder) within a single per-feature pipeline. Pass it explicitly in the Stage 2 prompt.
- The slicer-scaffolder reads the PRD body via `gh issue view` rather than re-receiving the Decision Summary. The PRD is the contract for slicing; the Decision Summary is upstream of it.
- If the user makes changes during the gate (rewording, removing scope), update your carried Decision Summary before spawning Stage 1
- Do NOT pass `new_terms` from one feature's PRD-writer into another's — each derives its own list from write-a-prd independently; the orchestrator merges after all pipelines return

## Parallel mode

Sequential is the default because:
1. Parallel pipelines may produce conflicting ROADMAP.md phase numbers
2. Parallel pipelines may produce conflicting Ubiquitous Language.md edits
3. Most ideas produce a single PRD — parallelism buys nothing

Trigger parallel mode only when:
- User passes `--parallel` explicitly, OR
- A seed GitHub issue has the `parallel-safe` label (which means a human already confirmed no ROADMAP conflicts)

In parallel mode, spawn all per-feature **PRD-writer** subagents in one message (multiple Agent tool calls — one per feature). Wait for ALL Stage-1 returns. Then spawn all slicer-scaffolder subagents in one message. This staging matters: slicer-scaffolders need their PRD issue numbers from Stage 1, and a feature's slicer must not start before its own PRD is written. Two-stage parallel = two waves of concurrent Agent calls, not one wave of mixed-stage calls.

## On interruptions

If the user breaks off mid-pipeline ("let's stop here", "I'll handle the rest later"), acknowledge the stopping point and tell them exactly which command to run to resume:

- Stopped after Phase 1 (Decision Summary approved, no PRD-writer spawned yet): "Resume by running `/write-a-prd` with the Decision Summary above"
- Stopped after PRD-writer returned but before slicer-scaffolder spawned: "Resume with `/prd-to-issues $PRD_ISSUE`" — this picks up at Stage 2 manually
- Stopped after slicer created slices but before issue-to-gsd ran: "Resume with `/issue-to-gsd <issue-N>` for each open slice in dependency order"

---

## Common Rationalizations

These are excuses you might generate to skip or collapse pipeline phases. Reject them.

| Rationalization | Why it's wrong |
|---|---|
| "The idea is simple — I can skip the PRD and go straight to issues." | Scope creep originates in undocumented assumptions. The PRD is the contract. |
| "The Decision Summary already covers everything — I'll write a minimal PRD." | The PRD is for GitHub. It must be self-contained for future Claude sessions. |
| "I'll combine multiple concerns into one slice issue to keep the list short." | Fat issues produce fat PRs. Preserve thin vertical slice granularity. |
| "I already know the codebase — I'll skip repo exploration in the PRD-writer." | The Decision Summary is based on what the user said, not what the code does. The PRD-writer's repo exploration catches contradictions before they become bad PRD assumptions. |
| "The user said continue quickly — I'll skip the gate." | Phase 1 has exactly one gate. Never skip it. |
| "I'll run the PRD-writer without the full Decision Summary to save prompt space." | The PRD-writer needs the full contract. Trim other prompt sections first. |
| "I'll merge the PRD-writer and slicer-scaffolder back into one subagent to save an Agent call." | Two-tier model split exists for a reason — the writer runs Opus for high-leverage conceptual work, the slicer runs Sonnet for mechanical decomposition. Re-merging burns Opus tokens on tedious GitHub scaffolding. |
| "I'll run the slicer-scaffolder on Opus too, just to be safe." | Slicing a PRD into vertical issues is templated work. Sonnet is fine. Reserve Opus for the writer where its judgment actually moves the needle. |

---

## Verification

Before declaring the pipeline complete, confirm every item:

- [ ] Phase 1: Decision Summary produced and user approved it explicitly (said "continue" or equivalent)
- [ ] Stage 1 (PRD-writer, Opus): spawned via Agent tool with ≤2k prompt; returned JSON with `prd_issue`, `new_terms`, `summary_md`
- [ ] Stage 2 (slicer-scaffolder, Sonnet): spawned via Agent tool with ≤2k prompt; returned JSON with `prd_issue`, `slice_issues`, `phases`, `branches`, `summary_md`
- [ ] Glossary batch: `/ubiquitous-language` ran once (if non-architecture new_terms exist), or silently skipped
- [ ] Glossary batch commit: `docs(glossary): formalize terms from PRDs #X, ...` (or skipped)
- [ ] Final summary: PRD issue, all slice issue numbers, all phase numbers, exact resume commands
- [ ] No duplicate ROADMAP.md phase numbers produced (verify if parallel mode was used)
- [ ] PRD-writer ran on Opus (not Sonnet/Haiku) — this is the high-leverage conceptual step
- [ ] Slicer-scaffolder ran on Sonnet (not Opus) — Opus on mechanical scaffolding is wasted budget
