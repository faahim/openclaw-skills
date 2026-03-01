# Listing Copy: Subtitle Generator

## Metadata
- **Type:** Skill
- **Name:** subtitle-generator
- **Display Name:** Subtitle Generator
- **Categories:** [media, automation]
- **Price:** $12
- **Dependencies:** [ffmpeg, python3, openai-whisper]
- **Icon:** 🎬

## Tagline

Generate SRT/VTT subtitles from video and audio files using Whisper AI

## Description

Adding subtitles to videos is tedious — manual transcription takes hours, and cloud services cost money per minute of audio. You need a fast, local solution.

Subtitle Generator uses OpenAI's Whisper speech recognition to automatically create accurate subtitles from any video or audio file. It runs entirely on your machine — no API keys, no cloud uploads, no per-minute charges. Process a 2-hour video in minutes.

**What it does:**
- 🎬 Generate SRT or VTT subtitles from any video/audio file
- 🌍 90+ languages with automatic language detection
- 📂 Batch process entire directories of media files
- 🔄 Translate foreign audio to English subtitles
- ⚡ Choose speed vs accuracy with 5 model sizes (tiny → large)
- 🔒 100% local processing — your files never leave your machine
- 🛠️ One command install, works in 5 minutes

Perfect for content creators, educators, podcasters, and anyone who needs subtitles without the hassle of manual transcription or expensive cloud services.

## Quick Start Preview

```bash
# Install
bash scripts/install.sh

# Generate subtitles
bash scripts/generate.sh --input video.mp4
# → video.srt

# Batch process
bash scripts/generate.sh --input-dir ./videos/ --format vtt
```

## Core Capabilities

1. Video subtitling — Extract audio and generate timed subtitles automatically
2. Audio transcription — Create subtitles from podcasts, interviews, recordings
3. Batch processing — Process all media files in a directory with one command
4. Multi-format output — SRT (video players) or VTT (web/HTML5)
5. Language detection — Automatically detects spoken language from 90+ options
6. Translation mode — Transcribe foreign audio and translate to English
7. Model selection — 5 sizes from tiny (fast) to large-v3 (most accurate)
8. Local processing — No API keys, no cloud, no per-minute fees
9. Cron-ready — Schedule overnight batch processing
10. Zero config — Works out of the box with sensible defaults

## Dependencies
- `ffmpeg` (audio extraction)
- `python3` (3.8+)
- `openai-whisper` (speech recognition)

## Installation Time
**5 minutes** — Run install.sh, start generating

## Pricing Justification

**Why $12:**
- Cloud alternatives: $0.006-0.024/min (adds up fast)
- Manual transcription: $1-3/min
- Our advantage: One-time payment, unlimited use, fully local
- Complexity: Medium (ffmpeg + Whisper integration, batch processing)
