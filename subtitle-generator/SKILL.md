---
name: subtitle-generator
description: >-
  Generate SRT/VTT subtitles from video and audio files using Whisper AI speech recognition.
categories: [media, automation]
dependencies: [ffmpeg, python3, pip]
---

# Subtitle Generator

## What This Does

Automatically generates subtitles (SRT or VTT format) from any video or audio file using OpenAI's Whisper speech recognition model. Supports 90+ languages, word-level timestamps, and batch processing. Runs entirely locally — no API keys or cloud services needed.

**Example:** "Generate English subtitles for a 2-hour video in under 10 minutes."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install ffmpeg (if not already installed)
which ffmpeg || sudo apt-get install -y ffmpeg

# Install Whisper
pip install -U openai-whisper
```

### 2. Generate Subtitles

```bash
bash scripts/generate.sh --input video.mp4

# Output:
# [subtitle-gen] Extracting audio from video.mp4...
# [subtitle-gen] Running Whisper (model: base)...
# [subtitle-gen] ✅ Subtitles saved to video.srt
```

### 3. Choose Format & Model

```bash
# VTT format (for web players)
bash scripts/generate.sh --input video.mp4 --format vtt

# Use larger model for better accuracy
bash scripts/generate.sh --input video.mp4 --model medium

# Specify language (skip auto-detection)
bash scripts/generate.sh --input video.mp4 --language es
```

## Core Workflows

### Workflow 1: Basic Subtitle Generation

**Use case:** Generate subtitles for a single video

```bash
bash scripts/generate.sh --input presentation.mp4
# → presentation.srt
```

### Workflow 2: Batch Processing

**Use case:** Generate subtitles for all videos in a directory

```bash
bash scripts/generate.sh --input-dir ./videos/ --format srt
# → ./videos/video1.srt
# → ./videos/video2.srt
# → ./videos/video3.srt
```

### Workflow 3: Audio File Transcription

**Use case:** Generate subtitles from podcast/audio

```bash
bash scripts/generate.sh --input podcast.mp3 --format vtt
# → podcast.vtt
```

### Workflow 4: Multi-Language Subtitles

**Use case:** Generate subtitles in a specific language

```bash
# Spanish audio → Spanish subtitles
bash scripts/generate.sh --input video.mp4 --language es

# Auto-detect language
bash scripts/generate.sh --input video.mp4
# [subtitle-gen] Detected language: Japanese (confidence: 0.97)
```

### Workflow 5: High-Accuracy Mode

**Use case:** Important content that needs precise subtitles

```bash
bash scripts/generate.sh --input interview.mp4 --model large-v3
# Slower but significantly more accurate
```

## Configuration

### Whisper Models (speed vs accuracy)

| Model | Size | Speed | Accuracy | Best For |
|-------|------|-------|----------|----------|
| `tiny` | 39M | ~32x realtime | Basic | Quick drafts, short clips |
| `base` | 74M | ~16x realtime | Good | **Default — best balance** |
| `small` | 244M | ~6x realtime | Better | Most content |
| `medium` | 769M | ~2x realtime | Great | Professional content |
| `large-v3` | 1.5G | ~1x realtime | Best | Critical accuracy needs |

### Supported Formats

**Input:** mp4, mkv, avi, mov, webm, mp3, wav, flac, ogg, m4a, aac  
**Output:** srt (SubRip), vtt (WebVTT)

### Environment Variables

```bash
# Override default model
export WHISPER_MODEL="small"

# Override default output format
export WHISPER_FORMAT="vtt"

# Set output directory (default: same as input)
export WHISPER_OUTPUT_DIR="./subtitles/"
```

## Advanced Usage

### Custom Output Path

```bash
bash scripts/generate.sh --input video.mp4 --output /path/to/subtitles/custom.srt
```

### Extract Audio Only (no transcription)

```bash
bash scripts/generate.sh --input video.mp4 --audio-only
# → video.wav (16kHz mono, optimized for Whisper)
```

### Translate to English

```bash
# Transcribe foreign audio AND translate to English
bash scripts/generate.sh --input japanese-video.mp4 --task translate
# → japanese-video.srt (English subtitles)
```

### Run as Cron Job (batch overnight)

```bash
# Process new videos daily at 2am
0 2 * * * cd /path/to/videos && bash /path/to/scripts/generate.sh --input-dir ./incoming/ --format srt --model medium >> /var/log/subtitle-gen.log 2>&1
```

## Troubleshooting

### Issue: "command not found: whisper"

**Fix:**
```bash
pip install -U openai-whisper
# If pip not found:
sudo apt-get install python3-pip
```

### Issue: "No module named 'torch'"

**Fix:**
```bash
pip install torch
# For CPU-only (smaller download):
pip install torch --index-url https://download.pytorch.org/whl/cpu
```

### Issue: Out of memory on large files

**Fix:** Use a smaller model or split the file:
```bash
# Use tiny model
bash scripts/generate.sh --input large-video.mp4 --model tiny

# Or split into chunks first
ffmpeg -i large-video.mp4 -f segment -segment_time 600 -c copy chunk_%03d.mp4
bash scripts/generate.sh --input-dir . --format srt
```

### Issue: Subtitles are inaccurate

**Fix:** Use a larger model:
```bash
bash scripts/generate.sh --input video.mp4 --model medium
# Or for best quality:
bash scripts/generate.sh --input video.mp4 --model large-v3
```

### Issue: Wrong language detected

**Fix:** Specify the language explicitly:
```bash
bash scripts/generate.sh --input video.mp4 --language fr
```

## Supported Languages

Whisper supports 90+ languages including: English, Spanish, French, German, Italian, Portuguese, Russian, Japanese, Korean, Chinese, Arabic, Hindi, Bengali, Turkish, Vietnamese, Thai, and many more.

Full list: `whisper --help` or see [Whisper docs](https://github.com/openai/whisper#available-models-and-languages).

## Key Principles

1. **Local-first** — All processing happens on your machine, no API keys needed
2. **Format flexibility** — SRT for video players, VTT for web
3. **Batch-ready** — Process entire directories in one command
4. **Model choice** — Trade speed for accuracy based on your needs
5. **Language agnostic** — 90+ languages with auto-detection
