# Listing Copy: Favicon Generator

## Metadata
- **Type:** Skill
- **Name:** favicon-generator
- **Display Name:** Favicon Generator
- **Categories:** [design, dev-tools]
- **Icon:** 🎨
- **Dependencies:** [imagemagick, bash]

## Tagline

Generate all favicon sizes and formats from a single image — ICO, Apple Touch, Android Chrome, MS tiles

## Description

Every web project needs favicons, and every web project handles them poorly. You need a 16x16 ICO, a 180x180 Apple Touch Icon, 192 and 512 Android Chrome PNGs, MS tile images in four sizes, a web manifest, and a browserconfig.xml. Most developers either skip half of them or waste 30 minutes on a favicon generator website.

Favicon Generator takes one source image and produces every favicon format modern browsers and platforms expect — 15+ optimized files in seconds. It auto-sharpens small sizes to prevent blur, generates maskable PWA icons with proper safe zones, creates `site.webmanifest` and `browserconfig.xml`, and outputs a copy-paste HTML `<head>` snippet.

**What it does:**
- 🔷 Multi-resolution ICO (16 + 32 + 48px)
- 🍎 Apple Touch Icons (120, 152, 167, 180px)
- 🤖 Android Chrome icons with maskable variants
- 🪟 MS tile images (70, 150, 310, 310x150 wide)
- 📋 site.webmanifest + browserconfig.xml
- 📝 Ready-to-paste HTML `<head>` snippet
- ✂️ Minimal mode (ICO + Apple + 32px only)
- 📱 PWA-only mode for existing projects
- 🖼️ SVG input for pixel-perfect output at every size
- ⚡ Batch processing for multiple projects

Perfect for developers, designers, and anyone shipping websites who doesn't want to think about favicons ever again.

## Quick Start Preview

```bash
bash scripts/generate.sh --input logo.png --output ./favicons

# Output: 15+ files including favicon.ico, apple-touch-icon.png,
# android-chrome-512x512.png, site.webmanifest, HEAD-SNIPPET.html
```

## Dependencies
- `bash` (4.0+)
- `imagemagick` (6.9+ or 7.x)
- Optional: `librsvg2` for SVG input

## Installation Time
**2 minutes** — Install ImageMagick if missing, run script
