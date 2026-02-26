---
name: color-palette
description: >-
  Extract dominant colors from images and generate harmonious palettes with CSS/JSON/Tailwind export.
categories: [design, productivity]
dependencies: [imagemagick, bash, jq]
---

# Color Palette Extractor

## What This Does

Extract dominant colors from any image using ImageMagick's color quantization. Generate complementary, analogous, and triadic palettes automatically. Export as CSS variables, JSON, or Tailwind config — ready to drop into your project.

**Example:** "Extract 5 colors from a hero image, generate a full palette, export as CSS custom properties."

## Quick Start (3 minutes)

### 1. Install Dependencies

```bash
# Check if ImageMagick is installed
which convert identify || echo "Install ImageMagick first"

# Ubuntu/Debian
sudo apt-get install -y imagemagick jq

# macOS
brew install imagemagick jq

# Verify
convert --version | head -1
```

### 2. Extract Colors from an Image

```bash
bash scripts/extract.sh --image photo.jpg --colors 5

# Output:
# 🎨 Dominant Colors from photo.jpg
# ─────────────────────────────────
# 1. #2C3E50  ██████  (28.4%)
# 2. #E74C3C  ██████  (22.1%)
# 3. #ECF0F1  ██████  (19.7%)
# 4. #3498DB  ██████  (16.3%)
# 5. #2ECC71  ██████  (13.5%)
```

### 3. Generate a Full Palette

```bash
bash scripts/extract.sh --image photo.jpg --colors 5 --harmony complementary --export css

# Output: palette.css
# :root {
#   --color-primary: #2C3E50;
#   --color-secondary: #E74C3C;
#   --color-accent: #3498DB;
#   --color-bg: #ECF0F1;
#   --color-success: #2ECC71;
#   --color-primary-light: #3D5166;
#   --color-primary-dark: #1A252F;
#   ...
# }
```

## Core Workflows

### Workflow 1: Extract Dominant Colors

**Use case:** See what colors dominate an image

```bash
bash scripts/extract.sh --image hero.png --colors 8
```

**Flags:**
- `--colors N` — Number of colors to extract (default: 5, max: 20)
- `--sort luminance|frequency` — Sort by brightness or prevalence (default: frequency)

### Workflow 2: Generate Harmonious Palette

**Use case:** Build a full design palette from extracted colors

```bash
bash scripts/extract.sh --image brand-photo.jpg --colors 5 --harmony all
```

**Harmony modes:**
- `complementary` — Opposite on color wheel
- `analogous` — Adjacent colors (±30°)
- `triadic` — Three evenly spaced colors (120° apart)
- `split-complementary` — Complement + two adjacent to complement
- `all` — Generate all harmonies

### Workflow 3: Export for Development

**Use case:** Get palette in your framework's format

```bash
# CSS Custom Properties
bash scripts/extract.sh --image photo.jpg --export css --output palette.css

# JSON (for JS/TS projects)
bash scripts/extract.sh --image photo.jpg --export json --output palette.json

# Tailwind config
bash scripts/extract.sh --image photo.jpg --export tailwind --output colors.js

# SCSS variables
bash scripts/extract.sh --image photo.jpg --export scss --output _colors.scss
```

**CSS output:**
```css
:root {
  --color-1: #2C3E50;
  --color-2: #E74C3C;
  --color-3: #ECF0F1;
  --color-4: #3498DB;
  --color-5: #2ECC71;
}
```

**JSON output:**
```json
{
  "palette": [
    {"hex": "#2C3E50", "rgb": [44, 62, 80], "hsl": [207, 29, 24], "percentage": 28.4},
    {"hex": "#E74C3C", "rgb": [231, 76, 60], "hsl": [6, 78, 57], "percentage": 22.1}
  ]
}
```

**Tailwind output:**
```javascript
module.exports = {
  colors: {
    primary: '#2C3E50',
    secondary: '#E74C3C',
    accent: '#3498DB',
    background: '#ECF0F1',
    success: '#2ECC71',
  }
}
```

### Workflow 4: Batch Process Multiple Images

**Use case:** Extract palettes from a directory of images

```bash
bash scripts/extract.sh --dir ./images/ --colors 5 --export json --output palettes/
```

### Workflow 5: Compare Palettes

**Use case:** See how two images' color palettes differ

```bash
bash scripts/extract.sh --compare image1.jpg image2.jpg --colors 5
```

### Workflow 6: Accessibility Check

**Use case:** Check contrast ratios between extracted colors

```bash
bash scripts/extract.sh --image photo.jpg --colors 5 --contrast

# Output:
# Contrast Ratios (WCAG 2.1)
# ──────────────────────────
# #2C3E50 vs #ECF0F1  →  11.7:1 ✅ AAA (large + normal text)
# #E74C3C vs #ECF0F1  →   3.9:1 ⚠️  AA (large text only)
# #3498DB vs #2C3E50  →   2.1:1 ❌ Fail
```

## Configuration

### Environment Variables

```bash
# Default number of colors (override with --colors)
export PALETTE_DEFAULT_COLORS=5

# Default export format
export PALETTE_DEFAULT_FORMAT=json

# Default output directory
export PALETTE_OUTPUT_DIR=./palettes
```

## Advanced Usage

### Pipe from URL

```bash
curl -sL "https://example.com/photo.jpg" | bash scripts/extract.sh --stdin --colors 5
```

### Use with OpenClaw Cron

```bash
# Extract palette from daily screenshot
bash scripts/extract.sh --image /tmp/daily-screenshot.png --export json --output ~/palettes/$(date +%Y-%m-%d).json
```

### Custom Color Names

```bash
bash scripts/extract.sh --image photo.jpg --colors 5 --names
# Adds nearest CSS color names: "Dark Slate Blue", "Alizarin Crimson", etc.
```

## Troubleshooting

### Issue: "convert: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install -y imagemagick

# macOS
brew install imagemagick

# Verify
convert --version
```

### Issue: "not authorized" error with ImageMagick

ImageMagick may block certain file types by default.

```bash
# Edit policy.xml
sudo sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml
```

### Issue: Colors look wrong / too few unique colors

```bash
# Increase color depth
bash scripts/extract.sh --image photo.jpg --colors 10 --depth 16

# Use different color space
bash scripts/extract.sh --image photo.jpg --colors 5 --colorspace LAB
```

## Dependencies

- `imagemagick` (6.9+ or 7.x) — Color quantization, image analysis
- `bash` (4.0+) — Script runtime
- `jq` — JSON formatting (for JSON/Tailwind export)
- `bc` — Math calculations (contrast ratios)
