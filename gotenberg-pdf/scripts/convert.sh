#!/bin/bash
# Gotenberg PDF API — Convert files to PDF
set -e

PORT="${GOTENBERG_PORT:-3000}"
BASE_URL="http://localhost:${PORT}"
OUTPUT=""
MODE=""
FILES=()
URL_VALUE=""
PAPER_WIDTH=""
PAPER_HEIGHT=""
MARGIN_TOP=""
MARGIN_BOTTOM=""
MARGIN_LEFT=""
MARGIN_RIGHT=""
PRINT_BG=""
WAIT_DELAY=""
LANDSCAPE=""
MERGE=false

usage() {
  cat <<EOF
Usage: bash scripts/convert.sh [options]

Modes (pick one):
  --html <file>          Convert HTML file to PDF (Chromium)
  --url <url>            Convert URL to PDF (Chromium)
  --markdown <file>      Convert Markdown to PDF (Chromium)
  --office <file(s)>     Convert Office docs to PDF (LibreOffice)

Output:
  --output, -o <file>    Output PDF path (default: output.pdf)

Options:
  --paper-width <in>     Paper width in inches (default: 8.5)
  --paper-height <in>    Paper height in inches (default: 11)
  --margin-top <in>      Top margin in inches
  --margin-bottom <in>   Bottom margin
  --margin-left <in>     Left margin
  --margin-right <in>    Right margin
  --landscape            Landscape orientation
  --print-background     Include background colors/images
  --wait-delay <dur>     Wait before converting (e.g., 3s)
  --merge                Merge multiple files into one PDF
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --html) MODE="html"; FILES+=("$2"); shift 2 ;;
    --url) MODE="url"; URL_VALUE="$2"; shift 2 ;;
    --markdown) MODE="markdown"; FILES+=("$2"); shift 2 ;;
    --office) MODE="office"; shift
      while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do FILES+=("$1"); shift; done ;;
    --output|-o) OUTPUT="$2"; shift 2 ;;
    --paper-width) PAPER_WIDTH="$2"; shift 2 ;;
    --paper-height) PAPER_HEIGHT="$2"; shift 2 ;;
    --margin-top) MARGIN_TOP="$2"; shift 2 ;;
    --margin-bottom) MARGIN_BOTTOM="$2"; shift 2 ;;
    --margin-left) MARGIN_LEFT="$2"; shift 2 ;;
    --margin-right) MARGIN_RIGHT="$2"; shift 2 ;;
    --landscape) LANDSCAPE="true"; shift ;;
    --print-background) PRINT_BG="true"; shift ;;
    --wait-delay) WAIT_DELAY="$2"; shift 2 ;;
    --merge) MERGE=true; shift ;;
    *) echo "Unknown: $1"; usage ;;
  esac
done

[[ -z "$MODE" ]] && echo "❌ Specify a mode: --html, --url, --markdown, or --office" && usage
OUTPUT="${OUTPUT:-output.pdf}"

# Build curl args
CURL_ARGS=(-f -X POST)

add_option() {
  local key="$1" val="$2"
  [[ -n "$val" ]] && CURL_ARGS+=(-F "${key}=${val}")
}

add_option "paperWidth" "$PAPER_WIDTH"
add_option "paperHeight" "$PAPER_HEIGHT"
add_option "marginTop" "$MARGIN_TOP"
add_option "marginBottom" "$MARGIN_BOTTOM"
add_option "marginLeft" "$MARGIN_LEFT"
add_option "marginRight" "$MARGIN_RIGHT"
add_option "landscape" "$LANDSCAPE"
add_option "printBackground" "$PRINT_BG"
add_option "waitDelay" "$WAIT_DELAY"

case "$MODE" in
  html)
    [[ ! -f "${FILES[0]}" ]] && echo "❌ File not found: ${FILES[0]}" && exit 1
    echo "📄 Converting HTML → PDF..."
    CURL_ARGS+=(-F "files=@${FILES[0]}")
    CURL_ARGS+=("${BASE_URL}/forms/chromium/convert/html")
    ;;
  url)
    echo "🌐 Converting URL → PDF..."
    CURL_ARGS+=(-F "url=${URL_VALUE}")
    CURL_ARGS+=("${BASE_URL}/forms/chromium/convert/url")
    ;;
  markdown)
    [[ ! -f "${FILES[0]}" ]] && echo "❌ File not found: ${FILES[0]}" && exit 1
    echo "📝 Converting Markdown → PDF..."
    # Wrap markdown in HTML for Chromium
    TMPHTML=$(mktemp /tmp/gotenberg-md-XXXX.html)
    cat > "$TMPHTML" <<MDEOF
<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; }
  code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
  pre { background: #f4f4f4; padding: 16px; border-radius: 6px; overflow-x: auto; }
  h1, h2, h3 { margin-top: 1.5em; }
  blockquote { border-left: 4px solid #ddd; margin-left: 0; padding-left: 16px; color: #666; }
</style>
</head><body>
$(cat "${FILES[0]}")
</body></html>
MDEOF
    CURL_ARGS+=(-F "files=@${TMPHTML}")
    CURL_ARGS+=("${BASE_URL}/forms/chromium/convert/html")
    ;;
  office)
    echo "📊 Converting Office doc(s) → PDF..."
    for f in "${FILES[@]}"; do
      [[ ! -f "$f" ]] && echo "❌ File not found: $f" && exit 1
      CURL_ARGS+=(-F "files=@${f}")
    done
    if [[ "$MERGE" == true && ${#FILES[@]} -gt 1 ]]; then
      CURL_ARGS+=(-F "merge=true")
    fi
    CURL_ARGS+=("${BASE_URL}/forms/libreoffice/convert")
    ;;
esac

CURL_ARGS+=(-o "$OUTPUT")

curl "${CURL_ARGS[@]}"

if [[ -f "$OUTPUT" ]]; then
  SIZE=$(du -h "$OUTPUT" | cut -f1)
  echo "✅ Created: $OUTPUT ($SIZE)"
else
  echo "❌ Conversion failed"
  exit 1
fi

# Cleanup temp files
[[ -n "${TMPHTML:-}" ]] && rm -f "$TMPHTML"
