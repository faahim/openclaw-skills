# Listing Copy: Video Thumbnails

## Metadata
- **Type:** Skill
- **Name:** video-thumbnails
- **Display Name:** Video Thumbnails
- **Categories:** [media, automation]
- **Price:** $8
- **Dependencies:** [ffmpeg, imagemagick]

## Tagline

Extract thumbnails, contact sheets, and animated GIF previews from any video file

## Description

Manually scrubbing through videos to find the right frame is tedious. Whether you're building a media library, creating documentation, or sharing previews — you need quick, automated thumbnail extraction.

Video Thumbnails uses ffmpeg and ImageMagick to extract evenly-spaced thumbnails, generate visual contact sheets (grid previews), and create optimized animated GIF previews from any video format. MP4, MKV, AVI, MOV, WebM — if ffmpeg can read it, this skill can process it.

**What it does:**
- 🖼️ Extract N evenly-spaced thumbnails from any video
- 📋 Generate contact sheets (customizable grid layouts)
- 🎞️ Create optimized animated GIF previews (2-pass quality)
- ⏱️ Extract frames at exact timestamps
- 📁 Batch process entire directories of videos
- 🏷️ Optional timestamp overlay on thumbnails
- 🎨 Configurable width, quality, format (JPG/PNG/WebP)

**Who it's for:** Content creators, media archivists, developers building video platforms, anyone managing video libraries.

## Quick Start Preview

```bash
# Extract 12 thumbnails
bash scripts/run.sh thumbnails --input video.mp4 --count 12

# Generate a 4×3 contact sheet with timestamps
bash scripts/run.sh contact-sheet --input video.mp4 --cols 4 --rows 3 --timestamp

# Create animated GIF preview
bash scripts/run.sh gif --input video.mp4 --duration 10 --width 320
```

## Core Capabilities

1. Thumbnail extraction — Evenly-spaced frames from any video format
2. Contact sheets — Customizable grid layouts with ImageMagick montage
3. Animated GIF previews — 2-pass palette optimization for quality
4. Timestamp overlay — Burn-in timecodes on extracted frames
5. Exact timestamp extraction — Pull frames at specific moments
6. Batch processing — Process entire directories in one command
7. Format flexibility — Output as JPG, PNG, or WebP
8. Quality control — Configurable compression quality
9. Size management — GIF size warnings and optimization tips
10. Zero config — Sensible defaults, works out of the box

## Dependencies
- `ffmpeg` (video processing)
- `imagemagick` (montage, convert)
- `bash` (4.0+)

## Installation Time
**2 minutes** — Install ffmpeg + imagemagick, run script

## Pricing Justification

**Why $8:**
- LarryBrain utility tier: $5-15
- Requires real tools (ffmpeg + ImageMagick)
- Multiple workflows (thumbnails, contact sheets, GIFs, batch)
- Saves significant manual work
- No monthly fees vs video processing SaaS
