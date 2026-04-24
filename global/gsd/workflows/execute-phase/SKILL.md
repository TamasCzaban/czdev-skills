---
name: gsd:workflow:execute-phase
description: Workflow for executing a project phase
version: 1.0.0
triggers: [execute phase, run phase]
tools: [Bash, Glob, Grep, Write]
---

# GSD Execute Phase Workflow

Workflow for executing a planned project phase with verification.

## When to Use

- Executing a planned phase
- Running wave-based development

## Phases

1. Plan phase details
2. Review plan
3. Execute waves
4. Verify work
5. Create checkpoint
6. **Ship**: open PR, auto-merge to integration branch if no HITL gates, delete feature branch
7. Request approval (only if HITL gates blocked auto-merge in step 6)

## Entry Points

- `gsd:plan-phase` - Create phase plan
- `gsd:execute-phase` - Execute phase (includes Ship step)
- `gsd:verify-work` - Verify implementation
- `gsd:create-checkpoint` - Create checkpoint

## Ship Step

Run the helper — it handles everything end-to-end:

```bash
bash "$HOME/.claude/skills/gsd/scripts/ship-phase.sh" --phase <NN>
```

Sequence: local tests → push → PR with `Closes #N` → CI gate →
`gh pr merge --squash --delete-branch` → `gh issue close` → STATE.md update.

See `gsd:execute-phase` SKILL.md §Ship Step for the full algorithm, HITL gate
rules, flags (`--dry-run`, `--skip-tests`, `--no-wait`, `--base`), and the
manual fallback flow.

## Success Criteria

Phase shipped: code merged into integration branch via PR, feature branch
deleted, post-merge CI green. (Or, if HITL gates exist: PR open with a
reviewer checklist, awaiting human merge.)
