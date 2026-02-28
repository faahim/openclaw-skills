---
name: webfont-generator
description: >-
  Convert desktop fonts to optimized web formats with CSS and specimen pages.
categories: [design, dev-tools]
dependencies: [python3, pip]
---

# Webfont Generator

## What This Does

Converts TTF and OTF font files into optimized web formats (WOFF, WOFF2), generates ready-to-use CSS `@font-face` declarations, and creates HTML specimen pages for previewing. Handles single fonts or entire directories in batch.

**Example:** "Convert 5 TTF files → WOFF2 (70% smaller), get CSS, preview page — all in one command."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install Python font tools
pip3 install fonttools brotli zopfli

# Verify installation
python3 -c "from fontTools.ttLib import TTFont; print('fonttools OK')"
```

### 2. Convert a Single Font

```bash
bash scripts/run.sh --input MyFont.ttf --output ./webfonts/

# Output:
# ✅ MyFont.woff2 (42 KB — 68% smaller than TTF)
# ✅ MyFont.woff (56 KB — 57% smaller than TTF)
# ✅ fonts.css generated
# ✅ specimen.html generated
```

### 3. Batch Convert a Directory

```bash
bash scripts/run.sh --input ./desktop-fonts/ --output ./webfonts/

# Converts ALL .ttf and .otf files in the directory
```

## Core Workflows

### Workflow 1: Convert TTF/OTF to WOFF2

**Use case:** Optimize fonts for web — WOFF2 is the smallest format, supported by all modern browsers.

```bash
bash scripts/run.sh --input Roboto-Regular.ttf --output ./webfonts/ --formats woff2
```

**Output:**
```
[webfont] Converting Roboto-Regular.ttf...
[webfont] ✅ Roboto-Regular.woff2 — 42,180 bytes (68% reduction)
[webfont] ✅ CSS written to ./webfonts/fonts.css
```

### Workflow 2: Generate All Formats + CSS

**Use case:** Support older browsers (WOFF for IE11).

```bash
bash scripts/run.sh --input ./fonts/ --output ./webfonts/ --formats woff2,woff --css --specimen
```

**Generated CSS (fonts.css):**
```css
@font-face {
  font-family: 'Roboto';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url('Roboto-Regular.woff2') format('woff2'),
       url('Roboto-Regular.woff') format('woff');
}

@font-face {
  font-family: 'Roboto';
  font-style: normal;
  font-weight: 700;
  font-display: swap;
  src: url('Roboto-Bold.woff2') format('woff2'),
       url('Roboto-Bold.woff') format('woff');
}
```

### Workflow 3: Subset Fonts (Reduce Size Further)

**Use case:** Only need Latin characters? Strip everything else.

```bash
bash scripts/run.sh --input MyFont.ttf --output ./webfonts/ --subset "latin"
```

**Subset options:** `latin`, `latin-ext`, `cyrillic`, `greek`, `custom:U+0020-007E`

### Workflow 4: Font Info & Inspection

**Use case:** Check what's in a font file before converting.

```bash
bash scripts/run.sh --info MyFont.ttf
```

**Output:**
```
Font: My Font
Family: My Font
Style: Regular
Weight: 400
Version: 1.002
Glyphs: 842
File size: 132,456 bytes
Unicode ranges: Basic Latin, Latin-1 Supplement, Latin Extended-A
```

## Configuration

### Command-Line Options

```bash
bash scripts/run.sh [OPTIONS]

Options:
  --input PATH        Input font file or directory (required)
  --output DIR        Output directory (default: ./webfonts)
  --formats LIST      Comma-separated: woff2,woff (default: woff2,woff)
  --css               Generate @font-face CSS (default: on)
  --no-css            Skip CSS generation
  --specimen          Generate HTML specimen page
  --subset RANGE      Subset to unicode range (latin, latin-ext, cyrillic, greek, custom:U+XXXX-XXXX)
  --font-display VAL  CSS font-display value (swap, block, fallback, optional) [default: swap]
  --prefix URL        URL prefix for font paths in CSS [default: ./]
  --info              Show font metadata without converting
  --help              Show this help
```

### Environment Variables

```bash
# Optional: custom Python path
export PYTHON_BIN="/usr/bin/python3"

# Optional: output quality for WOFF (1-9, default: 6)
export WOFF_QUALITY="9"
```

## Advanced Usage

### Use with CI/CD

```bash
# In GitHub Actions or similar
- name: Generate webfonts
  run: |
    pip install fonttools brotli zopfli
    bash scripts/run.sh --input ./src/fonts/ --output ./public/fonts/ --formats woff2 --css
```

### Custom Unicode Ranges

```bash
# Only Basic Latin + some symbols
bash scripts/run.sh --input MyFont.ttf --output ./webfonts/ \
  --subset "custom:U+0020-007E,U+2190-21FF"
```

### Integrate with Build Tools

```bash
# Add to package.json scripts
# "fonts": "bash path/to/webfont-generator/scripts/run.sh --input ./src/fonts --output ./dist/fonts --formats woff2 --css"
```

## Troubleshooting

### Issue: "ModuleNotFoundError: No module named 'fontTools'"

**Fix:**
```bash
pip3 install fonttools brotli zopfli
# Or with pipx:
pipx install fonttools[woff]
```

### Issue: "Permission denied" on output directory

**Fix:**
```bash
mkdir -p ./webfonts && chmod 755 ./webfonts
```

### Issue: WOFF2 output is larger than expected

**Check:** The font may already be compressed. WOFF2 uses Brotli — already-compressed fonts won't shrink much. Try `--subset` to reduce glyph count.

### Issue: CSS paths don't match deployment

**Fix:** Use `--prefix` to set the URL prefix:
```bash
bash scripts/run.sh --input ./fonts/ --output ./webfonts/ --prefix "/assets/fonts/"
```

## Dependencies

- `python3` (3.8+)
- `pip3` packages: `fonttools`, `brotli`, `zopfli`
- Optional: `woff2_compress` (Google's woff2 tool — fonttools handles this via brotli)
