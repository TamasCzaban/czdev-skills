---
name: notebooklm
description: >
  Query the user's NotebookLM knowledge base using the notebooklm MCP server.
  ONLY trigger when the user explicitly invokes /notebooklm, includes the word
  "notebooklm" in their prompt, or says things like "ask notebooklm", "check
  notebooklm", "search notebooklm", or "use notebooklm". Do NOT trigger for
  general web searches, regular research questions, or any prompt that does not
  explicitly reference NotebookLM.
---

# NotebookLM Query Skill

Routes research queries to the user's NotebookLM notebooks via the `notebooklm` MCP server. Only use this skill when explicitly invoked — do not substitute it for general web search.

## CZ Dev Context

When invoked from the czdev-content project:
- **Primary source document:** `analytics/czdev-notebooklm-source.md` — the combined context doc that should be uploaded to NotebookLM before querying.
- **Credentials:** Zsombor's Google account (AI Pro plan). Tamas's account does not have NotebookLM MCP access.
- **Typical queries:** Research for LinkedIn posts, generating Studio outputs (Slide Deck / Infographic / Briefing Report) for behind-the-scenes / education / case-study posts.
- **Hot-take posts skip NotebookLM entirely** — no query needed for those.

If Zsombor is not available or not logged in, inform the user and suggest manually uploading `analytics/czdev-notebooklm-source.md` at notebooklm.google.com.

---

## Step 1 — Check authentication

Use the `notebooklm` MCP tool to check if a session exists. If not authenticated, tell the user:
> "NotebookLM requires Zsombor's Google credentials. I'll open Chrome for authentication."

Then call the `authenticate` tool to initiate login. Wait for confirmation before proceeding.

---

## Step 2 — Extract the query

The query is everything after `/notebooklm` in the user's prompt, or the full question if they phrased it as "ask notebooklm [question]".

If no clear query is present, ask: "What would you like to ask NotebookLM?"

---

## Step 3 — Target notebook or search all

- If the user specifies a notebook (e.g. "ask notebooklm [czdev]: what are the risks?"), target that notebook.
- If invoked from czdev-content and no notebook specified, use the notebook loaded with `czdev-notebooklm-source.md`.
- Otherwise, use `search_library` to find relevant notebooks, then query the most relevant one.
- If unsure, list available notebooks with `list_notebooks` and ask the user to pick.

---

## Step 4 — Query and return answer

Call the `ask_question` MCP tool with the query. Return the answer including:
- The response from NotebookLM
- Which notebook was queried
- Any citations or source passages provided

---

## Notes

- This skill uses browser automation (Chrome). Responses may take 10–30 seconds.
- Do NOT fall back to web search if NotebookLM is slow or unavailable — inform the user instead.
- Use the `minimal` tool profile by default (query-only). Do not create, modify, or delete notebooks unless the user explicitly asks.
- For Studio outputs (Slide Deck / Infographic / Briefing Report): tell the user which deliverable type to select and that this requires a manual step in Chrome.
