# Hungarian TTS with Word-Level Timestamps — Plan

## Step 1: Language Review of the Script

**Original script:**
> "A MedKölcsön egy célszoftver orvostechnikai eszközök kezelésére. Modern webalkalmazás, Firebase és Streamlit alapokon. Háromszázkilencvenegy automatikus teszt. Éles üzemben, valódi ügyfelekkel."

**Assessment:** The Hungarian is grammatically correct and natural-sounding. Minor notes:

- "MedKölcsön" — proper noun, assumed intentional (brand name). No issue.
- "célszoftver" — slightly informal compound noun ("purpose-built software"), but perfectly acceptable in a product demo context.
- "Háromszázkilencvenegy" — correct Hungarian spelling of 391 written out as a word. Good choice for voiceover (reads more naturally than digits).
- "Éles üzemben" — idiomatic, correct. Means "in live/production operation."
- "valódi ügyfelekkel" — correct instrumental case. Means "with real clients."

**No language issues found.** The script is ready for TTS.

---

## Step 2: Generate Audio with Word-Level Timestamps

### Option A — ElevenLabs API (Recommended for quality)

ElevenLabs supports Hungarian and returns word-level timestamps via their `speech-to-text` or via the `/v1/text-to-speech/{voice_id}/with-timestamps` endpoint.

**Step 2a: Find a Hungarian-compatible voice**

```bash
curl -X GET "https://api.elevenlabs.io/v1/voices" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  | jq '.voices[] | select(.labels.language == "hu" or .labels.accent == "Hungarian") | {voice_id, name}'
```

If no Hungarian-tagged voice is found, use a multilingual model (e.g., `eleven_multilingual_v2`) with any voice — it handles Hungarian well.

**Step 2b: Generate audio WITH timestamps**

```bash
curl -X POST "https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}/with-timestamps" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "A MedKölcsön egy célszoftver orvostechnikai eszközök kezelésére. Modern webalkalmazás, Firebase és Streamlit alapokon. Háromszázkilencvenegy automatikus teszt. Éles üzemben, valódi ügyfelekkel.",
    "model_id": "eleven_multilingual_v2",
    "voice_settings": {
      "stability": 0.5,
      "similarity_boost": 0.75
    }
  }' \
  -o tts_response.json
```

**Step 2c: Extract audio and timestamps**

```python
import json, base64

with open("tts_response.json") as f:
    data = json.load(f)

# Save audio
audio_bytes = base64.b64decode(data["audio_base64"])
with open("voiceover.mp3", "wb") as f:
    f.write(audio_bytes)

# Extract word-level timestamps
alignment = data["alignment"]
words = alignment["characters"]       # or "words" depending on API version
starts = alignment["character_start_times_seconds"]
ends = alignment["character_end_times_seconds"]

print(json.dumps({"words": words, "starts": starts, "ends": ends}, indent=2, ensure_ascii=False))
```

---

### Option B — OpenAI Whisper (Free, post-hoc alignment)

If ElevenLabs is not available, generate audio with any TTS (e.g., Google TTS, Azure, or `gtts` Python library), then run Whisper to get word-level timestamps by transcribing the generated audio.

**Step 2a: Generate audio with gTTS (free)**

```python
from gtts import gTTS

text = "A MedKölcsön egy célszoftver orvostechnikai eszközök kezelésére. Modern webalkalmazás, Firebase és Streamlit alapokon. Háromszázkilencvenegy automatikus teszt. Éles üzemben, valódi ügyfelekkel."
tts = gTTS(text=text, lang="hu", slow=False)
tts.save("voiceover.mp3")
```

**Step 2b: Get word-level timestamps via Whisper**

```python
import whisper

model = whisper.load_model("base")
result = model.transcribe(
    "voiceover.mp3",
    language="hu",
    word_timestamps=True
)

for segment in result["segments"]:
    for word in segment["words"]:
        print(f"{word['word']:<35} start={word['start']:.3f}s  end={word['end']:.3f}s")
```

---

## Step 3: Expected Timestamp Output Format

The output will look like this (example — actual timings depend on speech rate):

```json
[
  { "word": "A",                         "start": 0.000, "end": 0.120 },
  { "word": "MedKölcsön",               "start": 0.120, "end": 0.620 },
  { "word": "egy",                       "start": 0.620, "end": 0.780 },
  { "word": "célszoftver",               "start": 0.780, "end": 1.280 },
  { "word": "orvostechnikai",            "start": 1.280, "end": 1.980 },
  { "word": "eszközök",                  "start": 1.980, "end": 2.420 },
  { "word": "kezelésére.",               "start": 2.420, "end": 3.020 },
  { "word": "Modern",                    "start": 3.200, "end": 3.540 },
  { "word": "webalkalmazás,",            "start": 3.540, "end": 4.140 },
  { "word": "Firebase",                  "start": 4.140, "end": 4.580 },
  { "word": "és",                        "start": 4.580, "end": 4.680 },
  { "word": "Streamlit",                 "start": 4.680, "end": 5.100 },
  { "word": "alapokon.",                 "start": 5.100, "end": 5.620 },
  { "word": "Háromszázkilencvenegy",     "start": 5.800, "end": 6.900 },
  { "word": "automatikus",              "start": 6.900, "end": 7.480 },
  { "word": "teszt.",                    "start": 7.480, "end": 7.880 },
  { "word": "Éles",                      "start": 8.060, "end": 8.360 },
  { "word": "üzemben,",                 "start": 8.360, "end": 8.800 },
  { "word": "valódi",                   "start": 8.800, "end": 9.160 },
  { "word": "ügyfelekkel.",             "start": 9.160, "end": 9.780 }
]
```

---

## Step 4: Use in Remotion

In your Remotion component, use the timestamps to drive animated captions or sync visuals:

```tsx
import { useCurrentFrame, useVideoConfig } from "remotion";
import { Audio } from "@remotion/media-utils";

const wordTimestamps = [
  { word: "A", start: 0.0, end: 0.12 },
  { word: "MedKölcsön", start: 0.12, end: 0.62 },
  // ... rest of timestamps
];

export const MyVideo = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const currentTime = frame / fps;

  const activeWord = wordTimestamps.find(
    (w) => currentTime >= w.start && currentTime < w.end
  );

  return (
    <div>
      <Audio src={staticFile("voiceover.mp3")} />
      <div style={{ position: "absolute", bottom: 80, width: "100%", textAlign: "center", fontSize: 48, color: "white" }}>
        {activeWord?.word ?? ""}
      </div>
    </div>
  );
};
```

---

## Summary

| Step | Action | Tool |
|------|--------|------|
| 1 | Language review | Manual / Claude |
| 2 | Generate Hungarian TTS audio | ElevenLabs API or gTTS |
| 3 | Get word-level timestamps | ElevenLabs `/with-timestamps` or OpenAI Whisper |
| 4 | Integrate into Remotion | `useCurrentFrame()` + timestamp lookup |

**Recommended stack:** ElevenLabs `eleven_multilingual_v2` model + `/with-timestamps` endpoint. This gives the best Hungarian pronunciation and timestamps in a single API call, with no separate alignment step needed.
