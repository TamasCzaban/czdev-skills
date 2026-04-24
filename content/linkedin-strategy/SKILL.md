# LinkedIn Strategy Skill

Audience growth planning, campaign design, and content calendar generation for CZ Dev LinkedIn presence.

## Trigger

Use when the user wants to:
- Plan the next month of content
- Design a campaign (launch, awareness, lead-gen)
- Brainstorm growth tactics for the company page or personal profile
- Build a content calendar
- Define targeting or audience strategy

Keywords: "content calendar", "plan next month", "campaign plan", "grow followers", "reach founders", "audience strategy", "what should we post", "plan a campaign"

## Context

- **Company page:** CZ Dev — targets B2B founders of 5–50 person companies
- **Personal profile:** Tamas Czaban — personal brand, thought leadership in custom dev/automation
- **Zsombor:** Can post from his own profile too; coordinated cross-posting amplifies reach
- **Content rotation:** hot-take → education → case-study → behind-the-scenes → repeat
- **Current proof of work:** BEMER CRM (primary case study)

## Campaign Planning Workflow

1. **Define goal** — followers / website clicks / DM inquiries / content reach
2. **Define duration** — typically 2–4 weeks
3. **Map content** — 3–5 posts per week, assign dates + content types
4. **Assign responsibilities** — Tamas (personal), Zsombor (personal), CZ Dev company page
5. **Write to `campaigns/<campaign-name>.md`** — see format below

### Campaign file format (`campaigns/<name>.md`)

```markdown
# Campaign: <name>
- Goal: <goal>
- Duration: YYYY-MM-DD to YYYY-MM-DD
- KPI: <target number>

## Content Calendar

| Date | Account | Type | Topic | Status |
|------|---------|------|-------|--------|
| YYYY-MM-DD | Tamas | hot-take | ... | planned |
| YYYY-MM-DD | CZ Dev | case-study | ... | planned |

## Tactics
- Cross-posting plan
- Engagement pod (first-hour comment strategy)
- CTA on each post

## Post-campaign
- Actual result vs KPI
- Learnings
```

## Content Calendar (Monthly)

When asked to plan a month:
1. Read `analytics/weekly/` to understand recent performance
2. Check `.post-state.json` for last content type used
3. Generate a 4-week calendar with the content rotation applied
4. Output as a markdown table

## Audience Growth Tactics (CZ Dev ICP)

Target: **founders of 5–50 person companies** hitting limits on Airtable/Notion/Bubble/Zapier.

Tactics to recommend based on goals:
- **Follows:** Comment on ICP founders' posts within 1h of publishing (algorithm boost)
- **Reach:** Use "hot-take" format — contrarian opinion about no-code limitations
- **Leads:** Case study posts with explicit CTA (DM, book a call)
- **Trust:** Behind-the-scenes posts (building in public)
- **Algorithm:** Native video, carousels, and polls outperform plain text currently
