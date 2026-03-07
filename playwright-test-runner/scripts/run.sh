#!/bin/bash
# Playwright Test Runner — Main Script
set -e

# Defaults
BROWSER="${PW_BROWSER:-chromium}"
VIEWPORT_W="${PW_VIEWPORT_WIDTH:-1920}"
VIEWPORT_H="${PW_VIEWPORT_HEIGHT:-1080}"
TIMEOUT="${PW_TIMEOUT:-30000}"
HEADLESS="${PW_HEADLESS:-true}"
FORMAT="${PW_SCREENSHOT_FORMAT:-png}"
REPORT_DIR="${PW_REPORT_DIR:-./playwright-report}"

COMMAND="$1"
shift || true

usage() {
  cat << 'EOF'
🎭 Playwright Test Runner

Usage: bash scripts/run.sh <command> [options]

Commands:
  screenshot      Take screenshot of a URL
  screenshot-batch Take screenshots of multiple URLs from file
  healthcheck     Check if URL loads, measure timing
  test            Run Playwright test file(s)
  linkcheck       Find broken links on a page
  perf            Page performance metrics
  pdf             Generate PDF from webpage
  codegen         Record and generate test code
  diff            Compare two screenshots

Screenshot Options:
  --url <url>         Target URL
  --output <file>     Output file path
  --full-page         Capture full scrollable page
  --viewport <WxH>    Viewport size (e.g. 375x812)
  --device <name>     Device emulation (e.g. "iPhone 13")

Test Options:
  --file <path>       Test file to run
  --dir <path>        Test directory
  --report <type>     Report format (html, list, json)
  --browsers <list>   Comma-separated browsers
  --timeout <ms>      Test timeout
  --retries <n>       Retry count

Linkcheck Options:
  --url <url>         URL to check
  --crawl             Follow internal links
  --depth <n>         Crawl depth (default: 1)

Environment Variables:
  PW_BROWSER          Browser (chromium/firefox/webkit)
  PW_VIEWPORT_WIDTH   Viewport width (default: 1920)
  PW_VIEWPORT_HEIGHT  Viewport height (default: 1080)
  PW_TIMEOUT          Timeout in ms (default: 30000)
  PW_HEADLESS         Headless mode (default: true)
EOF
  exit 0
}

# Parse common args
URL="" OUTPUT="" FULL_PAGE="" VIEWPORT="" DEVICE=""
TEST_FILE="" TEST_DIR="" REPORT="" BROWSERS="" RETRIES=""
CRAWL="" DEPTH="1" BASELINE="" CURRENT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --url) URL="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --full-page) FULL_PAGE="true"; shift ;;
    --viewport) VIEWPORT="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --file) TEST_FILE="$2"; shift 2 ;;
    --dir) TEST_DIR="$2"; shift 2 ;;
    --report) REPORT="$2"; shift 2 ;;
    --browsers) BROWSERS="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --retries) RETRIES="$2"; shift 2 ;;
    --crawl) CRAWL="true"; shift ;;
    --depth) DEPTH="$2"; shift 2 ;;
    --baseline) BASELINE="$2"; shift 2 ;;
    --current) CURRENT="$2"; shift 2 ;;
    --urls) URLS_FILE="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Screenshot ──────────────────────────────────────────────
cmd_screenshot() {
  [ -z "$URL" ] && { echo "❌ --url required"; exit 1; }
  [ -z "$OUTPUT" ] && OUTPUT="screenshot.${FORMAT}"

  local vp_arg=""
  if [ -n "$VIEWPORT" ]; then
    local w=$(echo "$VIEWPORT" | cut -dx -f1)
    local h=$(echo "$VIEWPORT" | cut -dx -f2)
    vp_arg="page.setViewportSize({width:${w},height:${h}});"
  fi

  local fp_arg="false"
  [ "$FULL_PAGE" = "true" ] && fp_arg="true"

  node -e "
    const { chromium, firefox, webkit } = require('playwright');
    (async () => {
      const browser = await ${BROWSER}.launch({ headless: ${HEADLESS} });
      const page = await browser.newPage({ viewport: { width: ${VIEWPORT_W}, height: ${VIEWPORT_H} } });
      ${vp_arg}
      await page.goto('${URL}', { timeout: ${TIMEOUT}, waitUntil: 'networkidle' });
      await page.screenshot({ path: '${OUTPUT}', fullPage: ${fp_arg}, type: '${FORMAT}' });
      await browser.close();
      console.log('📸 Screenshot saved: ${OUTPUT}');
    })().catch(e => { console.error('❌', e.message); process.exit(1); });
  "
}

# ── Screenshot Batch ────────────────────────────────────────
cmd_screenshot_batch() {
  [ -z "$URLS_FILE" ] && { echo "❌ --urls required"; exit 1; }
  [ -z "$OUTPUT_DIR" ] && OUTPUT_DIR="./screenshots"
  mkdir -p "$OUTPUT_DIR"

  local count=0
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    [[ "$url" == \#* ]] && continue
    local filename=$(echo "$url" | sed 's|https\?://||' | sed 's|[/:]|_|g').${FORMAT}
    bash scripts/run.sh screenshot --url "$url" --output "${OUTPUT_DIR}/${filename}" 2>&1
    count=$((count + 1))
  done < "$URLS_FILE"

  echo "📸 Captured ${count} screenshots in ${OUTPUT_DIR}/"
}

# ── Health Check ────────────────────────────────────────────
cmd_healthcheck() {
  [ -z "$URL" ] && { echo "❌ --url required"; exit 1; }

  node -e "
    const { chromium } = require('playwright');
    (async () => {
      const start = Date.now();
      const browser = await chromium.launch({ headless: true });
      const page = await browser.newPage();
      const response = await page.goto('${URL}', { timeout: ${TIMEOUT}, waitUntil: 'load' });
      const elapsed = ((Date.now() - start) / 1000).toFixed(1);
      const title = await page.title();
      const status = response.status();
      await browser.close();
      if (status >= 200 && status < 400) {
        console.log('✅ ${URL} — loaded in ' + elapsed + 's — title: \"' + title + '\" — status: ' + status);
      } else {
        console.log('❌ ${URL} — status: ' + status + ' — loaded in ' + elapsed + 's');
        process.exit(1);
      }
    })().catch(e => { console.error('❌ ${URL} —', e.message); process.exit(1); });
  "
}

# ── Test ────────────────────────────────────────────────────
cmd_test() {
  local args=""

  if [ -n "$TEST_FILE" ]; then
    args="$TEST_FILE"
  elif [ -n "$TEST_DIR" ]; then
    args="$TEST_DIR"
  fi

  if [ -n "$REPORT" ]; then
    args="$args --reporter=${REPORT}"
  fi

  if [ -n "$RETRIES" ]; then
    args="$args --retries=${RETRIES}"
  fi

  args="$args --timeout=${TIMEOUT}"

  if [ -n "$BROWSERS" ]; then
    IFS=',' read -ra BROWSER_LIST <<< "$BROWSERS"
    for b in "${BROWSER_LIST[@]}"; do
      echo "🌐 Running tests on ${b}..."
      npx playwright test $args --project="${b}"
    done
  else
    npx playwright test $args
  fi

  echo ""
  if [ "$REPORT" = "html" ]; then
    echo "📊 HTML report: ${REPORT_DIR}/index.html"
  fi
}

# ── Link Check ──────────────────────────────────────────────
cmd_linkcheck() {
  [ -z "$URL" ] && { echo "❌ --url required"; exit 1; }

  node -e "
    const { chromium } = require('playwright');
    const https = require('https');
    const http = require('http');
    const { URL } = require('url');

    async function checkUrl(url) {
      return new Promise((resolve) => {
        const mod = url.startsWith('https') ? https : http;
        const req = mod.get(url, { timeout: 10000 }, (res) => {
          resolve({ url, status: res.statusCode, ok: res.statusCode < 400 });
        });
        req.on('error', (e) => resolve({ url, status: 0, ok: false, error: e.message }));
        req.on('timeout', () => { req.destroy(); resolve({ url, status: 0, ok: false, error: 'timeout' }); });
      });
    }

    (async () => {
      const browser = await chromium.launch({ headless: true });
      const page = await browser.newPage();
      await page.goto('${URL}', { timeout: ${TIMEOUT}, waitUntil: 'networkidle' });

      const links = await page.evaluate(() =>
        [...document.querySelectorAll('a[href]')].map(a => a.href).filter(h => h.startsWith('http'))
      );

      const unique = [...new Set(links)];
      console.log('🔗 Checking ' + unique.length + ' links on ${URL}...');
      console.log('');

      let broken = 0;
      for (const link of unique) {
        const result = await checkUrl(link);
        if (result.ok) {
          console.log('✅ ' + link + ' — ' + result.status);
        } else {
          console.log('❌ ' + link + ' — ' + (result.status || result.error));
          broken++;
        }
      }

      console.log('');
      console.log('Summary: ' + unique.length + ' links checked, ' + broken + ' broken');

      await browser.close();
      if (broken > 0) process.exit(1);
    })().catch(e => { console.error('❌', e.message); process.exit(1); });
  "
}

# ── Performance ─────────────────────────────────────────────
cmd_perf() {
  [ -z "$URL" ] && { echo "❌ --url required"; exit 1; }

  node -e "
    const { chromium } = require('playwright');
    (async () => {
      const browser = await chromium.launch({ headless: true });
      const page = await browser.newPage();

      await page.goto('${URL}', { timeout: ${TIMEOUT}, waitUntil: 'networkidle' });

      const timing = await page.evaluate(() => {
        const t = performance.timing;
        return {
          domContentLoaded: t.domContentLoadedEventEnd - t.navigationStart,
          fullLoad: t.loadEventEnd - t.navigationStart,
          firstPaint: performance.getEntriesByType('paint').find(p => p.name === 'first-paint')?.startTime || 0,
        };
      });

      const metrics = await page.evaluate(() => {
        const entries = performance.getEntriesByType('resource');
        const totalSize = entries.reduce((s, e) => s + (e.transferSize || 0), 0);
        return { requests: entries.length, totalSizeKB: Math.round(totalSize / 1024) };
      });

      const errors = await page.evaluate(() => window.__pw_console_errors || 0);

      console.log('⚡ Performance Report: ${URL}');
      console.log('');
      console.log('  DOM Content Loaded: ' + (timing.domContentLoaded / 1000).toFixed(1) + 's');
      console.log('  Full Page Load:     ' + (timing.fullLoad / 1000).toFixed(1) + 's');
      console.log('  First Paint:        ' + (timing.firstPaint / 1000).toFixed(1) + 's');
      console.log('  Page Size:          ' + metrics.totalSizeKB + ' KB');
      console.log('  Requests:           ' + metrics.requests);
      console.log('');

      if (timing.fullLoad < 3000) {
        console.log('  ✅ Page loads within acceptable range');
      } else {
        console.log('  ⚠️  Page load exceeds 3s — consider optimization');
      }

      await browser.close();
    })().catch(e => { console.error('❌', e.message); process.exit(1); });
  "
}

# ── PDF ─────────────────────────────────────────────────────
cmd_pdf() {
  [ -z "$URL" ] && { echo "❌ --url required"; exit 1; }
  [ -z "$OUTPUT" ] && OUTPUT="page.pdf"

  node -e "
    const { chromium } = require('playwright');
    (async () => {
      const browser = await chromium.launch({ headless: true });
      const page = await browser.newPage();
      await page.goto('${URL}', { timeout: ${TIMEOUT}, waitUntil: 'networkidle' });
      await page.pdf({ path: '${OUTPUT}', format: 'A4', printBackground: true });
      await browser.close();
      console.log('📄 PDF saved: ${OUTPUT}');
    })().catch(e => { console.error('❌', e.message); process.exit(1); });
  "
}

# ── Codegen ─────────────────────────────────────────────────
cmd_codegen() {
  [ -z "$URL" ] && { echo "❌ --url required"; exit 1; }
  local out_arg=""
  [ -n "$OUTPUT" ] && out_arg="-o ${OUTPUT}"
  npx playwright codegen ${out_arg} "$URL"
}

# ── Diff ────────────────────────────────────────────────────
cmd_diff() {
  [ -z "$BASELINE" ] && { echo "❌ --baseline required"; exit 1; }
  [ -z "$CURRENT" ] && { echo "❌ --current required"; exit 1; }
  [ -z "$OUTPUT" ] && OUTPUT="diff.png"

  if ! command -v compare &>/dev/null; then
    echo "❌ ImageMagick 'compare' required for visual diff"
    echo "   Install: sudo apt-get install imagemagick"
    exit 1
  fi

  compare -metric RMSE "$BASELINE" "$CURRENT" "$OUTPUT" 2>&1 || true
  echo "📊 Visual diff saved: ${OUTPUT}"
}

# ── Dispatch ────────────────────────────────────────────────
case "$COMMAND" in
  screenshot) cmd_screenshot ;;
  screenshot-batch) cmd_screenshot_batch ;;
  healthcheck) cmd_healthcheck ;;
  test) cmd_test ;;
  linkcheck) cmd_linkcheck ;;
  perf) cmd_perf ;;
  pdf) cmd_pdf ;;
  codegen) cmd_codegen ;;
  diff) cmd_diff ;;
  -h|--help|"") usage ;;
  *) echo "❌ Unknown command: $COMMAND"; usage ;;
esac
