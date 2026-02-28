# Listing Copy: Audio Normalizer

## Metadata
- **Type:** Skill
- **Name:** audio-normalizer
- **Display Name:** Audio Normalizer
- **Categories:** [media, automation]
- **Price:** $10
- **Dependencies:** [ffmpeg, bash, bc]

## Tagline

Normalize audio loudness, convert formats, and trim silence — all locally with ffmpeg

## Description

Inconsistent audio levels across files are annoying — podcasts that jump in volume, recordings that are too quiet, or audio that needs converting between formats. Fixing this manually in Audacity takes forever, especially with batches.

Audio Normalizer handles it all from the command line. Normalize to broadcast-standard loudness (EBU R128 / -16 LUFS) using ffmpeg's two-pass loudnorm filter for professional-quality results. Convert between mp3, wav, flac, ogg, aac, and opus. Trim dead air from the start and end of recordings. Run the full pipeline in one command, or batch process entire directories in parallel.

**What it does:**
- 🎚️ Normalize loudness to any LUFS target (default: -16, podcast standard)
- 🔄 Convert between 6 audio formats with quality control
- ✂️ Auto-trim leading and trailing silence
- 📦 Batch process entire directories with parallel execution
- 📊 Analyze loudness without modifying files
- 🔧 Two-pass normalization for broadcast-quality output

Perfect for podcasters, content creators, musicians, and anyone dealing with audio files that need consistent levels and formats.

## Quick Start Preview

```bash
# Normalize a podcast episode
bash scripts/run.sh normalize --input episode.wav --output episode_norm.wav

# Full pipeline: trim + normalize + convert to mp3
bash scripts/run.sh pipeline --input raw.wav --output final.mp3 --normalize --trim --format mp3 --bitrate 192k
```

## Core Capabilities

1. Loudness normalization — EBU R128 two-pass for broadcast-quality results
2. Format conversion — mp3, wav, flac, ogg, aac, opus with bitrate/quality control
3. Silence trimming — Auto-detect and remove dead air from start/end
4. Full pipeline — Trim + normalize + convert in one command
5. Batch processing — Process entire directories with parallel execution
6. Audio analysis — Check loudness, true peak, format details without changes
7. True peak limiting — Prevent clipping with configurable dBTP limit
8. Configurable thresholds — Custom LUFS target, silence detection, quality settings
9. Parallel execution — Process multiple files simultaneously for speed
10. Zero cloud dependency — Everything runs locally via ffmpeg

## Dependencies
- `ffmpeg` (4.0+)
- `bash` (4.0+)
- `bc`

## Installation Time
**2 minutes** — Just needs ffmpeg installed
