# Topic Buckets for Pulse-Check Diversity Enforcement

Every signal must be tagged with exactly one bucket from this list. Step 3 of pulse-check enforces **max 1 topic per bucket** in the ranked top 5. If a bucket has appeared in the last 3 pulse runs (tracked in `.state.json`), penalize its score.

---

## Tooling-escape buckets (use sparingly — historically over-represented)

### `airtable-limits`
50k-record wall, 50-automation cap, API enforcement, pricing restructures. Keywords: "Airtable", "50000", "automation limit", "record cap".

### `bubble-cost`
$10K/month threshold, page load degradation, workload units, Bubble migration stories. Keywords: "Bubble.io", "$10K/mo", "workflow units", "outgrew Bubble".

### `zapier-pricing`
Per-task billing, price spikes, Make/n8n alternatives. Keywords: "Zapier", "£1,200", "per-task", "predatory pricing".

### `vendor-lockin`
Pricing restructures, export friction, can't-leave dynamics across any vendor. Keywords: "license restructure", "can't export", "locked in".

---

## Structural / craft buckets

### `data-modeling`
Relational complexity breaks spreadsheet tools — bridge tables, many-to-manys, joins. Keywords: "bridge table", "normalization", "data model", "relations".

### `migration-war-story`
Specific migration narratives — what broke during the cutover, what the 90-day plan looked like, what data was lost. Keywords: "migration", "cutover", "data loss", "migration plan".

---

## Vertical / industry buckets (prefer — under-represented)

### `vertical-pain`
Operational pain specific to a rotating vertical (logistics, agency, field service, property, e-commerce ops, manufacturing, healthcare ops, real estate). Tag with vertical sub-slug, e.g. `vertical-pain:logistics`.

---

## Builder / decision buckets (prefer — under-represented)

### `build-vs-buy`
Founder decision frameworks, intake questions, when to hire custom dev. Keywords: "build vs buy", "first engineer", "when to hire dev".

### `hiring-first-dev`
First technical hire, contractor vs in-house, scoping with non-technical founder. Keywords: "first dev", "hiring contractor", "technical co-founder".

### `shipped-internal-tool`
Founder stories about what they built — Show HN, launch posts, weekend builds. Keywords: "Show HN", "I built", "weekend project", "internal tool launched".

---

## Ops / adjacent buckets

### `ops-chaos`
Process sprawl, tool-switching cognitive load, undocumented Zaps, manual workarounds — without being tied to a single vendor. Keywords: "spaghetti", "cognitive overhead", "manual workaround", "tool sprawl".

### `reporting-hell`
Dashboard rebuild cycles, KPI reconciliation, board-pack prep pain. Keywords: "board deck", "KPI", "reporting", "dashboard".

### `compliance-workflow`
GDPR, SOC 2, audit trails, data retention — custom tooling need driven by compliance not efficiency. Keywords: "GDPR", "SOC 2", "audit trail", "compliance".

---

## How to tag a signal

1. Match keywords first.
2. If multiple buckets match, pick the **most specific** (e.g. `vertical-pain:logistics` beats `ops-chaos`).
3. If nothing matches, propose a new bucket in the pulse file's notes section and tag as `unbucketed` — do not silently drop the signal.

## Diversity enforcement (Step 3 rule)

When ranking the top 5:
- Sort all deduplicated signals by composite score.
- Walk the sorted list and accept each signal only if its bucket is not already in the accepted set.
- If a tooling-escape bucket (`airtable-limits`, `bubble-cost`, `zapier-pricing`, `vendor-lockin`) appeared in any of the last 3 pulse runs (check `.state.json`), apply −2 score penalty before sorting.
- Final output must contain at most **1** tooling-escape bucket in the top 5. If only tooling-escape signals exist, return fewer than 5 topics rather than padding.
