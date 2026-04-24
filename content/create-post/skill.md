---
name: create-post
description: >
  End-to-end LinkedIn content pipeline for CZ Dev. Reads rotation state, runs
  pulse check (or uses recent results), generates NotebookLM visual brief
  (conditional on post type), handles watermark removal, drafts two post
  variants, saves everything to posts/YYYY-MM-DD/, and suggests a publish date.
  One post per run. Use whenever: user says /create-post, wants to run the full
  content pipeline from scratch, or wants a LinkedIn post with visuals included.
  Optional argument: post type override (e.g. /create-post education).
---

# Create Post — Full Content Pipeline

> This skill orchestrates the entire CZ Dev LinkedIn content pipeline in one run.
> It references other skills rather than duplicating their rules:
> - Apply all formatting rules from the **linkedin-content** skill.
> - Use post type templates from `C:\Users\Toma\projects\czdev-content\.claude\skills\references\content-types.md`.
> - Use ICP, positioning, and tone from `C:\Users\Toma\projects\czdev-content\.claude\skills\references\czdev-context.md`.

---

## Step 1 — Read State & Determine Post Type

1. Read `C:\Users\Toma\projects\czdev-content\.post-state.json`.
   - Extract `next_type` (post type for this run).
   - Extract `rotation` array and `posts` history (to find last post date for scheduling).
   - If file is missing or corrupt, default to `next_type: "hot-take"`.
2. Read `C:\Users\Toma\projects\czdev-content\.claude\skills\references\czdev-context.md` for ICP and tone.
3. Read `C:\Users\Toma\projects\czdev-content\.claude\skills\references\content-types.md` for the template matching `next_type`.
4. If the user passed an explicit type argument (e.g. `/create-post education`), override `next_type` with that value. Do not advance the rotation counter for manual overrides.

State clearly before continuing:
```
Post type: [X]  (from rotation / user override)
Last post: [date] — [type]
Next in rotation after this: [Y]
```

---

## Step 2 — Pulse Check (Topic Discovery)

1. List files in `C:\Users\Toma\projects\czdev-content\analytics\pulse\` and find the most recently dated one.
2. If a pulse file exists from the **last 7 days**:
   - Read it and present the ranked topics:
     ```
     Found pulse from [date]. Pick a topic:
     1) [Topic 1 title] — [1-line angle]
     2) [Topic 2 title] — [1-line angle]
     3) [Topic 3 title] — [1-line angle]
     Or type your own topic.
     ```
   - Wait for user response (number or custom text).
3. If **no recent pulse** (older than 7 days or no files at all):
   - State: "No recent pulse found. Running scan now..."
   - Execute the full pulse-check inline (Steps 1–5 of the pulse-check skill):
     - Spawn three parallel sub-agents (Reddit, HN+PH, X/Twitter+LinkedIn)
     - Curate, rank, and gap-analyse signals
     - Save to `analytics/pulse/YYYY-MM-DD.md`
   - Present the ranked topics as above and wait for user choice.
4. Record: chosen topic title and source URL(s).

State clearly:
```
Topic: [topic title]
Source: [URL or "user-provided"]
```

---

## Step 3 — NotebookLM Visual Brief (Conditional)

Decide based on post type:

| Post Type | Action | Deliverable to request |
|-----------|--------|----------------------|
| hot-take | **SKIP this step entirely** | — |
| education | Generate Studio prompt | Slide Deck (5-7 slides) |
| case-study | Generate Studio prompt | Infographic (single page) |
| behind-the-scenes | Generate Studio prompt | Briefing Report (2 pages) |

### If post type is hot-take:
Skip to Step 5. Do not mention visuals.

### If post type is education, case-study, or behind-the-scenes:

Print this block exactly:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NOTEBOOKLM VISUAL — [POST TYPE]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Open NotebookLM Studio: https://notebooklm.google.com
   (use Zsombor's Google AI Pro account)

2. Upload or select the source doc:
   analytics/czdev-notebooklm-source.md

3. Paste this Studio prompt:

---STUDIO PROMPT---
[insert prompt from template below]
---END PROMPT---

4. Select deliverable: [Slide Deck / Infographic / Briefing Report]

5. Export as PDF or PNG.

6. Paste the exported file path here, or type "skip" to continue without a visual.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Studio prompt templates:**

**education — Slide Deck:**
```
Create a 5-7 slide educational deck about: [topic title].
Target audience: founders of 5-50 person companies who use no-code tools (Airtable, Notion, Bubble).
Tone: direct, specific, no fluff. Use concrete examples where possible.
Structure: what the problem looks like → why it happens → what the alternative is → key takeaway.
Brand: CZ Dev (czaban.dev) — "Custom tools for founders who've outgrown no-code."
Keep slides minimal: one idea per slide, short lines, no walls of text.
```

**case-study — Infographic:**
```
Create a single-page infographic summarising: [topic title].
Structure: Problem → Solution → Result (with specific numbers where available).
Use BEMER CRM data if the topic relates to CRM, rental management, or contract tracking.
Brand: CZ Dev (czaban.dev) — "Custom tools for founders who've outgrown no-code."
Keep it visual: icons, flow arrows, before/after comparison. Minimal text.
```

**behind-the-scenes — Briefing Report:**
```
Create a 2-page briefing report about: [topic title].
Show the real process, architecture decisions, or tooling choices behind this.
Audience: technical founders who want to understand what custom development actually looks like.
Brand: CZ Dev (czaban.dev).
Include a diagram, data model sketch, or decision flowchart if relevant to the topic.
```

Wait for user input. Two valid responses:
- A file path (e.g. `C:\Users\Toma\Downloads\slides.pdf`) → proceed to Step 4
- The word `skip` → jump directly to Step 5

---

## Step 4 — Watermark Removal & Visual Processing

1. Determine the **publish date folder** (from Step 7's schedule calculation, or today's date if schedule not yet known): `C:\Users\Toma\projects\czdev-content\posts\YYYY-MM-DD\`
2. Create the folder if it doesn't exist.
3. Run the watermark removal script. **Always pass `--carousel-pdf` for PDF inputs** (slide decks become a carousel on LinkedIn).

   **Crop amounts by deliverable type** (NotebookLM logo height varies):
   - PDF slide deck (rendered at 150 DPI): `--crop 116`
   - Single PNG/infographic export: default 30px is sufficient (logo is smaller in high-res PNGs)

   ```bash
   # For PDF input (slide deck) — explicit crop + carousel PDF
   python C:\Users\Toma\projects\czdev-content\scripts\remove_notebooklm_logo.py "[user-provided path]" --crop 116 --carousel-pdf "C:\Users\Toma\projects\czdev-content\posts\YYYY-MM-DD\carousel.pdf"

   # For single image input (infographic, briefing PNG) — default crop is fine
   python C:\Users\Toma\projects\czdev-content\scripts\remove_notebooklm_logo.py "[user-provided path]"
   ```
4. The script outputs files alongside the input:
   - For PDFs: `*_slide_01.png`, `*_slide_02.png`, etc. + `carousel.pdf` in the posts folder
   - For images: cleaned image at same path
5. Move all output PNGs to `posts/YYYY-MM-DD/` and rename sequentially:
   - `visual_clean_01.png`, `visual_clean_02.png`, etc.
   - `carousel.pdf` is already written directly to the posts folder by the script
6. Report:
   ```
   Visual: [N] PNG(s) → posts/YYYY-MM-DD/visual_clean_01.png ...
   Carousel PDF: posts/YYYY-MM-DD/carousel.pdf  (upload this to LinkedIn)
   ```

---

## Step 5 — LinkedIn Post Drafting

Apply all formatting rules from the **linkedin-content** skill throughout this step.

### 5a — Research Agent

Spawn a **general-purpose sub-agent** (haiku model is fine):

> Search the web for 5 pieces of LinkedIn content with high engagement relevant to "[post type]" posts about "[topic title]" in the niche of "custom software for founders who've outgrown no-code tools."
>
> Run these 3 searches:
> 1. `LinkedIn post founders "outgrown no-code" OR "custom software" OR "Airtable limits" high engagement`
> 2. `LinkedIn viral post [post type] startup founders automation tools`
> 3. `LinkedIn [post type] "[topic keyword]" founder 2025 2026`
>
> For each of the 5 pieces found, return:
> - Hook (first 1-2 lines verbatim or close paraphrase)
> - Body structure summary
> - CTA used
> - Engagement signal (likes/comments count, or qualitative note)
> - Why it worked (emotional trigger, format, pain point hit)
>
> Return a structured list of all 5.

Wait for research agent to complete.

### 5b — Research Brief

Analyse the 5 results yourself. Extract and output as `## Research Brief`:
- 2 strongest hook patterns (with examples)
- Dominant body structure
- Most effective CTA pattern
- Core emotional trigger
- Recommended CZ Dev angle for this topic + post type

### 5c — Draft Two Variants

Using the Research Brief + CZ Dev context + post type template:

**Variant A — Personal Voice** (Tamas's personal profile)
- First-person ("I", "we built", "last month I talked to a founder who...")
- Conversational, specific, story-driven
- 150–300 words

**Variant B — Brand Voice** (CZ Dev company page — post this one)
- Uses "we" or third-person, direct but human
- 150–300 words

Both MUST follow linkedin-content rules:
- Hook ≤ 210 characters (count carefully)
- One sentence per line, blank lines between paragraphs
- NO external links in post body
- End with engagement question (CTA)
- 3–5 niche hashtags at the end

If visuals were generated in Step 4, reference them naturally in the post where it fits (e.g. "See the breakdown in the carousel below" or "The infographic shows this clearly").

### 5d — Stop-Slop Pass

Run the **stop-slop** skill on both variants before proceeding. Apply all fixes inline — do not present the pre-fix drafts to the user. The stop-slop pass must catch and remove:

- Em dashes (—) anywhere — restructure the sentence instead
- Banned openers: "Here's the thing", "Most founders don't", any Wh- starter (What/When/Where/Which/Who/Why/How)
- Banned structures: "Not X. Y.", three-item lists, pull-quote one-liners as the final sentence
- Banned adverbs: really, just, literally, genuinely, honestly, simply, actually
- Banned phrases: "Here's a simple checklist.", "Let me explain.", "Think about it.", "That's a good problem to have."

After applying fixes, output the cleaned variants.

### 5e — Optimization Check

```
Hook ≤ 210 chars?          [ ] Variant A   [ ] Variant B
No links in body?          [ ] Variant A   [ ] Variant B
3-5 hashtags?              [ ] Variant A   [ ] Variant B
Engagement question (CTA)? [ ] Variant A   [ ] Variant B
No corporate opener?       [ ] Variant A   [ ] Variant B
One sentence per line?     [ ] Variant A   [ ] Variant B
80/20 value vs promo?      [ ] Variant A   [ ] Variant B
No em dashes or slop?      [ ] Variant A   [ ] Variant B
```

State which variant is stronger and why (1–2 sentences).

---

## Step 6 — Save & Deliver

### 6a — Create output folder

Target: `C:\Users\Toma\projects\czdev-content\posts\YYYY-MM-DD\` (today's date). Create if needed.

### 6b — Save post files

Plain text only — NO markdown formatting, no asterisks, no dashes. Raw text and blank lines only.

**`posts/YYYY-MM-DD/brand.txt`** (Variant B):
```
[brand voice post text]

---
FIRST COMMENT:
czaban.dev — Custom tools for founders who've outgrown no-code.
```

**`posts/YYYY-MM-DD/personal.txt`** (Variant A):
```
[personal voice post text]

---
FIRST COMMENT:
czaban.dev — Custom tools for founders who've outgrown no-code.
```

### 6c — Create notes.md

**`posts/YYYY-MM-DD/notes.md`**:
```markdown
# Post Notes — YYYY-MM-DD

- Type: [post type]
- Topic: [topic title]
- Source: [URL or "user-provided"]
- Visual: [Yes — visual_clean_01.png / No]
- Pulse used: [date of pulse file, or "fresh scan"]

## Post-publish (fill in after posting)
- Impressions:
- Reactions:
- Comments:
- Best comment/response:
- What landed:
- What to change:
```

### 6d — Update .post-state.json

Read current file, then write the updated version. **Preserve all existing entries in the posts array — append only.**

```json
{
  "last_type": "[type just used]",
  "rotation": ["hot-take", "education", "case-study", "behind-the-scenes"],
  "posts": [
    ...all existing entries...,
    {
      "date": "YYYY-MM-DD",
      "type": "[type]",
      "file": "posts/YYYY-MM-DD/brand.txt",
      "status": "draft"
    }
  ],
  "next_type": "[next type in rotation after this one]"
}
```

Rotation advancement: hot-take→education→case-study→behind-the-scenes→hot-take. If the user used a manual type override, still advance from the rotation's current position (not from the override).

---

## Step 7 — Schedule Suggestion

Calculate the recommended publish date:

1. Find the most recent **posted** or **draft** date from `.post-state.json` (the last entry before the one just created).
2. Add minimum 2 days spacing.
3. Find the next **Tuesday, Wednesday, or Thursday** on or after that minimum date.
4. If that date is today or in the past, start from tomorrow and find next Tue/Wed/Thu.
5. Suggest **7:30 AM Budapest time (CET/CEST)**.

Print final delivery block:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
POST READY
Type: [type] | Topic: [topic title]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Saved to: posts/YYYY-MM-DD/
  brand.txt        — paste into CZ Dev company page
  personal.txt     — Tamas personal profile (future use)
  carousel.pdf     — upload this to LinkedIn as carousel (if PDF visual)
  visual_clean_*.png — individual slide PNGs (reference / backup)
  notes.md         — fill in after 24h with engagement data

SUGGESTED PUBLISH DATE
[Weekday], [YYYY-MM-DD] at 7:30 AM Budapest time
(2+ days after last post on [last date])

NEXT POST TYPE: [next type]

REMINDERS
- Post brand.txt to the CZ Dev company page
- Attach visual(s) if generated
- Reply to every comment in the first 30-60 min
- Do not edit the post within the first hour
- Update notes.md after 24h with impressions and top response
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Important Rules

- **One post per run.** Run `/create-post` again for the next post.
- **Hot-take = no visual.** Never ask about NotebookLM for hot-take posts.
- **Never put URLs in post body.** Links go in the first comment only.
- **Never open with** "Excited to announce", "In today's landscape", or similar.
- **Never use more than 5 hashtags.**
- **Hook is 210 chars hard limit.** Count before finalising.
- **All output goes to `posts/YYYY-MM-DD/`.** Never write to project root.
- **Preserve post history.** Append to `.post-state.json`, never replace.
- **If user types "skip" at Step 3**, proceed to Step 5 with no visual.
