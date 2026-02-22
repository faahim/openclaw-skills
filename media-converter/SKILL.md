---
name: media-converter
description: >-
  Convert, compress, and extract audio/video with ffmpeg. Batch process media files, extract audio tracks, create thumbnails, and transcode between formats.
categories: [media, automation]
dependencies: [ffmpeg, bash]
---

# Media Converter

## What This Does

Automate media file conversion, compression, and extraction using ffmpeg. Convert between video formats (MP4, MKV, WebM, AVI), extract audio tracks, generate thumbnails, compress videos for web, create GIFs, and batch process entire directories.

**Example:** "Convert all MKV files in a folder to MP4, extract audio as MP3, and generate thumbnail previews — in one command."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Check if ffmpeg is installed
which ffmpeg || echo "ffmpeg not found"

# Install ffmpeg
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y ffmpeg

# macOS
brew install ffmpeg

# Verify
ffmpeg -version | head -1
```

### 2. Convert a Video

```bash
bash scripts/run.sh convert --input video.mkv --output video.mp4

# Output:
# [2026-02-22 10:00:00] 🎬 Converting video.mkv → video.mp4
# [2026-02-22 10:00:15] ✅ Done — video.mp4 (45.2 MB, 1920x1080, 00:03:24)
```

### 3. Batch Convert a Directory

```bash
bash scripts/run.sh batch --input-dir ./raw --output-dir ./converted --format mp4

# Output:
# [2026-02-22 10:00:00] 📂 Processing 12 files from ./raw
# [2026-02-22 10:00:05] 🎬 1/12 clip01.avi → clip01.mp4
# ...
# [2026-02-22 10:02:30] ✅ Batch complete — 12/12 converted (saved 340 MB)
```

## Core Workflows

### Workflow 1: Video Format Conversion

Convert between any supported video formats.

```bash
# MKV to MP4 (most common)
bash scripts/run.sh convert --input movie.mkv --output movie.mp4

# MP4 to WebM (for web)
bash scripts/run.sh convert --input video.mp4 --output video.webm

# AVI to MP4 with quality preset
bash scripts/run.sh convert --input old.avi --output new.mp4 --quality high
```

**Quality presets:**
- `low` — CRF 28, fast encoding, small files
- `medium` — CRF 23, balanced (default)
- `high` — CRF 18, slow encoding, best quality
- `lossless` — CRF 0, largest files

### Workflow 2: Extract Audio

Extract audio tracks from video files.

```bash
# Extract as MP3
bash scripts/run.sh extract-audio --input video.mp4 --format mp3

# Extract as FLAC (lossless)
bash scripts/run.sh extract-audio --input concert.mkv --format flac

# Extract as WAV (uncompressed)
bash scripts/run.sh extract-audio --input interview.mp4 --format wav --bitrate 320k
```

### Workflow 3: Compress Video for Web

Reduce file size while maintaining acceptable quality.

```bash
# Compress for web (target ~5MB per minute)
bash scripts/run.sh compress --input large.mp4 --target-size 50M

# Compress with max width (for mobile)
bash scripts/run.sh compress --input 4k.mp4 --max-width 1280 --output mobile.mp4

# Compress for social media (Instagram/TikTok)
bash scripts/run.sh compress --input raw.mp4 --preset social --output post.mp4
```

**Compression presets:**
- `web` — 720p, CRF 26, ~3MB/min
- `social` — 1080p, CRF 24, optimized for Instagram/TikTok
- `email` — 480p, CRF 28, <10MB total

### Workflow 4: Generate Thumbnails

Create thumbnail images from video.

```bash
# Single thumbnail at 50% mark
bash scripts/run.sh thumbnail --input video.mp4

# Multiple thumbnails (every 30 seconds)
bash scripts/run.sh thumbnail --input video.mp4 --interval 30 --output-dir ./thumbs

# Thumbnail at specific timestamp
bash scripts/run.sh thumbnail --input video.mp4 --at 01:23:45
```

### Workflow 5: Create GIF

Convert video clip to animated GIF.

```bash
# Create GIF from first 5 seconds
bash scripts/run.sh gif --input video.mp4 --duration 5

# GIF with custom start time and size
bash scripts/run.sh gif --input video.mp4 --start 00:01:30 --duration 3 --width 480

# High-quality GIF (palette optimization)
bash scripts/run.sh gif --input video.mp4 --start 00:00:10 --duration 5 --quality high
```

### Workflow 6: Audio Conversion

Convert between audio formats.

```bash
# WAV to MP3
bash scripts/run.sh convert --input audio.wav --output audio.mp3 --bitrate 320k

# FLAC to AAC
bash scripts/run.sh convert --input song.flac --output song.aac

# Batch convert all WAVs to MP3
bash scripts/run.sh batch --input-dir ./recordings --format mp3 --bitrate 192k
```

### Workflow 7: Trim / Cut

Extract a segment from a media file.

```bash
# Cut from 1:00 to 2:30
bash scripts/run.sh trim --input video.mp4 --start 00:01:00 --end 00:02:30

# First 60 seconds
bash scripts/run.sh trim --input podcast.mp3 --duration 60
```

### Workflow 8: Concatenate / Merge

Join multiple files together.

```bash
# Merge video files
bash scripts/run.sh merge --inputs "part1.mp4,part2.mp4,part3.mp4" --output full.mp4

# Merge with file list
echo "file 'clip1.mp4'" > list.txt
echo "file 'clip2.mp4'" >> list.txt
bash scripts/run.sh merge --file-list list.txt --output merged.mp4
```

## Configuration

### Environment Variables

```bash
# Default output directory (optional)
export MEDIA_CONVERTER_OUTPUT="./converted"

# Default quality preset
export MEDIA_CONVERTER_QUALITY="medium"

# Number of parallel jobs for batch processing
export MEDIA_CONVERTER_JOBS=4

# ffmpeg binary path (if not in PATH)
export FFMPEG_BIN="/usr/bin/ffmpeg"
```

## Advanced Usage

### Custom ffmpeg Flags

```bash
# Pass custom ffmpeg flags
bash scripts/run.sh convert --input video.mkv --output video.mp4 \
  --extra "-c:v libx264 -preset veryslow -tune film"
```

### Probe / Info

```bash
# Get media file info
bash scripts/run.sh info --input video.mp4

# Output:
# Format: mp4 (mov,mp4,m4a,3gp,3g2,mj2)
# Duration: 00:03:24.56
# Size: 45.2 MB
# Video: h264, 1920x1080, 30fps, 1.7 Mbps
# Audio: aac, 44100 Hz, stereo, 128 kbps
```

## Troubleshooting

### Issue: "ffmpeg: command not found"

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y ffmpeg

# macOS
brew install ffmpeg

# Verify
ffmpeg -version
```

### Issue: "Codec not supported"

```bash
# Check available codecs
ffmpeg -codecs | grep -i <codec>

# Install full ffmpeg with all codecs
sudo apt-get install -y ffmpeg libavcodec-extra
```

### Issue: Output file is larger than input

This happens when transcoding to a less efficient codec. Use:
```bash
bash scripts/run.sh compress --input file.mp4 --target-size <desired-size>
```

### Issue: Slow batch processing

```bash
# Increase parallel jobs
export MEDIA_CONVERTER_JOBS=8
bash scripts/run.sh batch --input-dir ./raw --format mp4
```

## Dependencies

- `ffmpeg` (4.0+) — media processing engine
- `bash` (4.0+) — script runtime
- `bc` — calculations (usually pre-installed)
