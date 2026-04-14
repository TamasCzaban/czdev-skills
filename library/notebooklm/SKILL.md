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

## Step 1 — Check authentication

Use the `notebooklm` MCP tool to check if a session exists. If not authenticated, tell the user:
> "You need to log in first. I'll open Chrome for NotebookLM authentication."

Then call the `authenticate` tool to initiate login. Wait for confirmation before proceeding.

## Step 2 — Extract the query

The query is everything after `/notebooklm` in the user's prompt, or the full question if they phrased it as "ask notebooklm [question]".

If no clear query is present, ask: "What would you like to ask NotebookLM?"

## Step 3 — Target notebook or search all

- If the user specifies a notebook name (e.g. "ask notebooklm [project X]: what are the risks?"), target that notebook.
- Otherwise, use the `search_library` tool to find relevant notebooks, then query the most relevant one.
- If unsure which notebook, list available notebooks with `list_notebooks` and ask the user to pick.

## Step 4 — Query and return answer

Call the `ask_question` MCP tool with the query. Return the answer including:
- The response from NotebookLM
- Which notebook was queried
- Any citations or source passages provided

## Notes

- This skill uses browser automation (Chrome). Responses may take 10–30 seconds.
- Do NOT fall back to web search if NotebookLM is slow or unavailable — inform the user instead.
- Use the `minimal` tool profile by default (query-only). Do not create, modify, or delete notebooks unless the user explicitly asks.
