# Listing Copy: Screen Recorder

## Metadata
- **Type:** Skill
- **Name:** screen-recorder
- **Display Name:** Screen Recorder
- **Categories:** [media, automation]
- **Icon:** 🎬
- **Dependencies:** [ffmpeg, x11-utils]

## Tagline

Record your screen to video or GIF — directly from the terminal

## Description

Manually setting up ffmpeg flags for screen recording is tedious and error-prone. You need to remember input formats, codec options, audio devices, and pixel formats every time. One wrong flag and you get a corrupted file or no output.

Screen Recorder wraps ffmpeg into a simple CLI that handles full-screen recording, region capture, audio, webcam overlays, and post-processing. Record demos, tutorials, or bug reports in seconds — then convert to GIF or compress for sharing.

**What it does:**
- 🎬 Record full screen or specific regions
- 🔊 Capture system audio and microphone
- 📷 Add webcam overlay (picture-in-picture)
- 🔄 Convert recordings to animated GIF with optimized palette
- 🗜️ Compress videos with configurable quality
- ✂️ Extract clips with precise timestamps
- 🖥️ Cross-platform: Linux (X11) + macOS (AVFoundation)
- ⚡ Zero-config defaults — works out of the box

Perfect for developers recording demos, sysadmins capturing issues, content creators making tutorials, or anyone who needs quick screen captures without a GUI app.

## Quick Start Preview

```bash
# Record 30 seconds of your screen
bash scripts/record.sh --duration 30 --output demo.mp4

# Convert to GIF for sharing
bash scripts/record.sh --to-gif demo.mp4 --width 640 --fps 10 --output demo.gif
```

## Core Capabilities

1. Full-screen recording — Capture entire display at configurable FPS
2. Region recording — Record specific screen area (WxH+X+Y)
3. Window recording — Click to select a window (Linux/xdotool)
4. Audio capture — System audio via PulseAudio/ALSA
5. Webcam overlay — Picture-in-picture with position control
6. GIF conversion — Two-pass palette optimization for quality
7. Video compression — Reduce file size with CRF control
8. Clip extraction — Cut segments with precise timestamps
9. Multiple formats — MP4, WebM, MKV, AVI output
10. Cross-platform — Linux X11 + macOS AVFoundation auto-detection
