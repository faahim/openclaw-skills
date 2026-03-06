# Listing Copy: Audio Splitter

## Metadata
- **Type:** Skill
- **Name:** audio-splitter
- **Display Name:** Audio Splitter
- **Categories:** [media, automation]
- **Icon:** ✂️
- **Dependencies:** [ffmpeg, sox]

## Tagline

Split audio files by silence, time, chapters, or timestamps — fully automated

## Description

Long audio files are a pain to work with. Whether you're chopping a 2-hour podcast into chapters, splitting an audiobook at natural pauses, or extracting segments from a live recording, doing it manually in an audio editor is slow and tedious.

Audio Splitter automates the entire process. Point it at any audio file and choose how to split: detect silence automatically, cut at fixed intervals, extract embedded chapters, or split at specific timestamps. It handles format conversion on the fly — input WAV, output MP3. Batch process entire directories. Preview splits before committing.

**What it does:**
- ✂️ Split by silence detection — finds natural pauses automatically
- ⏱️ Split by fixed time intervals (e.g., every 10 minutes)
- 📖 Split by embedded chapter markers (M4B, MP3 chapters)
- 📍 Split at specific timestamps you define
- 🔄 Convert formats while splitting (MP3, WAV, FLAC, OGG, M4A)
- 📁 Batch process entire directories
- 👀 Dry-run preview before splitting
- 🎚️ Configurable silence threshold, minimum segment length, fade in/out

Perfect for podcasters, audiobook listeners, musicians, and anyone who works with long audio recordings.

## Quick Start Preview

```bash
# Split at silence points
bash scripts/split.sh --input podcast.mp3 --mode silence

# Split into 10-minute chunks
bash scripts/split.sh --input recording.wav --mode time --interval 600

# Extract chapters from audiobook
bash scripts/split.sh --input book.m4b --mode chapters --format mp3
```

## Core Capabilities

1. Silence detection — Automatically find pauses and split there
2. Time-based splitting — Equal segments at any interval
3. Chapter extraction — Pull chapters from M4B/MP3 metadata
4. Timestamp splitting — Cut at exact times you specify
5. Format conversion — Convert between MP3, WAV, FLAC, OGG, M4A
6. Batch processing — Process entire directories at once
7. Dry-run mode — Preview split points before executing
8. Fade effects — Smooth transitions between segments
9. Configurable thresholds — Tune silence detection sensitivity
10. Minimum segment length — Prevent tiny fragments

## Dependencies
- `ffmpeg` (4.0+)
- `sox` (14.0+)
- `bash` (4.0+)
- `bc`

## Installation Time
**2 minutes** — Run install.sh, start splitting
