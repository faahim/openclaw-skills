---
name: screencast-to-gif
description: >-
  Convert screen recordings and video files to optimized, shareable GIFs.
  Batch processing, custom sizing, frame rate control, and automatic optimization.
categories: [media, automation]
dependencies: [ffmpeg, gifsicle]
---

# Screencast to GIF

## What This Does

Converts video files (MP4, WebM, MKV, MOV) to optimized GIFs — perfect for sharing demos, bug reports, tutorials, and README documentation. Handles single files or entire directories, with fine-grained control over size, frame rate, quality, and color palette. Uses ffmpeg for conversion and gifsicle for aggressive optimization (typically 40-60% size reduction).

**Example:** "Convert a 30-second screen recording to a 800px-wide, 15fps GIF under 5MB for a GitHub README."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Check if already installed
which ffmpeg gifsicle && echo "Ready!" || echo "Need to install"

# Ubuntu/Debian
sudo apt-get install -y ffmpeg gifsicle

# macOS
brew install ffmpeg gifsicle

# Arch
sudo pacman -S ffmpeg gifsicle

# Alpine
sudo apk add ffmpeg gifsicle
```

### 2. Convert Your First Video

```bash
bash scripts/convert.sh --input recording.mp4

# Output: recording.gif (same directory)
# [screencast-to-gif] Input: recording.mp4 (1920x1080, 30fps, 45s)
# [screencast-to-gif] Converting: 800px wide, 15fps, optimized palette
# [screencast-to-gif] Raw GIF: 12.4MB
# [screencast-to-gif] Optimized: 5.1MB (59% reduction)
# [screencast-to-gif] ✅ Output: recording.gif
```

### 3. Custom Settings

```bash
# Small GIF for Slack/Discord (480px, 10fps, max 2MB)
bash scripts/convert.sh --input demo.mp4 --width 480 --fps 10 --max-size 2

# High quality for documentation (1200px, 20fps)
bash scripts/convert.sh --input tutorial.mp4 --width 1200 --fps 20

# Trim a section (start at 5s, duration 10s)
bash scripts/convert.sh --input long-video.mp4 --start 5 --duration 10

# Batch convert all MP4s in a directory
bash scripts/convert.sh --input ./recordings/ --width 640 --fps 12
```

## Core Workflows

### Workflow 1: GitHub README GIF

**Use case:** Create a demo GIF for your project README

```bash
bash scripts/convert.sh \
  --input demo.mp4 \
  --width 800 \
  --fps 15 \
  --max-size 10 \
  --output docs/demo.gif
```

**Optimization tips:**
- GitHub renders GIFs up to 10MB well
- 800px width is ideal for README display
- 15fps is smooth enough for UI demos

### Workflow 2: Slack/Discord Sharing

**Use case:** Quick shareable GIF for team communication

```bash
bash scripts/convert.sh \
  --input bug-repro.mp4 \
  --width 480 \
  --fps 10 \
  --max-size 2 \
  --colors 128
```

### Workflow 3: Trim and Convert

**Use case:** Extract a specific moment from a longer recording

```bash
bash scripts/convert.sh \
  --input meeting-recording.mp4 \
  --start 120 \
  --duration 8 \
  --width 640 \
  --fps 12
```

### Workflow 4: Batch Processing

**Use case:** Convert all recordings in a directory

```bash
# Convert all video files in ./recordings/
bash scripts/convert.sh --input ./recordings/ --width 640 --fps 12

# Output goes to ./recordings/*.gif
```

### Workflow 5: Speed Up / Slow Down

**Use case:** Create a timelapse or slow-motion GIF

```bash
# 2x speed (timelapse effect)
bash scripts/convert.sh --input coding-session.mp4 --speed 2.0

# 0.5x speed (slow motion)
bash scripts/convert.sh --input quick-demo.mp4 --speed 0.5
```

## Configuration

### Command Line Options

| Option | Default | Description |
|--------|---------|-------------|
| `--input` | (required) | Input video file or directory |
| `--output` | `<input>.gif` | Output GIF path |
| `--width` | `800` | Output width in pixels (height auto-scales) |
| `--fps` | `15` | Frames per second |
| `--start` | `0` | Start time in seconds |
| `--duration` | (full) | Duration in seconds |
| `--speed` | `1.0` | Playback speed multiplier |
| `--max-size` | (none) | Max file size in MB (reduces quality to fit) |
| `--colors` | `256` | Color palette size (64-256) |
| `--optimize` | `3` | Gifsicle optimization level (1-3) |
| `--loop` | `0` | Loop count (0=infinite) |
| `--no-optimize` | false | Skip gifsicle optimization |

### Environment Variables

```bash
# Override defaults globally
export GIF_DEFAULT_WIDTH=640
export GIF_DEFAULT_FPS=12
export GIF_DEFAULT_COLORS=128
export GIF_DEFAULT_OPTIMIZE=3
```

## Advanced Usage

### Custom Color Palette (Best Quality)

The script generates an optimized color palette per-video by default. For even better results with specific color needs:

```bash
# Generate palette separately
ffmpeg -i input.mp4 -vf "fps=15,scale=800:-1:flags=lanczos,palettegen=max_colors=256:stats_mode=diff" palette.png

# Use custom palette
bash scripts/convert.sh --input input.mp4 --palette palette.png
```

### Add Text Overlay

```bash
bash scripts/convert.sh \
  --input demo.mp4 \
  --text "Click here to start" \
  --text-position bottom
```

### Combine with Screen Recording

```bash
# Record screen first (Linux with ffmpeg)
ffmpeg -video_size 1920x1080 -framerate 30 -f x11grab -i :0.0 -t 30 recording.mp4

# Then convert
bash scripts/convert.sh --input recording.mp4 --width 800 --fps 15
```

## Troubleshooting

### Issue: "ffmpeg: command not found"

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y ffmpeg

# macOS
brew install ffmpeg
```

### Issue: "gifsicle: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install -y gifsicle

# macOS
brew install gifsicle
```

### Issue: GIF is too large

**Solutions:**
1. Reduce width: `--width 480`
2. Lower FPS: `--fps 10`
3. Fewer colors: `--colors 128`
4. Set max size: `--max-size 5` (auto-adjusts quality)
5. Trim duration: `--start 5 --duration 10`

### Issue: GIF looks choppy

**Solutions:**
1. Increase FPS: `--fps 20` or `--fps 24`
2. Increase width (more detail)
3. Use higher color count: `--colors 256`

### Issue: Colors look wrong/banded

**Solutions:**
1. Increase colors: `--colors 256`
2. The script uses per-video palette generation by default — this handles most cases
3. For gradients, try: `--dither`

## Dependencies

- `ffmpeg` (4.0+) — Video processing and palette generation
- `gifsicle` (1.92+) — GIF optimization and compression
- `bash` (4.0+) — Script runtime
- Optional: `bc` — For floating point math in size calculations
