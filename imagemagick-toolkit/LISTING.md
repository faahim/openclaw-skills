# Listing Copy: ImageMagick Toolkit

## Metadata
- **Type:** Skill
- **Name:** imagemagick-toolkit
- **Display Name:** ImageMagick Toolkit
- **Categories:** [media, automation]
- **Icon:** 🖼️
- **Dependencies:** [imagemagick, bash]

## Tagline

Batch image processing — resize, watermark, convert, crop, and sprite in one toolkit

## Description

Manually resizing images, converting formats, and adding watermarks is tedious — especially when you're dealing with hundreds of files. You shouldn't need to open Photoshop or learn complex CLI flags to batch-process your images.

ImageMagick Toolkit wraps ImageMagick's power into simple, memorable commands. Resize an entire folder of photos in one line. Convert PNGs to WebP for web optimization. Add text or logo watermarks to protect your work. Generate thumbnail grids, create CSS sprite sheets, compare images for visual diffs, and strip metadata for privacy — all from your OpenClaw agent.

**What it does:**
- 🔄 Batch resize — width, height, percentage, or exact crop
- 🎨 Format convert — PNG, JPG, WebP, AVIF, TIFF, GIF, PDF→images
- 💧 Watermark — text or logo overlay with position/opacity control
- 📐 Smart crop — aspect ratio or geometry-based cropping
- 📋 Contact sheets — thumbnail grids from image directories
- 🧩 CSS sprites — combine icons into sprite + CSS
- 🔍 Image compare — visual diff with pixel count
- 🔒 Metadata strip — remove EXIF for privacy
- ⚡ Pipeline mode — chain resize + convert + watermark in one pass

Perfect for developers optimizing web assets, photographers batch-processing shoots, and anyone who needs fast, scriptable image manipulation without leaving the terminal.

## Quick Start Preview

```bash
# Resize all photos to 1200px wide, convert to WebP
bash scripts/run.sh pipeline --input ./photos --resize 1200 --format webp --output ./web

# Add watermark to all images
bash scripts/run.sh watermark --input ./photos --text "© 2026 MyBrand" --output ./marked
```

## Core Capabilities

1. Batch resize — process entire directories with one command
2. Format conversion — PNG/JPG/WebP/AVIF/TIFF/GIF/BMP/SVG/PDF
3. Text watermarks — customizable font, position, opacity
4. Logo watermarks — overlay images with auto-scaling
5. Thumbnail generation — square crops at any size
6. Contact sheets — visual grid of all images in a folder
7. CSS sprite sheets — combine icons + generate CSS classes
8. Visual comparison — diff two images, highlight changes
9. Aspect ratio cropping — 16:9, 1:1, 4:3, any ratio
10. Metadata stripping — remove EXIF/GPS data for privacy
11. Pipeline mode — chain operations without intermediate files
12. PDF extraction — convert PDF pages to images at any DPI
