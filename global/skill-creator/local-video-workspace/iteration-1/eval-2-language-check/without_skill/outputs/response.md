# German TTS Language Check — Script Analysis

## Script Under Review

> "Unser Tool hilft Ihnen, Daten in Echtzeit zu analysieren. Powered by Streamlit, PostgreSQL und Redis. Über 500 automatisierte Tests. Jetzt live in der Produktion."

---

## Issues Found

### 1. English loanwords / brand names used raw

**Affected terms:** `Powered by`, `Streamlit`, `PostgreSQL`, `Redis`

**Why this is a problem:**
German TTS engines read unknown or English-origin words phonetically using German pronunciation rules. This causes predictable mispronunciations:

| Word | German TTS will likely say | Correct/intended pronunciation |
|---|---|---|
| `Powered by` | "POW-erd bee" (hard German 'r', short 'i') | "PAU-erd bai" (English) |
| `Streamlit` | "SHTREEM-leet" | "STREEM-lit" (English) |
| `PostgreSQL` | "Post-greh-ES-KOO-EL" or garbled | "Post-gres-Q-L" (English) |
| `Redis` | "REH-dis" | "REE-dis" (English) |

**What to do:**

Option A — Spell them out phonetically for the TTS engine using German spelling hints:

```
Powered by  →  "Pauerd bai"  (if the engine supports phonetic overrides)
Streamlit   →  "Striemlit"
PostgreSQL  →  "Postgress Q L"   (split the abbreviation so it reads as letters)
Redis       →  "Riedis"
```

Option B — Use SSML `<phoneme>` tags if your TTS engine supports them (e.g., Google Cloud TTS, AWS Polly, ElevenLabs with SSML):

```xml
<speak>
  Unser Tool hilft Ihnen, Daten in Echtzeit zu analysieren.
  <phoneme alphabet="ipa" ph="ˈpaʊ.ərd baɪ">Powered by</phoneme>
  <phoneme alphabet="ipa" ph="ˈstriːm.lɪt">Streamlit</phoneme>,
  <phoneme alphabet="ipa" ph="ˈpoʊst.ɡrɛs kjuː ɛl">PostgreSQL</phoneme>
  und
  <phoneme alphabet="ipa" ph="ˈriːdɪs">Redis</phoneme>.
  Über 500 automatisierte Tests. Jetzt live in der Produktion.
</speak>
```

Option C — Rewrite to avoid the brand names in spoken audio entirely, and show them on screen as text overlays instead:

```
"Unser Tool hilft Ihnen, Daten in Echtzeit zu analysieren — mit modernen Open-Source-Technologien. Über 500 automatisierte Tests. Jetzt live in der Produktion."
```

---

### 2. The word `live`

**Affected term:** `live` (in "Jetzt live in der Produktion")

**Why this is a problem:**
`live` is an English word used colloquially in German tech contexts. A German TTS engine will almost certainly pronounce it as the German verb "live" (rhymes with "liebe"), i.e., "LEE-feh" or "LEE-veh", not the English "laɪv".

**What to do:**

Option A — Replace with a fully German phrase:
```
"Jetzt live in der Produktion"  →  "Jetzt im Produktiveinsatz"
                                or  "Ab sofort produktiv verfügbar"
                                or  "Bereits in der Produktion aktiv"
```

Option B — Use a phoneme override:
```xml
<phoneme alphabet="ipa" ph="laɪv">live</phoneme>
```

---

### 3. `Powered by` — grammatical awkwardness in German narration

Even if pronunciation is fixed, "Powered by Streamlit, PostgreSQL und Redis" is a fragment — grammatically incomplete in German. This can cause an unnatural pause or flat delivery from TTS, since there is no verb or clause structure.

**What to do:**
Rewrite as a full sentence:
```
"Das System basiert auf Streamlit, PostgreSQL und Redis."
or
"Die Basis: Streamlit, PostgreSQL und Redis." (with a natural pause cue)
```

---

### 4. Number "500" — safe, no action needed

German TTS engines reliably read `500` as "fünfhundert". No issue here.

---

### 5. `Über` — safe, no action needed

The umlaut `Ü` is handled correctly by all major German TTS engines. No issue.

---

## Recommended Revised Script (Clean German, TTS-safe)

```
Unser Tool hilft Ihnen, Daten in Echtzeit zu analysieren.
Das System basiert auf Streamlit, PostgreSQL und Redis.
Über 500 automatisierte Tests.
Ab sofort produktiv im Einsatz.
```

If you must keep the English brand names spoken aloud, use SSML phoneme overrides (see Option B above) and confirm your TTS provider supports SSML input.

---

## Summary of Actions

| Issue | Severity | Recommended Action |
|---|---|---|
| `Powered by` (English fragment) | High | Rewrite as German sentence or use SSML phoneme |
| `Streamlit` pronunciation | Medium | Phoneme override or screen text only |
| `PostgreSQL` pronunciation | High | Split as "Postgress Q L" or screen text only |
| `Redis` pronunciation | Medium | Phoneme override or screen text only |
| `live` (false friend) | High | Replace with German equivalent |

---

## Steps to Execute

1. Decide whether your TTS engine supports SSML (check docs for Google TTS, AWS Polly, ElevenLabs, etc.).
2. If yes: wrap the script in `<speak>` tags and add `<phoneme>` overrides for each English term.
3. If no: rewrite the script using the clean German version above, with brand names shown as screen text overlays instead of spoken.
4. Run a test TTS render of just the problematic sentences before generating the full audio.
5. Listen carefully to `Streamlit`, `PostgreSQL`, `Redis`, and `live` — these are the four highest-risk words.
