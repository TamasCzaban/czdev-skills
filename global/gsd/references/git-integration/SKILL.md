---
name: gsd:reference:git-integration
description: Git integration reference for GSD
version: 1.0.0
triggers: [git, version control, commits]
tools: [Bash, Glob, Grep, Write]
---

# GSD Git Integration Reference

Guide for using Git with GSD workflow.

## Commit Patterns

- Atomic commits per task
- Descriptive commit messages
- Link to task when possible
- Regular commits during work

## Branch Strategy

- Feature branches for tasks (one per phase, or per logical sub-unit)
- Integration branch (`dev`) for assembled work
- `uat` / `main` promoted from `dev` via PR
- Checkpoints as tags

## Shipping a Phase (auto-merge + cleanup)

A phase isn't done when commits land locally — it's done when the feature
branch is merged into the integration branch, linked issues are closed, and
the branch is deleted.

**Canonical path — use the ship helper:**

```bash
bash "$HOME/.claude/skills/gsd/scripts/ship-phase.sh" --phase <NN>
```

The helper runs: local tests → push → PR with `Closes #N` → CI gate →
`gh pr merge --squash --delete-branch` → `gh issue close` → STATE.md update.
See `gsd:execute-phase` SKILL.md §Ship Step for the full algorithm and flags.

**Manual fallback** (if helper is unavailable):

```bash
# 1. push
git push -u origin <feature-branch>

# 2. open PR — ALWAYS include Closes #N for every linked issue
gh pr create --base dev \
  --title "feat(<phase>): <summary>" \
  --body "$(cat <<'EOF'
## Summary
<phase summary>

## Changes
- <commit subject>

Closes #<N>
Closes #<N>

🤖 Generated with Claude Code
EOF
)"

# 3a. NO HITL gates → poll checks then auto-merge + delete branch
gh pr checks <pr-number> --watch
gh pr merge <pr-number> --squash --delete-branch

# 3b. HITL gates present → assign reviewer, post checklist comment, STOP
gh pr edit <pr-number> --add-reviewer <user>
gh pr comment <pr-number> --body "Human verification needed: ..."
```

**Closing linked issues:**
`Closes #N` in the PR body auto-closes the issue on merge (requires the repo's
GitHub Issues integration to be enabled). Always also run as a safety net:

```bash
gh issue close <N> --comment "Shipped in #<pr-number>"
```

**HITL gates (do NOT auto-merge if any apply):**
- UI/visual changes a non-dev should see (mum, designer, PM)
- Architect's Change Protocol items (new libraries, DESIGN.md edits, new patterns)
- Destructive migrations, secret rotations, prod-impacting infra changes
- Anything explicitly flagged HITL in the plan

**Verify CI green on the integration branch after merge.** A red post-merge
build is a deviation — fix and re-ship.

## Best Practices

- Commit early and often
- Write meaningful messages
- Atomic commits per task
- Always merge via PR (never raw `git merge`) — checks must run, merge must be auditable
- Always delete the branch after merge (`--delete-branch` on `gh pr merge`)

## Success Criteria

Clean git history with traceable changes. No orphaned merged branches on origin.
Every phase ships through a PR.
