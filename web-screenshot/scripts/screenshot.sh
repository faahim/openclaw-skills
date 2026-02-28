#!/bin/bash
# Web Screenshot — Capture web pages as images using headless Chromium
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Defaults
URL=""
OUTPUT="screenshot.png"
OUTPUT_DIR=""
FORMAT="png"
QUALITY=80
WIDTH="${SCREENSHOT_WIDTH:-1280}"
HEIGHT="${SCREENSHOT_HEIGHT:-720}"
DEVICE_SCALE=1
FULL_PAGE="false"
DELAY=0
WAIT_UNTIL="load"
WAIT_FOR=""
TIMEOUT=30000
SELECTOR=""
DARK_MODE="false"
INJECT_CSS=""
USER_AGENT=""
AUTH=""
BATCH_FILE=""
NO_JS="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --url) URL="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --quality) QUALITY="$2"; shift 2 ;;
    --width) WIDTH="$2"; shift 2 ;;
    --height) HEIGHT="$2"; shift 2 ;;
    --device-scale) DEVICE_SCALE="$2"; shift 2 ;;
    --full-page) FULL_PAGE="true"; shift ;;
    --delay) DELAY="$2"; shift 2 ;;
    --wait-until) WAIT_UNTIL="$2"; shift 2 ;;
    --wait-for) WAIT_FOR="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --selector) SELECTOR="$2"; shift 2 ;;
    --dark-mode) DARK_MODE="true"; shift ;;
    --inject-css) INJECT_CSS="$2"; shift 2 ;;
    --user-agent) USER_AGENT="$2"; shift 2 ;;
    --auth) AUTH="$2"; shift 2 ;;
    --batch) BATCH_FILE="$2"; shift 2 ;;
    --no-javascript) NO_JS="true"; shift ;;
    --help|-h) 
      echo "Usage: bash screenshot.sh --url <url> [options]"
      echo ""
      echo "Options:"
      echo "  --url <url>            URL to capture"
      echo "  --output <path>        Output file (default: screenshot.png)"
      echo "  --output-dir <dir>     Output directory for batch mode"
      echo "  --format <png|jpeg>    Image format (default: png)"
      echo "  --quality <1-100>      JPEG quality (default: 80)"
      echo "  --width <px>           Viewport width (default: 1280)"
      echo "  --height <px>          Viewport height (default: 720)"
      echo "  --device-scale <n>     Device scale factor (default: 1)"
      echo "  --full-page            Capture full scrollable page"
      echo "  --delay <ms>           Wait before capture"
      echo "  --wait-until <event>   load|domcontentloaded|networkidle"
      echo "  --wait-for <selector>  Wait for CSS selector"
      echo "  --timeout <ms>         Navigation timeout (default: 30000)"
      echo "  --selector <css>       Capture specific element"
      echo "  --dark-mode            Enable dark color scheme"
      echo "  --inject-css <css>     Inject CSS before capture"
      echo "  --user-agent <string>  Custom user agent"
      echo "  --auth <user:pass>     HTTP basic auth"
      echo "  --batch <file>         File with URLs (one per line)"
      echo "  --no-javascript        Disable JavaScript"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate
if [ -z "$URL" ] && [ -z "$BATCH_FILE" ]; then
  echo "❌ Error: --url or --batch required"
  echo "   Usage: bash screenshot.sh --url https://example.com --output shot.png"
  exit 1
fi

# Check Playwright
if [ ! -d "$SKILL_DIR/node_modules/playwright" ]; then
  echo "❌ Playwright not installed. Run: bash scripts/install.sh"
  exit 1
fi

# Build the Node.js screenshot script
capture_url() {
  local target_url="$1"
  local target_output="$2"

  # Create output directory if needed
  mkdir -p "$(dirname "$target_output")"

  cd "$SKILL_DIR"

  # Auto-detect Chromium executable
  CHROMIUM_PATH=""
  for p in "$HOME/.cache/ms-playwright"/chromium-*/chrome-linux/chrome "$HOME/.cache/ms-playwright"/chromium-*/chrome-linux/headless_shell; do
    [ -x "$p" ] && CHROMIUM_PATH="$p" && break
  done

  node -e "
const { chromium } = require('playwright');

(async () => {
  const launchOpts = { headless: true };
  const execPath = '${CHROMIUM_PATH}';
  if (execPath) launchOpts.executablePath = execPath;
  const browser = await chromium.launch(launchOpts);
  const context = await browser.newContext({
    viewport: { width: ${WIDTH}, height: ${HEIGHT} },
    deviceScaleFactor: ${DEVICE_SCALE},
    colorScheme: '${DARK_MODE}' === 'true' ? 'dark' : 'light',
    javaScriptEnabled: '${NO_JS}' !== 'true',
    ${USER_AGENT:+"userAgent: '${USER_AGENT}',"}
    ${AUTH:+"httpCredentials: { username: '${AUTH%%:*}', password: '${AUTH#*:}' },"}
  });

  const page = await context.newPage();

  try {
    await page.goto('${target_url}', {
      waitUntil: '${WAIT_UNTIL}',
      timeout: ${TIMEOUT}
    });

    // Wait for selector if specified
    const waitFor = '${WAIT_FOR}';
    if (waitFor) {
      await page.waitForSelector(waitFor, { timeout: ${TIMEOUT} });
    }

    // Inject CSS if specified
    const css = \`${INJECT_CSS}\`;
    if (css) {
      await page.addStyleTag({ content: css });
      await page.waitForTimeout(500);
    }

    // Delay if specified
    if (${DELAY} > 0) {
      await page.waitForTimeout(${DELAY});
    }

    // Screenshot options
    const opts = {
      path: '${target_output}',
      fullPage: ${FULL_PAGE},
      type: '${FORMAT}',
    };
    if ('${FORMAT}' === 'jpeg') opts.quality = ${QUALITY};

    // Element or full page
    const selector = '${SELECTOR}';
    if (selector) {
      const el = await page.\$(selector);
      if (!el) { console.error('❌ Selector not found: ' + selector); process.exit(1); }
      await el.screenshot(opts);
    } else {
      await page.screenshot(opts);
    }

    // Get file size
    const fs = require('fs');
    const stat = fs.statSync('${target_output}');
    const size = stat.size > 1024*1024
      ? (stat.size/(1024*1024)).toFixed(1) + 'MB'
      : (stat.size/1024).toFixed(0) + 'KB';

    console.log('✅ Screenshot saved: ${target_output} (' + size + ')');
  } catch (err) {
    console.error('❌ Failed: ' + err.message);
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
"
}

# Single URL mode
if [ -n "$URL" ] && [ -z "$BATCH_FILE" ]; then
  capture_url "$URL" "$OUTPUT"
  exit 0
fi

# Batch mode
if [ -n "$BATCH_FILE" ]; then
  if [ ! -f "$BATCH_FILE" ]; then
    echo "❌ Batch file not found: $BATCH_FILE"
    exit 1
  fi

  OUTPUT_DIR="${OUTPUT_DIR:-captures}"
  mkdir -p "$OUTPUT_DIR"

  TOTAL=$(grep -c '[^[:space:]]' "$BATCH_FILE")
  COUNT=0
  FAIL=0

  while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    COUNT=$((COUNT + 1))
    # Generate filename from URL
    FILENAME=$(echo "$line" | sed 's|https\?://||;s|/|_|g;s|[^a-zA-Z0-9._-]|_|g')
    FILEPATH="$OUTPUT_DIR/${FILENAME}.${FORMAT}"

    echo "📸 [$COUNT/$TOTAL] $line"
    if capture_url "$line" "$FILEPATH" 2>&1; then
      :
    else
      FAIL=$((FAIL + 1))
      echo "⚠️  Failed: $line"
    fi
  done < "$BATCH_FILE"

  echo ""
  echo "Done: $((COUNT - FAIL))/$COUNT captured ($FAIL failed)"
  exit 0
fi
