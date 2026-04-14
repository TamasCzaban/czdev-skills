# Sales Dashboard Demo Video — Full Pipeline Plan

**Target:** ~30 second MP4 demo video for a Python / Plotly Dash / Heroku sales dashboard app.
**Language:** English → Kokoro TTS (adam voice).
**Structure:** Title + Showcase (4 screens) + Tech + Closing.

---

## Phase 1: Script

Target word count: 65–75 words for ~30 seconds.

**Proposed script:**

> Sales teams drown in spreadsheets — decisions come too late.
> So we built the Sales Dashboard: one live view of everything that matters.
> Real-time sales charts, team leaderboard, territory mapping, and one-click CSV export — all in one system.
> Built with Python, Plotly Dash, and deployed on Heroku.
> Running in production and ready for your team today.

Word count: ~65 words. Estimated spoken duration: 28–31 seconds. Good fit.

**No language mismatch scan needed** — English-only script, using Kokoro.

---

## Phase 2: Generate audio (local-tts skill, Step 2a)

```bash
cd C:\Users\Toma\projects\f5-tts

python kokoro_generate.py "Sales teams drown in spreadsheets — decisions come too late. So we built the Sales Dashboard: one live view of everything that matters. Real-time sales charts, team leaderboard, territory mapping, and one-click CSV export — all in one system. Built with Python, Plotly Dash, and deployed on Heroku. Running in production and ready for your team today." sales-dashboard adam
# → output/sales-dashboard.wav
```

Kokoro outputs WAV directly — no ffmpeg conversion needed.

---

## Phase 3: Extract Whisper timestamps (local-tts skill, Step 4)

```bash
"C:\Users\Toma\projects\f5-tts\.venv\Scripts\python.exe" -c "
import whisper
m = whisper.load_model('large-v3')
r = m.transcribe('output/sales-dashboard.wav', word_timestamps=True)
print('TOTAL:', r['segments'][-1]['end'])
[print(f'{w[\"start\"]:.2f}-{w[\"end\"]:.2f}: {w[\"word\"]}') for s in r['segments'] for w in s['words']]
"
```

**What to look for in the output:**

Map four key narration moments to frame numbers (`frame = round(seconds * 30)`):

| Narration cue | ~Expected time | Frame (approx) |
|---|---|---|
| "So we built..." | ~3.5s | ~105 |
| "Real-time sales charts..." | ~8s | ~240 |
| "Built with Python..." | ~20s | ~600 |
| "Running in production..." | ~25s | ~750 |
| End of audio | ~30s | ~900 |

These become the `TIMING` constants. Actual values must come from Whisper output — do not guess.

---

## Phase 4: Scaffold Remotion project (remotion-portfolio-video skill, Step 1)

```bash
cd C:\Users\Toma\projects
npx create-video@latest sales-dashboard-video --yes --blank
cd sales-dashboard-video
npm install
```

---

## Phase 5: Copy reusable components from reference project

```bash
# Copy scenes and components from bemer-crm-video
cp C:\Users\Toma\projects\bemer-crm-video\src\components\ScreenFrame.tsx sales-dashboard-video\src\components\
cp C:\Users\Toma\projects\bemer-crm-video\src\components\FeaturePill.tsx sales-dashboard-video\src\components\
cp C:\Users\Toma\projects\bemer-crm-video\src\scenes\TitleScene.tsx sales-dashboard-video\src\scenes\
cp C:\Users\Toma\projects\bemer-crm-video\src\scenes\ScreensShowcase.tsx sales-dashboard-video\src\scenes\
cp C:\Users\Toma\projects\bemer-crm-video\src\scenes\TechScene.tsx sales-dashboard-video\src\scenes\
cp C:\Users\Toma\projects\bemer-crm-video\src\scenes\ClosingScene.tsx sales-dashboard-video\src\scenes\
```

---

## Phase 6: Copy assets

```bash
# Voiceover
cp C:\Users\Toma\projects\f5-tts\output\sales-dashboard.wav sales-dashboard-video\public\audio\voiceover.wav

# Screenshots — copy your 4 PNGs into:
#   public/screenshots/sales-charts.png
#   public/screenshots/leaderboard.png
#   public/screenshots/territory-map.png
#   public/screenshots/csv-export.png
```

Screenshot requirements:
- PNG format, full resolution
- Clean browser window — no bookmarks bar, dev tools, or personal browser data visible
- The `ScreenFrame` component will add the macOS browser chrome overlay automatically

---

## Phase 7: Configure Video.tsx

Replace TIMING values below with actual Whisper frame numbers once you have them.

```tsx
// src/Video.tsx
import { AbsoluteFill, Audio, Sequence, staticFile } from "remotion";
import { TitleScene } from "./scenes/TitleScene";
import { ScreensShowcase } from "./scenes/ScreensShowcase";
import { TechScene } from "./scenes/TechScene";
import { ClosingScene } from "./scenes/ClosingScene";

// Replace these with actual Whisper-derived frame numbers
export const TIMING = {
  title:    { from: 0,   duration: 105 },   // 0s → ~3.5s
  showcase: { from: 105, duration: 390 },   // ~3.5s → ~16.5s
  tech:     { from: 495, duration: 135 },   // ~16.5s → ~21s
  closing:  { from: 630, duration: 270 },   // ~21s → end
};

export const SalesDashboardVideo: React.FC = () => (
  <AbsoluteFill>
    <AbsoluteFill style={{ background: "#0d0d1f" }} />  {/* persistent — prevents black flashes */}
    <Audio src={staticFile("audio/voiceover.wav")} />
    <Sequence from={TIMING.title.from} durationInFrames={TIMING.title.duration}>
      <TitleScene title="Sales Dashboard" subtitle="One live view of everything that matters." />
    </Sequence>
    <Sequence from={TIMING.showcase.from} durationInFrames={TIMING.showcase.duration}>
      <ScreensShowcase
        introText="So we built the Sales Dashboard"
        screens={[
          { src: "screenshots/sales-charts.png",   label: "Real-Time Sales Charts" },
          { src: "screenshots/leaderboard.png",    label: "Team Leaderboard" },
          { src: "screenshots/territory-map.png",  label: "Territory Mapping" },
          { src: "screenshots/csv-export.png",     label: "CSV Export" },
        ]}
      />
    </Sequence>
    <Sequence from={TIMING.tech.from} durationInFrames={TIMING.tech.duration}>
      <TechScene techs={["Python", "Plotly Dash", "Heroku"]} />
    </Sequence>
    <Sequence from={TIMING.closing.from} durationInFrames={TIMING.closing.duration}>
      <ClosingScene name="Sales Dashboard" url="your-app.herokuapp.com" />
    </Sequence>
  </AbsoluteFill>
);
```

---

## Phase 8: Configure Root.tsx

```tsx
// src/Root.tsx
import { Composition } from "remotion";
import { SalesDashboardVideo } from "./Video";

// durationInFrames = Math.round(totalAudioSeconds * 30)
// Replace 900 with actual value: round(Whisper TOTAL * 30)
export const RemotionRoot: React.FC = () => (
  <Composition
    id="SalesDashboard"
    component={SalesDashboardVideo}
    durationInFrames={900}
    fps={30}
    width={1920}
    height={1080}
  />
);
```

**Critical:** After Whisper gives you the exact total duration (e.g. `TOTAL: 29.84`), update `durationInFrames`:
```
durationInFrames = Math.round(29.84 * 30)  // = 895
```
Mismatched duration = audio cut off or silent tail frames.

---

## Phase 9: Preview

```bash
cd C:\Users\Toma\projects\sales-dashboard-video
npm run dev
# Open http://localhost:3000
```

Check in Remotion Studio:
- Audio starts immediately and stays in sync throughout
- No black flashes between scenes
- Screenshots are sharp and framed correctly in browser chrome
- Feature labels (FeaturePill) fit within the frame
- Closing scene URL is readable

Adjust TIMING constants if any scene feels early/late relative to the voiceover.

---

## Phase 10: Render to MP4

```bash
cd C:\Users\Toma\projects\sales-dashboard-video

# ⚠️ Use src/index.ts as entry — NOT src/Root.tsx ("registerRoot not found" error)
npx remotion render src/index.ts SalesDashboard output/sales-dashboard-demo.mp4 --codec h264 --crf 18
```

Output: `output/sales-dashboard-demo.mp4`
Expected file size: ~3–5 MB for a 30-second video at CRF 18.
Use `--crf 23` if you need a smaller file (slight quality reduction).

---

## Quick-start checklist

- [ ] Script finalized (~65 words confirmed)
- [ ] Audio generated: `f5-tts/output/sales-dashboard.wav`
- [ ] Whisper timestamps extracted, TOTAL duration noted
- [ ] TIMING constants calculated from Whisper output (`frame = round(seconds * 30)`)
- [ ] `durationInFrames` set in Root.tsx (`Math.round(totalSeconds * 30)`)
- [ ] Remotion project scaffolded at `C:\Users\Toma\projects\sales-dashboard-video\`
- [ ] 4 clean PNG screenshots in `public/screenshots/`
- [ ] Voiceover WAV in `public/audio/voiceover.wav`
- [ ] Persistent `<AbsoluteFill style={{ background: "#0d0d1f" }} />` is first child in Video.tsx
- [ ] Preview checked in Remotion Studio (http://localhost:3000)
- [ ] Audio sync verified across all 4 scenes
- [ ] Rendered: `output/sales-dashboard-demo.mp4`

---

## Key gotchas for this project

| Problem | Fix |
|---|---|
| "registerRoot not found" render error | Use `src/index.ts` not `src/Root.tsx` as render entry |
| Black flashes between scenes | Persistent `<AbsoluteFill>` background must be first child |
| Audio ends before video / video cuts audio | Recalculate `durationInFrames` from Whisper TOTAL after every TTS regeneration |
| "Heroku" mispronounced | Kokoro handles "Heroku" well in English — no replacement needed |
| Screenshots show browser bookmarks/dev tools | Retake with clean browser window in full-screen or guest mode |
| FeaturePill label overflows | Keep labels under ~35 characters (all 4 labels here are well within limit) |
| Territory map screenshot looks blurry | Ensure PNG is at least 1280px wide before `ScreenFrame` scales it |
