# German TTS Script Language Check

## Skill Used: local-tts (Step 0 — Language Mismatch Detection)

The skill prescribes running a `flag_foreign_words()` scan before any TTS generation for non-English scripts. Below is the full plan for your German script.

---

## Your Script

```
Unser Tool hilft Ihnen, Daten in Echtzeit zu analysieren.
Powered by Streamlit, PostgreSQL und Redis.
Über 500 automatisierte Tests. Jetzt live in der Produktion.
```

---

## Step 0: Run the Language Scan

Per the skill, run this inline Python before generating audio:

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

script = "Unser Tool hilft Ihnen, Daten in Echtzeit zu analysieren. Powered by Streamlit, PostgreSQL und Redis. Über 500 automatisierte Tests. Jetzt live in der Produktion."
print(flag_foreign_words(script, 'de'))
```

Run with:
```bash
"C:\Users\Toma\projects\f5-tts\.venv\Scripts\python.exe" -c "<paste script above>"
```

---

## Predicted Flagged Words (Manual Analysis)

Even before running the command, these words are highly likely to be flagged as non-German by `langdetect`:

| Word | Likely Detected As | Risk Level | Reason |
|------|--------------------|------------|--------|
| `Tool` | `en` | Low | Common English loanword; German TTS voices usually handle it acceptably as "Tool" |
| `Powered` | `en` | High | English verb — German TTS will mispronounce, likely as "Po-verd" or similar |
| `Streamlit` | `en` | High | English brand name — will be read letter-by-letter or mispronounced |
| `PostgreSQL` | `en` | High | Technical brand name — pronunciation will be unpredictable (possibly "Post-gre-es-kuel") |
| `Redis` | `en` | Medium | Short brand name — may come out as "Reh-dis" instead of "Red-is" |
| `live` | `en` | Medium | English word used in German tech context — German TTS may say "lee-veh" (German pronunciation) instead of "lyve" |

---

## Recommended Fixes

### Option 1: Replace (Recommended for most words)

Rewrite the script to use German equivalents or phonetic descriptions. This produces the cleanest, most natural audio.

**Revised script:**
```
Unser Tool hilft Ihnen, Daten in Echtzeit zu analysieren.
Betrieben mit Streamlit, PostgreSQL und Redis.
Über 500 automatisierte Tests. Jetzt produktiv im Einsatz.
```

Specific changes:
- `Powered by` → `Betrieben mit` (natural German for "powered by")
- `live in der Produktion` → `produktiv im Einsatz` (avoids the ambiguous English "live")
- `Streamlit`, `PostgreSQL`, `Redis` — keep as-is but handle via splice (see Option 2 below)

### Option 2: Splice brand names (Best for Streamlit, PostgreSQL, Redis)

For brand names where English pronunciation matters, use the skill's splice workflow:

1. Generate the main German audio with silence gaps using SSML:

```python
import asyncio, edge_tts

ssml = """<speak>
  <voice name="de-DE-KatjaNeural">
    Unser Tool hilft Ihnen, Daten in Echtzeit zu analysieren.
    Betrieben mit
    <break time="600ms"/>
    ,
    <break time="600ms"/>
    und
    <break time="600ms"/>
    . Über 500 automatisierte Tests. Jetzt produktiv im Einsatz.
  </voice>
</speak>"""

async def generate_ssml(ssml: str, out_mp3: str):
    c = edge_tts.Communicate(ssml, "de-DE-KatjaNeural")
    await c.save(out_mp3)

asyncio.run(generate_ssml(ssml, r"C:\Users\Toma\projects\f5-tts\output\german_main.mp3"))
```

2. Generate each brand name in English using `en-US-AriaNeural`:

```python
asyncio.run(generate("Streamlit", "en-US-AriaNeural", "output/word_streamlit.mp3"))
asyncio.run(generate("PostgreSQL", "en-US-AriaNeural", "output/word_postgresql.mp3"))
asyncio.run(generate("Redis", "en-US-AriaNeural", "output/word_redis.mp3"))
```

3. Convert all MP3s to WAV:
```bash
ffmpeg -i output/german_main.mp3 output/german_main.wav -y
ffmpeg -i output/word_streamlit.mp3 output/word_streamlit.wav -y
ffmpeg -i output/word_postgresql.mp3 output/word_postgresql.wav -y
ffmpeg -i output/word_redis.mp3 output/word_redis.wav -y
```

4. Detect silence positions in the main audio:
```bash
ffmpeg -i output/german_main.wav -af "silencedetect=noise=-30dB:d=0.2" -f null - 2>&1 | grep silence
```

5. Splice each brand name clip into the silence gaps using `ffmpeg concat`.

---

## TTS Engine for German

Per the skill's engine table:

| Language | Engine | Recommended Voice |
|----------|--------|-------------------|
| German | Edge TTS | `de-DE-KatjaNeural` |

Do NOT use Kokoro for this script — Kokoro is English-only.

---

## Summary: Recommended Action Plan

1. Run the `flag_foreign_words()` scan to confirm which words are flagged.
2. Replace `Powered by` with `Betrieben mit` and `live in der Produktion` with `produktiv im Einsatz` — these have clean German equivalents.
3. Keep `Streamlit`, `PostgreSQL`, and `Redis` as brand names but splice them in English using the SSML + ffmpeg workflow.
4. Generate German audio with `de-DE-KatjaNeural` via Edge TTS.
5. Proceed to Step 4 (Whisper timestamps) once the final WAV is assembled.
