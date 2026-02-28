# Listing Copy: Asciinema Terminal Recorder

## Metadata
- **Type:** Skill
- **Name:** asciinema-recorder
- **Display Name:** Asciinema Terminal Recorder
- **Categories:** [dev-tools, media]
- **Icon:** 🎬
- **Dependencies:** [asciinema, curl, python3]

## Tagline

Record, replay, and share terminal sessions as lightweight asciicasts

## Description

Recording terminal sessions as video is overkill — huge files, lossy compression, no copy-paste. Asciinema captures terminal output as lightweight text-based recordings that play back perfectly in any browser.

**Asciinema Terminal Recorder** gives your OpenClaw agent full control over terminal recording: capture demos, trim dead time, upload to asciinema.org, convert to GIF/SVG for READMEs, and manage a local library of recordings.

**What it does:**
- 🎬 Record terminal sessions (interactive or single-command)
- ▶️ Play back recordings locally with speed control
- ⬆️ Upload to asciinema.org with embed code generation
- 🎞️ Convert to GIF (via agg) or SVG (via svg-term)
- ✂️ Trim recordings — remove dead time at start/end
- 🔗 Concatenate multiple recordings into one
- 📁 Manage local recording library
- ⚡ Auto-install on Ubuntu, macOS, Fedora, Arch, or pip

## Core Capabilities

1. Session recording — Capture any terminal session with configurable idle limits
2. Command recording — Record output of a specific command/script
3. Local playback — Replay recordings at 0.5x to 4x speed
4. Upload & share — Push to asciinema.org, get embeddable links
5. GIF conversion — Create animated GIFs for docs/READMEs via agg
6. SVG export — Sharper, smaller animated SVGs via svg-term
7. Recording trimming — Cut start/end of recordings with precision
8. Concatenation — Merge multiple recordings into one seamless file
9. Metadata inspection — View duration, dimensions, events, shell info
10. Cross-platform install — Auto-detects OS and installs via apt/brew/dnf/pacman/pip
