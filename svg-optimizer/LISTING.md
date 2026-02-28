# Listing Copy: SVG Optimizer

## Metadata
- **Type:** Skill
- **Name:** svg-optimizer
- **Display Name:** SVG Optimizer
- **Categories:** [design, automation]
- **Price:** $8
- **Dependencies:** [node, npm, svgo]

## Tagline

Batch-optimize SVG files — shrink 30-80% with zero quality loss

## Description

SVG files from design tools like Figma, Illustrator, and Inkscape are bloated with editor metadata, redundant attributes, and unoptimized path data. Every extra kilobyte slows down your website and wastes bandwidth.

SVG Optimizer installs and wraps [SVGO](https://github.com/svg/svgo) (60k+ GitHub stars) to batch-process your SVGs in seconds. Strip metadata, minify paths, collapse groups, and convert shapes — all automatically. Typical results: 30-80% file size reduction with zero visual difference.

**What it does:**
- 📁 Batch-optimize entire directories of SVGs
- 🎯 Multiple presets: default, aggressive, web-safe, icon
- 📊 CSV reports showing per-file size savings
- 👁️ Watch mode for auto-optimization on file change
- ♿ Web-safe mode preserves title, desc, and aria attributes
- ⚡ Multipass optimization for maximum compression
- 🔧 Custom SVGO config support for full control
- 🛡️ Non-destructive by default (separate output directory)

Perfect for frontend developers, designers, and anyone shipping SVGs on the web who wants smaller files without manual cleanup.

## Quick Start Preview

```bash
bash scripts/run.sh --input ./icons/ --output ./icons-optimized/

# ✅ icon-home.svg: 3.1 KB → 1.2 KB (61.3%)
# ✅ icon-user.svg: 4.8 KB → 1.5 KB (68.7%)
# ✅ logo.svg: 22.4 KB → 6.1 KB (72.8%)
# Total: 30.3 KB → 8.8 KB (71.0% reduction, 3 files)
```

## Installation Time
**2 minutes** — One command installs svgo globally
