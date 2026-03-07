---
name: playwright-test-runner
description: >-
  Install Playwright, run automated browser tests, capture screenshots, and generate HTML reports — all from the terminal.
categories: [dev-tools, automation]
dependencies: [node, npx]
---

# Playwright Test Runner

## What This Does

Installs and manages Playwright for automated browser testing. Run end-to-end tests, capture screenshots of any URL, check for broken links, validate page content, and generate rich HTML reports. No manual browser interaction needed — everything runs headless.

**Example:** "Test my staging site's login flow, screenshot every page, and email me the HTML report."

## Quick Start (5 minutes)

### 1. Install Playwright

```bash
# Install Playwright and browsers (Chromium, Firefox, WebKit)
bash scripts/install.sh

# Verify installation
npx playwright --version
```

### 2. Screenshot a URL

```bash
# Take a screenshot of any webpage
bash scripts/run.sh screenshot --url https://example.com --output screenshot.png

# Full-page screenshot
bash scripts/run.sh screenshot --url https://example.com --output full.png --full-page
```

### 3. Run a Quick Health Check

```bash
# Check if a URL loads successfully, measure load time
bash scripts/run.sh healthcheck --url https://example.com

# Output:
# ✅ https://example.com — loaded in 1.2s — title: "Example Domain"
```

## Core Workflows

### Workflow 1: Screenshot Multiple Pages

**Use case:** Visual regression, documentation, reporting

```bash
# Screenshot multiple URLs
bash scripts/run.sh screenshot-batch --urls urls.txt --output-dir ./screenshots

# urls.txt format (one URL per line):
# https://example.com
# https://example.com/about
# https://example.com/pricing
```

**Output:**
```
📸 Captured 3 screenshots:
  screenshots/example.com.png (1920x1080)
  screenshots/example.com_about.png (1920x1080)
  screenshots/example.com_pricing.png (1920x1080)
```

### Workflow 2: Run E2E Test Script

**Use case:** Automated testing of login flows, forms, user journeys

```bash
# Run a test file
bash scripts/run.sh test --file tests/login.spec.js

# Run all tests in a directory
bash scripts/run.sh test --dir tests/

# Run with HTML report
bash scripts/run.sh test --dir tests/ --report html
```

**Example test file (tests/login.spec.js):**
```javascript
const { test, expect } = require('@playwright/test');

test('login page loads', async ({ page }) => {
  await page.goto('https://myapp.com/login');
  await expect(page.locator('input[name="email"]')).toBeVisible();
  await expect(page.locator('input[name="password"]')).toBeVisible();
  await expect(page.locator('button[type="submit"]')).toHaveText('Sign In');
});

test('login with valid credentials', async ({ page }) => {
  await page.goto('https://myapp.com/login');
  await page.fill('input[name="email"]', 'test@example.com');
  await page.fill('input[name="password"]', 'password123');
  await page.click('button[type="submit"]');
  await expect(page).toHaveURL(/dashboard/);
});
```

### Workflow 3: Broken Link Checker

**Use case:** Find dead links on your site

```bash
# Check all links on a page
bash scripts/run.sh linkcheck --url https://example.com

# Crawl and check (follow internal links, depth 2)
bash scripts/run.sh linkcheck --url https://example.com --crawl --depth 2
```

**Output:**
```
🔗 Checking links on https://example.com...

✅ https://example.com/about — 200
✅ https://example.com/contact — 200
❌ https://example.com/old-page — 404
❌ https://external-site.com/broken — 503

Summary: 15 links checked, 2 broken
```

### Workflow 4: Page Performance Audit

**Use case:** Measure page load metrics

```bash
bash scripts/run.sh perf --url https://example.com
```

**Output:**
```
⚡ Performance Report: https://example.com

  DOM Content Loaded: 0.8s
  Full Page Load:     1.4s
  First Paint:        0.5s
  Page Size:          245 KB
  Requests:           12
  Console Errors:     0

  ✅ No critical issues detected
```

### Workflow 5: Visual Diff (Compare Screenshots)

**Use case:** Detect visual changes between deploys

```bash
# Take baseline screenshots
bash scripts/run.sh screenshot --url https://staging.myapp.com --output baseline.png

# After deploy, compare
bash scripts/run.sh diff --baseline baseline.png --current current.png --output diff.png
```

## Configuration

### Environment Variables

```bash
# Browser to use (chromium, firefox, webkit)
export PW_BROWSER="chromium"

# Viewport size
export PW_VIEWPORT_WIDTH="1920"
export PW_VIEWPORT_HEIGHT="1080"

# Timeout (ms)
export PW_TIMEOUT="30000"

# Headless mode (default: true)
export PW_HEADLESS="true"

# Screenshot format (png, jpeg)
export PW_SCREENSHOT_FORMAT="png"

# Test report directory
export PW_REPORT_DIR="./playwright-report"
```

### Config File (playwright.config.js)

```javascript
// playwright.config.js
module.exports = {
  testDir: './tests',
  timeout: 30000,
  retries: 1,
  use: {
    headless: true,
    viewport: { width: 1920, height: 1080 },
    screenshot: 'on-failure',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
  },
  reporter: [
    ['html', { open: 'never' }],
    ['list'],
  ],
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
    { name: 'firefox', use: { browserName: 'firefox' } },
    { name: 'webkit', use: { browserName: 'webkit' } },
  ],
};
```

## Advanced Usage

### Generate Test from Recording

```bash
# Record user interactions and generate test code
bash scripts/run.sh codegen --url https://example.com --output tests/recorded.spec.js
```

### Run Tests on Schedule (Cron)

```bash
# Add to crontab — run tests every hour
0 * * * * cd /path/to/project && bash scripts/run.sh test --dir tests/ --report html >> logs/test-runs.log 2>&1
```

### Multi-Browser Testing

```bash
# Run tests across all browsers
bash scripts/run.sh test --dir tests/ --browsers chromium,firefox,webkit
```

### Mobile Viewport Testing

```bash
# Test with mobile viewport
bash scripts/run.sh screenshot --url https://example.com \
  --viewport 375x812 --device "iPhone 13" --output mobile.png
```

### PDF Generation

```bash
# Generate PDF from webpage
bash scripts/run.sh pdf --url https://example.com --output page.pdf
```

## Troubleshooting

### Issue: "browserType.launch: Executable doesn't exist"

**Fix:** Install browsers:
```bash
npx playwright install
# Or install specific browser:
npx playwright install chromium
```

### Issue: "Missing system dependencies"

**Fix:**
```bash
# Ubuntu/Debian
npx playwright install-deps

# Or manually:
sudo apt-get install -y libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
  libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 \
  libgbm1 libpango-1.0-0 libcairo2 libasound2
```

### Issue: Tests timeout in CI

**Fix:** Increase timeout and use retry:
```bash
bash scripts/run.sh test --dir tests/ --timeout 60000 --retries 2
```

### Issue: Screenshots look wrong (wrong viewport)

**Fix:** Set explicit viewport:
```bash
bash scripts/run.sh screenshot --url https://example.com \
  --viewport 1920x1080 --output correct.png
```

## Examples

See `examples/` for:
- Login flow testing
- Multi-page screenshot capture
- API endpoint testing with browser context
- Visual regression workflow
- CI/CD integration examples

## Key Principles

1. **Headless by default** — No GUI needed, runs on servers
2. **Multi-browser** — Chromium, Firefox, WebKit all supported
3. **Rich reports** — HTML reports with screenshots and traces
4. **Fast** — Parallel test execution, browser reuse
5. **Reliable** — Auto-wait, smart selectors, retry on flake

## Dependencies

- `node` (18+)
- `npx` (comes with node)
- System libraries (installed via `playwright install-deps`)
