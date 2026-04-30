---
name: gsd-review-phase
description: Spawn a fresh-context reviewer subagent to adversarially review the current feature branch's diff against its parent issue's acceptance criteria. Writes findings to REVIEW.md and returns a JSON verdict (APPROVE / REQUEST_CHANGES / NEEDS_DISCUSSION). The reviewer never sees the implementing conversation, has no investment in the chosen approach, and must re-derive understanding from the diff + changed files alone. Used as the review gate inside /gsd-ship-phase and as the reviewer subagent entry point in the multi-agent context architecture (PRD #500). Triggers on "/gsd-review-phase", "review this phase", "review the diff", "second opinion on this branch".
---

# /gsd-review-phase — Adversarial Review (JSON-returning)

Spawn a fresh-context sub-agent to review the current feature branch against its parent issue's acceptance criteria. The reviewer never sees the implementing conversation and is forced to re-derive understanding from the diff + changed files alone. Findings are written to `REVIEW.md`; the orchestrator-parseable verdict is emitted as a final fenced JSON block.

## Invocation

```
/gsd-review-phase <N> [--model sonnet|haiku|opus]
```

`<N>` is a phase number from `.planning/ROADMAP.md`. Default model is selected by diff size: Sonnet for ≥300-line diffs, Haiku otherwise. `--model` overrides.

## Process

### 1. Gather context

Auto-detect from current state:

```bash
BRANCH=$(git branch --show-current)
BASE=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null \
  || echo "main")
PROJECT=$(gh repo view --json name --jq '.name' 2>/dev/null || basename $(git rev-parse --show-toplevel))
ISSUE_N=$(echo "$BRANCH" | sed -E 's|^feature/([0-9]+)-.*|\1|')
PHASE_NN=$(grep -E "^## Phase [0-9]+" .planning/ROADMAP.md 2>/dev/null \
  | grep "#$ISSUE_N" \
  | sed -E 's|^## Phase ([0-9]+):.*|\1|' | tail -1)
```

Abort with a clear message if:
- No commits ahead of `$BASE` (nothing to review)
- Issue number cannot be parsed and ROADMAP.md has no matching phase (warn but continue — reviewer can still check conventions and diff quality)

### 2. Build the review bundle

Collect, in order:

1. **Issue body** — `gh issue view $ISSUE_N --json title,body,labels` (skip if issue number not available)
2. **Acceptance criteria** — extract from issue body (`Acceptance criteria` checklist or `Must be TRUE` block), or from the matching phase in `.planning/ROADMAP.md`
3. **Diff** — `git diff $BASE...HEAD`
4. **Changed files** — `git diff $BASE...HEAD --name-only`
5. **Full content of each changed file** — read each in full for surrounding context. Skip: binary files, lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `poetry.lock`, `go.sum`), generated files (`dist/`, `build/`, `lib/`, `*.d.ts`, `*.pb.go`)
6. **Project conventions** — discover all `CLAUDE.md` files in the repo, read them all
7. **Testing strategy** — extract the `Testing Strategy` block for this phase from `.planning/ROADMAP.md` if it exists

### 3. Spawn the reviewer

Use the `Agent` tool with `subagent_type: general-purpose`. Model selection:

- `--model` flag → use that
- else: count diff lines → Sonnet for ≥300, Haiku otherwise
- escalate to Sonnet if Haiku flags any CRITICAL findings (re-run on Sonnet for second opinion)

**Critical prompt rules:**
- Never mention "AI", "Claude", "generated", "agent", or "automated" anywhere in the reviewer prompt
- Frame as: *"You're reviewing a pull request from a teammate. Be critical but fair."*
- Do not include any reasoning from the implementing conversation
- Force structured output (template below)

**Reviewer prompt template:**

```
You are reviewing a pull request from a teammate on the <PROJECT> project. The
author is not in the room — your review will be read async. Be critical but
fair: flag real problems, do not invent issues to look thorough, do not soften
findings to be polite.

## The work

**Issue #<ISSUE_N>:** <issue title>

**Acceptance criteria (must all be TRUE):**
<bulleted list from issue body or ROADMAP.md phase>

**Testing strategy declared for this phase:**
<TDD | Integration | E2E | None — and the reason/scope, or "not declared">

## Project conventions

<paste all discovered CLAUDE.md content — conventions, architectural rules, patterns>

## The diff

<paste git diff $BASE...HEAD>

## Changed files (full content for context)

<for each changed file, paste the file path and full content>

## Your job

Produce a review with this exact structure:

### Verdict
One of: **APPROVE** | **REQUEST_CHANGES** | **NEEDS_DISCUSSION**

### Acceptance criteria coverage
| Criterion | Status | Evidence |
|---|---|---|
| <criterion 1> | ✅ met / ⚠️ partial / ❌ missing | <file:line or "not addressed"> |

### Findings
Group by severity. Each finding must include `file:line` and a concrete
suggestion (not just "consider rethinking").

**[CRITICAL]** — bugs, security issues, broken acceptance criteria, data loss
**[SHOULD-FIX]** — convention violations, missing error handling at boundaries, missed edge cases
**[NIT]** — naming, formatting, minor clarity
**[QUESTION]** — things that look intentional but you cannot verify from the diff alone

If you find no issues in a severity bucket, write "None." Do not pad.

### Tests
- Were tests added/updated where the declared testing strategy required them?
- Do the tests verify behavior through public interfaces, or do they couple to implementation?
- Any obvious untested edge cases?

### One-line summary
<single sentence — what the author should know in 10 seconds>
```

### 4. Persist REVIEW.md

Write the reviewer's full output to:

```
.planning/phases/<NN>-<slug>/REVIEW.md
```

If `.planning/phases/` doesn't have a matching `<NN>-<slug>/` directory, write to `.planning/reviews/<BRANCH>-REVIEW.md` instead.

Prepend frontmatter:

```markdown
---
phase: <NN or "unknown">
issue: #<ISSUE_N or "unknown">
branch: <BRANCH>
base: <BASE>
project: <PROJECT>
reviewed_at: <ISO timestamp>
reviewer_model: <sonnet|haiku|opus>
diff_lines: <number>
verdict: <APPROVE|REQUEST_CHANGES|NEEDS_DISCUSSION>
---
```

### 5. Emit JSON

Final stdout must contain a fenced JSON block:

```json
{
  "phase": 197,
  "issue": 502,
  "branch": "feature/502-gsd-review-phase",
  "base": "dev",
  "verdict": "APPROVE",
  "findings_count": {
    "critical": 0,
    "should_fix": 0,
    "nit": 2,
    "question": 1
  },
  "review_path": ".planning/phases/197-gsd-review-phase/REVIEW.md",
  "summary_md": "≤5k recap: one-line verdict + findings highlights + tests assessment + acceptance criteria status"
}
```

`verdict` is exactly one of `APPROVE | REQUEST_CHANGES | NEEDS_DISCUSSION`.
`summary_md` ≤5k chars.
`review_path` points to the persisted REVIEW.md.

### 6. Print human-readable summary

Beyond the JSON, also print a short colored summary for terminal viewing:

```
🔍 Review complete — Verdict: APPROVE

Critical:    0 findings
Should-fix:  0 findings
Nit:         2 findings
Question:    1 finding

Full review: .planning/phases/197-gsd-review-phase/REVIEW.md

Next steps:
  - APPROVE: continue to /gsd-ship-phase
  - REQUEST_CHANGES: run /gsd-fix-phase <N> to address findings
  - NEEDS_DISCUSSION: read questions, decide manually
```

### 7. Do NOT auto-commit REVIEW.md

Leave it untracked or staged-but-not-committed. The orchestrator (or the user) decides whether REVIEW.md belongs in the phase commit. Some reviews contain blunt phrasing that does not belong in public git history.

## Anti-sycophancy guarantees

These are non-negotiable in the reviewer prompt:

1. **Hide authorship** — never reveal the code came from an AI or from the same session
2. **Force severity tags** — no ungraded "consider maybe..." findings
3. **Demand a verdict** — APPROVE / REQUEST_CHANGES / NEEDS_DISCUSSION, no fence-sitting
4. **Grade against acceptance criteria** as a separate section — checks the goal, not just the code
5. **Forbid padding** — explicit "If you find no issues in a bucket, write 'None'. Do not pad."

## Cost guidance

Typical phase (Sonnet 4.6):
- Small (1–3 files, <300 line diff): ~$0.05
- Medium (4–10 files, 300–1500 line diff): ~$0.10–$0.20
- Large (>10 files, >1500 line diff): ~$0.20–$0.40 — consider splitting the phase

For sub-300-line diffs, Haiku 4.5 is ~$0.02. Escalate to Sonnet if Haiku flags critical issues.

## Why this skill exists

In the multi-agent context architecture (PRD #500), the orchestrator's `/gsd:run-phase` helper spawns this skill as the **reviewer subagent** between the executor and ship steps. Each fix-loop iteration spawns a **fresh** reviewer (no memory of prior round) to prevent the "this is fine, I just looked at it" cumulative-bias trap.

The standalone `gsd-review` skill (`.claude/skills/gsd-review/SKILL.md`) is the predecessor and remains in place for ad-hoc post-merge audits until Phase 205 (cleanup slice). New work should use `/gsd-review-phase` for its JSON-emitting interface.

## Related

- `/gsd:run-phase` — orchestrator that spawns this as a subagent
- `/gsd-fix-phase` — runs after this skill returns REQUEST_CHANGES
- `/gsd-ship-phase` — runs after this skill returns APPROVE
- `/gsd-review` — predecessor skill, deprecated as of Phase 205
