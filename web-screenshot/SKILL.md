---
name: web-screenshot
description: >-
  Capture full-page or viewport screenshots of any URL using headless Chromium.
categories: [media, automation]
dependencies: [node, npx, playwright]
---

# Web Screenshot

## What This Does

Captures high-quality screenshots of web pages using headless Chromium via Playwright. Take full-page captures, viewport-only shots, element-specific screenshots, or batch-capture multiple URLs. Perfect for visual monitoring, page archiving, thumbnail generation, and automated reporting.

**Example:** "Screenshot 20 competitor landing pages, save as timestamped PNGs for weekly comparison."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install Playwright with Chromium (one-time setup)
bash scripts/install.sh
```

### 2. Take Your First Screenshot

```bash
# Screenshot a URL
bash scripts/screenshot.sh --url https://example.com --output screenshot.png

# Output:
# ✅ Screenshot saved: screenshot.png (1280x720, 245KB)
```

### 3. Full-Page Capture

```bash
# Capture entire page (scrolls to bottom)
bash scripts/screenshot.sh --url https://example.com --full-page --output full.png

# Output:
# ✅ Screenshot saved: full.png (1280x4200, 1.2MB)
```

## Core Workflows

### Workflow 1: Single URL Screenshot

**Use case:** Quick capture of a web page

```bash
bash scripts/screenshot.sh \
  --url https://yoursite.com \
  --output captures/yoursite.png
```

**Options:**
```bash
# Custom viewport size
bash scripts/screenshot.sh --url https://yoursite.com --width 1920 --height 1080 --output hd.png

# Mobile viewport
bash scripts/screenshot.sh --url https://yoursite.com --width 375 --height 812 --device-scale 2 --output mobile.png

# JPEG with quality setting
bash scripts/screenshot.sh --url https://yoursite.com --format jpeg --quality 80 --output shot.jpg
```

### Workflow 2: Batch Screenshots

**Use case:** Capture multiple URLs at once

```bash
# Create a URL list file
cat > urls.txt << 'EOF'
https://example.com
https://google.com
https://github.com
EOF

# Batch capture
bash scripts/screenshot.sh --batch urls.txt --output-dir captures/ --format png

# Output:
# ✅ [1/3] example.com — captures/example.com.png (245KB)
# ✅ [2/3] google.com — captures/google.com.png (189KB)
# ✅ [3/3] github.com — captures/github.com.png (312KB)
# Done: 3/3 captured
```

### Workflow 3: Timestamped Archive

**Use case:** Daily visual snapshots for change monitoring

```bash
# Capture with timestamp in filename
bash scripts/screenshot.sh \
  --url https://yoursite.com \
  --output "archives/yoursite-$(date +%Y%m%d-%H%M%S).png"
```

**Cron integration:**
```bash
# Add to crontab — capture every 6 hours
0 */6 * * * cd /path/to/skill && bash scripts/screenshot.sh --url https://yoursite.com --output "archives/yoursite-$(date +\%Y\%m\%d-\%H\%M\%S).png" >> logs/captures.log 2>&1
```

### Workflow 4: Wait for Content

**Use case:** Page needs time to load dynamic content (SPAs, JS-rendered pages)

```bash
# Wait for network idle (no requests for 500ms)
bash scripts/screenshot.sh --url https://spa-app.com --wait-until networkidle --output spa.png

# Wait for a specific selector to appear
bash scripts/screenshot.sh --url https://dashboard.com --wait-for "#chart-loaded" --output dashboard.png

# Wait fixed time (ms)
bash scripts/screenshot.sh --url https://slow-site.com --delay 5000 --output slow.png
```

### Workflow 5: Element Screenshot

**Use case:** Capture only a specific part of the page

```bash
# Screenshot a specific CSS selector
bash scripts/screenshot.sh --url https://yoursite.com --selector ".hero-section" --output hero.png

# Capture the header only
bash scripts/screenshot.sh --url https://yoursite.com --selector "header" --output header.png
```

### Workflow 6: Dark Mode & Custom CSS

**Use case:** Capture pages in dark mode or with custom styling

```bash
# Force dark color scheme
bash scripts/screenshot.sh --url https://yoursite.com --dark-mode --output dark.png

# Inject custom CSS before capture
bash scripts/screenshot.sh --url https://yoursite.com --inject-css "body { background: #000; }" --output custom.png

# Hide cookie banners and popups
bash scripts/screenshot.sh --url https://yoursite.com --inject-css ".cookie-banner, .popup-overlay { display: none !important; }" --output clean.png
```

## Configuration

### Environment Variables

```bash
# Custom Chromium path (optional — Playwright bundles its own)
export PLAYWRIGHT_CHROMIUM_PATH="/path/to/chromium"

# Default output directory
export SCREENSHOT_OUTPUT_DIR="./captures"

# Default viewport
export SCREENSHOT_WIDTH=1280
export SCREENSHOT_HEIGHT=720
```

### Command Reference

```
Usage: bash scripts/screenshot.sh [options]

Required:
  --url <url>              URL to capture

Output:
  --output <path>          Output file path (default: screenshot.png)
  --output-dir <dir>       Output directory for batch mode
  --format <png|jpeg>      Image format (default: png)
  --quality <1-100>        JPEG quality (default: 80)

Viewport:
  --width <px>             Viewport width (default: 1280)
  --height <px>            Viewport height (default: 720)
  --device-scale <n>       Device scale factor (default: 1)
  --full-page              Capture full scrollable page

Timing:
  --delay <ms>             Wait before capture (default: 0)
  --wait-until <event>     load|domcontentloaded|networkidle (default: load)
  --wait-for <selector>    Wait for CSS selector to appear
  --timeout <ms>           Navigation timeout (default: 30000)

Advanced:
  --selector <css>         Capture only this element
  --dark-mode              Enable dark color scheme
  --inject-css <css>       Inject CSS before capture
  --user-agent <string>    Custom user agent
  --auth <user:pass>       HTTP basic auth
  --batch <file>           File with URLs (one per line)
  --no-javascript          Disable JavaScript
```

## Troubleshooting

### Issue: "Chromium not found"

**Fix:**
```bash
# Re-run installer
bash scripts/install.sh

# Or install Playwright browsers manually
npx playwright install chromium
```

### Issue: "Navigation timeout" on slow pages

**Fix:**
```bash
# Increase timeout
bash scripts/screenshot.sh --url https://slow-site.com --timeout 60000 --output slow.png
```

### Issue: Screenshots look wrong (missing fonts/styles)

**Fix:**
```bash
# Wait for full load
bash scripts/screenshot.sh --url https://fancy-site.com --wait-until networkidle --delay 2000 --output fixed.png
```

### Issue: Cookie consent banners blocking content

**Fix:**
```bash
# Hide common banners
bash scripts/screenshot.sh --url https://site.com \
  --inject-css "[class*='cookie'], [class*='consent'], [class*='banner'] { display: none !important; }" \
  --output clean.png
```

## Dependencies

- `node` (16+)
- `npx` (comes with Node)
- `playwright` (auto-installed by install.sh)
- ~300MB disk for Chromium browser

## Key Principles

1. **Fast by default** — Uses Playwright's optimized Chromium
2. **Full-page support** — Captures pages of any length
3. **Batch-friendly** — Process URL lists efficiently
4. **Deterministic** — Same URL → same screenshot (networkidle wait)
5. **Lightweight script** — No heavy framework, just bash + Node one-liner
