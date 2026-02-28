# Listing Copy: ASCII Art Generator

## Metadata
- **Type:** Skill
- **Name:** ascii-art-generator
- **Display Name:** ASCII Art Generator
- **Categories:** [fun, media]
- **Price:** $5
- **Dependencies:** [figlet, toilet, jp2a, imagemagick]

## Tagline

Generate ASCII art from text and images — banners, styled text, and image-to-ASCII conversion

## Description

Want to create eye-catching text banners for your terminal, server MOTD, or just for fun? Manually crafting ASCII art is tedious and limited to whatever you can type.

ASCII Art Generator installs and wraps four powerful tools — figlet (100+ fonts for text banners), toilet (colorized/styled text with metal, rainbow, and border effects), jp2a (image-to-ASCII conversion), and ImageMagick (image preprocessing). One script, multiple creative workflows.

**What it does:**
- 🔤 Generate text banners with 100+ figlet fonts
- 🎨 Create styled text with color filters (metal, rainbow, border)
- 🖼️ Convert images (JPEG, PNG, GIF, WebP) to ASCII art
- 📦 Batch process: multiple banners or entire image directories
- 🎲 Random font/style mode for creative exploration
- 💾 Save output to files or pipe to other tools

Perfect for developers who want cool terminal banners, sysadmins setting up server MOTDs, or anyone who enjoys creative terminal art.

## Quick Start Preview

```bash
# Install all tools
bash scripts/install.sh

# Text banner
bash scripts/run.sh banner "DEPLOY" --font slant

# Styled rainbow text
bash scripts/run.sh style "PARTY" --filter gay

# Image to ASCII
bash scripts/run.sh image photo.jpg --width 80
```

## Core Capabilities

1. Text banners — 100+ figlet fonts (slant, banner, big, shadow, script, etc.)
2. Styled text — Colorized output with toilet filters (metal, gay, border, flip)
3. Image conversion — JPEG/PNG/GIF/WebP to ASCII via jp2a
4. URL support — Convert images directly from URLs
5. Image enhancement — Contrast boost and grayscale preprocessing
6. Batch processing — Process word lists or image directories
7. Random mode — Discover new fonts and styles randomly
8. Pipe-friendly — Works with stdin/stdout for scripting
9. MOTD ready — Generate server login banners
10. Cross-platform — Works on Linux (apt/dnf/pacman/apk) and macOS (brew)

## Dependencies
- `figlet` — Text banners
- `toilet` — Styled/colorized text
- `jp2a` — Image to ASCII
- `imagemagick` — Image preprocessing
- `curl` — URL image download

## Installation Time
**2 minutes** — Run install.sh, start creating
