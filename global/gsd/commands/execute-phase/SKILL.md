---
name: gsd:execute-phase
description: Execute phase tasks using wave-based parallel execution
version: 1.1.0
triggers: [execute phase, run phase]
tools: [Bash, Glob, Grep, Write, Skill, Agent]
---

# GSD Execute Phase

Executes phase tasks using wave-based parallel execution with gsd-executor agent.

## When to Use

- Running a planned phase
- Executing tasks in parallel waves
- Following structured development workflow

## Process

1. Load phase-plan.md for task list
2. Identify independent tasks for parallel execution
3. Execute tasks in waves (parallel where possible)
4. Create atomic commits per task
5. Handle deviations automatically (bugs, missing functionality, blocking)
6. Request checkpoint verification between waves
7. **Capture learnings** — invoke `/gsd:capture-learnings <NN>` (see Capture Learnings Step below). Must complete before ship; any commit it creates lands on the feature branch.
8. **Ship the phase** — open PR, auto-merge if no HITL gates, delete branch (see Ship Step below)

## Wave Execution Rules

- Independent tasks execute in parallel
- Dependent tasks wait for dependencies
- Deviations are handled per deviation rules
- Checkpoints occur between waves

## Deviation Handling

- BUG: Fix immediately in same context
- MISSING: Implement if under 5 minutes
- BLOCKING: Defer to backlog

## Capture Learnings Step (mandatory pre-ship step)

After all waves are committed and the checkpoint has verified the work, invoke
`/gsd:capture-learnings <NN>` before running ship-phase.sh. The capture skill:

- Reads PLAN.md + commit log + diff stat (not the full diff)
- Spawns a haiku sub-agent to extract only non-obvious lessons
- Appends to `LEARNINGS.md` (or `learnings/<domain>.md` if the project has split)
- Commits as `docs(learnings): phase <NN> lessons` on the feature branch
- Exits silently with no commit if nothing non-obvious was discovered (`NO_LEARNINGS`)

Rationale: the developer (Claude) has maximum context on what surprised it at
the moment execution finishes. Capturing after the PR merges loses that
context; capturing before execute doesn't have the material to capture.

If capture-learnings fails (malformed output, pre-commit hook error): log the
failure and **do not ship**. A dirty tree will trip ship-phase.sh's preflight
anyway, and a silent skip defeats the loop. Fix and re-run.

If capture-learnings is missing (skill file not found): warn, skip, continue
to ship. The loop is best-effort infrastructure, not a blocker for shipping.

## Ship Step (mandatory final step)

A phase is NOT complete until the PR is merged into the integration branch,
linked GitHub issues are closed, and the feature branch is deleted. Local
commits alone are not the deliverable.

**Run the ship helper** (after all waves pass + verification + checkpoint):

```bash
bash "$HOME/.claude/skills/gsd/scripts/ship-phase.sh" --phase <NN>
```

The helper does everything in sequence:
1. Preflight — dirty-tree check, protected-branch guard
2. Detect linked GitHub issues from PLAN.md / ROADMAP.md / commit messages
3. HITL gate scan — stops here and hands off to the human if gates are found
4. Run local tests (build + Playwright + Vitest; auto-detected; abort on red)
5. `git push -u origin HEAD`
6. `gh pr create --base dev` with `Closes #N` for every linked issue
7. `gh pr checks --watch` — waits for CI green
8. `gh pr merge --squash --delete-branch`
9. `gh issue close <N>` for each linked issue (safety net)
10. Append shipped entry to `.planning/STATE.md` and push

**Optional flags:** `--base <branch>` · `--dry-run` · `--skip-tests` · `--no-wait`

### When the helper stops at a HITL gate

The helper auto-detects and stops (exit 4) if:
- PLAN.md contains a `HITL` flag or `**HITL Gates:**` section
- A linked issue has `Status: Needs Review` label
- (Any UI/visual, new-library, destructive-migration, or secret-rotation changes
  should be explicitly flagged HITL in the plan to trigger this path)

When stopped: push the branch, open the PR manually with `Closes #N` in the
body, assign the reviewer, post the gate checklist as a comment — then stop.
Do NOT merge. Branch cleanup waits for human approval.

### Fallback (helper unavailable or environment issue)

If `ship-phase.sh` is missing or fails to execute, use the manual flow in
`references/git-integration/SKILL.md` — but always include `Closes #N` in
the PR body and always run `gh issue close <N>` after merge.

## Success Criteria

All phase tasks committed + ship helper exits 0: PR merged, feature branch
deleted, linked issues closed, STATE.md updated, post-merge CI green. If HITL
gates triggered: PR is open with a reviewer checklist, awaiting human merge.

## Related Skills

@skills/gsd/agents/executor - Agent that executes tasks
@skills/gsd/commands/plan-phase - Creates phase plans
@skills/gsd/commands/capture-learnings - Extracts non-obvious lessons before ship
