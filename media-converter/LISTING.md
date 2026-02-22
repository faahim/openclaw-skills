# Listing Copy: Media Converter

## Metadata
- **Type:** Skill
- **Name:** media-converter
- **Display Name:** Media Converter
- **Categories:** [media, automation]
- **Price:** $12
- **Dependencies:** [ffmpeg, bash]

## Tagline

"Convert, compress, and extract media files — ffmpeg automation for your agent"

## Description

Dealing with media files manually is tedious. Converting formats, compressing for web, extracting audio, making GIFs — each requires remembering obscure ffmpeg flags. Your agent shouldn't need to fumble with codec options either.

Media Converter wraps ffmpeg into simple, memorable commands your OpenClaw agent can execute instantly. Convert MKV to MP4, extract podcast audio, compress videos for social media, generate thumbnails, create GIFs, trim clips, and batch process entire directories — all with one-line commands.

**What it does:**
- 🎬 Convert between any video format (MP4, MKV, WebM, AVI, MOV)
- 🎵 Extract audio tracks (MP3, FLAC, WAV, AAC)
- 📦 Compress video with presets (web, social, email)
- 🖼️ Generate thumbnails at intervals or timestamps
- 🎭 Create animated GIFs with palette optimization
- ✂️ Trim/cut segments from media files
- 🔗 Merge/concatenate multiple files
- 📂 Batch convert entire directories in parallel
- 📊 Probe media files for format/codec/duration info

Perfect for developers, content creators, and anyone who processes media files regularly.

## Quick Start Preview

```bash
# Convert video
bash scripts/run.sh convert -i video.mkv -o video.mp4

# Extract audio
bash scripts/run.sh extract-audio -i video.mp4 -f mp3

# Compress for social media
bash scripts/run.sh compress -i raw.mp4 --preset social

# Create GIF
bash scripts/run.sh gif -i video.mp4 --duration 5 --width 480
```

## Dependencies
- `ffmpeg` (4.0+)
- `bash` (4.0+)
- `bc` (usually pre-installed)

## Installation Time
**2 minutes** — Install ffmpeg if not present, run commands
