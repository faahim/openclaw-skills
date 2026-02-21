# Listing Copy: Image Optimizer

## Metadata
- **Type:** Skill
- **Name:** image-optimizer
- **Display Name:** Image Optimizer
- **Categories:** [media, automation]
- **Price:** $10
- **Dependencies:** [imagemagick, cwebp, avifenc]

## Tagline

Batch optimize images for web — compress, resize, convert to WebP/AVIF, save 50-80% file size.

## Description

Images are the #1 cause of slow websites. Manually optimizing them one-by-one in Photoshop or Squoosh is tedious, and most developers skip it entirely. The result: bloated pages that tank Core Web Vitals and lose visitors.

Image Optimizer handles all of it in one command. Point it at a directory, and it compresses, resizes, converts to modern formats (WebP, AVIF), and strips metadata — automatically. It uses native tools (ImageMagick, cwebp, avifenc) for maximum quality and speed, processes files in parallel, and generates a detailed savings report.

**What it does:**
- 🖼️ Batch process entire directories of images
- 🔄 Convert to WebP or AVIF (50-80% smaller than JPEG/PNG)
- 📐 Resize to max dimensions while preserving aspect ratio
- 📱 Generate responsive sizes (480w, 768w, 1024w, 1920w)
- 🧹 Strip EXIF metadata for privacy and size
- 📊 Detailed optimization report with per-file savings
- ⚡ Parallel processing — uses all CPU cores
- 🛡️ Smart detection — won't save if output would be larger

Perfect for developers, designers, and anyone publishing images to the web.

## Quick Start Preview

```bash
bash scripts/optimize.sh --input ./images/ --output ./web-ready/ --format webp --quality 85
# [1/24] hero.png (2.4MB) → hero.webp (340KB) — saved 86%
# ✅ Done! 24 images. 38.2MB → 7.1MB (saved 81%)
```

## Core Capabilities

1. WebP conversion — Modern format, 25-35% smaller than JPEG at same quality
2. AVIF conversion — Next-gen format, 20% smaller than WebP
3. Batch processing — Process hundreds of images in one command
4. Responsive sizes — Generate srcset-ready images at multiple widths
5. Lossless PNG crush — Reduce PNG size without any quality loss
6. EXIF stripping — Remove metadata for privacy and smaller files
7. Quality control — Configurable 1-100 quality with sensible defaults
8. Smart skipping — Won't convert if output would be larger than input
9. In-place mode — Overwrite originals when you're sure
10. Dry run — Preview what would happen before committing

## Dependencies
- ImageMagick (`convert`)
- WebP tools (`cwebp`)
- AVIF tools (`avifenc`) — optional

## Installation Time
**2 minutes** — run install.sh, start optimizing
