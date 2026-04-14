# Hungarian TTS Voiceover — Step-by-Step Plan

**Script:** "A MedKölcsön egy célszoftver orvostechnikai eszközök kezelésére. Modern webalkalmazás, Firebase és Streamlit alapokon. Háromszázkilencvenegy automatikus teszt. Éles üzemben, valódi ügyfelekkel."
**Target language:** Hungarian (`hu`)

---

## Step 0 — Language mismatch check

Before generating audio, scan each word with `langdetect` to find any foreign-language words that would mispronounce in a Hungarian TTS voice.

```python
# Run with: C:\Users\Toma\projects\f5-tts\.venv\Scripts\python.exe
from langdetect import detect, DetectorFactory
DetectorFactory.seed = 0

def flag_foreign_words(script: str, target_lang: str) -> list:
    flagged = []
    words = script.split()
    for i, word in enumerate(words):
        clean = word.strip('.,!?—-()[]')
        if len(clean) < 4:
            continue  # skip short function words
        try:
            detected = detect(clean)
            if detected != target_lang:
                flagged.append({'word': clean, 'detected': detected, 'position': i})
        except Exception:
            pass
    return flagged

script = "A MedKölcsön egy célszoftver orvostechnikai eszközök kezelésére. Modern webalkalmazás, Firebase és Streamlit alapokon. Háromszázkilencvenegy automatikus teszt. Éles üzemben, valódi ügyfelekkel."
print(flag_foreign_words(script, 'hu'))
```

**Expected flagged words:**
- `Firebase` — detected as `en` (English brand name)
- `Streamlit` — detected as `en` (English brand name)

### Decision: How to handle Firebase and Streamlit

Two options are available:

**Option 1 — Replace (recommended for most cases):** Substitute with a Hungarian description so the voice never switches language.
- `Firebase` → `felhős adatbázis` ("cloud database")
- `Streamlit` → `adatvizualizációs keretrendszer` ("data visualization framework")

Resulting script:
> "A MedKölcsön egy célszoftver orvostechnikai eszközök kezelésére. Modern webalkalmazás, felhős adatbázis és adatvizualizációs keretrendszer alapokon. Háromszázkilencvenegy automatikus teszt. Éles üzemben, valódi ügyfelekkel."

**Option 2 — Splice (use when brand name pronunciation matters):** Generate the Hungarian audio with a silence gap where each brand name appears, generate the English brand names separately with `en-US-AriaNeural`, then cut them in using ffmpeg. This is the approach detailed in Steps 2–3 below.

For this plan, **Option 2 (splice)** is shown in full because brand name accuracy is typical for a product demo video. Swap to Option 1 if you prefer simplicity.

---

## Step 1 — Engine selection

- Language: Hungarian → use **Edge TTS**
- Voice: `hu-HU-NoemiNeural` (female, recommended)

---

## Step 2 — Generate the Hungarian audio (with silence gaps for brand names)

Use SSML to insert `<break>` pauses where Firebase and Streamlit will be spliced in.

```python
# File: generate_medkolcson.py
# Run with: C:\Users\Toma\projects\f5-tts\.venv\Scripts\python.exe generate_medkolcson.py

import asyncio, edge_tts

ssml = """<speak>
  <voice name="hu-HU-NoemiNeural">
    A MedKölcsön egy célszoftver orvostechnikai eszközök kezelésére.
    Modern webalkalmazás,
    <break time="600ms"/>
    és
    <break time="600ms"/>
    alapokon.
    Háromszázkilencvenegy automatikus teszt.
    Éles üzemben, valódi ügyfelekkel.
  </voice>
</speak>"""

async def generate_ssml(ssml_text: str, out_mp3: str):
    c = edge_tts.Communicate(ssml_text, "hu-HU-NoemiNeural")
    await c.save(out_mp3)

asyncio.run(generate_ssml(ssml, r"C:\Users\Toma\projects\f5-tts\output\medkolcson_main.mp3"))
print("Done: medkolcson_main.mp3")
```

Convert MP3 to WAV (Whisper requires WAV):
```bash
cd C:\Users\Toma\projects\f5-tts
ffmpeg -i output/medkolcson_main.mp3 output/medkolcson_main.wav -y
```

---

## Step 3 — Generate and splice the English brand names

### 3a — Generate English brand name audio clips

```python
# File: generate_brandnames.py
# Run with: C:\Users\Toma\projects\f5-tts\.venv\Scripts\python.exe generate_brandnames.py

import asyncio, edge_tts

async def gen(text, voice, path):
    await edge_tts.Communicate(text, voice).save(path)

base = r"C:\Users\Toma\projects\f5-tts\output"
asyncio.run(gen("Firebase", "en-US-AriaNeural", f"{base}/word_firebase.mp3"))
asyncio.run(gen("Streamlit", "en-US-AriaNeural", f"{base}/word_streamlit.mp3"))
print("Brand name clips done.")
```

Convert to WAV:
```bash
ffmpeg -i output/word_firebase.mp3  output/word_firebase.wav  -y
ffmpeg -i output/word_streamlit.mp3 output/word_streamlit.wav -y
```

### 3b — Detect the silence positions in the main audio

```bash
ffmpeg -i output/medkolcson_main.wav \
  -af "silencedetect=noise=-30dB:d=0.2" \
  -f null - 2>&1 | grep silence
```

This prints lines like:
```
silence_start: 3.84
silence_end: 4.44 | silence_duration: 0.60
silence_start: 4.62
silence_end: 5.22 | silence_duration: 0.60
```

Note the two silence windows — one for Firebase, one for Streamlit.

### 3c — Split and rejoin with brand names inserted

Using the timestamps from 3b (example values shown — replace with actual detected values):

```bash
# Segment before first silence (before Firebase gap)
ffmpeg -i output/medkolcson_main.wav -t 3.84 -c copy output/seg1.wav

# Segment between the two silences (between Firebase and Streamlit gaps)
ffmpeg -i output/medkolcson_main.wav -ss 4.44 -t 0.18 -c copy output/seg2.wav

# Segment after second silence (after Streamlit gap)
ffmpeg -i output/medkolcson_main.wav -ss 5.22 -c copy output/seg3.wav

# Concatenate: Hungarian part 1 + Firebase + Hungarian bridge + Streamlit + Hungarian rest
ffmpeg \
  -i output/seg1.wav \
  -i output/word_firebase.wav \
  -i output/seg2.wav \
  -i output/word_streamlit.wav \
  -i output/seg3.wav \
  -filter_complex "[0][1][2][3][4]concat=n=5:v=0:a=1" \
  output/medkolcson_final.wav
```

---

## Step 4 — Extract word-level timestamps with Whisper

```python
# File: whisper_timestamps.py
# Run with: C:\Users\Toma\projects\f5-tts\.venv\Scripts\python.exe whisper_timestamps.py

import whisper

model = whisper.load_model('large-v3')
result = model.transcribe(
    r'C:\Users\Toma\projects\f5-tts\output\medkolcson_final.wav',
    word_timestamps=True,
    language='hu'
)

fps = 30
total_duration = result['segments'][-1]['end']
total_frames = round(total_duration * fps)

print(f"TOTAL DURATION: {total_duration:.2f}s")
print(f"TOTAL FRAMES (30fps): {total_frames}")
print()

for seg in result['segments']:
    for w in seg['words']:
        frame_start = round(w['start'] * fps)
        frame_end   = round(w['end']   * fps)
        print(f"{w['start']:.2f}s-{w['end']:.2f}s  (frames {frame_start}-{frame_end}): {w['word']}")
```

Run it:
```bash
"C:\Users\Toma\projects\f5-tts\.venv\Scripts\python.exe" whisper_timestamps.py
```

**Expected output format:**
```
TOTAL DURATION: 11.40s
TOTAL FRAMES (30fps): 342

0.00s-0.18s  (frames 0-5):    A
0.18s-0.60s  (frames 5-18):   MedKölcsön
0.60s-0.78s  (frames 18-23):  egy
...
```

Use `frame_start` values directly in Remotion:
```tsx
// Root.tsx
<Composition
  durationInFrames={342}  // from total_frames above
  fps={30}
  ...
/>

// In a sequence component:
<Sequence from={18}>  {/* word starts at frame 18 */}
  <WordHighlight word="egy" />
</Sequence>
```

---

## Summary of output files

| File | Description |
|------|-------------|
| `output/medkolcson_main.mp3` | Raw Hungarian TTS (with silence gaps) |
| `output/medkolcson_main.wav` | Converted for Whisper |
| `output/word_firebase.wav` | English "Firebase" clip |
| `output/word_streamlit.wav` | English "Streamlit" clip |
| `output/seg1.wav`, `seg2.wav`, `seg3.wav` | Split Hungarian segments |
| `output/medkolcson_final.wav` | Final spliced audio — use this in Remotion |

---

## Language check findings

The script is grammatically correct Hungarian. Two foreign-language tokens were identified:

- **Firebase** — English brand name, position 7 in the token sequence
- **Streamlit** — English brand name, position 9 in the token sequence

All other words are valid Hungarian and will pronounce correctly with `hu-HU-NoemiNeural`. No rewording of the Hungarian portions is needed.
