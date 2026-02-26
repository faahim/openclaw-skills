# Listing Copy: Color Palette Extractor

## Metadata
- **Type:** Skill
- **Name:** color-palette
- **Display Name:** Color Palette Extractor
- **Categories:** [design, productivity]
- **Price:** $8
- **Dependencies:** [imagemagick, bash, jq, bc]
- **Icon:** 🎨

## Tagline
Extract dominant colors from images — Generate harmonious palettes with CSS/JSON/Tailwind export

## Description

Picking colors from images manually is slow and imprecise. Designers and developers waste time eyedropping colors, checking contrast ratios, and converting between formats. You need automated color extraction.

Color Palette Extractor uses ImageMagick's color quantization to pull dominant colors from any image — photos, screenshots, logos, hero images. It generates harmonious palettes (complementary, analogous, triadic) and exports directly to CSS custom properties, JSON, Tailwind config, or SCSS variables. Ready to drop into your project.

**What it does:**
- 🎨 Extract 1-20 dominant colors from any image format
- 🔄 Generate color harmonies (complementary, analogous, triadic, split-complementary)
- 📦 Export as CSS, JSON, Tailwind, or SCSS — copy-paste ready
- ♿ WCAG 2.1 contrast ratio checker built in
- 📁 Batch process entire directories of images
- 🔍 Compare palettes between two images
- 🏷️ Auto-name colors to nearest CSS color name
- ⚡ Works with JPG, PNG, GIF, WebP, BMP, TIFF

Perfect for developers building UIs, designers extracting brand colors, and anyone who needs a quick palette from a reference image.

## Quick Start Preview

```bash
bash scripts/extract.sh --image hero.jpg --colors 5 --export css --output palette.css
```

## Core Capabilities

1. Dominant color extraction — ImageMagick quantization, frequency-sorted
2. Multiple export formats — CSS, JSON, Tailwind config, SCSS variables
3. Color harmony generation — Complementary, analogous, triadic, split-complementary
4. WCAG contrast checking — AAA/AA/Fail grades for all color pairs
5. Batch processing — Process entire image directories at once
6. Palette comparison — Compare two images side-by-side
7. Color naming — Nearest CSS color name for each extracted color
8. Stdin support — Pipe images from curl or other tools
9. Configurable — Color count, sort order, color space, depth
10. Zero config — Works out of the box with sensible defaults

## Installation Time
**3 minutes** — Install ImageMagick if needed, run script
