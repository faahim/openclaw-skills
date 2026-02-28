# Listing Copy: Web Screenshot

## Metadata
- **Type:** Skill
- **Name:** web-screenshot
- **Display Name:** Web Screenshot
- **Categories:** [media, automation]
- **Price:** $10
- **Dependencies:** [node, playwright]

## Tagline

Capture full-page screenshots of any URL using headless Chromium

## Description

Manually screenshotting web pages is tedious — especially when you need to capture multiple pages regularly for monitoring, archiving, or reporting. Browser extensions are clunky, and online tools add watermarks or limit captures.

Web Screenshot uses Playwright's headless Chromium to capture pixel-perfect screenshots of any URL — full-page scrolls, mobile viewports, specific elements, or batch lists of URLs. No browser window needed, no manual clicking, just one command.

**What it does:**
- 📸 Screenshot any URL in PNG or JPEG format
- 📜 Full-page capture (scrolls entire page automatically)
- 📱 Custom viewports — desktop, tablet, mobile sizes
- 🎯 Element-specific capture (CSS selectors)
- 📋 Batch mode — screenshot lists of URLs
- 🌙 Dark mode support
- 💉 CSS injection — hide cookie banners, popups
- ⏱️ Wait for dynamic content (SPAs, JS-rendered pages)
- 🔐 HTTP basic auth support
- ⏰ Cron-ready for scheduled captures

Perfect for developers monitoring visual changes, marketers archiving competitor pages, or anyone who needs automated web captures without opening a browser.

## Quick Start Preview

```bash
# Install (one-time)
bash scripts/install.sh

# Capture a page
bash scripts/screenshot.sh --url https://yoursite.com --output shot.png

# Full-page mobile screenshot
bash scripts/screenshot.sh --url https://yoursite.com --width 375 --height 812 --full-page --output mobile.png

# Batch capture
bash scripts/screenshot.sh --batch urls.txt --output-dir captures/
```

## Core Capabilities

1. Single URL capture — Quick screenshot of any web page
2. Full-page scroll capture — Entire page regardless of length
3. Custom viewport sizes — Desktop, tablet, mobile, or any custom resolution
4. Element targeting — Screenshot specific CSS selectors only
5. Batch processing — Capture URL lists from file
6. Dark mode — Force dark color scheme on any page
7. CSS injection — Hide popups, banners, overlays before capture
8. Wait strategies — networkidle, selector wait, fixed delay for SPAs
9. Format options — PNG (lossless) or JPEG (with quality control)
10. Cron integration — Schedule recurring captures for monitoring

## Dependencies
- `node` (16+)
- `playwright` (auto-installed)
- ~300MB disk for Chromium

## Installation Time
**5 minutes** — Run install script, start capturing

## Pricing Justification

**Why $10:**
- Replaces screenshot SaaS tools ($15-50/mo)
- One-time purchase, unlimited captures
- Playwright-powered (same engine as enterprise tools)
- Batch mode saves hours of manual work
- No usage limits or watermarks
