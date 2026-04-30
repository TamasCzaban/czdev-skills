---
name: gsd-fix-phase
description: Read REVIEW.md from a phase, address the reviewer's findings, commit fixes to the existing feature branch, and append an entry to FIX-LOG.md. The fixer subagent enters cold with only the diff + REVIEW.md findings + acceptance criteria — it does NOT re-derive the executor's plan or explore unrelated parts of the codebase. Used by /gsd-ship-phase's REQUEST_CHANGES branch and by /gsd:run-phase's fix loop. Triggers on "/gsd-fix-phase", "address review findings for phase N", "fix the things the reviewer flagged".
---

# /gsd-fix-phase — Address Reviewer Findings

The **fixer subagent's entry point**. Reads `REVIEW.md` produced by `/gsd-review-phase`, addresses the findings, commits to the existing feature branch, and appends an entry to `FIX-LOG.md`. Designed for narrow, focused work: address what the reviewer flagged, nothing more.

## Invocation

```
/gsd-fix-phase <N>
```

Where `<N>` is a phase number from `.planning/ROADMAP.md`. The current branch must match the phase's branch (per `**Branch:**` in the ROADMAP entry).

## Process

### Step 0 — Preflight

Verify all of:
- Currently on a feature branch (not main / master / dev / uat)
- `.planning/phases/<NN>-<slug>/REVIEW.md` exists
- REVIEW.md frontmatter `verdict` is `REQUEST_CHANGES` (or `NEEDS_DISCUSSION` with explicit user override)
- Working tree is clean

If REVIEW.md is missing OR verdict is already `APPROVE`, abort with:

```json
{"phase": <N>, "status": "FAILED", "error": "<reason>"}
```

### Step 1 — Read narrow context

The fixer reads ONLY:
1. `.planning/phases/<NN>-<slug>/REVIEW.md` — the verdict, criteria coverage, findings
2. `git diff $BASE...HEAD` — what changed in this phase
3. Full content of files mentioned in REVIEW.md findings (`file:line` references)
4. The parent issue's acceptance criteria (`gh issue view <ISSUE_N>`)
5. Project conventions (CLAUDE.md files at repo root and in subdirs the diff touches)

The fixer does **NOT**:
- Re-explore the entire codebase
- Re-read the executor's PLAN.md or EXEC-LOG.md (would re-introduce executor bias)
- Look at files unrelated to flagged findings

### Step 2 — Address findings in priority order

Process findings in this order:
1. All `[CRITICAL]` findings — must address every one
2. All `[SHOULD-FIX]` findings — must address every one or document in FIX-LOG.md why not (e.g., "false positive: <reason>")
3. `[NIT]` findings — address if cheap; otherwise list in FIX-LOG.md as deferred
4. `[QUESTION]` findings — usually don't require code changes; if the answer requires a doc clarification, add it; otherwise note resolution in FIX-LOG.md

For each finding addressed:
- Make the targeted code change (no surrounding cleanup, no refactoring)
- Use atomic commits where natural — one commit per finding ID is ideal but not strict
- Commit message format: `fix(<NN>): address [<SEVERITY>] <one-line> (REVIEW finding #<n>)`

### Step 3 — Append to FIX-LOG.md

After all changes are committed, append an entry to `.planning/phases/<NN>-<slug>/FIX-LOG.md`:

```markdown
## Fix iteration <K> — <ISO date>

**Reviewer model:** <sonnet|haiku|opus>
**Verdict before:** REQUEST_CHANGES
**Findings addressed:** <count>

### Findings worked

| # | Severity | File:Line | Action | Commit |
|---|---|---|---|---|
| 1 | CRITICAL | src/foo.ts:42 | Fixed null check | abc1234 |
| 2 | SHOULD-FIX | src/bar.ts:88 | Added test | def5678 |
| 3 | NIT | src/baz.ts:12 | Renamed var | ghi9012 |

### Findings deferred or rejected

| # | Severity | File:Line | Reason |
|---|---|---|---|
| 4 | QUESTION | src/qux.ts:5 | False positive — pattern is intentional per CLAUDE.md `<rule>` |

### Notes

<optional free-form: anything the reviewer should know on next pass>
```

Where `<K>` is the iteration number (1, 2, ...). Each invocation of this skill increments `<K>` based on prior FIX-LOG.md entries (or starts at 1 if file doesn't exist).

Commit FIX-LOG.md as part of (or appended to) the last fix commit.

### Step 4 — Verify

After all fixes:
- Run project's typecheck (`npm run build` or `npx tsc --noEmit` for TS projects, equivalent for others) — must pass
- Run project's lint (`npm run lint`) — must pass
- Run any tests the changed files have (Vitest unit tests for `src/lib/*` per project convention; component tests if Firestore emulator is set up — usually skipped per current bemer_crm policy)

If verification fails: do NOT commit a "WIP" — fix it inline or revert, then continue.

### Step 5 — Emit JSON

Final stdout must contain a fenced JSON block:

```json
{
  "phase": 198,
  "status": "FIXED",
  "branch": "feature/503-gsd-fix-phase",
  "iteration": 1,
  "findings_addressed": 3,
  "findings_deferred": 1,
  "files_touched": ["src/foo.ts", "src/bar.ts", ".planning/phases/198-gsd-fix-phase/FIX-LOG.md"],
  "fix_log_path": ".planning/phases/198-gsd-fix-phase/FIX-LOG.md",
  "summary_md": "≤5k recap: what was fixed, what was deferred and why"
}
```

`status` is `FIXED` (success), `FAILED` (preflight or verification failed), `BLOCKED` (REVIEW.md missing or verdict already APPROVE).
`summary_md` ≤5k chars.

## Why this skill exists

Architecture: an executor subagent that wrote the code is biased toward defending it. A reviewer subagent enters cold and finds problems. A **third** fresh-context fixer subagent — also cold, narrow input — addresses the findings without the executor's investment in the original approach.

In the multi-agent context architecture (PRD #500), the orchestrator's `/gsd:run-phase` helper spawns this skill in a max-2-iteration fix loop:
1. Reviewer says REQUEST_CHANGES
2. Spawn fixer (this skill) → produces fixes
3. Re-spawn reviewer (FRESH context, new iteration) → re-verdict
4. If still REQUEST_CHANGES after 2 fix rounds → escalate to AWAITING_REVIEW (HITL)

The orchestrator enforces the iteration cap; this skill itself does not. Each invocation is one iteration.

## Failure modes

| Symptom | JSON status | Notes |
|---|---|---|
| No REVIEW.md | `BLOCKED` | Run `/gsd-review-phase <N>` first |
| Verdict was APPROVE | `BLOCKED` | Nothing to fix |
| Preflight fails | `BLOCKED` | Wrong branch, dirty tree, etc. |
| Verification (build/lint) fails | `FAILED` | Some fixes broke the build; user must investigate |
| Reviewer requested impossible changes (e.g., conflicting requirements) | `FAILED` | Document in FIX-LOG.md, escalate to HITL |

## Related

- `/gsd-review-phase` — produces REVIEW.md that this skill consumes
- `/gsd:run-phase` — orchestrator that spawns this skill in the fix loop
- `/gsd-ship-phase` — ships after fix loop converges to APPROVE
