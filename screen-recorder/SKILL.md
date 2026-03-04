---
name: screen-recorder
description: >-
  Record your screen to video or GIF from the terminal using ffmpeg. Supports area selection, audio capture, webcam overlay, and format conversion.
categories: [media, automation]
dependencies: [ffmpeg, xdpyinfo]
---

# Screen Recorder

## What This Does

Record your screen directly from the terminal — full screen, specific windows, or custom regions. Output as MP4, WebM, MKV, or animated GIF. Optionally capture system audio and microphone. No GUI needed.

**Example:** "Record a 60-second demo of my app, output as MP4 with audio, then generate a GIF preview."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Check if ffmpeg is installed
which ffmpeg || echo "Install ffmpeg first"

# Ubuntu/Debian
sudo apt-get install -y ffmpeg x11-utils

# Fedora
sudo dnf install -y ffmpeg xdpyinfo

# Mac (uses AVFoundation instead of x11grab)
brew install ffmpeg
```

### 2. Record Full Screen (30 seconds)

```bash
bash scripts/record.sh --duration 30 --output demo.mp4
```

### 3. Record a Region

```bash
bash scripts/record.sh --region 1920x1080+0+0 --duration 60 --output region.mp4
```

## Core Workflows

### Workflow 1: Full Screen Recording

```bash
bash scripts/record.sh \
  --duration 120 \
  --output fullscreen.mp4 \
  --fps 30

# Output:
# 🎬 Recording started (full screen, 1920x1080)
# ⏱️  Duration: 120s | FPS: 30 | Format: mp4
# ✅ Saved to fullscreen.mp4 (45.2 MB)
```

### Workflow 2: Record with Audio

```bash
bash scripts/record.sh \
  --duration 60 \
  --audio pulse \
  --output with-audio.mp4

# Captures system audio via PulseAudio
```

### Workflow 3: Convert Recording to GIF

```bash
bash scripts/record.sh --to-gif recording.mp4 --output demo.gif --width 640 --fps 10

# Output:
# 🔄 Converting recording.mp4 → demo.gif
# 📐 Width: 640px | FPS: 10
# ✅ Saved to demo.gif (8.3 MB)
```

### Workflow 4: Record Specific Window (Linux/X11)

```bash
# Get window ID by clicking on it
bash scripts/record.sh --pick-window --duration 30 --output window.mp4
```

### Workflow 5: Record with Webcam Overlay

```bash
bash scripts/record.sh \
  --duration 60 \
  --webcam /dev/video0 \
  --webcam-size 320x240 \
  --webcam-position bottom-right \
  --output with-webcam.mp4
```

### Workflow 6: Compress Existing Recording

```bash
bash scripts/record.sh --compress input.mp4 --output compressed.mp4 --crf 28

# Output:
# 🗜️  Compressing input.mp4 (120 MB)
# ✅ Saved to compressed.mp4 (34 MB) — 72% reduction
```

### Workflow 7: Extract Clip from Recording

```bash
bash scripts/record.sh --clip input.mp4 --start 00:01:30 --end 00:02:45 --output clip.mp4
```

## Configuration

### Environment Variables

```bash
# Default display (Linux/X11)
export DISPLAY=":0"

# Default audio device (Linux PulseAudio)
export SCREEN_REC_AUDIO_DEVICE="default"

# Default output directory
export SCREEN_REC_OUTPUT_DIR="$HOME/recordings"

# Default format
export SCREEN_REC_FORMAT="mp4"

# Default FPS
export SCREEN_REC_FPS="30"
```

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--duration N` | Record for N seconds | Until Ctrl+C |
| `--output FILE` | Output file path | `recording_TIMESTAMP.mp4` |
| `--fps N` | Frames per second | 30 |
| `--region WxH+X+Y` | Record specific region | Full screen |
| `--audio DEVICE` | Capture audio (pulse/alsa) | No audio |
| `--mic DEVICE` | Capture microphone | No mic |
| `--format FMT` | Output format (mp4/webm/mkv/avi) | mp4 |
| `--crf N` | Quality (0=lossless, 51=worst) | 23 |
| `--pick-window` | Click to select window | - |
| `--webcam DEV` | Add webcam overlay | - |
| `--webcam-size WxH` | Webcam overlay size | 320x240 |
| `--webcam-position POS` | Overlay position (top-left/top-right/bottom-left/bottom-right) | bottom-right |
| `--to-gif FILE` | Convert video to GIF | - |
| `--compress FILE` | Compress a video file | - |
| `--clip FILE` | Extract clip from video | - |
| `--start HH:MM:SS` | Clip start time | 00:00:00 |
| `--end HH:MM:SS` | Clip end time | End of file |
| `--width N` | GIF width (pixels) | 480 |
| `--no-cursor` | Hide mouse cursor | Show cursor |

## Advanced Usage

### Scheduled Recording

```bash
# Record at specific time via cron
echo "30 14 * * * cd ~/recordings && bash /path/to/scripts/record.sh --duration 300 --output meeting.mp4" | crontab -
```

### Continuous Recording with Rotation

```bash
# Record in 10-minute segments
bash scripts/record.sh --duration 600 --output "segment_%03d.mp4" --segment 600
```

### macOS Support

On macOS, the script auto-detects and uses AVFoundation:

```bash
# List available devices
ffmpeg -f avfoundation -list_devices true -i "" 2>&1

# Record (auto-detected)
bash scripts/record.sh --duration 30 --output demo.mp4
```

## Troubleshooting

### Issue: "Cannot open display"

**Fix:** Ensure DISPLAY is set (Linux/X11):
```bash
export DISPLAY=:0
# Or for Wayland:
# This tool requires X11 or XWayland. Check: echo $XDG_SESSION_TYPE
```

### Issue: No audio in recording

**Fix:** Check PulseAudio:
```bash
pactl list short sources  # List audio devices
bash scripts/record.sh --audio "alsa_output.pci-0000_00_1f.3.analog-stereo.monitor" --duration 10 --output test.mp4
```

### Issue: Recording is choppy

**Fix:** Lower FPS or resolution:
```bash
bash scripts/record.sh --fps 15 --crf 28 --output smooth.mp4
```

### Issue: GIF is too large

**Fix:** Reduce width and FPS:
```bash
bash scripts/record.sh --to-gif input.mp4 --width 320 --fps 5 --output small.gif
```

## Dependencies

- `ffmpeg` (4.0+) — core recording & conversion engine
- `x11-utils` (Linux) — screen info via xdpyinfo
- `pulseaudio-utils` (optional) — audio capture on Linux
- `xdotool` (optional) — window selection

## Key Principles

1. **Zero config** — Works out of the box with sensible defaults
2. **Cross-platform** — Linux (X11) + macOS (AVFoundation)
3. **Composable** — Record → Compress → GIF in pipeline
4. **Lightweight** — Just bash + ffmpeg, no heavy frameworks
