---
name: remotion-portfolio-video
description: >
  Animated portfolio/demo video production using Remotion (React-based video framework). Use this
  skill whenever the user wants to create a video demo of a software project, app walkthrough,
  portfolio showcase, or product demo — even if they don't say "Remotion" explicitly. Covers the
  full pipeline: scaffolding the project, building animated scenes (title, feature showcase with
  screenshots in a browser frame, tech stack, closing), integrating TTS audio, syncing scene
  timing to Whisper timestamps, previewing in Remotion Studio, and rendering to MP4. Works with
  the local-tts skill for audio generation. Reference project with reusable scene templates:
  C:\Users\Toma\projects\bemer-crm-video\
---

# Remotion Portfolio Video

A proven scene structure and component library for 30–60 second animated portfolio videos.

## Reference project

`C:\Users\Toma\projects\bemer-crm-video\` — fully working example with English + Hungarian versions.
Copy scenes and components from here as starting templates rather than writing from scratch.

---

## Step 1: Scaffold

```bash
cd C:\Users\Toma\projects
npx create-video@latest <project-name>-video --yes --blank
cd <project-name>-video
npm install
```

The blank template gives you: `src/Root.tsx`, `src/Composition.tsx`, `src/index.ts`, Tailwind v4.

---

## Step 2: Project structure

Reorganize into this layout (copy from bemer-crm-video as needed):

```
src/
  Root.tsx           — <Composition> entry: set id, durationInFrames, fps=30, width=1920, height=1080
  Video.tsx          — main composition with TIMING constants + scene <Sequence> blocks
  index.ts           — registerRoot — DO NOT use as render entry point (see Step 6)
  scenes/
    TitleScene.tsx        — dark gradient, icon + title spring-in, subtitle fade
    ScreensShowcase.tsx   — intro card (99 frames) + screenshot carousel
    TechScene.tsx         — tech logo pills + animated 0→N counter
    ClosingScene.tsx      — pulsing live dot + name + URL
  components/
    ScreenFrame.tsx   — macOS browser chrome wrapper for screenshots
    FeaturePill.tsx   — animated colored label badge
public/
  audio/voiceover.wav     — from local-tts skill
  screenshots/            — PNG screenshots of the app (see Step 3)
```

---

## Step 3: Screenshots

- Take clean app screenshots at full resolution (PNG, no browser dev tools visible)
- Save to `public/screenshots/` with descriptive names: `inventory.png`, `rentals.png`, etc.
- `ScreenFrame` adds the browser chrome overlay — no need to pre-crop

---

## Step 4: TIMING constants (Video.tsx)

Always derive from Whisper timestamps (run `local-tts` skill Step 4).

```tsx
// Video.tsx pattern
export const TIMING = {
  title:    { from: 0,        duration: titleFrames    },
  showcase: { from: X,        duration: showcaseFrames },
  tech:     { from: X+Y,      duration: techFrames     },
  closing:  { from: X+Y+Z,    duration: closingFrames  },
};
```

Total frames → set in `Root.tsx` as `durationInFrames`:
```
durationInFrames = Math.round(totalAudioSeconds * 30)
```

**Always add a persistent background as the very first child** — without it, scene gaps render as black flashes:
```tsx
export const MyVideo: React.FC = () => (
  <AbsoluteFill>
    <AbsoluteFill style={{ background: "#0d0d1f" }} />   {/* persistent — never remove */}
    <Audio src={staticFile("audio/voiceover.wav")} />
    <Sequence from={TIMING.title.from} durationInFrames={TIMING.title.duration}>
      <TitleScene />
    </Sequence>
    {/* ... more scenes */}
  </AbsoluteFill>
);
```

---

## Step 5: Key animation patterns

```tsx
import { spring, interpolate, useCurrentFrame, useVideoConfig } from "remotion";

const frame = useCurrentFrame();
const { fps } = useVideoConfig();

// Spring entrance — icon scale-in, card pop
const scale = spring({ frame, fps, from: 0.2, to: 1,
  config: { damping: 12, stiffness: 150 }, delay: 5 });

// Fade + slide up
const opacity = interpolate(frame, [20, 40], [0, 1],
  { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
const y = interpolate(frame, [20, 40], [24, 0],
  { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

// Fade out at end of a scene
const fadeOut = interpolate(frame, [duration - 15, duration], [1, 0],
  { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

// Animated counter (0 → target)
const count = Math.floor(interpolate(frame, [40, 100], [0, 391],
  { extrapolateLeft: "clamp", extrapolateRight: "clamp" }));

// Pulsing dot (live indicator)
const pulse = interpolate(Math.sin((frame / 30) * Math.PI * 2), [-1, 1], [0.4, 1.0]);
```

---

## Step 6: ScreensShowcase timing formula

```tsx
const INTRO_DURATION = 99;  // "So we built X" intro card — ~3.3s
const SCREEN_DURATION = Math.floor((totalShowcaseFrames - INTRO_DURATION) / numScreens);

// Each slide: slide in from right + fade in (12 frames), hold, fade out (12 frames at end)
const slideX = interpolate(frame, [0, 12], [60, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
const opacity = interpolate(frame, [0, 12], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
const fadeOut = interpolate(frame, [SCREEN_DURATION - 12, SCREEN_DURATION], [1, 0],
  { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
```

---

## Step 7: Color palette

| Use | Value |
|-----|-------|
| Persistent base bg | `#0d0d1f` |
| Title/closing gradient | `linear-gradient(135deg, #0d0d1f, #1a1040)` |
| Showcase bg | `#0f172a` |
| Tech bg | `#0d0d1f` |
| Grid overlay | `rgba(255,255,255,0.03)` |
| Heading text | `#FFFFFF` |
| Subtext | `#9CA3AF` |
| Muted | `#6B7280` |
| Red accent | `#E63946` |
| Indigo accent | `#6366F1` |
| Green (live) | `#10B981` |

---

## Step 8: Preview and render

```bash
# Preview in browser (hot-reloads on save)
npm run dev
# → http://localhost:3000

# Render to MP4
# ⚠️ Entry point is src/index.ts — NOT src/Root.tsx (Root.tsx gives "registerRoot not found" error)
npx remotion render src/index.ts <CompositionId> output/<name>.mp4 --codec h264 --crf 18
```

CRF 18 = high quality, ~3–5 MB for a 30s video. Use CRF 23 for smaller file if needed.

---

## Scene-building order (recommended)

1. **TitleScene** — simplest, good warm-up, establishes color palette
2. **ClosingScene** — also simple, bookends the video
3. **ScreensShowcase** — the visual core, most complex
4. **TechScene** — counter animation, logo pills

---

## Common mistakes to avoid

- `durationInFrames` out of sync with audio length → recalculate from Whisper total after every TTS regeneration
- Using `src/Root.tsx` as render entry → always use `src/index.ts`
- Missing persistent background → black flashes between scenes in rendered MP4
- Screenshots with visible browser bookmarks/dev tools → retake with clean browser window
- FeaturePill overflowing frame → keep labels under ~35 characters
