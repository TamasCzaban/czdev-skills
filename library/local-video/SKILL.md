---
name: local-video
description: >
  End-to-end local video production pipeline — script to rendered MP4, entirely free, no paid APIs.
  Use this skill as the single entry point whenever the user wants to make a demo video, portfolio
  video, product walkthrough, or any short-form video for a software project. Orchestrates the
  local-tts skill (Kokoro/Edge TTS + Whisper timestamps) and the remotion-portfolio-video skill
  (React animated scenes + render). Trigger this whenever the user says things like "make a video
  for my project", "create a demo video", "I want to showcase this app", "record a walkthrough",
  or "build a portfolio video" — even if they don't mention Remotion, TTS, or any specific tool.
---

# Local Video Production Pipeline

Orchestrates two skills end-to-end:
- **`local-tts`** → script → voiceover WAV + Whisper timestamps
- **`remotion-portfolio-video`** → Remotion scenes → MP4

Reference project: `C:\Users\Toma\projects\bemer-crm-video\` (reuse scenes + components).

---

## Phase 1: Plan

### 1a. Understand the project
Ask the user (or read from context):
- What does the app/project do? (1-2 sentences)
- What are the 3–5 most impressive features to show?
- What language should the video be in?
- Are screenshots available? (PNG, clean browser window)
- Rough target length: ~30s or ~60s?

### 1b. Choose video length and structure

| Target | Words | Scenes |
|--------|-------|--------|
| ~30s | 65–75 | Title + Showcase + Tech + Closing |
| ~60s | 130–150 | Title + Problem + Showcase (×10 screens) + Tech + Closing |

### 1c. Choose TTS engine
```
English script only → Kokoro (adam = authoritative, onyx = warm)
Any other language → Edge TTS
  Hungarian → hu-HU-NoemiNeural (female ✓ recommended)
  German    → de-DE-KatjaNeural
  French    → fr-FR-DeniseNeural
  Spanish   → es-ES-ElviraNeural
```

---

## Phase 2: Write the script

**Structure:** Hook → Solution → Features (rapid list) → Credibility → Close

**~30s English template:**
```
[Hook: problem or context — 1-2 sentences]
So we built [AppName]: [one-liner].
[Feature 1], [Feature 2], [Feature 3], [Feature 4], and [Feature 5] — all in one system.
Built with [Tech1], [Tech2], and [Tech3]. [N] automated tests.
Running in production with real clients today.
```

**Non-English scripts — avoid brand names** that the TTS engine will mispronounce.
Replace with category descriptions:
- "Streamlit" → "modern webalkalmazás" / "eine moderne Web-App"
- "Firebase" → "felhős adatbázis" / "eine Cloud-Datenbank"
- "Stripe" → "online fizetési rendszer" / "ein Zahlungssystem"

The tech scene will show the actual logos visually — viewers get both.

---

## Phase 3: Generate audio (use local-tts skill)

**Always scan for language mismatches first** (see local-tts Step 0), then generate:

```bash
# English
cd C:\Users\Toma\projects\f5-tts
python kokoro_generate.py "Script here." project_name adam
# → output/project_name.wav

# Hungarian
python -c "
import asyncio, edge_tts
async def main():
    c = edge_tts.Communicate('Szöveg itt.', 'hu-HU-NoemiNeural')
    await c.save('output/project_name.mp3')
asyncio.run(main())
"
ffmpeg -i output/project_name.mp3 output/project_name.wav -y
```

Get timestamps:
```bash
.venv\Scripts\python.exe -c "
import whisper
m = whisper.load_model('large-v3')
r = m.transcribe('output/project_name.wav', word_timestamps=True, language='hu')
print('TOTAL:', r['segments'][-1]['end'])
[print(f'{w[\"start\"]:.2f}-{w[\"end\"]:.2f}: {w[\"word\"]}') for s in r['segments'] for w in s['words']]
"
```

**Map key narration phrases to frame numbers** (`frame = round(seconds * 30)`). These become the scene boundaries in `TIMING`.

---

## Phase 4: Build Remotion project (use remotion-portfolio-video skill)

```bash
cd C:\Users\Toma\projects
npx create-video@latest project-name-video --yes --blank
cd project-name-video && npm install
```

Copy reusable components from `C:\Users\Toma\projects\bemer-crm-video\src\`:
- `components/ScreenFrame.tsx` — browser chrome wrapper
- `components/FeaturePill.tsx` — animated label badge
- `scenes/TitleScene.tsx` — update title/subtitle text
- `scenes/ScreensShowcase.tsx` — update screen list + labels
- `scenes/TechScene.tsx` — update tech names + test count
- `scenes/ClosingScene.tsx` — update name/URL

Copy audio + screenshots:
```bash
cp f5-tts/output/project_name.wav project-name-video/public/audio/voiceover.wav
# Copy screenshots to project-name-video/public/screenshots/
```

Set `TIMING` constants from Whisper output. Set `durationInFrames = Math.round(totalSeconds * 30)`.

---

## Phase 5: Preview + render

```bash
cd project-name-video

# Preview (hot reload, check audio sync)
npm run dev

# Render (⚠️ use src/index.ts, NOT src/Root.tsx)
npx remotion render src/index.ts <CompositionId> output/demo.mp4 --codec h264 --crf 18
```

---

## Quick-start checklist

- [ ] Script written (correct language, no mispronouncing brand names)
- [ ] Language mismatch scan run
- [ ] Audio generated + converted to WAV
- [ ] Whisper timestamps extracted + scene boundaries mapped to frames
- [ ] Remotion project scaffolded
- [ ] Screenshots in `public/screenshots/` (PNG, clean)
- [ ] Voiceover in `public/audio/voiceover.wav`
- [ ] `TIMING` constants set from timestamps
- [ ] `durationInFrames` in Root.tsx matches audio length
- [ ] Persistent background `<AbsoluteFill style={{ background: "#0d0d1f" }} />` is first child
- [ ] Preview checked in Remotion Studio
- [ ] Rendered to MP4

---

## Known gotchas (burned us before)

| Problem | Fix |
|---------|-----|
| "registerRoot not found" render error | Use `src/index.ts` not `src/Root.tsx` as entry |
| Black flashes between scenes | Add persistent `<AbsoluteFill>` background as first child |
| Checkered pattern in Studio | Normal — transparency shows as black in final MP4, not checkers |
| Audio/video out of sync | Recalculate `durationInFrames` after any TTS regeneration |
| TTS mispronounces brand names | Replace with target-language category description |
| Edge TTS outputs MP3 | Convert: `ffmpeg -i in.mp3 out.wav -y` before Whisper |
| Whisper wrong language | Pass `language='hu'` (or relevant code) to transcribe() |
