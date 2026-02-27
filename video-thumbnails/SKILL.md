---
name: video-thumbnails
description: >-
  Extract thumbnails, contact sheets, and animated GIF previews from video files using ffmpeg and ImageMagick.
categories: [media, automation]
dependencies: [ffmpeg, imagemagick]
---

# Video Thumbnails

## What This Does

Extract key frames, generate contact sheets (grid of thumbnails), and create animated GIF previews from any video file. Uses ffmpeg for frame extraction and ImageMagick for compositing. Works with MP4, MKV, AVI, MOV, WebM, and any format ffmpeg supports.

**Example:** "Extract 12 evenly-spaced thumbnails from a 2-hour movie, arrange them in a 4×3 contact sheet, and generate a 10-second animated GIF preview."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Check if already installed
which ffmpeg montage convert 2>/dev/null || echo "Need to install ffmpeg and imagemagick"

# Ubuntu/Debian
sudo apt-get install -y ffmpeg imagemagick

# macOS
brew install ffmpeg imagemagick

# Arch
sudo pacman -S ffmpeg imagemagick
```

### 2. Extract Thumbnails

```bash
# Extract 8 evenly-spaced thumbnails from a video
bash scripts/run.sh thumbnails --input video.mp4 --count 8

# Output: thumbs/video_001.jpg thumbs/video_002.jpg ... thumbs/video_008.jpg
```

### 3. Generate Contact Sheet

```bash
# Create a 4×3 grid contact sheet
bash scripts/run.sh contact-sheet --input video.mp4 --cols 4 --rows 3

# Output: video_contact_sheet.jpg
```

### 4. Create Animated GIF Preview

```bash
# Generate a 10-second GIF preview (1 fps, 320px wide)
bash scripts/run.sh gif --input video.mp4 --duration 10 --width 320

# Output: video_preview.gif
```

## Core Workflows

### Workflow 1: Extract Key Thumbnails

**Use case:** Get representative frames from a video for previews, documentation, or social media.

```bash
bash scripts/run.sh thumbnails \
  --input /path/to/video.mp4 \
  --count 12 \
  --width 640 \
  --output-dir ./thumbs \
  --format jpg \
  --quality 90
```

**Output:**
```
[video-thumbnails] Extracting 12 thumbnails from video.mp4 (duration: 01:32:15)
[video-thumbnails] Frame interval: every 460 seconds
[video-thumbnails] ✅ thumbs/video_001.jpg (00:07:40)
[video-thumbnails] ✅ thumbs/video_002.jpg (00:15:20)
...
[video-thumbnails] ✅ thumbs/video_012.jpg (01:32:00)
[video-thumbnails] Done — 12 thumbnails saved to ./thumbs/
```

### Workflow 2: Contact Sheet (Grid Preview)

**Use case:** Single image showing video content at a glance. Great for video libraries, archives.

```bash
bash scripts/run.sh contact-sheet \
  --input video.mp4 \
  --cols 4 \
  --rows 3 \
  --thumb-width 320 \
  --timestamp \
  --header "My Video - 01:32:15" \
  --output video_sheet.jpg
```

**Output:** A single JPEG with a 4×3 grid of timestamped thumbnails, plus a header with video title.

### Workflow 3: Animated GIF Preview

**Use case:** Quick animated preview for web, messaging, or documentation.

```bash
bash scripts/run.sh gif \
  --input video.mp4 \
  --duration 15 \
  --fps 2 \
  --width 480 \
  --start 00:01:00 \
  --output preview.gif
```

### Workflow 4: Extract at Specific Timestamps

**Use case:** Pull frames at exact moments.

```bash
bash scripts/run.sh timestamps \
  --input video.mp4 \
  --times "00:05:30,00:12:45,01:05:00,01:30:22" \
  --width 1280 \
  --output-dir ./specific_frames
```

### Workflow 5: Batch Process Multiple Videos

**Use case:** Generate contact sheets for an entire folder of videos.

```bash
bash scripts/run.sh batch \
  --input-dir /path/to/videos \
  --mode contact-sheet \
  --cols 4 \
  --rows 3 \
  --output-dir ./sheets
```

## Configuration

### Environment Variables

```bash
# Default output quality (1-100, default: 85)
export VT_QUALITY=85

# Default thumbnail width (default: 640)
export VT_WIDTH=640

# Default output format (jpg, png, webp)
export VT_FORMAT=jpg

# Max GIF file size in MB (default: 10)
export VT_MAX_GIF_SIZE=10
```

### Command Reference

| Command | Description |
|---------|-------------|
| `thumbnails` | Extract evenly-spaced thumbnails |
| `contact-sheet` | Generate a grid contact sheet image |
| `gif` | Create animated GIF preview |
| `timestamps` | Extract frames at specific timestamps |
| `batch` | Process multiple videos |

### Common Options

| Option | Default | Description |
|--------|---------|-------------|
| `--input` | required | Input video file |
| `--output` / `--output-dir` | auto | Output file or directory |
| `--width` | 640 | Thumbnail width (height auto-scales) |
| `--format` | jpg | Output format: jpg, png, webp |
| `--quality` | 85 | JPEG/WebP quality (1-100) |
| `--count` | 8 | Number of thumbnails to extract |
| `--cols` | 4 | Contact sheet columns |
| `--rows` | 3 | Contact sheet rows |
| `--timestamp` | false | Overlay timestamp on thumbnails |
| `--fps` | 1 | GIF frames per second |
| `--duration` | 10 | GIF duration in seconds |
| `--start` | auto | Start time for GIF extraction |

## Troubleshooting

### Issue: "convert: not authorized" (ImageMagick policy)

**Fix:** Edit ImageMagick policy to allow PDF/video processing:
```bash
sudo sed -i 's/rights="none" pattern="@\*"/rights="read|write" pattern="@*"/' /etc/ImageMagick-6/policy.xml 2>/dev/null
# Or for ImageMagick 7:
sudo sed -i 's/rights="none" pattern="@\*"/rights="read|write" pattern="@*"/' /etc/ImageMagick-7/policy.xml 2>/dev/null
```

### Issue: "ffmpeg: command not found"

**Fix:** Install ffmpeg for your OS (see Quick Start section).

### Issue: GIF is too large

**Fix:** Reduce width, fps, or duration:
```bash
bash scripts/run.sh gif --input video.mp4 --width 240 --fps 1 --duration 8
```

### Issue: Black/empty thumbnails

**Cause:** Video may have a long intro with black frames.  
**Fix:** Use `--start` to skip the intro:
```bash
bash scripts/run.sh thumbnails --input video.mp4 --count 8 --start 00:00:30
```

## Dependencies

- `ffmpeg` (video processing, frame extraction)
- `imagemagick` (`montage`, `convert` — contact sheets, compositing)
- `bash` (4.0+)
- Optional: `bc` (duration calculations — usually pre-installed)
