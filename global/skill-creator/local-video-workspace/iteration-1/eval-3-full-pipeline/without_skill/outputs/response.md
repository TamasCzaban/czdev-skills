# Sales Dashboard Demo Video — Full Pipeline: Script to MP4

## Overview

This guide walks through producing a ~30-second demo video for a Python/Plotly Dash sales dashboard app, starting from a written script and finishing with a rendered MP4. No paid services are required for the core pipeline; optional paid upgrades are noted where relevant.

**Toolchain:**
- **TTS:** `edge-tts` (free, Microsoft neural voices via CLI)
- **Image assembly + video render:** `ffmpeg` (free, open-source)
- **Optional enhancement:** DaVinci Resolve (free tier) for polish

---

## Step 1: Write the Script

Target length: ~30 seconds at a natural speaking pace (~130 words per minute = ~65 words). Keep it tight.

**Script (example):**

```
Meet your new sales command center — built with Python and Plotly Dash, running live on Heroku.

At a glance: real-time sales charts that update automatically, keeping every rep in the loop.

The team leaderboard shows exactly who's closing — ranked, live, and motivating.

Zoom into territory mapping to see performance by region, so you know where to focus.

And when you need the data — one click exports everything to CSV.

Fast. Clear. Deployable. Your sales dashboard is ready.
```

Word count: ~70 words. Expected audio duration: ~30–33 seconds.

Save this to a plain text file:

```
# Path: C:\Users\Toma\projects\bemer-crm-video\script.txt
```

---

## Step 2: Generate Voiceover with edge-tts

`edge-tts` is a free CLI that uses Microsoft Edge's neural TTS engine — no API key needed.

**Install:**
```bash
pip install edge-tts
```

**List available English voices:**
```bash
edge-tts --list-voices | grep en-US
```

Recommended voices for a professional product demo:
- `en-US-GuyNeural` — confident male, clear diction
- `en-US-AriaNeural` — warm female, professional tone
- `en-US-AndrewNeural` — conversational male

**Generate the voiceover:**
```bash
edge-tts \
  --voice en-US-GuyNeural \
  --rate "+5%" \
  --text "$(cat C:/Users/Toma/projects/bemer-crm-video/script.txt)" \
  --write-media C:/Users/Toma/projects/bemer-crm-video/voiceover.mp3 \
  --write-subtitles C:/Users/Toma/projects/bemer-crm-video/voiceover.vtt
```

Flags:
- `--rate "+5%"` — slightly faster pacing, sounds more energetic
- `--write-subtitles` — generates a `.vtt` file you can burn in later if needed

**Verify duration:**
```bash
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 \
  C:/Users/Toma/projects/bemer-crm-video/voiceover.mp3
```

If output is outside 28–35 seconds, adjust `--rate` and regenerate.

---

## Step 3: Prepare Your Screenshots

You said you have screenshots ready. Organize them to match the script beats:

| Slide # | Content | Script line |
|---------|---------|-------------|
| 01 | App hero / overview / landing view | "Meet your new sales command center…" |
| 02 | Real-time sales charts (zoomed in) | "real-time sales charts that update automatically…" |
| 03 | Team leaderboard | "The team leaderboard shows exactly who's closing…" |
| 04 | Territory map | "Zoom into territory mapping…" |
| 05 | CSV export UI / download dialog | "one click exports everything to CSV…" |
| 06 | Full dashboard / hero shot again | "Fast. Clear. Deployable." |

**Requirements per image:**
- Resolution: 1920x1080 (crop/pad if needed)
- Format: PNG or JPG
- Name them sequentially for easy reference

**Resize/pad to 1920x1080 with ffmpeg (if screenshots are different sizes):**
```bash
ffmpeg -i C:/Users/Toma/projects/bemer-crm-video/screenshots/raw_01.png \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=black" \
  C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_01.png
```

Run this for each screenshot (01 through 06), adjusting filenames accordingly.

---

## Step 4: Calculate Slide Timings

With a ~31-second voiceover and 6 slides, you need to decide how long each slide stays on screen. You can do this by ear (listen to the voiceover and note timestamps) or split evenly.

**Rough timing based on the script beats:**

| Slide | Start | Duration |
|-------|-------|----------|
| 01 | 0.0s | 4.5s |
| 02 | 4.5s | 6.0s |
| 03 | 10.5s | 5.5s |
| 04 | 16.0s | 6.0s |
| 05 | 22.0s | 5.0s |
| 06 | 27.0s | 4.0s |

Note the total: 31 seconds. Adjust to match your actual voiceover duration.

---

## Step 5: Create a Slideshow Video with ffmpeg

This command takes each screenshot, holds it for the specified duration, and stitches them into a silent video.

**Create a concat input file** (`slides.txt`):
```
file 'C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_01.png'
duration 4.5
file 'C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_02.png'
duration 6.0
file 'C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_03.png'
duration 5.5
file 'C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_04.png'
duration 6.0
file 'C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_05.png'
duration 5.0
file 'C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_06.png'
duration 4.0
```

Note: ffmpeg's concat demuxer requires the last entry to be repeated once (a quirk for image concat):
```
file 'C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_06.png'
```
(Add this extra line at the end with no `duration`, so the last frame renders correctly.)

**Render the silent slideshow:**
```bash
ffmpeg -f concat -safe 0 \
  -i C:/Users/Toma/projects/bemer-crm-video/slides.txt \
  -vsync vfr \
  -pix_fmt yuv420p \
  -c:v libx264 -crf 18 \
  C:/Users/Toma/projects/bemer-crm-video/slideshow_silent.mp4
```

- `-crf 18` — high quality (lower = better, 18–23 is the sweet spot)
- `-pix_fmt yuv420p` — required for broad compatibility (QuickTime, browsers, etc.)

---

## Step 6: Add Cross-Dissolve Transitions (Optional but Recommended)

Hard cuts between slides can feel abrupt. Add a 0.5s fade transition between each slide using the `xfade` filter.

This is more complex with ffmpeg's filter graph. Here is the command for 6 slides with dissolve transitions:

```bash
ffmpeg \
  -loop 1 -t 4.5  -i C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_01.png \
  -loop 1 -t 6.5  -i C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_02.png \
  -loop 1 -t 6.0  -i C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_03.png \
  -loop 1 -t 6.5  -i C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_04.png \
  -loop 1 -t 5.5  -i C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_05.png \
  -loop 1 -t 4.5  -i C:/Users/Toma/projects/bemer-crm-video/screenshots/slide_06.png \
  -filter_complex "
    [0:v][1:v]xfade=transition=dissolve:duration=0.5:offset=4.0[v01];
    [v01][2:v]xfade=transition=dissolve:duration=0.5:offset=10.0[v02];
    [v02][3:v]xfade=transition=dissolve:duration=0.5:offset=15.5[v03];
    [v03][4:v]xfade=transition=dissolve:duration=0.5:offset=21.5[v04];
    [v04][5:v]xfade=transition=dissolve:duration=0.5:offset=26.5[v05]
  " \
  -map "[v05]" \
  -pix_fmt yuv420p -c:v libx264 -crf 18 \
  C:/Users/Toma/projects/bemer-crm-video/slideshow_transitions.mp4
```

The `offset` values (in seconds) mark when each transition starts — set them to match your timing table minus 0.5s for the dissolve duration.

---

## Step 7: Merge Video + Voiceover

Combine the silent slideshow video with the voiceover MP3:

```bash
ffmpeg \
  -i C:/Users/Toma/projects/bemer-crm-video/slideshow_transitions.mp4 \
  -i C:/Users/Toma/projects/bemer-crm-video/voiceover.mp3 \
  -c:v copy \
  -c:a aac -b:a 192k \
  -shortest \
  C:/Users/Toma/projects/bemer-crm-video/demo_with_audio.mp4
```

- `-c:v copy` — no re-encoding, fast and lossless for the video track
- `-c:a aac` — encodes audio to AAC for maximum compatibility
- `-shortest` — trims to the shorter of video/audio (handles any minor length mismatch)

---

## Step 8: Add Background Music (Optional)

For a polished feel, layer in subtle background music. A good free source: **Pixabay Music** (pixabay.com/music, royalty-free, no attribution required for commercial use).

Search for: "corporate upbeat" or "tech product demo" — pick something ~120 BPM, clean, not distracting.

Download to: `C:/Users/Toma/projects/bemer-crm-video/music.mp3`

**Mix voiceover (loud) with background music (quiet):**
```bash
ffmpeg \
  -i C:/Users/Toma/projects/bemer-crm-video/slideshow_transitions.mp4 \
  -i C:/Users/Toma/projects/bemer-crm-video/voiceover.mp3 \
  -i C:/Users/Toma/projects/bemer-crm-video/music.mp3 \
  -filter_complex "
    [1:a]volume=1.0[voice];
    [2:a]volume=0.12[music];
    [voice][music]amix=inputs=2:duration=first[aout]
  " \
  -map 0:v -map "[aout]" \
  -c:v copy -c:a aac -b:a 192k \
  -shortest \
  C:/Users/Toma/projects/bemer-crm-video/demo_with_music.mp4
```

- `volume=0.12` for music keeps it clearly in the background without drowning the voice
- Adjust between `0.08` (barely audible) and `0.20` (more present) to taste

---

## Step 9: Add Captions / Burned-In Subtitles (Optional)

The `.vtt` file generated by `edge-tts` in Step 2 can be converted to `.srt` and burned in.

**Convert VTT to SRT:**
```bash
ffmpeg -i C:/Users/Toma/projects/bemer-crm-video/voiceover.vtt \
  C:/Users/Toma/projects/bemer-crm-video/voiceover.srt
```

**Burn subtitles into video (requires ffmpeg with libass):**
```bash
ffmpeg \
  -i C:/Users/Toma/projects/bemer-crm-video/demo_with_music.mp4 \
  -vf "subtitles=C\\:/Users/Toma/projects/bemer-crm-video/voiceover.srt:force_style='FontName=Arial,FontSize=24,PrimaryColour=&Hffffff,OutlineColour=&H000000,Outline=2,Alignment=2'" \
  -c:a copy \
  C:/Users/Toma/projects/bemer-crm-video/demo_captioned.mp4
```

Note: On Windows, the subtitle path in the `subtitles=` filter requires escaping backslashes — use forward slashes with the drive letter colon escaped as `C\\:/`.

---

## Step 10: Final Quality Check and Export

**Check the final file:**
```bash
ffprobe -v error \
  -show_entries format=duration,size,bit_rate \
  -show_entries stream=codec_name,width,height,r_frame_rate \
  -of default=noprint_wrappers=1 \
  C:/Users/Toma/projects/bemer-crm-video/demo_captioned.mp4
```

Expected output:
- Duration: ~30–33 seconds
- Resolution: 1920x1080
- Video codec: h264
- Audio codec: aac

**Export a web-optimized version** (smaller file for embedding/uploading):
```bash
ffmpeg \
  -i C:/Users/Toma/projects/bemer-crm-video/demo_captioned.mp4 \
  -c:v libx264 -crf 23 -preset slow \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  C:/Users/Toma/projects/bemer-crm-video/demo_final.mp4
```

- `-movflags +faststart` — moves MP4 metadata to the front of the file, enabling instant playback in browsers without fully downloading
- `-preset slow` — slower encode = better compression at the same quality level

---

## Full File Structure at the End

```
C:/Users/Toma/projects/bemer-crm-video/
  script.txt                    # Written script
  voiceover.mp3                 # Generated TTS audio
  voiceover.vtt                 # Subtitle file from edge-tts
  voiceover.srt                 # Converted subtitle file
  music.mp3                     # Background music (downloaded)
  slides.txt                    # ffmpeg concat input list
  screenshots/
    slide_01.png                # Padded/resized screenshots
    slide_02.png
    slide_03.png
    slide_04.png
    slide_05.png
    slide_06.png
  slideshow_silent.mp4          # Slideshow, no audio
  slideshow_transitions.mp4     # Slideshow with dissolves
  demo_with_audio.mp4           # Video + voiceover
  demo_with_music.mp4           # Video + voiceover + music
  demo_captioned.mp4            # + burned-in subtitles
  demo_final.mp4                # Final web-optimized output
```

---

## Quick Reference: Minimum Viable Pipeline

If you want the shortest path to a working MP4:

```bash
# 1. Generate voiceover
edge-tts --voice en-US-GuyNeural --text "$(cat script.txt)" --write-media voiceover.mp3

# 2. Build slideshow (after creating slides.txt)
ffmpeg -f concat -safe 0 -i slides.txt -vsync vfr -pix_fmt yuv420p -c:v libx264 -crf 18 slideshow.mp4

# 3. Merge audio + video
ffmpeg -i slideshow.mp4 -i voiceover.mp3 -c:v copy -c:a aac -b:a 192k -shortest demo_final.mp4
```

Three commands. Done.

---

## Tools Required

| Tool | Install | Cost |
|------|---------|------|
| `ffmpeg` | `winget install ffmpeg` or https://ffmpeg.org/download.html | Free |
| `edge-tts` | `pip install edge-tts` | Free |
| `ffprobe` | Included with ffmpeg | Free |
| Background music | pixabay.com/music | Free (royalty-free) |
| Python (for pip) | Already installed (Dash project) | Free |

No API keys, no subscriptions, no watermarks.
