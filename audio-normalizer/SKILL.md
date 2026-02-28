---
name: audio-normalizer
description: >-
  Normalize audio levels, convert formats, trim silence, and batch process audio files using ffmpeg.
categories: [media, automation]
dependencies: [ffmpeg, bash]
---

# Audio Normalizer

## What This Does

Normalize audio loudness to broadcast standards (EBU R128 / -16 LUFS), convert between formats (mp3, wav, flac, ogg, aac, opus), trim leading/trailing silence, and batch process entire directories. Uses ffmpeg — no cloud services, everything runs locally.

**Example:** "Normalize 50 podcast episodes to -16 LUFS, trim silence, convert to mp3 320kbps — in one command."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Check ffmpeg
which ffmpeg || echo "Install ffmpeg: sudo apt install ffmpeg (or brew install ffmpeg)"

# Make scripts executable
chmod +x scripts/*.sh
```

### 2. Normalize a Single File

```bash
bash scripts/run.sh normalize --input recording.wav --output normalized.wav

# Output:
# [audio-normalizer] Analyzing: recording.wav
# [audio-normalizer] Input loudness: -22.3 LUFS
# [audio-normalizer] Target loudness: -16.0 LUFS
# [audio-normalizer] Gain applied: +6.3 dB
# [audio-normalizer] ✅ Output: normalized.wav (-16.0 LUFS)
```

### 3. Batch Process a Directory

```bash
bash scripts/run.sh batch --input ./raw-episodes/ --output ./processed/ --format mp3 --bitrate 320k

# Output:
# [audio-normalizer] Processing 12 files...
# [audio-normalizer] ✅ ep01.wav → ep01.mp3 (-16.0 LUFS, 42MB → 18MB)
# [audio-normalizer] ✅ ep02.wav → ep02.mp3 (-16.0 LUFS, 38MB → 16MB)
# ...
# [audio-normalizer] Done: 12/12 files processed
```

## Core Workflows

### Workflow 1: Normalize Loudness (EBU R128)

**Use case:** Make all audio files the same perceived volume

```bash
# Default: -16 LUFS (podcast/streaming standard)
bash scripts/run.sh normalize --input file.wav --output file_norm.wav

# Custom target (e.g., -14 LUFS for louder output)
bash scripts/run.sh normalize --input file.wav --output file_norm.wav --target -14

# With true peak limiting (-1 dBTP)
bash scripts/run.sh normalize --input file.wav --output file_norm.wav --true-peak -1
```

### Workflow 2: Convert Audio Format

**Use case:** Convert between mp3, wav, flac, ogg, aac, opus

```bash
# WAV to MP3 (320kbps)
bash scripts/run.sh convert --input recording.wav --output recording.mp3 --bitrate 320k

# FLAC to OGG (quality 8)
bash scripts/run.sh convert --input album.flac --output album.ogg --quality 8

# Any format to Opus (efficient for voice)
bash scripts/run.sh convert --input voice.wav --output voice.opus --bitrate 64k
```

### Workflow 3: Trim Silence

**Use case:** Remove dead air from start/end of recordings

```bash
# Auto-detect and trim silence (default: -50dB threshold, 0.5s min duration)
bash scripts/run.sh trim --input recording.wav --output trimmed.wav

# Custom threshold
bash scripts/run.sh trim --input recording.wav --output trimmed.wav --threshold -40 --duration 1.0
```

### Workflow 4: Analyze Audio (No Changes)

**Use case:** Check loudness levels without modifying files

```bash
bash scripts/run.sh analyze --input file.wav

# Output:
# [audio-normalizer] File: file.wav
# [audio-normalizer] Duration: 45:32
# [audio-normalizer] Format: WAV (PCM 16-bit)
# [audio-normalizer] Sample rate: 44100 Hz
# [audio-normalizer] Channels: 2 (stereo)
# [audio-normalizer] Integrated loudness: -22.3 LUFS
# [audio-normalizer] True peak: -1.2 dBTP
# [audio-normalizer] Loudness range: 8.4 LU
```

### Workflow 5: Full Pipeline (Normalize + Trim + Convert)

**Use case:** One command to prepare audio for publishing

```bash
bash scripts/run.sh pipeline --input raw.wav --output final.mp3 \
  --normalize --target -16 \
  --trim --threshold -50 \
  --format mp3 --bitrate 192k

# Trims silence → normalizes to -16 LUFS → converts to mp3 192k
```

### Workflow 6: Batch Process Directory

**Use case:** Process an entire folder of audio files

```bash
bash scripts/run.sh batch \
  --input ./raw/ \
  --output ./processed/ \
  --normalize --target -16 \
  --trim \
  --format mp3 --bitrate 320k \
  --parallel 4

# Processes 4 files at a time for speed
```

## Configuration

### Environment Variables

```bash
# Override default target loudness
export AUDIO_NORM_TARGET="-16"        # LUFS (default: -16)
export AUDIO_NORM_TRUE_PEAK="-1.5"    # dBTP (default: -1.5)
export AUDIO_NORM_SILENCE_DB="-50"    # dB threshold for silence detection
export AUDIO_NORM_PARALLEL="4"        # Parallel batch jobs (default: 4)
```

### Supported Formats

| Format | Extension | Notes |
|--------|-----------|-------|
| MP3 | .mp3 | Most compatible, lossy |
| WAV | .wav | Uncompressed, large files |
| FLAC | .flac | Lossless compression |
| OGG Vorbis | .ogg | Open format, lossy |
| AAC | .aac/.m4a | Apple/streaming standard |
| Opus | .opus | Best quality-per-bit for voice |

## Troubleshooting

### Issue: "command not found: ffmpeg"

```bash
# Ubuntu/Debian
sudo apt-get install ffmpeg

# Mac
brew install ffmpeg

# Check version (needs 4.0+)
ffmpeg -version | head -1
```

### Issue: Output sounds distorted

The input may already be near 0 dBFS. Use true peak limiting:
```bash
bash scripts/run.sh normalize --input file.wav --output out.wav --true-peak -1.5
```

### Issue: Silence trim removes too much

Lower the threshold (more negative = only detect quieter silence):
```bash
bash scripts/run.sh trim --input file.wav --output out.wav --threshold -60 --duration 1.0
```

## Dependencies

- `ffmpeg` (4.0+) — audio processing engine
- `bash` (4.0+) — script runtime
- `bc` — calculations (usually pre-installed)
