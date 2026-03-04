# Listing Copy: Screencast to GIF

## Metadata
- **Type:** Skill
- **Name:** screencast-to-gif
- **Display Name:** Screencast to GIF
- **Categories:** [media, automation]
- **Icon:** 🎬
- **Dependencies:** [ffmpeg, gifsicle]

## Tagline

Convert screen recordings to optimized, shareable GIFs — perfect for READMEs, demos, and bug reports.

## Description

Sharing a screen recording shouldn't require uploading to YouTube or attaching a 200MB video file. GIFs are universal — they play everywhere, inline, with zero friction. But converting video to GIF that looks good AND stays small is surprisingly tricky.

Screencast to GIF handles the entire pipeline: optimal palette generation per-video (not generic 256 colors), smart frame rate reduction, resolution scaling, and aggressive optimization via gifsicle. The result is GIFs that are typically 40-60% smaller than naive conversion, with noticeably better color accuracy.

**What it does:**
- 🎬 Convert MP4, WebM, MKV, MOV to optimized GIF
- 📏 Custom width, FPS, and color palette control
- ✂️ Trim clips — specify start time and duration
- ⚡ Speed up or slow down playback
- 📦 Max file size enforcement (auto-reduces quality to fit)
- 📁 Batch convert entire directories
- 🎨 Per-video palette optimization for best color accuracy
- 🔄 Gifsicle optimization (40-60% size reduction)

Perfect for developers documenting projects, filing visual bug reports, creating tutorial snippets, or sharing quick demos on Slack and Discord.

## Quick Start

```bash
# Install dependencies
bash scripts/install.sh

# Convert a video to GIF
bash scripts/convert.sh --input recording.mp4

# Custom size for GitHub README (800px, 15fps, max 10MB)
bash scripts/convert.sh --input demo.mp4 --width 800 --fps 15 --max-size 10

# Trim and convert (start at 5s, 10s duration)
bash scripts/convert.sh --input long-video.mp4 --start 5 --duration 10 --width 640
```
