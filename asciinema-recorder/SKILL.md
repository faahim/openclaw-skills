---
name: asciinema-recorder
description: >-
  Record, manage, and share terminal sessions as lightweight asciicasts.
  Perfect for demos, documentation, and tutorials.
categories: [dev-tools, media]
dependencies: [asciinema, curl]
---

# Asciinema Terminal Recorder

## What This Does

Record your terminal sessions as lightweight asciicast files — replayable in browsers, embeddable in docs, shareable via asciinema.org. No video encoding, no huge files — just text-based recordings that capture every keystroke and output.

**Example:** "Record a 5-minute demo of deploying an app, upload to asciinema.org, get an embeddable link for your README."

## Quick Start (3 minutes)

### 1. Install Asciinema

```bash
bash scripts/install.sh
```

### 2. Record a Session

```bash
bash scripts/run.sh record --title "My Demo" --output demo.cast
# Type commands in the new shell, then exit (Ctrl+D or `exit`)
```

### 3. Play It Back

```bash
bash scripts/run.sh play demo.cast
```

### 4. Upload & Share

```bash
bash scripts/run.sh upload demo.cast
# Returns: https://asciinema.org/a/123456
```

## Core Workflows

### Workflow 1: Record a Terminal Session

**Use case:** Capture a demo, tutorial, or debugging session.

```bash
bash scripts/run.sh record \
  --title "Deploy to Production" \
  --idle-limit 2 \
  --output deploy-demo.cast
```

**Options:**
- `--title` — Title shown on asciinema.org
- `--idle-limit <seconds>` — Cap idle time (removes long pauses)
- `--output <file>` — Save to file (default: timestamped name)
- `--cols <N>` — Force terminal width
- `--rows <N>` — Force terminal height
- `--command "<cmd>"` — Record a specific command instead of interactive shell

### Workflow 2: Record a Specific Command

**Use case:** Record output of a single command/script.

```bash
bash scripts/run.sh record \
  --command "htop" \
  --title "System Monitor" \
  --idle-limit 1 \
  --output htop-demo.cast
```

### Workflow 3: Play Back Locally

**Use case:** Review a recording before uploading.

```bash
bash scripts/run.sh play demo.cast

# Speed controls:
bash scripts/run.sh play demo.cast --speed 2    # 2x speed
bash scripts/run.sh play demo.cast --speed 0.5  # Half speed
```

### Workflow 4: Upload to asciinema.org

**Use case:** Share a recording publicly or privately.

```bash
# Upload and get a link
bash scripts/run.sh upload demo.cast

# Output:
# ✅ Uploaded: https://asciinema.org/a/123456
# 📋 Embed: <script src="https://asciinema.org/a/123456.js" ...></script>
```

### Workflow 5: List Local Recordings

**Use case:** See all saved recordings.

```bash
bash scripts/run.sh list

# Output:
# FILE                     DURATION  TITLE              DATE
# deploy-demo.cast         02:34     Deploy to Prod     2026-02-28
# htop-demo.cast           00:45     System Monitor     2026-02-28
# debug-session.cast       05:12     Debug API Issue    2026-02-27
```

### Workflow 6: Convert to GIF

**Use case:** Create a GIF for README/docs (requires agg or svg-term).

```bash
bash scripts/run.sh gif demo.cast --output demo.gif

# Or SVG (sharper, smaller):
bash scripts/run.sh svg demo.cast --output demo.svg
```

### Workflow 7: Trim a Recording

**Use case:** Remove the beginning/end of a recording.

```bash
bash scripts/run.sh trim demo.cast \
  --start 5 \
  --end 120 \
  --output demo-trimmed.cast
```

## Configuration

### Environment Variables

```bash
# Asciinema.org auth (auto-set on first upload)
export ASCIINEMA_API_URL="https://asciinema.org"

# Default recording settings
export ASCIINEMA_REC_IDLE_LIMIT=2     # Max idle seconds
export ASCIINEMA_REC_COLS=120         # Terminal width
export ASCIINEMA_REC_ROWS=30          # Terminal height
```

### Config File

```bash
# ~/.config/asciinema/config
[record]
idle_time_limit = 2
cols = 120
rows = 30

[play]
speed = 1.0

[api]
url = https://asciinema.org
```

## Advanced Usage

### Embed in Markdown/HTML

After uploading, use the embed code:

```html
<!-- HTML embed -->
<script src="https://asciinema.org/a/123456.js" id="asciicast-123456" async></script>

<!-- Markdown (image link) -->
[![asciicast](https://asciinema.org/a/123456.svg)](https://asciinema.org/a/123456)
```

### Self-hosted Server

Point to your own asciinema server:

```bash
export ASCIINEMA_API_URL="https://asciinema.your-domain.com"
bash scripts/run.sh upload demo.cast
```

### Batch Record Multiple Commands

```bash
# Record a sequence of commands
bash scripts/run.sh record \
  --command "bash scripts/demo-sequence.sh" \
  --title "Full Setup Demo" \
  --output full-demo.cast
```

### Concatenate Recordings

```bash
bash scripts/run.sh concat \
  part1.cast part2.cast part3.cast \
  --output full-session.cast
```

## Troubleshooting

### Issue: "asciinema: command not found"

**Fix:** Run the install script:
```bash
bash scripts/install.sh
```

Or install manually:
```bash
# Ubuntu/Debian
sudo apt-get install asciinema

# macOS
brew install asciinema

# pip (any OS)
pip3 install asciinema
```

### Issue: Upload fails with auth error

**Fix:** Re-authenticate:
```bash
asciinema auth
# Opens browser to link your install ID to your account
```

### Issue: Recording looks wrong (wrong terminal size)

**Fix:** Set explicit dimensions:
```bash
bash scripts/run.sh record --cols 120 --rows 30 --output demo.cast
```

### Issue: GIF conversion fails

**Fix:** Install agg (asciinema gif generator):
```bash
# Download from https://github.com/asciinema/agg/releases
# Or build from source:
cargo install agg
```

## Dependencies

- `asciinema` (recording/playback — installed by scripts/install.sh)
- `curl` (for uploads)
- Optional: `agg` (GIF conversion)
- Optional: `svg-term-cli` (SVG conversion via npm)
