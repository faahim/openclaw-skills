---
name: ffmpeg-toolkit
description: >-
  Convert, compress, trim, merge, and process video/audio files with ffmpeg — batch operations, format conversion, and media extraction.
categories: [media, automation]
dependencies: [ffmpeg, ffprobe, bash]
---

# FFmpeg Toolkit

## What This Does

Automates common video and audio processing tasks using ffmpeg — the most powerful media processing tool available. Convert formats, compress videos, extract audio, trim clips, merge files, create thumbnails, add watermarks, and batch process entire directories.

**Example:** "Convert all .mov files to .mp4, compress to 50% size, extract thumbnails at 10s intervals."

## Quick Start (5 minutes)

### 1. Install FFmpeg

```bash
# Check if installed
which ffmpeg ffprobe || bash scripts/install.sh
```

### 2. Convert a Video

```bash
bash scripts/run.sh convert --input video.mov --output video.mp4
```

### 3. Compress a Video

```bash
bash scripts/run.sh compress --input video.mp4 --quality medium
# Output: video_compressed.mp4 (~50% smaller)
```

## Core Workflows

### Workflow 1: Format Conversion

Convert between any video/audio format.

```bash
# Video: MOV → MP4
bash scripts/run.sh convert --input video.mov --output video.mp4

# Video: MKV → MP4 (with codec copy for speed)
bash scripts/run.sh convert --input video.mkv --output video.mp4 --copy

# Audio: WAV → MP3
bash scripts/run.sh convert --input audio.wav --output audio.mp3

# Audio: FLAC → AAC
bash scripts/run.sh convert --input music.flac --output music.m4a --bitrate 256k

# Batch: All MOV files in directory → MP4
bash scripts/run.sh batch-convert --dir ./videos --from mov --to mp4
```

### Workflow 2: Video Compression

Reduce file size while maintaining quality.

```bash
# Quick compress (CRF 28, ~50% smaller)
bash scripts/run.sh compress --input video.mp4 --quality medium

# High quality (CRF 23, ~30% smaller)
bash scripts/run.sh compress --input video.mp4 --quality high

# Maximum compression (CRF 32, ~70% smaller)
bash scripts/run.sh compress --input video.mp4 --quality low

# Target file size (e.g., under 25MB for Discord)
bash scripts/run.sh compress --input video.mp4 --target-size 25M

# Batch compress all videos in directory
bash scripts/run.sh batch-compress --dir ./videos --quality medium
```

### Workflow 3: Trim & Cut

Extract clips from videos.

```bash
# Trim from 00:01:30 to 00:02:45
bash scripts/run.sh trim --input video.mp4 --start 00:01:30 --end 00:02:45

# First 30 seconds
bash scripts/run.sh trim --input video.mp4 --duration 30

# Last 60 seconds
bash scripts/run.sh trim --input video.mp4 --last 60

# Split into 5-minute chunks
bash scripts/run.sh split --input long-video.mp4 --segment 300
```

### Workflow 4: Extract Audio

Pull audio tracks from video files.

```bash
# Extract audio as MP3
bash scripts/run.sh extract-audio --input video.mp4 --format mp3

# Extract audio as WAV (lossless)
bash scripts/run.sh extract-audio --input video.mp4 --format wav

# Extract audio with specific bitrate
bash scripts/run.sh extract-audio --input video.mp4 --format mp3 --bitrate 320k

# Batch extract audio from all videos
bash scripts/run.sh batch-extract-audio --dir ./videos --format mp3
```

### Workflow 5: Thumbnails & Screenshots

Generate thumbnails or screenshot grids.

```bash
# Single screenshot at 10 seconds
bash scripts/run.sh screenshot --input video.mp4 --time 00:00:10

# Thumbnails every 30 seconds
bash scripts/run.sh thumbnails --input video.mp4 --interval 30 --outdir ./thumbs

# Contact sheet (grid of screenshots)
bash scripts/run.sh contact-sheet --input video.mp4 --cols 4 --rows 4

# Extract first frame
bash scripts/run.sh screenshot --input video.mp4 --time 0
```

### Workflow 6: Merge & Concatenate

Combine multiple files.

```bash
# Merge videos (same codec)
bash scripts/run.sh merge --inputs "part1.mp4 part2.mp4 part3.mp4" --output full.mp4

# Merge with re-encoding (different codecs/resolutions)
bash scripts/run.sh merge --inputs "a.mp4 b.mkv c.mov" --output merged.mp4 --reencode

# Combine audio + video
bash scripts/run.sh mux --video video.mp4 --audio audio.mp3 --output combined.mp4

# Add audio track to video (replace existing)
bash scripts/run.sh replace-audio --video video.mp4 --audio narration.mp3
```

### Workflow 7: Resize & Scale

Change video resolution.

```bash
# Scale to 720p
bash scripts/run.sh resize --input video.mp4 --height 720

# Scale to 1080p
bash scripts/run.sh resize --input video.mp4 --height 1080

# Scale to specific width (maintain aspect ratio)
bash scripts/run.sh resize --input video.mp4 --width 1280

# Scale to exact dimensions (may distort)
bash scripts/run.sh resize --input video.mp4 --width 1920 --height 1080 --force
```

### Workflow 8: GIF Creation

Convert video clips to GIFs.

```bash
# Video to GIF (10 seconds starting at 00:00:05)
bash scripts/run.sh gif --input video.mp4 --start 00:00:05 --duration 10

# High quality GIF with palette
bash scripts/run.sh gif --input video.mp4 --start 0 --duration 5 --quality high

# GIF with custom size
bash scripts/run.sh gif --input video.mp4 --start 0 --duration 3 --width 480
```

### Workflow 9: Watermark

Add text or image overlays.

```bash
# Text watermark (bottom-right)
bash scripts/run.sh watermark --input video.mp4 --text "© 2026 MyBrand" --position br

# Image watermark
bash scripts/run.sh watermark --input video.mp4 --image logo.png --position br --opacity 0.5

# Positions: tl (top-left), tr (top-right), bl (bottom-left), br (bottom-right), center
```

### Workflow 10: Media Info

Inspect file metadata.

```bash
# Quick info (duration, resolution, codec, bitrate)
bash scripts/run.sh info --input video.mp4

# Full probe (all streams, metadata)
bash scripts/run.sh info --input video.mp4 --full

# Batch info for directory
bash scripts/run.sh batch-info --dir ./videos

# Output:
# video.mp4 | 1920x1080 | h264 | 23.98fps | 8.2Mbps | 00:05:32 | 342MB
```

## Configuration

### Environment Variables

```bash
# Default output directory
export FFMPEG_OUTPUT_DIR="./output"

# Default compression quality (high/medium/low)
export FFMPEG_QUALITY="medium"

# Hardware acceleration (auto-detected if not set)
export FFMPEG_HWACCEL="auto"  # auto, vaapi, nvenc, videotoolbox, qsv

# Number of threads
export FFMPEG_THREADS="0"  # 0 = auto
```

## Advanced Usage

### Hardware Acceleration

```bash
# NVIDIA GPU encoding
bash scripts/run.sh compress --input video.mp4 --quality medium --hwaccel nvenc

# Intel Quick Sync
bash scripts/run.sh compress --input video.mp4 --quality medium --hwaccel qsv

# AMD VAAPI
bash scripts/run.sh compress --input video.mp4 --quality medium --hwaccel vaapi
```

### Custom FFmpeg Commands

```bash
# Pass raw ffmpeg flags
bash scripts/run.sh raw --input video.mp4 --output out.mp4 --flags "-vf scale=640:480 -c:v libx264 -preset fast"
```

### Subtitles

```bash
# Burn subtitles into video
bash scripts/run.sh subtitles --input video.mp4 --srt subtitles.srt --output video_subbed.mp4

# Extract subtitles from MKV
bash scripts/run.sh extract-subs --input video.mkv --output subs.srt
```

## Troubleshooting

### Issue: "ffmpeg: command not found"

```bash
bash scripts/install.sh
# Or manually:
# Ubuntu/Debian: sudo apt install ffmpeg
# Mac: brew install ffmpeg
# Arch: sudo pacman -S ffmpeg
```

### Issue: Slow encoding

- Use `--hwaccel auto` for GPU acceleration
- Use `--copy` flag when just changing container (no re-encode)
- Use `--preset ultrafast` for speed over compression

### Issue: Output file larger than input

- The default codec may be less efficient. Try: `--codec h265`
- For audio, reduce bitrate: `--bitrate 128k`

## Dependencies

- `ffmpeg` (4.0+)
- `ffprobe` (comes with ffmpeg)
- `bash` (4.0+)
- Optional: GPU drivers for hardware acceleration
