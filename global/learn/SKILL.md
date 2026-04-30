---
name: learn
description: Manually capture session-level learnings into the project's LEARNINGS.md and the user's auto-memory dir. Replaces /gsd:capture-learnings — works anywhere, not just at end of GSD phase. Trigger when the user says /learn, asks to "capture learnings", "save what we learned", "write up gotchas from this session", or wants to commit insights from the current session before context loss. Strict-CWD scope: writes to whichever project the CWD belongs to. Outputs LEARNINGS.md entries (project-bound technical gotchas) AND typed memory entries (behaviour / preference / fact-about-project), atomically committed.
version: 1.1.0
triggers: [/learn, capture learnings, save what we learned, write up gotchas, capture session insights, save session learnings]
tools: [Bash, Read, Write, Edit, Glob, Grep, Agent]
---

# /learn — Manual session learnings capture

Replaces `/gsd:capture-learnings` with a flexible manual capture that works mid-session, end-of-session, or any time the user wants to durably record what was figured out. Writes to two places, atomically:

- **`<repo>/LEARNINGS.md`** — project-bound technical gotchas, RCAs, library/tooling quirks, race conditions. Domain-bucketed, newest-first within each section.
- **`~/.claude/projects/<slug>/memory/<name>.md`** — typed memory entries (`user` / `feedback` / `project` / `reference`) matching the auto-memory format, for behaviour / preference / fact-about-project insights.

## When to use

- **Manual:** user types `/learn` (optionally `/learn <hint>` to bias extraction toward a topic).
- **NOT automatic.** Don't fire from a Stop hook or end-of-phase script. The whole point is user control — auto-memory already covers reactive capture.
- **NOT for GSD waves:** `/gsd:execute-phase` no longer invokes this. Inside a GSD flow, the user calls `/learn` themselves at the moment they want capture.

## Preconditions

- CWD is inside a git repository.
- `~/.claude/projects/` exists and the active session's slug dir is locatable (most-recently-modified `.jsonl` across all slug dirs identifies it).

## Process

### 1. Identify scope

- **Project repo:** walk up from CWD until `.git/` is found. That's the project root.
- **Active slug dir:** under `~/.claude/projects/`, find the dir whose `.jsonl` files have the latest mtime overall. That's the active session's project slug. (Don't try to compute the slug from the path — Claude Code's slugging rules are inconsistent across projects.)
- **Memory dir:** `~/.claude/projects/<slug>/memory/`. Create if missing.
- **Hint:** the optional `<hint>` argument from `/learn <hint>`. Empty string if none.

### 2. Gather inputs

The transcripts are the load-bearing input — the rest is supporting context.

**Filter the transcripts first.** Raw JSONLs are 1-3 MB each (mostly tool calls and tool results, which are noise for learning extraction). The skill bundles a filter script that strips them down ~10× without losing dialog substance:

```bash
SLUG_DIR="<absolute path to slug dir>"
JSONLS=$(ls -t "$SLUG_DIR"/*.jsonl | head -5 | tr '\n' ' ')
python ~/.claude/skills/learn/scripts/filter_transcript.py /tmp/learn_transcripts.txt $JSONLS
wc -c /tmp/learn_transcripts.txt   # sanity check, ~700 KB-1 MB
```

Then gather the rest:

- **Cutoff timestamp:** read `<slug>/memory/.last_learn` (a single ISO-8601 timestamp). If absent, use the mtime of `<repo>/LEARNINGS.md`. If LEARNINGS.md doesn't exist, use 7 days ago.
- **Git context:** `git log --since=<cutoff> --stat -p` from the project root. Cap at ~200 lines.
- **Existing LEARNINGS.md** in full (for dedup).
- **Every `.md` file** in the memory dir (for dedup).
- **Project context:** read `<repo>/CLAUDE.md` if present. The subagent will use it to skip restating already-documented conventions.

Assemble all of these into `/tmp/learn_bundle.md` with clear section headers (`## EXISTING LEARNINGS.md`, `## SESSION TRANSCRIPTS`, etc.) so the subagent can navigate.

### 3. Spawn extraction subagent

Use the **Agent** tool with `subagent_type: general-purpose` and `model: sonnet`. The transcripts can be large; haiku will miss nuance.

Brief the subagent with:

> You are the extraction subagent for the `/learn` skill. Read `/tmp/learn_bundle.md` and produce candidate entries for two streams. The bundle contains the existing LEARNINGS.md, the project's CLAUDE.md, recent git log, the existing memory entries, and the dialog substance of the last 5 Claude Code sessions for this project (already filtered — only user messages and assistant text/thinking remain).
>
> **Project:** `<project name>`
> **Project root:** `<absolute path>`
> **User hint:** `<hint or "(none)">`
> **Today's date:** `<YYYY-MM-DD>`
>
> ## OUTPUT CONTRACT (read this twice)
>
> Your entire response must be EITHER:
>
> - The literal string `NO_LEARNINGS` and nothing else (when no non-obvious insights surface), OR
> - A single JSON object — no preamble, no `"```json"` fences, no trailing prose, no commentary. The first character of your response is `{` and the last is `}`. If you wrap output in fences or add explanatory text, the parser fails and the run is wasted.
>
> JSON shape:
> ```
> {
>   "learnings": [
>     {
>       "title": "<5-8 word title>",
>       "bullets": ["<truth>", "<consequence>", "<optional reference>"],
>       "domain_hint": "<existing LEARNINGS.md section name, or empty>"
>     }
>   ],
>   "memory_entries": [
>     {
>       "name": "<kebab-case>",
>       "description": "<one-line>",
>       "type": "<user|feedback|project|reference>",
>       "body": "<multi-line markdown>"
>     }
>   ]
> }
> ```
>
> ## Stream 1: LEARNINGS.md candidates (project-bound technical gotchas)
>
> Format each entry as:
> ```
> ### YYYY-MM-DD · /learn · <5-8 word title>
> - <non-obvious truth>
> - <consequence or fix>
> - (optional) Reference: `file.ext:line`, related PR, external link.
> ```
>
> Belongs here: bugs not obvious from code, failed assumptions, library/tooling/version quirks, performance surprises, race conditions, integration traps, OOM patterns, retry strategies that worked.
>
> Does NOT belong here: code-explaining bullets, style notes, generic advice, feature/refactor descriptions, anything already documented in CLAUDE.md or existing LEARNINGS.md.
>
> ## Stream 2: Memory entries (typed, in auto-memory format)
>
> Type guidance:
> - `user` — facts about the user's role, expertise, preferences about themselves.
> - `feedback` — guidance the user gave you about how to work (corrections OR validated approaches that worked). Body should include `**Why:**` (motivation/incident) and `**How to apply:**` (when this kicks in) lines.
> - `project` — facts about ongoing work, decisions, motivations not derivable from code or git history.
> - `reference` — pointers to external resources / dashboards / tracking systems.
>
> Names are kebab-case filenames. Descriptions are one line and used for relevance matching by future sessions.
>
> ## Anti-confabulation rules (these are why prior runs went off the rails)
>
> 1. **Every claim must be traceable to specific evidence in the bundle.** A real session line, a real commit, a real env var that appears in the transcript or in `.env.example`. If you can't point at the source, omit it.
> 2. **Do not infer plausible-sounding patterns.** "The user probably did X because that would solve Y" is forbidden. Only extract things that actually happened.
> 3. **Be conservative.** Better to under-extract than to confabulate. A run that produces 5 high-fidelity entries is more valuable than one that produces 12 with 4 invented.
> 4. **No env vars or config keys that aren't in the bundle.** If you mention `RAGAS_LLM_MODEL` or `OLLAMA_NUM_GPU` or any other configuration knob, it must appear in `.env.example`, `CLAUDE.md`, the transcripts, or the git diff — somewhere in the bundle. Otherwise drop it.
> 5. **Cross-reference your own output.** Before finalizing, re-read each entry and confirm the specific file paths, error messages, and commit hashes you cite are real (present in the bundle).
>
> ## Dedup rules
>
> 1. If a candidate is already covered by content in CLAUDE.md or LEARNINGS.md (same fact, same insight), skip it. Don't generate near-duplicates.
> 2. If existing memory entries already cover a memory candidate, skip it.
>
> ## Hint handling
>
> If the user hint is non-empty, bias extraction toward that topic. Items unrelated may still surface if they're highly significant.
>
> ## Final self-check
>
> Before emitting, verify:
> - Output starts with `{` (or is the literal `NO_LEARNINGS`).
> - Output ends with `}`.
> - No ``` fences anywhere.
> - No "Here is the JSON" / "I have analyzed" / "Let me produce" preamble.
> - Every entry passes the anti-confabulation rules above.

The brief above is the SUBAGENT prompt — pass it as the `prompt` parameter to the Agent tool, with the project name, root path, hint, and date interpolated into the placeholders.

### 4. Parse subagent output

Strip leading/trailing whitespace. If the result is `NO_LEARNINGS`, go to step 5a.

Otherwise:
- Strip ``` fences if the subagent emitted them despite the contract (don't fail the run on this — log and continue, then iterate the skill).
- Strip leading/trailing prose if any (split on first `{` and last `}` and parse what's between).
- Parse as JSON. On parse failure, save raw output to `/tmp/learn-subagent-<ts>.log`, exit with: `Extraction subagent returned malformed output — see <log path>. No commit made.`

### 5. Decide

#### 5a. NO_LEARNINGS

- Print: `No new learnings surfaced for <project>.`
- Update the `.last_learn` marker (we still did the pass — don't re-extract these transcripts next time).
- Exit. Do not commit.

#### 5b. Otherwise: present draft

Print the parsed JSON as a numbered, grouped preview. Number every item (LEARNINGS first, memory second, single number space). Example:

```
## Proposed LEARNINGS.md entries

[1] 2026-04-29 · /learn · OLLAMA_NUM_PARALLEL=2 OOMs Qwen-32B
    - Setting OLLAMA_NUM_PARALLEL=2 makes Qwen-32B request 19.9 GiB RAM…
    - Symptom: ollama 500 "model requires more system memory"…

[2] 2026-04-29 · /learn · Rich progress bar masks LightRAG querying time
    - …

## Proposed memory entries

[3] feedback / max-async-recommendation
    description: MAX_ASYNC=4 is the sweet spot when OLLAMA_NUM_PARALLEL=2; raise no further.
    type: feedback
    body (preview): MAX_ASYNC=4 + OLLAMA_NUM_PARALLEL=2 saturates the 3090 …

Reply `ship` to commit, or edits in plain English.
Examples:
  "drop 2 and 4"
  "rewrite #1 bullet 2 to mention chunk-2 specifically"
  "refile 3 to LEARNINGS as Ingestion section"
  "add: bemer e2e tests need mail.tm because Gmail throttles"
  "cancel"
```

Show ~3 lines per entry preview — enough for the user to decide without reading the full body.

### 6. Curation loop

Accept user instructions in plain English:

| User says | Do |
|---|---|
| `ship` / `yes` / `approve all` / `looks good` | proceed to step 7 |
| `drop N` (or `drop N, M, K`) | remove the listed items, then **also strip references to them from sibling entry bodies** (see below), reprint, wait |
| `rewrite N bullet K → <new text>` | replace that bullet, reprint, wait |
| `rewrite N → <new draft>` | replace the whole entry, reprint, wait |
| `refile N to LEARNINGS [as <section>]` | move from memory list to LEARNINGS list, reprint |
| `refile N to memory as <type>` | move from LEARNINGS to memory with given type, reprint |
| `add: <free-form description>` | spawn a quick sonnet subagent to draft an entry from the hint, slot it in, reprint |
| `cancel` / `abort` | discard draft, do not commit, do not update marker |

Do NOT write files until the user explicitly ships.

**Body refresh on drop.** When the user drops an item, the remaining items may still cite the dropped fact in their bodies (e.g. memory entry summarizing 4 things, one of which was dropped). After removal, scan the remaining bodies for substring references to the dropped entry's topic:
- For LEARNINGS drops: search remaining bodies for the dropped title's distinctive nouns (e.g. dropping "RAGAS_LLM_MODEL gives 7B judge speedup" → search for `RAGAS_LLM_MODEL` in remaining bodies).
- If a hit is found, surface it: `Heads up: entry #N's body still mentions <token> — should I strip that line? (yes/no/leave it)`
- The user decides per-case. Default: leave it (user opted to drop the standalone but may still want the cross-reference).

This step exists because the user's first /learn run discovered that dropping an entry left its content stranded in a memory entry's body — the curation should catch this before commit.

### 7. Write files

**LEARNINGS entries:**
- Open `<repo>/LEARNINGS.md`. Read in full.
- For each entry, choose the destination section:
  1. If `domain_hint` matches an existing `## <Section>` heading (case-insensitive substring) → use it.
  2. Else, keyword-match the entry against existing section headings.
  3. Else, create a new `## <reasonable section name>` (or fall back to `## General`).
- Insert entries at the TOP of their section (newest-first within the section).
- Preserve everything else byte-for-byte.

**Memory entries:**
- For each entry, write `<slug>/memory/<name>.md`:
  ```
  ---
  name: <name>
  description: <description>
  type: <type>
  ---
  <body>
  ```
- If `<slug>/memory/MEMORY.md` exists, append a one-line index entry: `- [<name>](<name>.md) — <description>`. If it doesn't exist, create it with a `# Memory Index` header.
- If a file with that `name` already exists, the curation loop should have caught this — if it slipped through, ABORT writes and re-prompt user.

### 8. Atomic commit

```bash
cd <repo>
git add LEARNINGS.md
git commit -m "docs(learnings): /learn capture <YYYY-MM-DD>"
```

The memory dir is outside the project repo — those writes land as files but aren't committed by this skill.

If the pre-commit hook fails: surface its output, exit non-zero. Do NOT use `--no-verify`. Do NOT amend. The user fixes the hook issue and re-runs.

### 9. Update marker and report

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ" > "<slug>/memory/.last_learn"
```

Print a tight summary:

```
✓ Captured N learning(s) → <repo>/LEARNINGS.md
✓ Wrote M memory entry/entries → ~/.claude/projects/<slug>/memory/
→ Run /reingest in cz_dev_rag/ to push these into LightRAG.
```

## Bypass for trust-building

`/learn --auto` skips the curation step (step 6). Subagent draft → write → commit. Use only after the skill is calibrated and you trust its extraction. Default behaviour stays interactive.

## Success criteria

- A commit `docs(learnings): /learn capture YYYY-MM-DD` exists on the current branch (or `NO_LEARNINGS` was returned and no commit was made).
- The `<slug>/memory/.last_learn` marker is updated.
- New memory entries have valid YAML frontmatter and appear in `MEMORY.md`.

## Failure modes

- **Not in a git repo** → exit with: `/learn must be run inside a git repository.`
- **No active slug dir found** (no JSONL anywhere with a recent mtime) → fall back to git log + LEARNINGS.md as the only inputs. Print a warning that transcript-based extraction is degraded.
- **Subagent malformed output** (unparseable, no `learnings`/`memory_entries` keys) → log raw to `/tmp/learn-subagent-<ts>.log`, exit 0 with: `Extraction subagent returned malformed output — see <log path>. No commit made.`
- **Pre-commit hook fails** → exit non-zero with hook output. Files written remain on disk uncommitted.
- **Memory file with same `name` already exists at write time** → abort all writes, re-enter curation loop with the conflict surfaced.
- **Git working tree dirty before `/learn`** → not a hard fail; the `git add LEARNINGS.md` is targeted. The user's other unstaged changes won't be touched.

## Bundled scripts

- `scripts/filter_transcript.py` — strips Claude Code JSONL transcripts to dialog substance (drops tool calls / tool results), reduces ~10× before feeding to the extraction subagent.

## Related skills

- `~/.claude/skills/gsd/commands/capture-learnings/` — DEPRECATED, slated for removal once `/learn` is dialed in.
- `<cz_dev_rag>/.claude/skills/reingest/` — consumes the output of `/learn` (changed LEARNINGS / memory files) to update the LightRAG graph. Run separately, when ready.
