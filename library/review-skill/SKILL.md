---
name: review-skill
description: >
  Review and improve an existing Claude Code skill by analyzing its real-world
  invocation logs. Use this whenever the user says /review-skill, wants to improve
  a skill based on how it has actually performed, asks to analyze skill usage patterns,
  or says things like "let's improve the X skill" or "the X skill isn't working well".
  Requires skill invocation logs to exist at ~/.claude/skill-logs/<skill-name>/.
---

# Skill Reviewer

Analyzes real invocation logs for a skill and proposes targeted improvements,
gating all changes on human approval before writing anything.

## Step 1 — Identify the skill

The skill name comes from the user's invocation argument (e.g. `/review-skill cv-reviewer`).

If no name was given, run **discovery mode** before asking:

1. Glob for all log directories: `~/.claude/skill-logs/*/`
2. For each directory found, count the JSON files inside it
3. Present a summary table:

```
--- SKILL LOG INVENTORY ---

Skill               Logs   Status
─────────────────────────────────
cv-reviewer            7   ✓ Ready for review
frontend-design        3   ✓ Ready for review (minimum)
pdf                    1   ⚠ Low — analysis will be limited
docx                   0   ✗ No logs yet

Skills with no logs directory: algorithmic-art, brand-guidelines, ...
─────────────────────────────────
```

- **Ready for review**: 3+ log entries
- **Low**: 1-2 entries (can still review, but flag limited signal)
- **No logs yet**: directory missing or empty

If the `~/.claude/skill-logs/` directory is empty or missing, explain that logging
hooks need to be set up first to capture skill invocations, and offer to help
configure them.

After showing the table, ask: "Which skill would you like to review?"

## Step 2 — Load logs

Read all JSON files under `~/.claude/skill-logs/<skill-name>/`.
Use Glob: `~/.claude/skill-logs/<skill-name>/*.json`, then Read each file.

If fewer than 3 log entries exist, tell the user:
> "Only N log entries found for '<skill-name>'. Analysis will be limited —
> the more real sessions logged, the better the signal. Continue anyway?"

If zero logs exist, stop and explain that the logging hooks need to accumulate
some invocations first.

## Step 3 — Load the current skill

Find the SKILL.md. Check in order:
1. `~/.claude/skills/<skill-name>/SKILL.md`  (user override)
2. Use Glob `~/.claude/plugins/cache/**/<skill-name>/SKILL.md` for plugin-installed skills

Read the full SKILL.md. Hold its content in context — you'll need it for the diff.

## Step 4 — Analyze the logs

For each log entry note:
- `status`: completed vs pending (ignore pending)
- `error_count`: 0 = clean run, >0 = something failed
- `tool_sequence`: what tools were actually invoked
- `user_prompt`: what the user asked for
- `assistant_message_count`: proxy for complexity/verbosity

Then identify cross-log patterns. Look for:

**SUCCESSES** — prompt types that completed cleanly with short tool sequences.
These tell you what the skill handles well already.

**FAILURES** — runs with error_count > 0. What tool failed? What was the user
asking for? Is there a pattern?

**MISSING TRIGGERS** — user prompts that clearly needed this skill but the
phrasing differs from the description. These are missed-trigger candidates.

**VERBOSITY SIGNALS** — if tool_sequence length is consistently > 10 for
requests that seem simple, the skill may be giving unclear step-by-step guidance.

**DEAD INSTRUCTIONS** — if certain tool types never appear across any runs (e.g.
skill says "run a bash script" but Bash never appears in tool_sequence), that
instruction may be confusing or ignored.

## Step 5 — Formulate proposed changes

Produce up to 5 targeted changes, ranked by expected impact:

1. **Description/trigger improvements** (highest impact) — make the skill fire
   when it should, and not when it shouldn't
2. **Error-prevention additions** — guard clauses or clarifications for known
   failure modes seen in logs
3. **Instruction clarifications** — reword steps that correlate with errors or
   high tool counts
4. **Removal of dead instructions** — clean up guidance that never shows up in
   tool sequences
5. **Coverage gaps** — add guidance for prompt types that appear in logs but
   aren't addressed

Keep changes surgical. Don't rewrite sections that are working well.
Explain the log evidence behind each proposed change.

## Step 6 — APPROVAL GATE (required before writing anything)

Present changes in this exact format:

```
--- PROPOSED CHANGES TO <skill-name>/SKILL.md ---

Change 1: [one-line summary]
Evidence: [which log entries support this, e.g. "3/5 runs failed with Bash errors when user asked about X"]
BEFORE:
  [exact current text, indented]
AFTER:
  [proposed replacement, indented]

Change 2: ...

--- END PROPOSED CHANGES ---
```

Then ask:
> "Approve all changes? Or type the numbers to apply (e.g. `1,3`). Type `none` to cancel."

**DO NOT use Write or Edit tools until the user explicitly responds with an approval.**

## Step 6b — Suggest test prompts for A/B testing with skill-creator

After presenting the proposed changes, also extract 3-5 representative test prompts
from the logs to hand off to `/skill-creator` for benchmarking. Pick prompts that:

- **Cover the changes** — at least one prompt per proposed change, targeting the
  specific behavior that change is meant to improve
- **Include a failure case** — pick a `user_prompt` from a log entry with `error_count > 0`
  so you can verify the fix actually works
- **Include a success case** — pick a prompt that already works well, to ensure the
  changes don't regress existing behavior
- **Vary in complexity** — mix simple and multi-step requests if the logs show both

Present them in this format after the proposed changes:

```
--- SUGGESTED TEST PROMPTS FOR A/B TESTING ---

These prompts are extracted from real invocation logs. Use them with
/skill-creator to benchmark the proposed changes against the current version.

1. "<user_prompt from logs>"
   Source: log entry <filename/id> | Tests change(s): #1, #3

2. "<user_prompt from logs>"
   Source: log entry <filename/id> | Tests change(s): #2 (was a failure case)

3. "<user_prompt from logs>"
   Source: log entry <filename/id> | Regression guard (currently passing)

--- END TEST PROMPTS ---
```

If the user wants to A/B test before applying, they can take these prompts directly
to `/skill-creator` — the prompts are already in the right shape for `evals/evals.json`.

## Step 7 — Apply approved changes

Apply only the approved changes. For each:
- If the skill is in `~/.claude/plugins/cache/`, write the updated version to
  `~/.claude/skills/<skill-name>/SKILL.md` (local override, takes precedence,
  won't be clobbered by plugin updates)
- If the skill is already in `~/.claude/skills/`, edit in place

After writing, show the final SKILL.md for confirmation.

## Notes

- Trust the logs over assumptions. If the evidence is thin (1-2 entries), say so.
- Don't propose changes just to have something to say. "No changes needed" is a valid output.
- Changes to the `description` frontmatter field have outsized effect — they control
  when the skill triggers at all. Be precise here.
