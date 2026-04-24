---
name: linkedin-post
description: "Standalone LinkedIn post drafter for CZ Dev. Reads rotation state, checks recent pulse file for topics, drafts 2 post variants (personal + brand voice) with stop-slop check, and saves to posts/YYYY-MM-DD/. Trigger when: user says /linkedin-post, wants to write or draft a LinkedIn post for CZ Dev, has a post type or topic ready, has already run pulse-check and wants the draft, or just transcribed competitor content and wants to turn it into a post. Arguments: optional post type (hot-take, education, case-study, behind-the-scenes) and optional topic string. Use create-post instead if the user wants the full pipeline including NotebookLM visuals or hasn't done a pulse check yet."
---

# LinkedIn Post Pipeline — CZ Dev

> Read `references/czdev-context.md` for CZ Dev positioning, ICP, and tone.
> Read `references/content-types.md` for post type templates and rotation order.
> Refer to the `linkedin-content` skill for hook formulas, formatting rules, and algorithm signals. Apply all rules to every post.

---

## Invocation

```
/linkedin-post [type] ["topic"]
```

**Examples:**
- `/linkedin-post` — auto-selects next type from rotation, checks for pulse data
- `/linkedin-post hot-take` — forces hot-take format
- `/linkedin-post education "5 signs you've outgrown Airtable"` — type + specific topic
- `/linkedin-post behind-the-scenes` *(after transcribing competitor reels)* — uses transcribed content as research input

---

## Pipeline Steps

Execute **in order**. Do not skip steps.

---

### Step 1 — Determine Post Type, Topic & Research Mode

1. Read `C:\Users\Toma\projects\czdev-content\.post-state.json`.
   If missing, default to `last_type: null`, start rotation from `hot-take`.
2. If the user passed a type argument, use it. Otherwise use `next_type` from the state file.
   Rotation order: hot-take → education → case-study → behind-the-scenes → repeat.
3. **Determine topic and research mode:**
   - **If the user passed a topic string** → use it directly. Set research mode to `web-search`.
   - **If transcribed content is present in the conversation** (from a prior `/transcribe` call or pasted text) → set research mode to `transcribed-content`. Note that the transcribed material will serve as the research input in Step 2.
   - **If no topic was passed:** Check `C:\Users\Toma\projects\czdev-content\analytics\pulse\` for a pulse file from the last 7 days (list files by date, pick the most recent).
     - **If a fresh pulse file exists:** Read it and present ranked topics: "Found pulse from [date]. Pick a topic: 1) [title] 2) [title] 3) [title] — or type your own." Wait for their choice. Set research mode to `pulse-informed`.
     - **If no pulse file:** Set research mode to `web-search`. Derive a topic from post type + CZ Dev context.
4. State clearly before continuing: `Post type: X | Topic: Y | Research mode: Z`

---

### Step 2 — Research

**If research mode is `pulse-informed`:**
The pulse file already contains curated source links and engagement signals. Extract directly from it:
- The 2 strongest hook patterns implied by the sources
- The dominant pain point and emotional trigger
- The recommended angle for CZ Dev (already in the pulse file)
No web research agent needed. Proceed to Step 3.

**If research mode is `transcribed-content`:**
Analyze the transcribed text in context:
- Extract hook patterns and structures that performed well (high view counts, engagement signals)
- Identify the emotional triggers and body structures used
- Note what to adapt vs. avoid for the CZ Dev audience
No web research agent needed. Proceed to Step 3.

**If research mode is `web-search`:**
Spawn a **general-purpose sub-agent** with this task:

> Search the web for 5 pieces of LinkedIn content with high engagement relevant to [post type] in the niche of "custom software for founders who've outgrown no-code tools."
>
> Run these 3 searches:
> 1. `LinkedIn post founders "outgrown no-code" OR "custom software" OR "Airtable limits" high engagement`
> 2. `LinkedIn viral post [post type] startup founders automation tools`
> 3. `LinkedIn [post type] "no-code" OR "CRM" OR "custom tools" founder 2024 2025`
>
> For each of the 5 pieces found, return:
> - Hook (first 1-2 lines)
> - Body structure summary (story arc, list, etc.)
> - CTA used
> - Engagement signal (likes/comments mentioned, or why it appears high-engagement)
> - Why it worked (emotional trigger, pain point, format)
>
> Return a structured list of all 5.

Wait for the research agent to complete before continuing.

---

### Step 3 — Research Brief

Synthesize the research into a brief (5–8 bullet points). Label it `## Research Brief`:
- **2 strongest hook patterns** (with examples)
- **Dominant body structure** (list, story, before/after, etc.)
- **Most effective CTA pattern**
- **Core emotional trigger**
- **Recommended angle for CZ Dev**

---

### Step 4 — Draft Two Post Variants

Using the Research Brief + CZ Dev context + post type template:

**Variant A — Personal Voice** (Tamas's personal profile)
- First-person ("I", "we built", "last month I talked to a founder who...")
- Conversational, specific, story-driven
- 150–300 words

**Variant B — Brand Voice** (CZ Dev company page — post this one)
- "We" or third-person ("CZ Dev"), direct but human
- 150–300 words

Both variants must follow `linkedin-content` skill rules:
- Hook ≤ 210 characters (count carefully)
- One sentence per line, blank lines between paragraphs
- No external links in the post body
- End with an engagement question (CTA)
- 3–5 niche hashtags at the end

---

### Step 5 — Stop-Slop Pass

Run the stop-slop check on both variants. This is mandatory — do not skip.

**Banned patterns to remove:**
- Em dash (—) anywhere — restructure the sentence
- Openers: "Here's the thing / Here's what / Here's why", "Most founders don't...", Wh- starters (What, When, Where, Which, Who, Why, How)
- Structures: "Not X. Y." / "Not X, it's Y." — state Y directly instead
- "None of these are..." / negative listing
- Three-item lists (use two or four)
- Corporate openers: "Excited to announce", "I'm proud to share", "In today's world/landscape"

Revise any violating sentences in-place. If a variant is clean, note "✓ clean".

---

### Step 6 — Optimization Check

Review both revised variants against this checklist:

```
Hook ≤ 210 chars?          [ ] Variant A   [ ] Variant B
No links in body?          [ ] Variant A   [ ] Variant B
3–5 hashtags?              [ ] Variant A   [ ] Variant B
Engagement question (CTA)? [ ] Variant A   [ ] Variant B
No corporate opener?       [ ] Variant A   [ ] Variant B
One sentence per line?     [ ] Variant A   [ ] Variant B
80/20 value vs promo?      [ ] Variant A   [ ] Variant B
No stop-slop patterns?     [ ] Variant A   [ ] Variant B
```

State which variant is stronger and why (1–2 sentences).

---

### Step 7 — Save & Deliver Output

**7a — Save post files**

Create `C:\Users\Toma\projects\czdev-content\posts\YYYY-MM-DD\` (today's date) if it doesn't exist.

Save two plain-text files (no markdown, no asterisks, no dashes — just raw text and blank lines):

**`posts/YYYY-MM-DD/brand.txt`**
```
[Variant B — brand voice, plain text]

---
FIRST COMMENT:
[czaban.dev link + 1-line description of what to find there]
```

**`posts/YYYY-MM-DD/personal.txt`**
```
[Variant A — personal voice, plain text]

---
FIRST COMMENT:
[czaban.dev link + 1-line description]
```

**7b — Update rotation state**

Read the current `.post-state.json`, then write the updated version preserving all existing entries:
```json
{
  "last_type": "[type just used]",
  "rotation": ["hot-take", "education", "case-study", "behind-the-scenes"],
  "posts": [
    ...existing posts...,
    {
      "date": "YYYY-MM-DD",
      "type": "[type]",
      "file": "posts/YYYY-MM-DD/brand.txt",
      "status": "draft"
    }
  ],
  "next_type": "[next type in rotation]"
}
```

**7c — Print delivery summary**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
POST READY
Type: [type] | Recommended: Brand voice (Variant B)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Saved to: posts/YYYY-MM-DD/brand.txt
Open the file → select all → paste into LinkedIn. No formatting issues.

METADATA
Hashtags: [list]
Timing: Tuesday–Thursday, 7–8 AM Budapest time
Visual: [Yes — describe / No]
Hook length: [X chars]
Research mode used: [pulse-informed / transcribed-content / web-search]

NEXT POST TYPE IN ROTATION: [next type]

REMINDER: Reply to every comment in the first 30–60 min after posting.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Rules (enforced by steps above — included here as a quick reference)

- No URL in post body — always in the first comment
- Hook ≤ 210 characters, always count before finalizing
- No more than 5 hashtags
- All output files go to `posts/YYYY-MM-DD/` — never to the project root
- Stop-slop pass is not optional
- Do not edit the post within the first hour after publishing (LinkedIn algorithm penalty)
