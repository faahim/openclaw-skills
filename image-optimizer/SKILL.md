---
name: image-optimizer
description: >-
  Batch optimize images for web — compress, resize, convert to WebP/AVIF, strip metadata. Saves 50-80% file size.
categories: [media, automation]
dependencies: [imagemagick, cwebp, avifenc]
---

# Image Optimizer

## What This Does

Batch compress, resize, and convert images to modern formats (WebP, AVIF) with zero quality loss visible to the human eye. Strips EXIF metadata, generates responsive sizes, and outputs a summary report. Typical savings: 50-80% file size reduction.

**Example:** "Optimize all PNGs in `./assets/` — convert to WebP, resize to max 1920px wide, compress to quality 85."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. Optimize a Single Image

```bash
bash scripts/optimize.sh --input photo.jpg --output optimized/ --format webp --quality 85
```

### 3. Batch Optimize a Directory

```bash
bash scripts/optimize.sh --input ./images/ --output ./optimized/ --format webp --quality 85 --max-width 1920
```

## Core Workflows

### Workflow 1: Compress for Web (Most Common)

Convert images to WebP at quality 85 with max width 1920px:

```bash
bash scripts/optimize.sh \
  --input ./images/ \
  --output ./web-ready/ \
  --format webp \
  --quality 85 \
  --max-width 1920 \
  --strip-metadata
```

**Output:**
```
Processing 24 images...
[1/24] hero.png (2.4MB) → hero.webp (340KB) — saved 86%
[2/24] team.jpg (1.8MB) → team.webp (290KB) — saved 84%
...
✅ Done! 24 images optimized.
   Total: 38.2MB → 7.1MB (saved 81%)
   Report: ./web-ready/optimization-report.txt
```

### Workflow 2: Generate Responsive Sizes

Create multiple sizes for srcset:

```bash
bash scripts/optimize.sh \
  --input ./images/ \
  --output ./responsive/ \
  --format webp \
  --quality 85 \
  --responsive 480,768,1024,1920
```

**Output structure:**
```
responsive/
├── hero-480w.webp
├── hero-768w.webp
├── hero-1024w.webp
├── hero-1920w.webp
└── optimization-report.txt
```

### Workflow 3: Convert to AVIF (Maximum Compression)

AVIF offers ~20% better compression than WebP:

```bash
bash scripts/optimize.sh \
  --input ./images/ \
  --output ./avif/ \
  --format avif \
  --quality 80
```

### Workflow 4: Compress In-Place (Overwrite Originals)

```bash
bash scripts/optimize.sh \
  --input ./images/ \
  --inplace \
  --quality 85 \
  --strip-metadata
```

### Workflow 5: PNG Optimization (Lossless)

Lossless PNG crush — reduce size without any quality loss:

```bash
bash scripts/optimize.sh \
  --input ./icons/ \
  --output ./icons-optimized/ \
  --format png \
  --lossless
```

## Configuration

### All Options

| Flag | Default | Description |
|------|---------|-------------|
| `--input` | (required) | Input file or directory |
| `--output` | `./optimized/` | Output directory |
| `--format` | `webp` | Output format: `webp`, `avif`, `jpg`, `png`, `original` |
| `--quality` | `85` | Quality 1-100 (ignored for lossless) |
| `--max-width` | (none) | Max width in pixels (maintains aspect ratio) |
| `--max-height` | (none) | Max height in pixels |
| `--responsive` | (none) | Comma-separated widths for responsive images |
| `--strip-metadata` | `false` | Remove EXIF/metadata |
| `--lossless` | `false` | Lossless compression (PNG only) |
| `--inplace` | `false` | Overwrite originals |
| `--recursive` | `true` | Process subdirectories |
| `--dry-run` | `false` | Show what would be done without doing it |
| `--report` | `true` | Generate optimization report |

### Supported Input Formats

JPG, JPEG, PNG, GIF, BMP, TIFF, SVG, WebP, AVIF

## Troubleshooting

### "convert: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install imagemagick

# Mac
brew install imagemagick
```

### "cwebp: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install webp

# Mac
brew install webp
```

### "avifenc: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install libavif-bin

# Mac
brew install libavif
```

### Images look blurry after optimization

Increase quality: `--quality 90` or `--quality 95`. Default 85 is good for photos; use 90+ for text-heavy images.

### Large GIFs not converting well

GIFs with animation won't convert properly. Use `--format original` to keep them as-is, or use ffmpeg to convert to video.

## Key Principles

1. **No visible quality loss** at default settings (quality 85)
2. **Preserve originals** unless `--inplace` is used
3. **Detailed reporting** — know exactly what was saved
4. **Parallel processing** — uses all CPU cores for speed
5. **Smart format detection** — won't convert if output would be larger
