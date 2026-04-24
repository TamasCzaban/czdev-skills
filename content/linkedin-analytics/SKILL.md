# LinkedIn Analytics Skill

Track CZ Dev LinkedIn performance and produce engagement reports from local data files.

## Trigger

Use when the user wants to:
- Log this week's LinkedIn impressions, followers, or engagement stats
- See how posts or campaigns are performing
- Generate a weekly or monthly analytics summary
- Compare performance across content types

Keywords: "log analytics", "track impressions", "how did the post do", "weekly report", "engagement stats", "follower count", "analytics summary"

## Data Storage

All data lives in `analytics/` within czdev-content:

```
analytics/
├── weekly/
│   └── YYYY-WW.md     # One file per ISO week, e.g. 2026-14.md
└── campaigns/
    └── <campaign-name>.md
```

### Weekly file format (`analytics/weekly/YYYY-WW.md`)

```markdown
# Week YYYY-WW (Mon DD – Sun DD)

## Company Page
- Impressions: X
- Followers: X (±X vs last week)
- Engagement rate: X%

## Personal (Tamas)
- Impressions: X
- Connections: X (±X)
- Top post: [title] — X impressions

## Notes
- What worked, what didn't, content observations
```

### Campaign file format (`analytics/campaigns/<name>.md`)

```markdown
# Campaign: <name>
- Start: YYYY-MM-DD
- End: YYYY-MM-DD
- Goal: (followers / leads / impressions)
- Posts: list with dates and impressions
- Result: summary
```

## Workflow

1. **Log stats:** User provides numbers → write to `analytics/weekly/YYYY-WW.md`
2. **Weekly summary:** Read last 4 weeks → calculate trends → output markdown report
3. **Campaign tracking:** Read from `analytics/campaigns/` → compare goal vs actual
4. **Content type analysis:** Cross-reference with `posts/` folder to see which formats performed best

## Output

Always output:
- The file path written or read
- A brief narrative summary (2–4 sentences)
- Trend direction (up/down/flat) with ± number vs previous period
