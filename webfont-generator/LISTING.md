# Listing Copy: Webfont Generator

## Metadata
- **Type:** Skill
- **Name:** webfont-generator
- **Display Name:** Webfont Generator
- **Categories:** [design, dev-tools]
- **Price:** $8
- **Dependencies:** [python3, fonttools, brotli]

## Tagline
Convert desktop fonts to optimized WOFF2/WOFF with CSS and specimen pages

## Description

Self-hosting fonts? Downloading a TTF from Google Fonts and just throwing it on your server? That's leaving 50-70% file size savings on the table. Your users are downloading bloated font files on every page load.

Webfont Generator converts TTF and OTF fonts into optimized WOFF2 and WOFF formats, generates production-ready `@font-face` CSS, and creates HTML specimen pages — all from a single command. No online converters, no manual work, no uploading your fonts to third-party services.

**What it does:**
- 🔤 Convert TTF/OTF → WOFF2 (Brotli compression, ~70% smaller)
- 🔤 Convert TTF/OTF → WOFF (Zopfli compression, ~50% smaller)
- 📄 Generate `@font-face` CSS with correct weights, styles, and `font-display`
- 🖼️ Create HTML specimen pages for font previewing
- ✂️ Subset fonts to specific unicode ranges (Latin, Cyrillic, Greek, custom)
- 📂 Batch convert entire directories
- 🔒 Everything runs locally — fonts never leave your machine

## Core Capabilities

1. TTF/OTF to WOFF2 conversion — Brotli-compressed, smallest web format
2. TTF/OTF to WOFF conversion — Broad browser compatibility
3. Automatic CSS generation — Production-ready @font-face declarations
4. Font subsetting — Strip unused glyphs, reduce size further
5. Specimen page generation — Preview fonts in browser instantly
6. Batch processing — Convert entire font directories at once
7. Font metadata inspection — Check families, weights, glyph counts
8. Configurable font-display — swap, block, fallback, optional
9. Custom URL prefixes — Works with any deployment path
10. CI/CD ready — Run in build pipelines

## Dependencies
- `python3` (3.8+)
- `fonttools` (pip)
- `brotli` (pip, for WOFF2)
- `zopfli` (pip, optional, for better WOFF compression)

## Installation Time
**2 minutes** — pip install, run script
