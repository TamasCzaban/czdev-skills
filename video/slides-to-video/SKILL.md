---
name: slides-to-video
description: >
  Converts a folder of static images (slide PNGs, NotebookLM exports, screenshot sequences) plus
  a narration script into a fully rendered MP4 using Edge TTS / Kokoro for voiceover, Whisper
  large-v3 for word-level timestamps, and Remotion for animation and rendering.

  Use this skill whenever the user wants to turn a set of images or slides into a narrated video —
  including LinkedIn case study videos, product demos, NotebookLM slide exports, or any "slides +
  voiceover → video" task. Trigger even if the user doesn't say "Remotion" or "MP4" — phrases like
  "make a video from these slides", "add narration to my presentation", "animate my deck",
  "turn this into a short video" are all strong signals.
---

# slides-to-video

Turn a folder of static images and a narration script into an animated MP4. The pipeline has five
stages: extract slides → generate TTS audio → run Whisper for timestamps → build Remotion
composition → render.

---

## Prerequisites

- **Remotion scaffold** — created per-project (see Stage 4)
- **f5-tts venv** at `C:\Users\Toma\projects\f5-tts\.venv\Scripts\python.exe` — used for both
  Edge TTS and Whisper
- **ffmpeg** — available on PATH
- **Node.js / npm** — for Remotion

---

## Stage 1 — Extract slide PNGs

If the source is a PPTX file (e.g. a NotebookLM export), extract the embedded images with Python:

```python
import zipfile, shutil, os

pptx_path = r"C:\path\to\slides.pptx"
out_dir   = r"C:\path\to\project-video\public\slides"
os.makedirs(out_dir, exist_ok=True)

with zipfile.ZipFile(pptx_path) as z:
    media = sorted(n for n in z.namelist() if n.startswith("ppt/media/image"))
    for i, name in enumerate(media, 1):
        ext = name.rsplit(".", 1)[-1]
        out = os.path.join(out_dir, f"slide-{i:02d}.{ext}")
        with z.open(name) as src, open(out, "wb") as dst:
            shutil.copyfileobj(src, dst)
        print(out)
```

If slides are already PNGs in a folder, copy them into `public/slides/` inside the Remotion
project (naming convention: `slide-01.png`, `slide-02.png`, ...).

---

## Stage 2 — Generate TTS audio

Use the f5-tts venv. Output goes to `output/` alongside the script.

### Hungarian (Edge TTS — hu-HU-NoemiNeural)

```python
import asyncio, edge_tts

TEXT = """
Your narration script here.
"""

async def main():
    communicate = edge_tts.Communicate(TEXT, "hu-HU-NoemiNeural")
    await communicate.save(r"C:\path\to\project-video\public\audio\voiceover.mp3")

asyncio.run(main())
```

Run with:
```
C:\Users\Toma\projects\f5-tts\.venv\Scripts\python.exe tts_script.py
```

### English (Kokoro)

Invoke the `local-tts` skill for English voices — it handles Kokoro ONNX automatically.

### Hungarian script tips

- Spell out URLs: write `czaban pont dev` not `czaban.dev`
- Spell out abbreviations phonetically if Whisper gets them wrong
- Add a natural pause (~1.5 s of silence or a full sentence buffer) at the end so the last word
  isn't cut off in the final video
- Review the Edge TTS output before proceeding — replay it and fix any mispronounced words by
  adjusting spelling in the script

---

## Stage 3 — Whisper timestamps

Convert MP3 to WAV first (Whisper prefers WAV):

```bash
ffmpeg -i voiceover.mp3 voiceover.wav -y
```

Then run Whisper with word-level timestamps. Use the f5-tts venv:

```python
import whisper, json

model = whisper.load_model("large-v3")
result = model.transcribe(
    r"C:\path\to\voiceover.wav",
    word_timestamps=True,
    language="hu",          # change to "en" for English
)

# Flatten to a list of {word, start, end} dicts
words = []
for seg in result["segments"]:
    for w in seg.get("words", []):
        words.append({"word": w["word"], "start": w["start"], "end": w["end"]})

with open("timestamps.json", "w", encoding="utf-8") as f:
    json.dump(words, f, ensure_ascii=False, indent=2)

print(f"Total duration: {result['segments'][-1]['end']:.2f}s")
```

Run with:
```
C:\Users\Toma\projects\f5-tts\.venv\Scripts\python.exe whisper_timestamps.py
```

---

## Stage 4 — Build the Remotion composition

### 4a. Scaffold (first time for each project)

```bash
cd C:\Users\Toma\projects
npx create-video@latest <project-name>-video --yes --blank
cd <project-name>-video
npm install
```

Place slide PNGs in `public/slides/` and the WAV file in `public/audio/`.

### 4b. Map segments to slides

Read `timestamps.json` and decide which Whisper word/segment boundary maps to each slide
transition. This is a manual judgement call: look at the transcript, find the sentence where
the speaker moves to the next topic, note the `start` time of that word.

**Timing math (30 fps):**
```
frame = round(seconds * 30)
total_frames = round(total_duration * 30) + 45   # 1.5 s buffer
```

For each slide:
- `from`: frame where this slide starts (= frame of the matching word boundary)
- `duration`: `next_slide.from - this_slide.from` for all but the last slide
- Last slide `duration`: `total_frames - last_slide.from` (absorbs the buffer)

### 4c. Write `src/Video.tsx`

```tsx
import { AbsoluteFill, Audio, Sequence, staticFile } from "remotion";
import { SlideScene } from "./scenes/SlideScene";

export const SLIDES = [
  { file: "slide-01.png", from: 0,    duration: 130 },
  { file: "slide-02.png", from: 130,  duration: 421 },
  // ... one entry per slide
];

export const MyVideo: React.FC = () => {
  return (
    <AbsoluteFill>
      {/* Persistent background — prevents black flashes between scenes */}
      <AbsoluteFill style={{ background: "#f5f0eb" }} />

      <Audio src={staticFile("audio/voiceover.wav")} />

      {SLIDES.map((slide) => (
        <Sequence key={slide.file} from={slide.from} durationInFrames={slide.duration}>
          <SlideScene file={slide.file} duration={slide.duration} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
```

The persistent background `AbsoluteFill` is the first child and uses a solid fill. This is
important: without it, Remotion renders black frames between scene transitions which show up as
flickers in the final MP4.

### 4d. Write `src/scenes/SlideScene.tsx`

```tsx
import {
  AbsoluteFill, Img, interpolate, spring,
  staticFile, useCurrentFrame, useVideoConfig,
} from "remotion";

interface SlideSceneProps {
  file: string;
  duration: number;
}

export const SlideScene: React.FC<SlideSceneProps> = ({ file, duration }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Fade in over 15 frames
  const opacity = interpolate(frame, [0, 15], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Subtle zoom-out entrance (1.04 → 1.0)
  const scale = spring({
    frame,
    fps,
    from: 1.04,
    to: 1.0,
    config: { damping: 20, stiffness: 120 },
  });

  // Fade out over last 12 frames
  const fadeOut = interpolate(frame, [duration - 12, duration], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ opacity: opacity * fadeOut }}>
      <Img
        src={staticFile(`slides/${file}`)}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "contain",
          transform: `scale(${scale})`,
        }}
      />
    </AbsoluteFill>
  );
};
```

### 4e. Write `src/Root.tsx`

```tsx
import "./index.css";
import { Composition } from "remotion";
import { MyVideo } from "./Video";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="MyVideo"                  // used in render command
      component={MyVideo}
      durationInFrames={1860}       // total_frames from timing math
      fps={30}
      width={1280}
      height={720}
    />
  );
};
```

Update `durationInFrames` to match the value calculated in Stage 4b.

---

## Stage 5 — Render

Preview first (opens browser):
```bash
npx remotion studio
```

Render to MP4:
```bash
npx remotion render src/index.ts MyVideo output/my-video.mp4 --codec h264 --crf 18
```

- `MyVideo` must match the `id` in `Root.tsx`
- `--crf 18` is high quality; use `--crf 23` for smaller file size
- Output lands in `<project>/output/`

---

## Debugging checklist

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Black flashes between slides | Missing persistent background | Add `<AbsoluteFill style={{background: "..."}} />` as first child in `Video.tsx` |
| Audio out of sync | Wrong `from` frames | Recalculate: `frame = round(seconds * 30)` |
| Last slide cut off | Buffer too small | Increase buffer frames (default: +45) |
| Whisper misreads word | Hungarian pronunciation | Edit script text phonetically, regenerate TTS |
| Edge TTS mispronounces | Abbreviation / URL | Spell it out in script (e.g. `czaban pont dev`) |
| `staticFile` 404 at runtime | File not in `public/` | Move asset to `public/slides/` or `public/audio/` |
| PPTX has wrong image order | `ppt/media/` sort order | Sort by filename and verify order matches slide deck visually |

---

## Reference project

A working implementation lives at:
`C:\Users\Toma\projects\czdev-bemer-video\`

Key files:
- `src/Root.tsx` — composition registration with exact `durationInFrames`
- `src/Video.tsx` — `SLIDES` array with frame timings and the background pattern
- `src/scenes/SlideScene.tsx` — fade + spring animation implementation
