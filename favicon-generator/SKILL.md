---
name: favicon-generator
description: >-
  Generate all favicon sizes and formats from a single source image. Outputs ICO, PNG, Apple Touch Icon, Android Chrome icons, and browserconfig tile — plus a ready-to-paste HTML snippet.
categories: [design, dev-tools]
dependencies: [imagemagick, bash]
---

# Favicon Generator

## What This Does

Takes a single high-resolution image (PNG, SVG, or JPG) and generates every favicon format a modern website needs: ICO (multi-size), Apple Touch Icons, Android Chrome icons, MS tile images, and a manifest.json. Outputs a copy-paste HTML snippet for your `<head>`.

**Example:** "Give me `logo.png`, get back 15 optimized favicon files + HTML + manifest.json — ready to drop into any project."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Check for ImageMagick (required)
which convert identify || echo "Install ImageMagick: sudo apt install imagemagick / brew install imagemagick"

# Optional: SVG support
which rsvg-convert || echo "For SVG input: sudo apt install librsvg2-bin / brew install librsvg2"
```

### 2. Generate Favicons

```bash
# From a PNG/JPG source (at least 512x512 recommended)
bash scripts/generate.sh --input logo.png --output ./favicons

# From SVG (best quality)
bash scripts/generate.sh --input logo.svg --output ./favicons

# With custom background color (for transparent PNGs on MS tiles)
bash scripts/generate.sh --input logo.png --output ./favicons --bg "#ffffff"
```

### 3. Check Output

```
favicons/
├── favicon.ico              (16x16 + 32x32 + 48x48 multi-size)
├── favicon-16x16.png
├── favicon-32x32.png
├── favicon-48x48.png
├── apple-touch-icon.png     (180x180)
├── apple-touch-icon-120x120.png
├── apple-touch-icon-152x152.png
├── apple-touch-icon-167x167.png
├── android-chrome-192x192.png
├── android-chrome-512x512.png
├── mstile-70x70.png
├── mstile-150x150.png
├── mstile-310x310.png
├── mstile-310x150.png       (wide tile)
├── site.webmanifest
├── browserconfig.xml
└── HEAD-SNIPPET.html         (copy-paste into <head>)
```

## Core Workflows

### Workflow 1: Full Favicon Set (Default)

**Use case:** Generate everything for a new website

```bash
bash scripts/generate.sh --input logo.png --output ./favicons
```

**Output includes:**
- ICO (multi-resolution)
- PNGs for all standard sizes
- Apple Touch Icons (all iOS sizes)
- Android Chrome icons
- MS tile images
- `site.webmanifest` for PWA
- `browserconfig.xml` for Windows
- `HEAD-SNIPPET.html` with ready HTML

### Workflow 2: Minimal Set (Just ICO + Apple)

**Use case:** Quick favicon for a simple site

```bash
bash scripts/generate.sh --input logo.png --output ./favicons --minimal
```

**Generates only:**
- `favicon.ico` (16+32+48)
- `apple-touch-icon.png` (180x180)
- `favicon-32x32.png`
- `HEAD-SNIPPET.html`

### Workflow 3: PWA Icons Only

**Use case:** Adding to existing PWA project

```bash
bash scripts/generate.sh --input logo.png --output ./favicons --pwa-only
```

**Generates:**
- `android-chrome-192x192.png`
- `android-chrome-512x512.png`
- Maskable icon variant (with safe zone padding)
- `site.webmanifest`

### Workflow 4: SVG Source (Best Quality)

**Use case:** Vector logo → pixel-perfect at every size

```bash
bash scripts/generate.sh --input logo.svg --output ./favicons
```

SVG is rasterized at each target size for maximum sharpness (no upscaling artifacts).

## Configuration

### Command Line Options

```
--input FILE        Source image (PNG, JPG, SVG) — 512x512+ recommended
--output DIR        Output directory (created if missing)
--bg COLOR          Background color for transparent images (default: transparent)
                    Used for MS tiles and ICO. Hex format: "#ffffff"
--minimal           Only generate ICO + Apple Touch + 32x32 PNG
--pwa-only          Only generate PWA/Android Chrome icons + manifest
--no-manifest       Skip site.webmanifest generation
--no-browserconfig  Skip browserconfig.xml generation
--site-name NAME    Site name for manifest.json (default: "My Website")
--theme-color HEX   Theme color for manifest (default: "#ffffff")
--prefix PATH       URL prefix for icon paths in HTML snippet (default: "/")
```

### Environment Variables

```bash
# Override ImageMagick binary (for custom installs)
export MAGICK_BIN="/usr/local/bin/magick"

# SVG rasterizer (default: rsvg-convert, fallback: ImageMagick)
export SVG_RASTERIZER="rsvg-convert"
```

## Advanced Usage

### Custom Size Set

Edit `scripts/sizes.conf` to add/remove sizes:

```bash
# Format: filename width height [crop_mode]
# crop_mode: center (default), north, south, east, west
favicon-16x16.png 16 16
favicon-32x32.png 32 32
custom-64x64.png 64 64
```

### Batch Processing (Multiple Projects)

```bash
for logo in projects/*/logo.png; do
  project=$(dirname "$logo")
  bash scripts/generate.sh --input "$logo" --output "$project/favicons"
  echo "✅ Generated favicons for $project"
done
```

### Integration with Build Tools

```bash
# Add to package.json scripts
# "generate:favicons": "bash path/to/scripts/generate.sh --input src/logo.svg --output public/"

# Or as a git pre-commit hook
# scripts/generate.sh --input assets/logo.svg --output public/ --minimal
```

## Troubleshooting

### Issue: "convert: command not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install imagemagick

# macOS
brew install imagemagick

# Verify
convert --version
```

### Issue: Poor quality at small sizes (blurry 16x16)

**Fix:** Use SVG as source, or use a 1024x1024+ PNG. The script applies sharpening for small sizes automatically.

### Issue: SVG not rendering correctly

**Fix:**
```bash
# Install librsvg2 for better SVG support
sudo apt-get install librsvg2-bin  # Ubuntu/Debian
brew install librsvg2               # macOS
```

### Issue: "not authorized" error with ImageMagick

**Fix:** ImageMagick 7 security policy may block certain operations:
```bash
# Edit policy (Ubuntu/Debian)
sudo sed -i 's/rights="none" pattern="@\*"/rights="read|write" pattern="@*"/' /etc/ImageMagick-6/policy.xml
```

## Key Principles

1. **Source quality matters** — Use 512x512+ PNG or SVG for best results
2. **Sharpening for small sizes** — Auto-applied to 16x16 and 32x32 to prevent blur
3. **Transparent backgrounds preserved** — Except for ICO and MS tiles (configurable)
4. **Standards-compliant** — Follows current browser/platform requirements (2025+)
5. **Copy-paste ready** — HEAD-SNIPPET.html goes straight into your HTML

## Dependencies

- `bash` (4.0+)
- `imagemagick` (6.9+ or 7.x) — core image processing
- Optional: `librsvg2-bin` / `librsvg2` — better SVG rasterization
