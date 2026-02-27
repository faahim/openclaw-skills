---
name: imagemagick-toolkit
description: >-
  Batch image processing toolkit — resize, crop, watermark, convert formats, generate thumbnails, create sprites, extract PDF pages, and compare images.
categories: [media, automation]
dependencies: [imagemagick, bash]
---

# ImageMagick Toolkit

## What This Does

A comprehensive image processing toolkit powered by ImageMagick. Batch resize thousands of images, add watermarks, convert between formats (PNG/JPG/WebP/AVIF/TIFF), generate thumbnail grids, create CSS sprite sheets, extract PDF pages as images, and visually compare images for differences.

**Example:** "Resize all PNGs in a folder to 800px wide, convert to WebP, add a watermark, and generate a thumbnail contact sheet — in one command."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. Resize Images

```bash
bash scripts/run.sh resize --input ./photos --width 800 --output ./resized
```

### 3. Convert Formats

```bash
bash scripts/run.sh convert --input ./photos --format webp --quality 85 --output ./converted
```

## Core Workflows

### Workflow 1: Batch Resize

Resize images maintaining aspect ratio.

```bash
# Resize to max width 1200px
bash scripts/run.sh resize --input ./images --width 1200 --output ./resized

# Resize to exact dimensions (may crop)
bash scripts/run.sh resize --input ./images --width 800 --height 600 --crop --output ./resized

# Resize to percentage
bash scripts/run.sh resize --input ./images --percent 50 --output ./half-size
```

**Output:**
```
[resize] Processing 47 images...
[resize] ✅ photo1.jpg → 1200x800 (was 4032x2688)
[resize] ✅ photo2.png → 1200x900 (was 3024x2268)
...
[resize] Done: 47/47 processed, 0 errors
[resize] Saved 142MB (was 312MB → now 170MB)
```

### Workflow 2: Format Conversion

Convert between PNG, JPG, WebP, AVIF, TIFF, BMP, GIF.

```bash
# Convert all PNGs to WebP
bash scripts/run.sh convert --input ./screenshots --format webp --quality 85 --output ./web

# Convert to AVIF (best compression)
bash scripts/run.sh convert --input ./photos --format avif --quality 70 --output ./optimized

# Convert PDF pages to PNG
bash scripts/run.sh convert --input ./document.pdf --format png --density 300 --output ./pages
```

### Workflow 3: Add Watermark

Overlay text or image watermark on photos.

```bash
# Text watermark (bottom-right)
bash scripts/run.sh watermark --input ./photos --text "© 2026 MyBrand" \
  --position southeast --opacity 50 --output ./watermarked

# Image watermark (logo overlay)
bash scripts/run.sh watermark --input ./photos --logo ./logo.png \
  --position center --opacity 30 --scale 20 --output ./watermarked
```

### Workflow 4: Generate Thumbnails

Create thumbnail grids / contact sheets.

```bash
# Generate 200px thumbnails
bash scripts/run.sh thumbnail --input ./photos --size 200 --output ./thumbs

# Create contact sheet (grid of all images)
bash scripts/run.sh contact-sheet --input ./photos --columns 5 --thumb-size 200 \
  --output ./contact-sheet.jpg
```

**Output:** A single image showing all photos in a 5-column grid.

### Workflow 5: Create CSS Sprite Sheet

Combine icons/small images into a single sprite with CSS coordinates.

```bash
bash scripts/run.sh sprite --input ./icons --output ./sprite.png --css ./sprite.css
```

**Output files:**
- `sprite.png` — Combined image
- `sprite.css` — CSS classes with background-position for each icon

```css
.icon-home { width: 32px; height: 32px; background: url('sprite.png') -0px -0px; }
.icon-search { width: 32px; height: 32px; background: url('sprite.png') -32px -0px; }
.icon-user { width: 32px; height: 32px; background: url('sprite.png') -64px -0px; }
```

### Workflow 6: Image Comparison

Compare two images and highlight differences.

```bash
bash scripts/run.sh compare --input1 ./before.png --input2 ./after.png \
  --output ./diff.png --metric AE
```

**Output:**
```
[compare] Difference: 1,247 pixels (0.3% of total)
[compare] Saved diff visualization → diff.png
```

### Workflow 7: Batch Crop

Crop images to specific regions or aspect ratios.

```bash
# Crop to 16:9 aspect ratio (center)
bash scripts/run.sh crop --input ./photos --aspect 16:9 --gravity center --output ./cropped

# Crop specific region
bash scripts/run.sh crop --input ./photo.jpg --geometry 800x600+100+50 --output ./cropped.jpg
```

### Workflow 8: Strip Metadata

Remove EXIF/metadata for privacy.

```bash
bash scripts/run.sh strip --input ./photos --output ./clean
```

## Configuration

### Environment Variables

```bash
# Default output quality (1-100)
export IM_QUALITY=85

# Default watermark opacity (0-100)
export IM_WATERMARK_OPACITY=50

# Max parallel processes
export IM_PARALLEL=4

# Default output format
export IM_FORMAT=webp
```

### Supported Formats

| Format | Read | Write | Best For |
|--------|------|-------|----------|
| JPEG | ✅ | ✅ | Photos |
| PNG | ✅ | ✅ | Screenshots, transparency |
| WebP | ✅ | ✅ | Web (best size/quality) |
| AVIF | ✅ | ✅ | Web (next-gen, smallest) |
| TIFF | ✅ | ✅ | Print, archival |
| GIF | ✅ | ✅ | Animation |
| BMP | ✅ | ✅ | Legacy |
| PDF | ✅ | ✅ | Documents → images |
| SVG | ✅ | ✅ | Vector → raster |

## Advanced Usage

### Pipeline Multiple Operations

```bash
# Resize + convert + watermark in one pass
bash scripts/run.sh pipeline --input ./raw-photos \
  --resize 1200 \
  --format webp \
  --watermark "© MyBrand" \
  --strip-metadata \
  --output ./final
```

### Run as Cron (Batch Process Uploads)

```bash
# Process new uploads every hour
0 * * * * cd /path/to/skill && bash scripts/run.sh resize --input /uploads/new --width 1200 --format webp --output /uploads/processed --move-done /uploads/archived
```

## Troubleshooting

### Issue: "convert: command not found"

```bash
# Run installer
bash scripts/install.sh

# Or manually:
# Ubuntu/Debian
sudo apt-get install -y imagemagick

# Mac
brew install imagemagick
```

### Issue: "not authorized" for PDF conversion

ImageMagick blocks PDF by default for security. Fix:

```bash
# Edit policy (installer does this automatically)
sudo sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml 2>/dev/null
sudo sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' /etc/ImageMagick-7/policy.xml 2>/dev/null
```

### Issue: AVIF/WebP not supported

Your ImageMagick may be compiled without these codecs:

```bash
# Check supported formats
convert -list format | grep -i 'avif\|webp'

# If missing, install from source or use newer package
# Ubuntu 22.04+: sudo apt install imagemagick webp libheif-dev
```

### Issue: Out of memory on large batches

```bash
# Limit memory usage
export MAGICK_MEMORY_LIMIT=512MiB
export MAGICK_MAP_LIMIT=1GiB

# Or process in smaller batches
bash scripts/run.sh resize --input ./photos --width 1200 --batch-size 20 --output ./resized
```

## Dependencies

- `imagemagick` (6.9+ or 7.0+) — core image processing
- `bash` (4.0+) — script runner
- `ghostscript` (optional) — PDF support
- `webp` (optional) — WebP format support
- `libheif` (optional) — AVIF/HEIF format support

## Key Principles

1. **Non-destructive** — Never modifies originals; always writes to output dir
2. **Batch-first** — Process entire directories, not just single files
3. **Format-aware** — Automatically detects input format, converts cleanly
4. **Memory-safe** — Configurable limits prevent OOM on large batches
5. **Parallel** — Uses GNU parallel or xargs for multi-core processing
