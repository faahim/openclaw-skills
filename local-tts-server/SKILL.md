---
name: local-tts-server
description: >-
  Install and run a local text-to-speech engine using Piper TTS. Convert text to natural-sounding audio files offline — no API keys, no cloud, no costs.
categories: [media, automation]
dependencies: [bash, curl, tar, aplay]
---

# Local TTS Server

## What This Does

Installs Piper TTS — a fast, high-quality, offline text-to-speech engine — and provides scripts to convert text to WAV/MP3 audio files. No API keys needed, no cloud dependency, runs entirely on your machine. Supports 30+ languages with dozens of voice models.

**Example:** "Convert a 500-word blog post to a natural-sounding MP3 in under 5 seconds."

## Quick Start (5 minutes)

### 1. Install Piper

```bash
bash scripts/install.sh
```

This downloads the Piper binary and a default English voice model (~50MB total).

### 2. Convert Text to Speech

```bash
# Simple text
echo "Hello, this is a test of the local TTS server." | bash scripts/tts.sh > output.wav

# From a file
bash scripts/tts.sh --input article.txt --output article.wav

# To MP3 (requires ffmpeg)
bash scripts/tts.sh --input article.txt --output article.mp3
```

### 3. List Available Voices

```bash
bash scripts/tts.sh --list-voices
```

### 4. Change Voice

```bash
# Download a new voice
bash scripts/install-voice.sh en_US-lessac-medium

# Use it
bash scripts/tts.sh --voice en_US-lessac-medium --input text.txt --output speech.wav
```

## Core Workflows

### Workflow 1: Convert Text to Audio File

**Use case:** Turn articles, blog posts, or notes into listenable audio

```bash
bash scripts/tts.sh --input mypost.txt --output mypost.wav
# [✓] Generated mypost.wav (42.3s, 1.4MB) in 3.2s
```

### Workflow 2: Batch Convert Multiple Files

**Use case:** Convert a directory of text files to audio

```bash
bash scripts/batch-tts.sh --input-dir ./texts/ --output-dir ./audio/ --format mp3
# [✓] Converted 12 files in 28.4s
# [✓] Output: ./audio/file1.mp3, ./audio/file2.mp3, ...
```

### Workflow 3: Pipe Text from Other Commands

**Use case:** Integrate with other tools

```bash
# Read a man page aloud
man ls | col -b | head -50 | bash scripts/tts.sh > ls-manual.wav

# Read clipboard
xclip -selection clipboard -o | bash scripts/tts.sh > clipboard.wav

# Speak a notification
echo "Build complete!" | bash scripts/tts.sh | aplay
```

### Workflow 4: Multi-Language Support

**Use case:** Generate speech in other languages

```bash
# Install German voice
bash scripts/install-voice.sh de_DE-thorsten-medium

# Generate German speech
echo "Hallo Welt, wie geht es Ihnen?" | bash scripts/tts.sh --voice de_DE-thorsten-medium > german.wav

# Install French voice
bash scripts/install-voice.sh fr_FR-siwis-medium
echo "Bonjour le monde!" | bash scripts/tts.sh --voice fr_FR-siwis-medium > french.wav
```

### Workflow 5: Adjust Speech Speed and Quality

```bash
# Slower speech (0.5-2.0, default 1.0)
bash scripts/tts.sh --speed 0.8 --input text.txt --output slow.wav

# Use high-quality model
bash scripts/install-voice.sh en_US-lessac-high
bash scripts/tts.sh --voice en_US-lessac-high --input text.txt --output hq.wav
```

## Configuration

### Environment Variables

```bash
# Default voice (set in ~/.bashrc or ~/.openclaw/env)
export PIPER_VOICE="en_US-lessac-medium"

# Piper install directory
export PIPER_HOME="$HOME/.local/share/piper"

# Default output format (wav or mp3)
export PIPER_FORMAT="wav"
```

### Voice Models

Piper supports 30+ languages. Popular voices:

| Voice | Language | Quality | Size |
|-------|----------|---------|------|
| `en_US-lessac-medium` | English (US) | ★★★★ | 65MB |
| `en_US-lessac-high` | English (US) | ★★★★★ | 105MB |
| `en_GB-alba-medium` | English (UK) | ★★★★ | 65MB |
| `de_DE-thorsten-medium` | German | ★★★★ | 65MB |
| `fr_FR-siwis-medium` | French | ★★★★ | 65MB |
| `es_ES-davefx-medium` | Spanish | ★★★★ | 65MB |
| `zh_CN-huayan-medium` | Chinese | ★★★ | 65MB |
| `ja_JP-kokoro-medium` | Japanese | ★★★ | 65MB |

Full list: https://github.com/rhasspy/piper/blob/master/VOICES.md

## Advanced Usage

### Run as HTTP Server

```bash
# Start a local TTS API server on port 5000
bash scripts/tts-server.sh --port 5000 &

# Use the API
curl -X POST http://localhost:5000/tts \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello world", "voice": "en_US-lessac-medium"}' \
  --output speech.wav
```

### Integration with OpenClaw Cron

```bash
# Daily news briefing TTS
# Add to your OpenClaw cron:
# 1. Fetch news summary
# 2. Convert to audio
# 3. Send via Telegram

bash scripts/tts.sh --input /tmp/news-summary.txt --output /tmp/briefing.mp3
```

### SSML Support (Basic)

```bash
# Add pauses
echo 'Hello. <break time="1s"/> How are you today?' | bash scripts/tts.sh > with-pause.wav
```

## Troubleshooting

### Issue: "piper: command not found"

**Fix:** Run the installer again
```bash
bash scripts/install.sh
# Or add to PATH manually:
export PATH="$HOME/.local/share/piper:$PATH"
```

### Issue: "No voice model found"

**Fix:** Install a voice model
```bash
bash scripts/install-voice.sh en_US-lessac-medium
```

### Issue: MP3 output not working

**Fix:** Install ffmpeg
```bash
# Ubuntu/Debian
sudo apt-get install ffmpeg
# Mac
brew install ffmpeg
```

### Issue: Audio sounds robotic

**Fix:** Use a higher quality model
```bash
bash scripts/install-voice.sh en_US-lessac-high
# "high" models sound much better than "low" or "medium"
```

### Issue: Slow on Raspberry Pi / ARM

Piper is optimized for ARM. If still slow:
```bash
# Use a "low" quality model (faster inference)
bash scripts/install-voice.sh en_US-lessac-low
```

## Dependencies

- `bash` (4.0+)
- `curl` (downloading models)
- `tar` (extracting archives)
- Optional: `ffmpeg` (MP3 conversion)
- Optional: `aplay`/`sox` (direct audio playback)

## System Requirements

- **Disk:** ~50MB for Piper + 65-105MB per voice model
- **RAM:** ~200MB during inference
- **CPU:** Any modern x86_64 or aarch64 processor
- **OS:** Linux (x86_64, aarch64), macOS (experimental)
