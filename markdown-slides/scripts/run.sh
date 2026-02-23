#!/bin/bash
# Markdown Slides — Convert Markdown to presentations
set -e

INPUT=""
FORMAT="html"
OUTPUT=""
THEME=""
WATCH=false
HTML_TAGS=false

usage() {
  echo "Usage: bash scripts/run.sh [options]"
  echo ""
  echo "Options:"
  echo "  --input FILE|DIR     Markdown file or directory to convert (required)"
  echo "  --format FORMAT      Output format: html, pdf, pptx, all (default: html)"
  echo "  --output DIR         Output directory (default: same as input)"
  echo "  --theme FILE         Custom CSS theme file"
  echo "  --watch              Start live preview server"
  echo "  --html-tags          Allow HTML in slides"
  echo "  -h, --help           Show this help"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --input) INPUT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --theme) THEME="$2"; shift 2 ;;
    --watch) WATCH=true; shift ;;
    --html-tags) HTML_TAGS=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$INPUT" ]]; then
  echo "❌ --input is required"
  usage
fi

if [[ ! -e "$INPUT" ]]; then
  echo "❌ Input not found: $INPUT"
  exit 1
fi

# Find marp command
MARP=""
if command -v marp &>/dev/null; then
  MARP="marp"
elif command -v npx &>/dev/null; then
  MARP="npx @marp-team/marp-cli"
else
  echo "❌ Marp CLI not found. Run: bash scripts/install.sh"
  exit 1
fi

# Build command
CMD="$MARP"

# Prevent stdin hang + allow local files
CMD="$CMD --no-stdin --allow-local-files"

# HTML tags
if $HTML_TAGS; then
  CMD="$CMD --html"
fi

# Theme
if [[ -n "$THEME" ]]; then
  CMD="$CMD --theme \"$THEME\""
fi

# Output directory
if [[ -n "$OUTPUT" ]]; then
  mkdir -p "$OUTPUT"
  CMD="$CMD --output \"$OUTPUT\""
fi

# Watch mode
if $WATCH; then
  echo "👁️ Starting live preview for $INPUT..."
  eval $CMD --preview "$INPUT"
  exit 0
fi

# Convert function
convert() {
  local fmt=$1
  local flag=""
  case $fmt in
    html) flag="--html" ;;  # default output is HTML
    pdf) flag="--pdf" ;;
    pptx) flag="--pptx" ;;
    *) echo "❌ Unknown format: $fmt"; exit 1 ;;
  esac

  echo "📄 Converting to $fmt..."

  if [[ -d "$INPUT" ]]; then
    # Directory mode — convert all .md files
    for f in "$INPUT"/*.md; do
      [[ -f "$f" ]] || continue
      echo "  → $(basename "$f")"
      eval $CMD $flag "$f"
    done
  else
    eval $CMD $flag "$INPUT"
  fi

  echo "✅ $fmt export complete!"
}

# Execute
if [[ "$FORMAT" == "all" ]]; then
  convert html
  convert pdf
  convert pptx
else
  convert "$FORMAT"
fi

echo ""
echo "🎉 Done! Slides ready."
