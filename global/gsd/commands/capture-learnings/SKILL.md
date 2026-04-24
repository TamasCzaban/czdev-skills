---
name: gsd:capture-learnings
description: Extract non-obvious lessons from a completed phase and append them to LEARNINGS.md before shipping. Auto-triggered from /gsd:execute-phase after waves pass, before ship-phase.sh runs. Also callable manually as `/gsd:capture-learnings <NN>`.
version: 1.0.0
triggers: [capture learnings, /gsd:capture-learnings, extract phase lessons]
tools: [Bash, Glob, Grep, Read, Write, Edit, Agent]
---

# GSD Capture Learnings

Closes the compound-engineering loop. After a phase's waves pass but before the ship script runs, this skill extracts what was *surprising* or *non-obvious* about the work and appends it to `LEARNINGS.md` so future phases (and Zsombor) benefit.

## When to Use

- **Automatic:** invoked by `/gsd:execute-phase` as step 6.5, after checkpoint verification and before the ship step. Also invoked by `/gsd-execute` between execute and ship of each phase.
- **Manual:** `/gsd:capture-learnings <NN>` to re-run on a past phase (e.g. if the auto-capture was skipped or produced poor output and you've since learned more).

## Preconditions

- Must run **after** execute-phase's waves are committed but **before** ship-phase.sh runs (ship's preflight requires a clean working tree; any commit this skill produces must land before push).
- Phase number must be provided or inferrable from the current feature branch name (same convention as ship-phase.sh — leading digits in the branch segment).
- Current branch must NOT be a protected branch (`main`, `master`, `dev`, `uat`).

## Process

### 1. Resolve inputs

- **Phase number** — from arg, else extract leading digits from `git rev-parse --abbrev-ref HEAD`.
- **Base branch** — default `dev`, overridable via `--base`. Same default as `ship-phase.sh`.
- **Plan file** — find `.planning/phases/<NN>*/PLAN.md` (zero-padded match).
- **Diff summary** — `git log origin/<BASE>..HEAD --stat` and `git log origin/<BASE>..HEAD --pretty=format:"%h %s%n%b"`. Do **not** load the full diff into context — it's usually too large. The summary and commit bodies are enough; the sub-agent can Read specific files if it needs more.
- **Existing learnings** — if `learnings/<domain>.md` exists use it; otherwise `LEARNINGS.md` at repo root. Read it so the sub-agent can deduplicate.

### 2. Determine domain

Read PLAN.md. If it declares a `Domain:` field, use that. Otherwise match keywords against the project's `.claude/CLAUDE.md` routing table (if present) or infer from changed file paths:

- `src/auth*` / `functions/**/stripe*` → `auth-stripe`
- `src/db*` / `frontend/src/hooks/use*` → `db-cache`
- `frontend/src/components/**` / `frontend/src/pages/**` → `ui-views`
- `frontend/src/lib/businessRules.ts` / rental/sale flows → `transactions`
- `devices` in path or PLAN → `devices`
- `contracts` / `html2pdf` → `contracts`
- `tests/**` / `*.test.*` / `*.spec.*` → `testing`

If no clear domain, default to a `General` section.

### 3. Extract lessons via sub-agent

Spawn a **haiku** agent (cheap, good for extraction) with this exact brief:

> You are reviewing a completed GSD phase to extract non-obvious lessons.
>
> **Inputs (provided below):** PLAN.md, commit messages, diff stat, existing LEARNINGS.md content for the target domain.
>
> **Extract only:**
> - Gotchas that were not obvious from the code itself
> - Assumptions that turned out wrong
> - Library/tooling/version quirks
> - Performance surprises
> - Race conditions, edge cases, or integration traps
>
> **Reject (do NOT include):**
> - Restatements of what the code does
> - Style/convention notes
> - Generic advice ("remember to test edge cases")
> - Anything already present in the existing learnings (deduplicate)
> - Anything documented in CLAUDE.md or context/ (the user has told me that duplication rots fastest)
>
> **If nothing non-obvious was discovered, output the literal string `NO_LEARNINGS` and stop.** An empty phase is fine — not every phase teaches something.
>
> **Output format** (markdown, no preamble):
>
> ```
> ### <today's date YYYY-MM-DD> · Phase <NN> · <5-8 word title>
>
> - <non-obvious truth>
> - <consequence or fix>
> - (optional) Reference: `file.ts:line`, `#issue`, or external link
> ```
>
> Keep it to 2–5 bullets. If there are genuinely multiple distinct lessons, produce multiple entries (each with its own header).

Pass in the PLAN.md content, the commit log (subjects + bodies), the `--stat` summary, and the target domain's existing learnings content.

### 4. Handle empty case

If the agent returned `NO_LEARNINGS`: print `No new learnings captured for phase <NN>.` and exit 0. Do not create a commit.

### 5. Append to the right file

- If `learnings/<domain>.md` exists → append the new entries under that file's main heading.
- Else if `LEARNINGS.md` has a section header matching the domain (case-insensitive prefix match on the domain label) → insert directly below that section header (before any other entries, so newest-first).
- Else → append under a new `## <Domain>` section at the end of `LEARNINGS.md`, above no other content.

Preserve existing content exactly. Do not reformat prior entries.

### 6. Check for staleness flags (cheap pass)

After appending, grep the updated file for any symbol references in entries older than 90 days. If a referenced symbol no longer exists in the codebase, append a `⚠ stale?` marker to that entry's first bullet. Do not delete old entries — mark only.

Implementation: for each `` `file.ext:line` `` or `` `symbolName` `` reference in entries with a date > 90 days old, run a quick Glob/Grep. If zero matches, edit the entry to prepend `⚠ stale? ` to its first bullet. Skip this step if it would take more than ~10 lookups — cap the work.

### 7. Commit

```bash
git add LEARNINGS.md learnings/ 2>/dev/null
git commit -m "docs(learnings): phase <NN> lessons"
```

No `--no-verify`. If a pre-commit hook fails, report the failure and exit non-zero — the user can fix and re-run. Do not silently skip the commit; an uncommitted LEARNINGS.md change will make ship-phase.sh preflight fail.

### 8. Report

Print a compact summary:

```
✓ Captured N learning(s) for phase <NN> → <file>
  - <first bullet of each entry, truncated to 80 chars>
```

## Success Criteria

- Either a commit `docs(learnings): phase <NN> lessons` exists on the feature branch, or the phase was genuinely empty (`NO_LEARNINGS`) and no commit was made.
- Working tree is clean — ship-phase.sh preflight will pass.
- Appended entries follow the format and do not duplicate existing content.

## Failure Modes

- **Sub-agent returns malformed output** (not starting with `###`) → log the raw output, skip the append, exit 0 with a warning. Never ship broken markdown into LEARNINGS.md.
- **Pre-commit hook fails** → exit non-zero, print the hook output. Do not amend, do not bypass.
- **Working tree dirty before run** → exit non-zero with a message. The preceding execute-phase waves should have left a clean tree; a dirty tree means something upstream went wrong and needs investigation, not a workaround.

## Related Skills

- `@skills/gsd/commands/execute-phase` — invokes this as step 6.5 before shipping.
- `@skills/gsd/scripts/ship-phase.sh` — runs immediately after this; requires clean tree.
- `@skills/gsd-execute` — meta pipeline that chains plan → execute (which now includes this) → ship.
