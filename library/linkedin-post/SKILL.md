---
name: linkedin-post
description: "Full LinkedIn content pipeline for CZ Dev. Researches high-engagement posts in the niche, extracts patterns via sub-agents, drafts 2 post variants (personal + brand voice), runs optimization check, and delivers ready-to-copy output. Use whenever: user says /linkedin-post, wants to write a LinkedIn post for CZ Dev, needs a content idea drafted, or wants to run the content pipeline. Arguments: optional post type (hot-take, education, case-study, behind-the-scenes) and optional topic string."
---

# LinkedIn Post Pipeline — CZ Dev

> Refer to the `linkedin-content` skill for formatting rules, hook formulas, and algorithm signals. Apply all rules from that skill to every post you write.
> Read `references/czdev-context.md` for CZ Dev positioning, ICP, and tone.
> Read `references/content-types.md` for post type templates and rotation order.

---

## Invocation

```
/linkedin-post [type] ["topic"]
```

**Examples:**
- `/linkedin-post` — auto-selects next type from rotation
- `/linkedin-post hot-take` — forces hot-take format
- `/linkedin-post education "5 signs you've outgrown Airtable"` — specific type + topic

---

## Pipeline Steps

Execute these steps **in order**. Do not skip steps.

---

### Step 1 — Determine Post Type & Topic

1. Read `C:\Users\Toma\projects\czdev-content\.post-state.json` to get `last_type` and `rotation`.
   If the file is missing or unreadable, default to `last_type: null` and start rotation from `hot-take`.
2. If the user passed a type argument, use it.
   If no type was passed, pick the **next type** in the rotation array after `last_type`.
   Rotation order: hot-take → education → case-study → behind-the-scenes → hot-take → ...
3. If the user passed a topic string, use it as the post angle. Otherwise derive a topic from the post type + CZ Dev context.
4. State clearly: "Post type: X | Topic: Y" before proceeding.

---

### Step 2 — Research Agent

Spawn a **general-purpose sub-agent** with this task:

> Search the web for 5 pieces of LinkedIn content with high engagement that are relevant to [post type] in the niche of "custom software for founders who've outgrown no-code tools."
>
> Run these 3 searches (replace [post type] with the actual type from Step 1 before searching):
> 1. `LinkedIn post founders "outgrown no-code" OR "custom software" OR "Airtable limits" high engagement`
> 2. `LinkedIn viral post [post type] startup founders automation tools`
> 3. `LinkedIn [post type] "no-code" OR "CRM" OR "custom tools" founder 2024 2025`
>
> For each of the 5 pieces found, return:
> - Hook (first 1-2 lines)
> - Body structure summary (story arc, list, etc.)
> - CTA used
> - Engagement signal (likes/comments mentioned, or why it appears high-engagement based on structure)
> - Why it worked (emotional trigger, pain point, format)
>
> Return a structured list of all 5.

Wait for the research agent to complete before continuing.

---

### Step 3 — Curation & Brief

Analyze the 5 research results yourself (no sub-agent needed — you have the data):

Extract and summarize:
- **2 strongest hook patterns** from the 5 posts (with examples)
- **Dominant body structure** (list, story, before/after, etc.)
- **CTA pattern** that appeared most effective
- **Core emotional trigger** (fear of being left behind, desire for freedom, pain of manual work, etc.)
- **Recommended angle for CZ Dev** based on the above

Output this as a brief (5–8 bullet points). Label it `## Research Brief`.

---

### Step 4 — Draft Two Post Variants

Using the Research Brief + CZ Dev context + post type template from `references/content-types.md`:

Write **Variant A** and **Variant B**:

**Variant A — Personal Voice** (for Tamas's personal LinkedIn profile, future use)
- First-person ("I", "we built", "last month I talked to a founder who...")
- Conversational, specific, story-driven
- 150–300 words

**Variant B — Brand Voice** (for CZ Dev company page, post now)
- Uses "we" or third-person ("CZ Dev"), more direct
- Still human, not corporate
- 150–300 words

Both variants MUST follow the `linkedin-content` skill rules:
- Hook ≤ 210 characters (count carefully — this is what shows before "see more")
- One sentence per line, blank lines between paragraphs
- NO external links in the post body
- End with an engagement question (CTA)
- 3–5 niche hashtags at the end

---

### Step 5 — Optimization Check

Review both variants yourself against this checklist. Flag any issues inline:

```
Hook ≤ 210 chars?          [ ] Variant A   [ ] Variant B
No links in body?          [ ] Variant A   [ ] Variant B
3–5 hashtags?              [ ] Variant A   [ ] Variant B
Engagement question (CTA)? [ ] Variant A   [ ] Variant B
No corporate opener?       [ ] Variant A   [ ] Variant B
  ("Excited to announce", "In today's landscape", etc.)
One sentence per line?     [ ] Variant A   [ ] Variant B
80/20 value vs promo?      [ ] Variant A   [ ] Variant B
```

State which variant is stronger and why (1–2 sentences).

---

### Step 6 — Save & Deliver Output

**6a — Save post files**

Create the folder `C:\Users\Toma\projects\czdev-content\` if it doesn't exist.

Save two plain-text files (NO markdown, no asterisks, no dashes — just raw text and blank lines):

**File 1:** `C:\Users\Toma\projects\czdev-content\[YYYY-MM-DD]-[type]-brand.txt`
Contents:
```
[Variant B — brand voice post, plain text only]

---
FIRST COMMENT:
[czaban.dev link text]
```

**File 2:** `C:\Users\Toma\projects\czdev-content\[YYYY-MM-DD]-[type]-personal.txt`
Contents:
```
[Variant A — personal voice post, plain text only]

---
FIRST COMMENT:
[czaban.dev link text]
```

Use today's date for YYYY-MM-DD.

**6b — Update rotation state**

Write the updated state to `C:\Users\Toma\projects\czdev-content\.post-state.json`:
```json
{ "last_type": "[type just used]", "rotation": ["hot-take", "education", "case-study", "behind-the-scenes"] }
```

**6c — Print delivery summary**

After saving, output:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
POST READY
Type: [type] | Recommended: Brand voice (Variant B)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Saved to: C:\Users\Toma\projects\czdev-content\[filename]-brand.txt
Open the file → select all → paste into LinkedIn. No formatting issues.

METADATA
Hashtags: [list]
Timing: Tuesday–Thursday, 7–8 AM Budapest time
Visual: [Yes — [describe] / No]
Hook length: [X chars]

NEXT POST TYPE IN ROTATION: [next type]

REMINDER: Reply to every comment in the first 30–60 min after posting.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Important Rules

- Never put a URL in the post body. Always move links to the first comment.
- Never open with "Excited to announce" or "I'm proud to share" or "In today's world."
- Never use more than 5 hashtags.
- Always count hook characters before finalizing — 210 is a hard limit.
- Engage with comments for 30–60 minutes after posting (remind the user of this).
- Do not edit the post within the first hour after publishing (LinkedIn algorithm penalty).
