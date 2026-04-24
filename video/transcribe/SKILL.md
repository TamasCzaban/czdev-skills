---
name: transcribe
description: Transcribe audio or video from URLs (Instagram Reels, YouTube, TikTok, or any yt-dlp-supported site) or local video/audio files using local GPU-accelerated Whisper. Use this skill whenever the user pastes a video URL and wants to know what's being said, asks to transcribe a reel/video/clip, wants the text from a social media video, says things like "what does this video say", "transcribe this", "get the transcript of", "pull the audio from", or wants to discuss the content of a video they just shared. Also trigger when the user drops a local .mp4, .mp3, .wav, .mov, or similar file and wants a transcript.
---

# Transcribe

Transcribe any video or audio source to text using the local Whisper large-v3 model on GPU — no API keys, no usage limits, no upload required.

## Script location

```
C:\Users\Toma\projects\reel-transcriber\transcribe.py
```

## How to run

Use Bash to run the script. ffmpeg must be on PATH — add it explicitly since it may not survive shell restarts:

```bash
export PATH="$PATH:/c/Users/Toma/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-8.1-full_build/bin"
python C:/Users/Toma/projects/reel-transcriber/transcribe.py "<url_or_path>"
```

**Optional second argument** — model size (default: `large-v3`):
- `large-v3` — best quality, ~10-15s for a 60s clip (default)
- `medium` — slightly faster, still good
- `small` / `base` / `tiny` — use only if the user asks for speed over accuracy

## Supported sources

- Instagram Reels, Stories, posts
- YouTube videos and Shorts
- TikTok, Twitter/X, Facebook, Reddit videos
- Any site supported by yt-dlp (1000+)
- Local files: `.mp4`, `.mp3`, `.wav`, `.mov`, `.m4a`, `.webm`, etc.

## Private/login-required content

If the first download attempt fails (e.g., private IG reel), the script automatically retries using Chrome cookies. If that also fails, tell the user they may need to be logged into Chrome for that platform.

## After transcribing

1. Print the full transcript in the conversation so the user can read it immediately.
2. The transcript is also saved to `C:\Users\Toma\projects\reel-transcriber\transcript.txt`.
3. Ask the user if they want to discuss, research, or act on the content — don't wait for them to ask.

**Good follow-up prompt:** "Want me to dig into any of the ideas or tools mentioned here?"

## What to show the user

Show the transcript output from the script (it already prints timestamps + final text). After that, briefly summarize what the video is about in 1-2 sentences so the user has instant context.
