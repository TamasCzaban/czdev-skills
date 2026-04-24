---
name: pulse-check
description: >
  Scan Reddit, Hacker News, Product Hunt, and X/Twitter for trending pain points
  in the founder/no-code/custom-tools space. Outputs 3-5 ranked topic ideas with
  source links and engagement signals to feed into /linkedin-post. Use whenever:
  user says /pulse-check, wants content topic ideas, needs content inspiration,
  or wants to know what founders are talking about this week. Optional argument:
  a keyword to narrow the scan (e.g. /pulse-check "CRM").
---

# Pulse Check — Content Radar

Scan the internet for real founder pain points before writing a post. Output ranked topic ideas backed by actual online discussion, not guesswork.

Diversity is enforced. Sub-agents target different angles (vertical pain, builder signals, adjacent struggles) rather than all chasing the same "no-code limits" cluster. URLs already used in prior pulses are excluded. Tooling-escape buckets are penalised when recently used.

---

## Step 1 — Load Context & Check Recency

1. Read `C:\Users\Toma\projects\czdev-content\.claude\skills\references\czdev-context.md` for ICP and positioning.
2. Read `C:\Users\Toma\projects\czdev-content\.post-state.json` to get `next_type`.
3. Read `C:\Users\Toma\projects\czdev-content\analytics\pulse\.state.json` (see Step 1.5 if missing).
4. Read `C:\Users\Toma\projects\czdev-content\.claude\skills\pulse-check\references\verticals.md` and `topic-buckets.md`.
5. Check `C:\Users\Toma\projects\czdev-content\analytics\pulse\` for any file dated within the last 3 days. If one exists, tell the user: "A pulse from [date] already exists. Run anyway to refresh, or use the existing file?" Wait for their answer.
6. Read the most recent 3 files in `C:\Users\Toma\projects\czdev-content\posts\` to note recently covered topics.

---

## Step 1.5 — Initialise State If Missing

If `analytics/pulse/.state.json` does not exist, create it with:
```json
{
  "vertical_rotation": ["logistics", "agencies", "field-service", "property", "ecommerce-ops", "manufacturing", "healthcare-ops", "real-estate"],
  "next_vertical_index": 0,
  "cited_urls": [],
  "topic_buckets_last_3_runs": [],
  "pulse_history": []
}
```

Extract the current vertical:
```
vertical = state.vertical_rotation[state.next_vertical_index]
```

State clearly before continuing:
```
Next post type: [X]
This run's vertical: [vertical slug]
Scanning for: [keyword if provided, else "general founder pain + vertical"]
Excluded URLs: [N] from prior pulses
Penalised buckets (used in last 3 runs): [list]
Recent post topics to avoid: [list]
```

---

## Step 2 — Parallel Source Scanning (Redesigned Sub-Agents)

Spawn **three sub-agents in parallel** (single message, three tool calls). Each targets a different angle — no overlap with the others.

If the user passed a keyword argument, blend it into Agent A's vertical queries only (not B or C).

---

### Sub-Agent A: Vertical Pain Scout

> You are scanning for operational pain specific to the **[VERTICAL]** vertical. The ICP is 5–50 person companies in this vertical hitting ceilings on their current tooling. DO NOT search for "no-code" directly — look for lived operational failures and connect them back to tooling in the angle you propose.
>
> Read `C:\Users\Toma\projects\czdev-content\.claude\skills\pulse-check\references\verticals.md` and use the three search templates for **[VERTICAL]** verbatim. If the user passed a keyword, append it to each query.
>
> For each promising result, use WebFetch to read the source and extract the founder's own words.
>
> **Reject any URL in this exclusion list:** [paste state.cited_urls]
>
> Reject any source older than 90 days unless uniquely relevant.
>
> Return up to 5 signals. For each:
> - Pain point (1 sentence — the operational failure, not the tool)
> - Source URL (full, canonicalised)
> - Source date (YYYY-MM-DD if visible)
> - Engagement signal (upvotes, comment count, or qualitative note)
> - Key verbatim quote
> - Proposed topic bucket (use `vertical-pain:[vertical]`)
> - Suggested CZ Dev angle (how a custom backend solves the lived failure)

---

### Sub-Agent B: Builder Signals Scout

> You are scanning for what founders are **actively building** — not what they are escaping. The ICP is 5–50 person company founders who have shipped or are shipping a custom internal tool.
>
> Run these 3 web searches:
> 1. `site:news.ycombinator.com ("Show HN" OR "Launch HN") (internal tool OR dashboard OR CRM OR "internal app") 2025 OR 2026`
> 2. `site:news.ycombinator.com "Ask HN" ("built ourselves" OR "custom tool" OR "recommendations for" internal) 2025 OR 2026`
> 3. `site:reddit.com (r/SaaS OR r/Entrepreneur OR r/startups) "I built" OR "we built" "internal tool" OR "custom dashboard" OR "replaced" 2025 OR 2026`
>
> For the top 3–5 threads, use WebFetch to read the discussion.
>
> **Reject any URL in this exclusion list:** [paste state.cited_urls]
>
> Reject anything older than 120 days.
>
> Return up to 5 signals. For each:
> - What the founder built (1 sentence)
> - Why they built it (the trigger — what broke, what they outgrew)
> - Source URL + date
> - Engagement signal
> - Key verbatim quote
> - Proposed topic bucket (likely `shipped-internal-tool` or `build-vs-buy`)
> - Suggested CZ Dev angle (parallel story, validation signal, or contrast)

---

### Sub-Agent C: Adjacent Struggle Scout

> You are scanning for **non-tooling founder pain** that connects back to the need for custom tools. The ICP is 5–50 person company founders. Target topics: hiring the first engineer, build vs buy decisions, reporting/KPI pain, compliance workflows, team onboarding process chaos, scaling ops without proportional headcount.
>
> Run these 3 web searches:
> 1. `site:reddit.com (r/startups OR r/Entrepreneur) "first engineer" OR "build vs buy" OR "hire a developer" 2025 OR 2026`
> 2. `site:news.ycombinator.com ("Ask HN" OR "Show HN") ("reporting" OR "compliance" OR "audit trail" OR "board deck") 2025 OR 2026`
> 3. `site:reddit.com (r/smallbusiness OR r/Entrepreneur) "scaling ops" OR "process documentation" OR "manual work" OR "team onboarding" 2025 OR 2026`
>
> For the top 3–5 threads, use WebFetch.
>
> **Reject any URL in this exclusion list:** [paste state.cited_urls]
>
> Reject anything older than 120 days.
>
> Return up to 5 signals. For each:
> - Pain point (1 sentence)
> - Source URL + date
> - Engagement signal
> - Key verbatim quote
> - Proposed topic bucket (likely `build-vs-buy`, `hiring-first-dev`, `reporting-hell`, `compliance-workflow`, or `ops-chaos`)
> - Suggested CZ Dev angle (how custom tooling is the underlying answer)

---

Wait for all three sub-agents to complete before continuing.

---

## Step 3 — Curation, Ranking & Diversity Enforcement

Process all returned signals (up to 15):

1. **Deduplicate** — merge signals describing the same underlying story. Combine best quotes and sources.

2. **Drop excluded URLs** — any signal whose source URL is in `state.cited_urls`, drop entirely. Sub-agents should have already filtered, but double-check here.

3. **Tag each signal** with exactly one topic bucket from `topic-buckets.md`. If nothing fits, tag as `unbucketed` and keep.

4. **Score each signal** (base 0, add/subtract):
   - Engagement strength: +3 (high: 100+ upvotes, 20+ comments), +1 (moderate), 0 (qualitative only)
   - Recency: +2 (under 60 days), +1 (under 120 days), 0 (older)
   - Specificity: +2 (concrete metric/quote), +1 (specific story), 0 (vague)
   - Fit for `next_type`: +2 (strong fit), +1 (workable), 0 (mismatch)
   - Bucket penalty: **−2** if bucket appears in `state.topic_buckets_last_3_runs`
   - Tooling-escape bucket cap: `airtable-limits`, `bubble-cost`, `zapier-pricing`, `vendor-lockin` get an additional **−1**

5. **Diversity enforcement** — walk the sorted list greedily:
   - Start with empty accepted set.
   - For each signal in descending score: accept only if its bucket is not already in the accepted set.
   - Additional rule: at most **1** tooling-escape bucket total across the accepted set.
   - Stop at 5.
   - If fewer than 3 distinct buckets survive, return fewer topics rather than padding.

6. **Source diversity check** — the accepted top N must contain at least 2 distinct source domains. If not, drop the lowest-scoring duplicate-domain signal and promote the next distinct one.

7. **Format each accepted topic** as:
   ```
   ### [N]. [Topic Title]
   - Pain point: [1-2 sentences]
   - Source: [URL(s) with date]
   - Engagement: [signal]
   - Post type: [recommended type]
   - Bucket: [bucket tag]
   - Angle: [CZ Dev framing — specific hook direction]
   - Status: fresh
   ```

---

## Step 4 — Optional NotebookLM Enrichment

1. Check `mcp__notebooklm__get_health`.
2. If available, query: "What founder pain points appear most across sources for: [list accepted topic titles]?"
3. If returns useful context, annotate matching topics with `NotebookLM signal: [finding]`.
4. Non-blocking. Skip if unavailable or >30s.

---

## Step 5 — Save & Deliver

### 5a — Save pulse file

Create `analytics/pulse/YYYY-MM-DD.md`:
```
# Pulse Check — YYYY-MM-DD

Next post type: [type]
Vertical scanned: [vertical slug]
Penalised buckets (recent use): [list]
Sources scanned: Reddit, Hacker News, Product Hunt, X/Twitter, LinkedIn
URLs excluded from prior pulses: [N]

---

## Ranked Topics

[accepted topics, formatted per Step 3.7]

---

## Quick Use

/linkedin-post [type] "[Topic 1 title]"
/linkedin-post [type] "[Topic 2 title]"
/linkedin-post [type] "[Topic 3 title]"

---

## Raw Signals

### Vertical Scout ([vertical])
[raw Agent A output]

### Builder Signals
[raw Agent B output]

### Adjacent Struggles
[raw Agent C output]
```

### 5b — Update `.state.json`

Read, modify, write back atomically:
- Advance `next_vertical_index` by 1, wrap to 0 at end of `vertical_rotation`
- Append every accepted topic's source URL(s) to `cited_urls` (dedupe)
- Append every accepted topic's bucket to `topic_buckets_last_3_runs`, then trim to the last 3 runs worth of buckets (keep last 15 entries as a rough cap — or trim by `pulse_history` boundary)
- Append a new entry to `pulse_history`: `{"date": "YYYY-MM-DD", "vertical": "[slug]", "buckets": [...]}`
- Trim `pulse_history` to last 10 entries

### 5c — Print delivery summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PULSE CHECK COMPLETE
Vertical this run: [vertical]
Signals found: [N raw] → [M ranked]
URLs excluded: [K] from prior pulses
Buckets represented: [list]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TOP PICK: [#1 topic title]
→ [pain point, 1 sentence]
→ /linkedin-post [type] "[topic]"

Saved: analytics/pulse/YYYY-MM-DD.md
State updated: next vertical = [next vertical slug]

NEXT: Run /linkedin-post to auto-pick, or pass one directly.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Important Rules

- Never fabricate engagement numbers. If counts aren't visible, say "engagement not quantified — assessed from thread depth."
- Only scan publicly accessible content.
- Cap total WebSearch calls at 12 (3 agents × 3 searches + buffer).
- If a sub-agent finds zero relevant signals, return "No relevant signals found on [angle] this period." Do not stretch.
- Do not recommend topics that center CZ Dev features. Every topic must start from a real founder pain point or builder story.
- Return fewer than 5 topics if diversity enforcement can't find enough distinct buckets. Padding with near-duplicates is worse than a short list.
- Never skip the URL exclusion step. If a signal's URL is in `cited_urls`, drop it regardless of score.
- Each run must advance `next_vertical_index`. If a user re-runs the same day, it still advances — verticals rotate, not stall.
