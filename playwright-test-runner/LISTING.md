# Listing Copy: Playwright Test Runner

## Metadata
- **Type:** Skill
- **Name:** playwright-test-runner
- **Display Name:** Playwright Test Runner
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [node, npx]
- **Icon:** 🎭

## Tagline

Run browser tests, capture screenshots, and check broken links — all headless from the terminal

## Description

Setting up browser testing is tedious — install browsers, configure test runners, write boilerplate, figure out selectors. Most developers skip it entirely until bugs hit production.

Playwright Test Runner handles the entire setup and gives you ready-to-use commands for the most common browser automation tasks. Screenshot any URL, run E2E test suites across Chromium/Firefox/WebKit, find broken links, measure page performance, and generate rich HTML reports — all headless, all from one script.

**What it does:**
- 📸 Screenshot any URL (single, batch, full-page, mobile viewport)
- 🧪 Run E2E test suites with HTML reports and failure traces
- 🔗 Find broken links on any page (with crawl support)
- ⚡ Measure page load performance metrics
- 📄 Generate PDFs from web pages
- 🎬 Record user interactions and generate test code
- 📊 Visual diff between screenshots (catch regressions)
- 🌐 Multi-browser support (Chromium, Firefox, WebKit)
- 📱 Mobile device emulation

Perfect for developers, QA engineers, and indie hackers who want automated browser testing without the DevOps overhead.

## Quick Start Preview

```bash
# Install
bash scripts/install.sh

# Screenshot a URL
bash scripts/run.sh screenshot --url https://yoursite.com --output home.png

# Check for broken links
bash scripts/run.sh linkcheck --url https://yoursite.com

# Run tests
bash scripts/run.sh test --dir tests/ --report html
```

## Core Capabilities

1. URL screenshots — Capture any page as PNG/JPEG, full-page or viewport
2. Batch screenshots — Screenshot multiple URLs from a file
3. E2E test runner — Run Playwright test suites with retries and reports
4. Broken link checker — Find dead links, optionally crawl internal pages
5. Performance audit — DOM load time, first paint, page size, request count
6. PDF generation — Convert any webpage to PDF
7. Test code generator — Record interactions, output test scripts
8. Visual regression — Compare screenshots, detect changes
9. Multi-browser — Test on Chromium, Firefox, and WebKit simultaneously
10. Mobile testing — Emulate any device viewport and user agent

## Installation Time
**5 minutes** — Run install script, start testing
