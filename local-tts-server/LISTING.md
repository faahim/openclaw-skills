# Listing Copy: Local TTS Server

## Metadata
- **Type:** Skill
- **Name:** local-tts-server
- **Display Name:** Local TTS Server
- **Categories:** [media, automation]
- **Icon:** 🔊
- **Price:** $10
- **Dependencies:** [bash, curl, tar]

## Tagline

"Offline text-to-speech with Piper — Convert text to natural audio, no API keys needed"

## Description

Tired of paying per-character for cloud TTS APIs? Local TTS Server installs Piper — a fast, high-quality, neural text-to-speech engine — directly on your machine. No API keys, no cloud dependency, no per-request costs.

Local TTS Server handles everything: installing the Piper binary, downloading voice models (30+ languages), converting text files to WAV/MP3, batch processing entire directories, and even running a local HTTP API server. It runs entirely offline after setup.

**What it does:**
- 🔊 Convert text to natural-sounding speech (WAV/MP3)
- 🌍 30+ languages with dozens of voice models
- 📦 Batch convert directories of text files
- 🖥️ Optional HTTP API server for programmatic access
- ⚡ Fast inference — 500 words in under 5 seconds
- 🔒 Fully offline — no data leaves your machine
- 💰 Zero ongoing costs — one-time setup

Perfect for developers building voice features, content creators making audio versions of articles, or anyone who wants local TTS without the cloud dependency.

## Quick Start Preview

```bash
# Install Piper + default English voice
bash scripts/install.sh

# Convert text to speech
echo "Hello world!" | bash scripts/tts.sh > hello.wav

# Batch convert files
bash scripts/batch-tts.sh --input-dir ./texts/ --output-dir ./audio/ --format mp3
```

## Core Capabilities

1. One-command installation — Piper binary + voice model in 2 minutes
2. Text to WAV/MP3 — Pipe text or read from files
3. 30+ language support — English, German, French, Spanish, Chinese, Japanese, and more
4. Batch conversion — Convert entire directories of text files
5. Adjustable speech speed — 0.5x to 2.0x
6. Multiple quality tiers — Low (fast), Medium (balanced), High (natural)
7. HTTP API server — Local REST endpoint for programmatic access
8. Stdin piping — Integrate with any CLI tool
9. Offline operation — No internet needed after initial setup
10. Cross-platform — Linux x86_64, ARM64, ARMv7

## Dependencies
- `bash` (4.0+)
- `curl` (for initial download)
- `tar` (for extraction)
- Optional: `ffmpeg` (MP3 conversion), `socat` (HTTP server)

## Installation Time
**2-3 minutes** — Download binary + voice model

## Pricing Justification

**Why $10:**
- Replaces cloud TTS APIs ($4-16 per million characters)
- One-time cost, unlimited usage
- Includes multi-language support, batch processing, HTTP server
- Comparable local TTS setup guides sell for $15-25
