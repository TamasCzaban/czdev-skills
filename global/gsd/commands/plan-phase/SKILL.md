---
name: gsd:plan-phase
description: Create detailed execution plan for a project phase
version: 1.0.0
triggers: [plan phase, create plan]
tools: [Bash, Glob, Grep, Write]
---

# GSD Plan Phase

Creates detailed execution plans for project phases using gsd-planner agent.

## When to Use

- Starting a new phase of development
- Breaking down a wave into atomic tasks
- Planning phase implementation details

## Process

### 0. Claim the GitHub issue (if linked)

Read the phase's block in `.planning/ROADMAP.md`. Look for a line matching
`**GitHub Issue:** #<N>`.

If found, run:

```bash
CURRENT_USER=$(gh api user --jq .login 2>/dev/null)
gh issue edit <N> --add-assignee @me 2>/dev/null
echo "Claimed issue #<N> for ${CURRENT_USER}"
```

This is idempotent — `gh` exits 0 if you are already assigned. Skip silently
if:
- No `**GitHub Issue:**` line in the phase entry
- `gh` is not authenticated (do not block planning on this)

Rationale: planning is the real "I'm starting this" moment. Scaffolding
(`issue-to-gsd`) and PRD creation can be speculative; `/gsd:plan-phase` is not.

### 1–5. Create the plan

1. Analyze wave description and acceptance criteria
2. Load codebase map for context (if exists)
3. Spawn gsd-planner agent to create phase plan
4. Verify plan structure (phases/waves/tasks)
5. Commit phase plan to git

## Output Documents

- phase-plan.md - Detailed phase breakdown
- Includes phases, waves, and atomic tasks

## Success Criteria

Complete phase plan with all tasks documented.

## Related Skills

@skills/gsd/agents/planner - Agent that creates detailed plans
@skills/gsd/commands/new-project - Creates initial project structure
