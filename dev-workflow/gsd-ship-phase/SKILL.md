---
name: gsd-ship-phase
description: Ship a phase's feature branch with a mandatory adversarial review gate. Orchestrates preflight + tests (via ship-phase.sh --stop-after-tests) → spawn /gsd-review-phase reviewer subagent → branch on verdict (APPROVE → continue, REQUEST_CHANGES → exit 5, NEEDS_DISCUSSION → exit 6) → push + PR + auto-merge (via ship-phase.sh --from-push). Adds exit codes 5/6 on top of the existing 0/1/2/3/4 from ship-phase.sh, plus a --skip-review flag for typo-only / doc-only / lockfile-bump PRs. Used as the ship gate inside /gsd:run-phase and as the standalone last step of the manual /gsd-plan-phase → /gsd-execute-phase → /gsd-ship-phase flow. Triggers on "/gsd-ship-phase", "ship phase N", "ship a feature branch", "merge phase N", "push and merge with review gate".
---

# /gsd-ship-phase — Ship with Mandatory Review Gate

Two-half ship pipeline that splits the existing `~/.claude/skills/gsd/scripts/ship-phase.sh` around an automated reviewer subagent. The bash script remains the backbone for preflight, tests, push, PR, CI, and merge; this skill inserts the review gate between them and routes on its verdict.

## Invocation

```
/gsd-ship-phase <N> [--skip-review] [--no-wait] [--skip-tests] [--dry-run] [--base <branch>]
```

`<N>` is a phase number from `.planning/ROADMAP.md`. The current branch must be the phase's feature branch (the bash script enforces this). All flags except `--skip-review` are forwarded to `ship-phase.sh` unchanged.

## Process

### Step 1 — Preflight + tests (bash backbone)

Invoke the bash script in stage-gate mode:

```bash
bash ~/.claude/skills/gsd/scripts/ship-phase.sh --phase <N> --stop-after-tests \
  ${BASE:+--base "$BASE"} \
  ${NO_WAIT:+--no-wait} \
  ${SKIP_TESTS:+--skip-tests} \
  ${DRY_RUN:+--dry-run}
```

The script runs preflight (branch sanity, dirty-tree check, phase resolution), HITL gate detection, and the local test suite, then exits 0 at the stage gate without pushing.

Propagate exits unchanged:

| Exit | Meaning | Action |
|---|---|---|
| 0 | Stage gate reached — preflight + tests OK | Continue to step 2 |
| 1 | Test failure | Re-emit; exit 1 |
| 3 | Preflight failure (dirty tree, protected branch, missing tools) | Re-emit; exit 3 |
| 4 | HITL gate (PLAN.md flag or `Needs Review` label) — branch not pushed | Re-emit; exit 4 |

### Step 2 — Review gate

Skipped iff `--skip-review` was passed (see Step 2b below).

Invoke `/gsd-review-phase <N>` via the `Agent` tool. The reviewer enters with no prior context, builds its own bundle from the diff + changed files, and emits a fenced JSON block plus a `REVIEW.md` on disk. Parse the JSON and read `verdict`.

Then commit `REVIEW.md` to the feature branch so the audit trail survives:

```bash
REVIEW_PATH=".planning/phases/<NN>-<slug>/REVIEW.md"
if [[ -f "$REVIEW_PATH" ]]; then
  git add "$REVIEW_PATH"
  git commit -m "docs(review): phase <NN> reviewer findings (verdict: <VERDICT>)"
fi
```

The reviewer skill itself does NOT auto-commit (see `gsd-review-phase` Step 7). Committing here keeps the policy "ship-phase owns the audit trail."

#### Step 2b — `--skip-review` bypass

When `--skip-review` is set:

- Skip the Agent call and REVIEW.md commit.
- Log a single line: `⚠ Review skipped — reason: <user-supplied or DEFAULT>`. If the user passed `--skip-review=<reason>`, use that; otherwise `DEFAULT`.
- Append `[skip-review]` to the PR body in step 4 so the audit trail captures it.

Use `--skip-review` only for: typo-only fixes, doc-only edits, lockfile bumps, rebase cleanups, or when an external reviewer has already approved out of band. Do not use it to bypass review on substantive code changes.

### Step 3 — Branch on verdict

#### APPROVE

Continue to step 4.

#### REQUEST_CHANGES

Print the REVIEW.md findings (or `summary_md` from the JSON, ≤5k chars), the exact next-step command, and update STATE.md:

```
🔍 Phase <NN>: REQUEST_CHANGES — branch not pushed.

<paste summary_md from reviewer JSON>

Next step:
  /gsd-fix-phase <N>

After fixes land, re-run /gsd-ship-phase <N> to retry the review gate.
```

Append a row to `.planning/STATE.md` under a `## Phase status` table (or create the table if absent):

```
| <NN> | <branch> | REQUEST_CHANGES | <ISO date> | See REVIEW.md |
```

Exit 5. Branch remains local; nothing is pushed.

#### NEEDS_DISCUSSION

Print the findings, the questions block from REVIEW.md, and mark AWAITING_REVIEW in STATE.md:

```
🔍 Phase <NN>: NEEDS_DISCUSSION — branch not pushed.

<paste summary_md from reviewer JSON>

The reviewer flagged questions that require human judgement. Read REVIEW.md,
make a decision, then either:
  - /gsd-fix-phase <N>            (if changes are needed)
  - /gsd-ship-phase <N> --skip-review  (if the questions resolve to "ship as is")
```

STATE.md row:

```
| <NN> | <branch> | AWAITING_REVIEW | <ISO date> | See REVIEW.md questions |
```

Exit 6. Branch remains local.

### Step 4 — Push + PR + CI + merge (bash backbone)

Invoke the bash script in second-half mode:

```bash
bash ~/.claude/skills/gsd/scripts/ship-phase.sh --phase <N> --from-push \
  ${BASE:+--base "$BASE"} \
  ${NO_WAIT:+--no-wait} \
  ${DRY_RUN:+--dry-run}
```

`--from-push` skips the HITL gate re-evaluation and the test suite (already passed in step 1) but re-runs preflight as a safety net. The script handles: push, PR creation with `Closes #N`, CI watch, squash-merge with `--delete-branch`, switch to base, pull, local-branch cleanup, linked-issue closure, and STATE.md `## Shipped` row.

Propagate exits:

| Exit | Meaning |
|---|---|
| 0 | Shipped successfully |
| 2 | CI failure on PR — PR is open; fix on the same branch and re-run |

### Step 5 — Done summary

After step 4 returns 0, print:

```
✅ Phase <NN> shipped.
   PR:        <URL>
   Closed:    #<issue> #<issue>
   REVIEW.md: <commit SHA> (committed in step 2)
```

## Exit codes (consolidated)

Source-of-truth across both this skill and `ship-phase.sh`. The script itself never returns 5 or 6 — those originate in this skill's verdict routing.

| Exit | Origin | Meaning |
|---|---|---|
| 0 | both | Shipped successfully (or stage-gate reached on `--stop-after-tests`) |
| 1 | script | Local test failure |
| 2 | script | CI failure on PR |
| 3 | script | Preflight failure / invalid flag combination |
| 4 | script | HITL gate (PLAN.md flag or `Needs Review` label) — branch not pushed |
| 5 | skill  | Reviewer verdict REQUEST_CHANGES — branch not pushed |
| 6 | skill  | Reviewer verdict NEEDS_DISCUSSION — branch not pushed |

## Why this skill exists

The bash `ship-phase.sh` is well-tested and handles all the GitHub mechanics (PR body, `Closes #N`, CI watch, squash-merge, issue closure, STATE.md). What it cannot do from bash is spawn an LLM reviewer subagent. This skill keeps the bash backbone for what bash is good at, and inserts the review gate where an LLM is actually needed.

In the multi-agent context architecture (PRD #500), `/gsd-ship-phase` is the **last step** of `/gsd:run-phase`'s pipeline (executor → reviewer → fix-loop → ship). The orchestrator can also call this skill standalone, e.g. for ad-hoc shipping after a manual `/gsd-plan-phase → /gsd-execute-phase` flow.

## Failure modes

| Symptom | Exit | Notes |
|---|---|---|
| Dirty working tree | 3 | Commit or stash, then re-run |
| Branch is `main`/`dev`/`uat` | 3 | Checkout a feature branch |
| Conflicting stage flags | 3 | Don't pass both `--stop-after-tests` and `--from-push` directly to the script |
| Test failure | 1 | Fix locally and re-run from the start |
| HITL label or PLAN.md flag | 4 | Push manually and assign reviewer; script prints the exact commands |
| Reviewer says REQUEST_CHANGES | 5 | Run `/gsd-fix-phase <N>`, then re-run this skill |
| Reviewer says NEEDS_DISCUSSION | 6 | Read REVIEW.md, decide, then either fix or `--skip-review` |
| CI failure after push | 2 | Fix on same branch, re-run; PR stays open |
| `git push` rejected (non-FF, missing branch protection bypass, etc.) | 3 | Investigate; do not force-push without explicit user approval |

## Related

- `~/.claude/skills/gsd/scripts/ship-phase.sh` — the bash backbone (must be on `--stop-after-tests` / `--from-push` capable version, i.e. ≥ Phase 199)
- `/gsd-review-phase` — produces REVIEW.md + verdict JSON consumed by step 2
- `/gsd-fix-phase` — runs after a REQUEST_CHANGES verdict to address findings
- `/gsd:run-phase` — orchestrator that calls this skill as its final per-phase step
