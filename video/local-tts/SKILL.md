---
name: local-tts
description: >
  Local, free text-to-speech pipeline — no API key needed. Use this skill whenever the user wants
  to generate voiceover audio, narration, or any spoken audio from a script. Covers English (Kokoro
  ONNX, high-quality neural voices) and 40+ other languages including Hungarian (Edge TTS neural
  voices). Also handles: detecting foreign words in a script before generation, SSML-based pauses,
  splicing English brand names into non-English audio with ffmpeg, and extracting word-level
  timestamps with Whisper for video/Remotion sync. Trigger this skill for any TTS task, voiceover
  generation, audio timestamp extraction, or language mismatch detection — even if the user just
  says "generate audio for this script" or "get timestamps from this WAV".
---

# Local TTS Pipeline

All tools live in `C:\Users\Toma\projects\f5-tts\`. Always use the venv Python:
```
C:\Users\Toma\projects\f5-tts\.venv\Scripts\python.exe
```
Output goes to `C:\Users\Toma\projects\f5-tts\output\`.

---

## Step 0: Check the script for language mismatches (always do this first for non-English)

Before generating, scan for foreign words that will mispronounce. Run inline:

```python
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

# Example:
script = "Modern webalkalmazás, Firebase alapokon."
print(flag_foreign_words(script, 'hu'))
# → [{'word': 'Firebase', 'detected': 'en', 'position': 2}]
```

**When flagged words are found, present two options to the user:**
1. **Replace** — swap the foreign word with a target-language description (e.g. "Firebase" → "felhős adatbázis"). Cleaner, recommended for most cases.
2. **Splice** — generate the foreign word separately in English and cut it into the audio at the silence gap. Better for brand names where pronunciation matters.

---

## Step 1: Choose your TTS engine

| Language | Engine | Voices |
|----------|--------|--------|
| English | **Kokoro** | adam (authoritative), onyx (warm), michael, echo, eric, liam |
| Hungarian | **Edge TTS** | `hu-HU-NoemiNeural` ✓ (female, recommended), `hu-HU-TamasNeural` (male) |
| Other | **Edge TTS** | Any `xx-XX-XxxNeural` voice |

**Rule:** English-only script → use Kokoro. Any other language → use Edge TTS.

---

## Step 2a: Generate with Kokoro (English)

```bash
cd C:\Users\Toma\projects\f5-tts
python kokoro_generate.py "Your script here." output_name adam
# Output: output/output_name.wav
```

Kokoro outputs WAV directly — no conversion needed.

---

## Step 2b: Generate with Edge TTS (non-English)

Edge TTS outputs MP3, which must be converted to WAV for Whisper.

```python
import asyncio, edge_tts, os

async def generate(text: str, voice: str, out_mp3: str):
    c = edge_tts.Communicate(text, voice)
    await c.save(out_mp3)

asyncio.run(generate(
    "A szöveg ide kerül.",
    "hu-HU-NoemiNeural",
    r"C:\Users\Toma\projects\f5-tts\output\project_name.mp3"
))
```

Convert to WAV:
```bash
ffmpeg -i output/project_name.mp3 output/project_name.wav -y
```

### SSML for pauses (use when splicing foreign words)

Insert a silence gap where a brand name will be spliced in:
```python
ssml = """<speak>
  <voice name="hu-HU-NoemiNeural">
    Modern webalkalmazás, felhős adatbázis és
    <break time="700ms"/>
    alapokon.
  </voice>
</speak>"""

async def generate_ssml(ssml: str, out_mp3: str):
    # Pass any voice; SSML overrides it
    c = edge_tts.Communicate(ssml, "hu-HU-NoemiNeural")
    await c.save(out_mp3)
```

---

## Step 3 (optional): Splice foreign words into non-English audio

Use this when brand names must be said in English but the rest is another language.

**3a.** Generate the English word(s) with `en-US-AriaNeural` (neutral female — best timbre match for cross-language splicing):
```python
asyncio.run(generate("Streamlit", "en-US-AriaNeural", "output/word_streamlit.mp3"))
```
Convert to WAV: `ffmpeg -i output/word_streamlit.mp3 output/word_streamlit.wav -y`

**3b.** Find the silence position in the main audio:
```bash
ffmpeg -i output/main.wav -af "silencedetect=noise=-30dB:d=0.2" -f null - 2>&1 | grep silence
```
Note the `silence_start` and `silence_end` timestamps.

**3c.** Split main audio at the silence, insert the English clip, rejoin:
```bash
# Split before and after silence
ffmpeg -i main.wav -t 4.2 -c copy seg1.wav
ffmpeg -i main.wav -ss 4.9 -c copy seg2.wav
# Concatenate: seg1 + english_word + seg2
ffmpeg -i seg1.wav -i word_streamlit.wav -i seg2.wav \
  -filter_complex "[0][1][2]concat=n=3:v=0:a=1" output/final.wav
```

---

## Step 4: Extract word-level timestamps (for Remotion/video sync)

Run Whisper large-v3 (CUDA) on the final WAV:

```python
import whisper

model = whisper.load_model('large-v3')
result = model.transcribe(
    'output/project_name.wav',
    word_timestamps=True,
    language='hu'   # set to target language, or omit for English
)

print('TOTAL DURATION:', result['segments'][-1]['end'])
for seg in result['segments']:
    for w in seg['words']:
        print(f"{w['start']:.2f}-{w['end']:.2f}: {w['word']}")
```

Run with venv Python:
```bash
"C:\Users\Toma\projects\f5-tts\.venv\Scripts\python.exe" whisper_timestamps.py
```

**Convert to Remotion frame numbers:**
```python
fps = 30
frame = round(timestamp_seconds * fps)
```

**Total composition frames:**
```python
total_frames = round(total_duration_seconds * fps)
# Set this in Root.tsx → durationInFrames
```

---

## Common language codes for Edge TTS

| Language | Code | Recommended voice |
|----------|------|-------------------|
| Hungarian | `hu` | `hu-HU-NoemiNeural` |
| German | `de` | `de-DE-KatjaNeural` |
| French | `fr` | `fr-FR-DeniseNeural` |
| Spanish | `es` | `es-ES-ElviraNeural` |
| Italian | `it` | `it-IT-ElsaNeural` |
| Polish | `pl` | `pl-PL-AgnieszkaNeural` |
| English (female) | `en` | `en-US-AriaNeural` |

To list all available voices:
```python
import asyncio, edge_tts
async def main():
    voices = await edge_tts.list_voices()
    hu_voices = [v for v in voices if v['Locale'].startswith('hu')]
    print(hu_voices)
asyncio.run(main())
```

---

## Quick reference

```bash
# English TTS (WAV out)
python kokoro_generate.py "Script." name adam

# Hungarian TTS (MP3 → WAV)
python -c "import asyncio,edge_tts; asyncio.run(edge_tts.Communicate('Szöveg.','hu-HU-NoemiNeural').save('output/name.mp3'))"
ffmpeg -i output/name.mp3 output/name.wav -y

# Whisper timestamps
.venv\Scripts\python.exe -c "
import whisper; m=whisper.load_model('large-v3')
r=m.transcribe('output/name.wav',word_timestamps=True,language='hu')
print('TOTAL:',r['segments'][-1]['end'])
[print(f'{w[\"start\"]:.2f}-{w[\"end\"]:.2f}: {w[\"word\"]}') for s in r['segments'] for w in s['words']]
"
```
