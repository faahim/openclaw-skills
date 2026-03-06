---
name: audio-splitter
description: >-
  Split audio files by silence detection, time intervals, or chapter markers using ffmpeg and sox.
categories: [media, automation]
dependencies: [ffmpeg, sox]
---

# Audio Splitter

## What This Does

Split audio files into segments automatically — by detecting silence, at fixed time intervals, or using embedded chapter markers. Perfect for chopping podcasts into chapters, splitting audiobooks, extracting individual tracks from live recordings, or preparing audio for upload.

**Example:** "Split a 2-hour podcast recording into segments wherever there's 1+ second of silence."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. Split by Silence

```bash
bash scripts/split.sh --input recording.mp3 --mode silence
# Output: output/recording_001.mp3, recording_002.mp3, ...
```

### 3. Split by Time

```bash
bash scripts/split.sh --input podcast.mp3 --mode time --interval 600
# Splits into 10-minute segments
```

## Core Workflows

### Workflow 1: Split by Silence Detection

**Use case:** Split a podcast/recording at natural pauses

```bash
bash scripts/split.sh \
  --input recording.mp3 \
  --mode silence \
  --min-silence 1.5 \
  --silence-thresh -40 \
  --output-dir ./chapters
```

**Parameters:**
- `--min-silence` — Minimum silence duration in seconds (default: 1.0)
- `--silence-thresh` — Silence threshold in dB (default: -35)
- `--min-segment` — Minimum segment length in seconds (default: 30)

**Output:**
```
[audio-splitter] Analyzing silence in recording.mp3...
[audio-splitter] Found 12 silence points
[audio-splitter] Splitting into 13 segments...
[audio-splitter] ✅ chapters/recording_001.mp3 (04:23)
[audio-splitter] ✅ chapters/recording_002.mp3 (06:11)
...
[audio-splitter] Done! 13 segments created in ./chapters/
```

### Workflow 2: Split by Fixed Time Intervals

**Use case:** Break a long file into equal chunks

```bash
bash scripts/split.sh \
  --input audiobook.mp3 \
  --mode time \
  --interval 1800 \
  --output-dir ./parts
```

**Output:** 30-minute segments (1800 seconds each)

### Workflow 3: Split by Chapter Markers

**Use case:** Extract chapters from files with embedded metadata (M4B, MP3 with chapters)

```bash
bash scripts/split.sh \
  --input audiobook.m4b \
  --mode chapters \
  --output-dir ./chapters \
  --format mp3
```

**Output:** One file per chapter, named by chapter title

### Workflow 4: Split at Specific Timestamps

**Use case:** Cut specific segments from a file

```bash
bash scripts/split.sh \
  --input interview.mp3 \
  --mode timestamps \
  --timestamps "0:00,5:30,12:45,25:00,40:15" \
  --output-dir ./segments
```

### Workflow 5: Batch Split Multiple Files

**Use case:** Process an entire directory of recordings

```bash
bash scripts/split.sh \
  --input-dir ./recordings/ \
  --mode silence \
  --output-dir ./split-output/ \
  --format mp3
```

## Configuration

### Environment Variables

```bash
# Default output format (mp3, wav, flac, ogg, m4a)
export AUDIO_SPLITTER_FORMAT="mp3"

# Default MP3 bitrate
export AUDIO_SPLITTER_BITRATE="192k"

# Default silence detection threshold (dB)
export AUDIO_SPLITTER_SILENCE_THRESH="-35"

# Default minimum silence duration (seconds)
export AUDIO_SPLITTER_MIN_SILENCE="1.0"

# Default minimum segment length (seconds)
export AUDIO_SPLITTER_MIN_SEGMENT="30"
```

### Supported Formats

**Input:** MP3, WAV, FLAC, OGG, M4A, M4B, AAC, WMA, AIFF, OPUS
**Output:** MP3, WAV, FLAC, OGG, M4A

## Advanced Usage

### Silence Detection with Preview

```bash
# Preview silence points without splitting
bash scripts/split.sh --input file.mp3 --mode silence --dry-run
```

**Output:**
```
[audio-splitter] Silence points detected:
  1. 04:23.150 - 04:25.200 (2.05s)
  2. 10:34.800 - 10:36.100 (1.30s)
  3. 15:12.500 - 15:14.900 (2.40s)
...
Would split into 4 segments. Use without --dry-run to execute.
```

### Custom Output Naming

```bash
bash scripts/split.sh \
  --input podcast.mp3 \
  --mode time \
  --interval 600 \
  --prefix "episode42" \
  --output-dir ./parts
# Output: episode42_001.mp3, episode42_002.mp3, ...
```

### Convert Format While Splitting

```bash
bash scripts/split.sh \
  --input recording.wav \
  --mode silence \
  --format mp3 \
  --bitrate 320k
```

### Fade In/Out Between Segments

```bash
bash scripts/split.sh \
  --input podcast.mp3 \
  --mode silence \
  --fade 0.5
# Adds 0.5s fade-in and fade-out to each segment
```

## Troubleshooting

### Issue: "ffmpeg: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
# Ubuntu/Debian: sudo apt-get install ffmpeg sox
# Mac: brew install ffmpeg sox
# Fedora: sudo dnf install ffmpeg sox
```

### Issue: No silence points detected

**Fix:** Lower the silence threshold:
```bash
bash scripts/split.sh --input file.mp3 --mode silence --silence-thresh -50
```

### Issue: Too many tiny segments

**Fix:** Increase minimum segment length:
```bash
bash scripts/split.sh --input file.mp3 --mode silence --min-segment 60
```

### Issue: Splits happening mid-speech

**Fix:** Increase minimum silence duration:
```bash
bash scripts/split.sh --input file.mp3 --mode silence --min-silence 2.0
```

## Dependencies

- `ffmpeg` (4.0+) — Audio processing and format conversion
- `sox` (14.0+) — Silence detection
- `bash` (4.0+)
- `bc` — Floating point math
- Optional: `jq` — JSON chapter parsing
