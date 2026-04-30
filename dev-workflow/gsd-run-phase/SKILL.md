---
name: gsd-run-phase
description: Per-phase pipeline helper — encapsulates the full executor → reviewer → (fixer + reviewer)×0-2 → ship loop for a single phase. Spawns each subagent via the Agent tool with a ≤2k prompt; subagents return ≤10k JSON. Designed as the single shared module called by both /gsd-execute and /idea-to-ship orchestrators after Phase 201 refactor. Also manually invokable. Triggers on "/gsd-run-phase", "/gsd:run-phase", "run phase N end-to-end", "ship phase N with review".
---

# /gsd-run-phase — Per-Phase Pipeline (Executor → Reviewer → Fix-Loop → Ship)

Encapsulates the complete per-phase pipeline for one GSD phase. The orchestrator (`/gsd-execute`, `/idea-to-ship`) spawns this skill as a subagent per phase; it does all the heavy work and returns a compact JSON result. Also manually invokable for individual phases.

## Invocation

```
/gsd-run-phase <N>
```

`<N>` is a phase number from `.planning/ROADMAP.md`. Must be on or able to check out the phase's feature branch.

## Process

### Step 0 — Preflight

Before spawning any subagent:

1. Read `.planning/ROADMAP.md` — confirm phase `N` exists and is `NOT STARTED` or `EXECUTED_NOT_REVIEWED` or `NEEDS_FIX`.
2. Confirm the phase's feature branch exists: `git branch --list feature/N-*` or check ROADMAP's `**Branch:**` field.
3. If blocked (DONE, missing from ROADMAP, or its blockers not yet shipped): emit failure JSON and exit.

### Step 1 — Execute

Print status: `🚀 Phase <N> — Spawning executor...`

Spawn **executor subagent** via the `Agent` tool. Model: Sonnet. Prompt (must be ≤2k chars):

```
You are the executor for GSD phase <N>. Your job:
1. Check out branch: feature/<branch-slug>
2. Run /gsd-plan-execute <N>
3. Return the JSON block that /gsd-plan-execute emits verbatim.

Context pointers (read these yourself — do not ask me for their content):
- Phase ROADMAP entry: .planning/ROADMAP.md (search for "## Phase <N>:")
- Project conventions: CLAUDE.md files at repo root and .claude/CLAUDE.md
- Phase branch: <branch-name> (from ROADMAP **Branch:** field)

Return format (JSON, ≤10k):
{"phase":<N>,"status":"EXECUTED_NOT_PUSHED"|"FAILED"|"BLOCKED","branch":"...","files_changed":<n>,"diff_lines":<n>,"tests_passed":true|false,"artifacts":{"plan":"...","exec_log":"...","learnings":"..."},"summary_md":"..."}
```

Wait for the executor subagent to return. Parse the JSON:
- `status: FAILED` or `status: BLOCKED` → emit failure JSON and exit (do not attempt review or ship).
- `status: EXECUTED_NOT_PUSHED` → continue to Step 2.

### Step 2 — Review (first pass)

Print status: `🔍 Phase <N> — Spawning reviewer...`

Spawn **reviewer subagent** via the `Agent` tool. Model: Sonnet (for ≥300-line diffs) or Haiku. This subagent must be **fresh** — its prompt must NOT include any content from the executor's reasoning or return JSON (only pointers). Prompt (must be ≤2k chars):

```
You are a code reviewer for GSD phase <N>. Your job:
1. Check out branch: feature/<branch-slug>
2. Run /gsd-review-phase <N>
3. Return the JSON block that /gsd-review-phase emits verbatim.

Context pointers (read these yourself):
- Phase branch: <branch-name>
- Phase issue: #<issue-number> (from ROADMAP **GitHub Issue:** field)
- REVIEW.md will be written to: .planning/phases/<NN>-<slug>/REVIEW.md

Return format (JSON, ≤10k):
{"phase":<N>,"issue":<issue-n>,"branch":"...","base":"dev","verdict":"APPROVE"|"REQUEST_CHANGES"|"NEEDS_DISCUSSION","findings_count":{"critical":<n>,"should_fix":<n>,"nit":<n>,"question":<n>},"review_path":"...","summary_md":"..."}
```

Parse the verdict.

### Step 3 — Branch on verdict

#### APPROVE (first pass)

Continue to Step 5 (ship). `fix_iterations = 0`.

#### REQUEST_CHANGES

Enter the fix loop (Step 4).

#### NEEDS_DISCUSSION

Print the `summary_md` from the reviewer JSON (≤5k chars). Print:

```
🔍 Phase <N>: NEEDS_DISCUSSION — branch not pushed.

<summary_md from reviewer>

Read .planning/phases/<NN>-<slug>/REVIEW.md for the full questions.
Decide, then either:
  /gsd-fix-phase <N>           (if changes are needed)
  /gsd-run-phase <N>           (re-runs from executor; use after branch updates)
  /gsd-ship-phase <N> --skip-review  (if questions resolve to "ship as is")
```

Emit final JSON with `status: "AWAITING_REVIEW"` and exit.

### Step 4 — Fix loop (max 2 iterations)

Iteration counter starts at 1. Maximum 2 iterations.

**Per iteration:**

Print status: `🔧 Phase <N> — Spawning fixer (iteration <K>)...`

Spawn **fixer subagent** via `Agent` tool. Prompt (must be ≤2k chars):

```
You are the fixer for GSD phase <N>, fix iteration <K>. Your job:
1. Check out branch: feature/<branch-slug>
2. Run /gsd-fix-phase <N>
3. Return the JSON block that /gsd-fix-phase emits verbatim.

Context pointers (read these yourself):
- REVIEW.md: .planning/phases/<NN>-<slug>/REVIEW.md (already written by reviewer)
- Phase branch: <branch-name>
- Phase issue: #<issue-number>

Return format (JSON, ≤10k):
{"phase":<N>,"status":"FIXED"|"FAILED"|"BLOCKED","branch":"...","iteration":<K>,"findings_addressed":<n>,"findings_deferred":<n>,"files_touched":[...],"fix_log_path":"...","summary_md":"..."}
```

If fixer returns `status: FAILED` or `BLOCKED`: emit failure JSON, set `status: "AWAITING_REVIEW"`, exit.

Print status: `🔍 Phase <N> — Re-spawning reviewer (fresh context, iteration <K>)...`

Spawn **fresh reviewer subagent** via `Agent` tool. **Critical:** this reviewer's prompt must NOT reference any prior reviewer or fixer output — it starts cold from the diff. Same ≤2k prompt template as Step 2, with iteration context added:

```
You are a code reviewer for GSD phase <N>, review iteration <K>. Your job:
1. Check out branch: feature/<branch-slug>
2. Run /gsd-review-phase <N>
3. Return the JSON block verbatim.

Context pointers (read these yourself):
- Phase branch: <branch-name>
- Phase issue: #<issue-number>
- Prior REVIEW.md (if any) at: .planning/phases/<NN>-<slug>/REVIEW.md (you may read it for context but must re-derive your verdict from the current diff independently)

Return format (JSON, ≤10k):
{"phase":<N>,"issue":<issue-n>,"branch":"...","base":"dev","verdict":"APPROVE"|"REQUEST_CHANGES"|"NEEDS_DISCUSSION","findings_count":{...},"review_path":"...","summary_md":"..."}
```

Parse verdict:
- `APPROVE` → break out of fix loop, continue to Step 5. `fix_iterations = K`.
- `REQUEST_CHANGES` → if `K < 2`, increment K and repeat the iteration. If `K == 2` (cap reached):
  ```
  🔍 Phase <N>: fix-loop cap reached (2 iterations) — AWAITING_REVIEW.
  
  <summary_md from final reviewer>
  
  Read .planning/phases/<NN>-<slug>/REVIEW.md and .planning/phases/<NN>-<slug>/FIX-LOG.md.
  Investigate manually, then re-run /gsd-run-phase <N> after additional fixes.
  ```
  Emit final JSON with `status: "AWAITING_REVIEW"`, exit.
- `NEEDS_DISCUSSION` → same handling as Step 3 NEEDS_DISCUSSION, exit.

### Step 5 — Ship

Print status: `📦 Phase <N> — Shipping...`

Invoke `/gsd-ship-phase <N> --skip-review`.

The `--skip-review` flag is safe here: the review was already done in Steps 2–4. The ship skill will still run preflight, tests, push, PR, CI gate, and merge.

If ship exits non-zero:
- Exit 1 (test failure): emit `status: "FAILED"`, include error.
- Exit 2 (CI failure): emit `status: "FAILED"`, include CI link.
- Exit 3 (preflight failure): emit `status: "FAILED"`, include reason.
- Exit 4 (HITL gate): emit `status: "AWAITING_REVIEW"`, include manual push instructions.

On exit 0 (shipped successfully):

Print: `✅ Phase <N> shipped.`

### Step 6 — Emit final JSON

Final stdout must contain a fenced JSON block:

```json
{
  "phase": <N>,
  "status": "DONE" | "AWAITING_REVIEW" | "FAILED" | "BLOCKED",
  "pr_url": "<url or null>",
  "fix_iterations": <0|1|2>,
  "review_verdict": "APPROVE" | "REQUEST_CHANGES" | "NEEDS_DISCUSSION" | null,
  "summary_md": "≤5k recap: executor summary + reviewer verdict + ship result. No diff content, no full plan — pointers only."
}
```

`status` meanings:
- `DONE` — shipped, PR merged, branch deleted
- `AWAITING_REVIEW` — HITL gate, NEEDS_DISCUSSION verdict, or fix-loop cap hit — human action required
- `FAILED` — executor, fixer, or ship hard-failed; tree may have commits
- `BLOCKED` — phase not startable (wrong prereqs, branch missing, ROADMAP not found)

## Subagent prompt construction rules

When assembling each subagent prompt:
1. Keep the prompt ≤2k chars. Count characters before spawning — if over budget, trim `summary_md` references first.
2. Never include: executor reasoning, reviewer findings text, fixer notes, prior iteration outputs, diff content, plan content.
3. Always include: the skill name to invoke, the phase number, the branch name, the issue number (for reviewer/fixer), the disk paths to relevant artifacts (for reviewer/fixer).
4. The JSON return schema (25–30 lines) is mandatory in every prompt — it's how you parse the return.

## Failure modes

| Symptom | JSON status | Notes |
|---|---|---|
| Phase not in ROADMAP | `BLOCKED` | Check phase number |
| Phase already DONE | `BLOCKED` | Already shipped; do not re-run |
| Executor FAILED | `FAILED` | Some commits may exist on branch |
| Reviewer NEEDS_DISCUSSION | `AWAITING_REVIEW` | Human reads REVIEW.md, decides |
| Fix-loop cap (2 iterations) hit | `AWAITING_REVIEW` | Read REVIEW.md + FIX-LOG.md |
| Ship HITL gate (exit 4) | `AWAITING_REVIEW` | Manual push + PR; script printed commands |
| Ship CI failure (exit 2) | `FAILED` | PR is open; push fix commits to same branch |

## Why this skill exists

In the multi-agent context architecture (PRD #500), orchestrators (`/gsd-execute`, `/idea-to-ship`) carry only the JSON return summaries from each phase (≤10k each) — never the full plan content, execute traces, or review findings. Those live on disk and die with the subagent's context. This keeps the orchestrator coherent across many phases.

The executor subagent (`/gsd-plan-execute`), reviewer subagent (`/gsd-review-phase`), and fixer subagent (`/gsd-fix-phase`) are each isolated — they read only what they need from disk + git + gh, do their job, and return a compact JSON. This skill is the coordinator that sequences them.

For manual users: run `/gsd-run-phase 200` to plan, execute, review, and ship phase 200 end-to-end without touching the larger orchestrators.

## Related

- `/gsd-plan-execute` — executor subagent entry point (Step 1)
- `/gsd-review-phase` — reviewer subagent entry point (Steps 2, 4)
- `/gsd-fix-phase` — fixer subagent entry point (Step 4 fix loop)
- `/gsd-ship-phase` — ship step (Step 5, called with `--skip-review`)
- `/gsd-execute` — multi-phase orchestrator (spawns this skill per phase after Phase 201)
- `idea-to-ship` — full idea-to-ship orchestrator (spawns this skill per phase after Phase 201)
