# Listing Copy: FFmpeg Toolkit

## Metadata
- **Type:** Skill
- **Name:** ffmpeg-toolkit
- **Display Name:** FFmpeg Toolkit
- **Categories:** [media, automation]
- **Price:** $12
- **Icon:** 🎬
- **Dependencies:** [ffmpeg, ffprobe, bash]

## Tagline

Convert, compress, trim, merge, and batch-process video & audio files with ffmpeg

## Description

Manually running ffmpeg commands means memorizing dozens of flags, codec names, and filter syntax. One wrong parameter and you're re-encoding for hours or getting corrupted output.

FFmpeg Toolkit wraps the full power of ffmpeg into simple, memorable commands. Convert formats, compress videos to target sizes (perfect for Discord's 25MB limit), extract audio, create GIFs, generate thumbnail grids, add watermarks, burn subtitles, and batch-process entire directories — all with one-liner commands.

**What it does:**
- 🔄 Convert between any video/audio format (MOV→MP4, MKV→MP4, WAV→MP3)
- 📦 Smart compression with quality presets or target file size
- ✂️ Trim, split, and merge video clips
- 🎵 Extract audio tracks (MP3, WAV, AAC)
- 📸 Generate thumbnails, screenshots, and contact sheets
- 🎞️ Create high-quality GIFs with palette optimization
- 💧 Add text or image watermarks
- 📊 Inspect media metadata (resolution, codec, bitrate, duration)
- 🔁 Batch process entire directories in one command
- ⚡ Hardware acceleration support (NVIDIA, Intel QSV, AMD VAAPI)

Perfect for developers, content creators, and anyone who regularly processes media files without wanting to memorize ffmpeg's 500+ options.

## Quick Start Preview

```bash
# Compress a video to medium quality (~50% smaller)
bash scripts/run.sh compress --input video.mp4 --quality medium

# Convert MOV to MP4
bash scripts/run.sh convert --input recording.mov --output recording.mp4

# Extract audio as MP3
bash scripts/run.sh extract-audio --input video.mp4 --format mp3

# Create GIF from 5-second clip
bash scripts/run.sh gif --input video.mp4 --start 00:00:10 --duration 5
```

## Installation Time
**2 minutes** — Install ffmpeg (if not present), run commands
