#!/bin/bash
# SVG Optimizer — Main Script
# Batch-optimize SVG files using svgo
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT=""
OUTPUT=""
INPLACE=false
AGGRESSIVE=false
WEB_SAFE=false
WATCH=false
REPORT=false
CONFIG=""
REPORT_FILE="optimization-report.csv"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --input|-i) INPUT="$2"; shift 2 ;;
    --output|-o) OUTPUT="$2"; shift 2 ;;
    --inplace) INPLACE=true; shift ;;
    --aggressive) AGGRESSIVE=true; shift ;;
    --web-safe) WEB_SAFE=true; shift ;;
    --watch|-w) WATCH=true; shift ;;
    --report|-r) REPORT=true; shift ;;
    --report-file) REPORT_FILE="$2"; shift 2 ;;
    --config|-c) CONFIG="$2"; shift 2 ;;
    --help|-h)
      echo "SVG Optimizer — Batch-optimize SVG files"
      echo ""
      echo "Usage: bash run.sh --input <file|dir> [--output <dir>] [options]"
      echo ""
      echo "Options:"
      echo "  --input, -i      Input SVG file or directory (required)"
      echo "  --output, -o     Output directory (required unless --inplace)"
      echo "  --inplace        Optimize files in-place (overwrites originals)"
      echo "  --aggressive     Maximum compression mode"
      echo "  --web-safe       Preserve accessibility attrs (title, desc, aria)"
      echo "  --watch, -w      Watch for changes and auto-optimize"
      echo "  --report, -r     Generate CSV optimization report"
      echo "  --report-file    Report filename (default: optimization-report.csv)"
      echo "  --config, -c     Custom svgo config file"
      echo "  --help, -h       Show this help"
      exit 0
      ;;
    *) echo "❌ Unknown option: $1"; exit 1 ;;
  esac
done

# Validate
if [ -z "$INPUT" ]; then
  echo "❌ --input is required. Use --help for usage."
  exit 1
fi

if [ "$INPLACE" = false ] && [ -z "$OUTPUT" ]; then
  echo "❌ Either --output or --inplace is required."
  exit 1
fi

# Check svgo
if ! command -v svgo &>/dev/null; then
  echo "❌ svgo not found. Run: bash scripts/install.sh"
  exit 1
fi

# Determine config
SVGO_ARGS="--multipass"

if [ -n "$CONFIG" ]; then
  SVGO_ARGS="$SVGO_ARGS --config $CONFIG"
elif [ "$AGGRESSIVE" = true ]; then
  SVGO_ARGS="$SVGO_ARGS --config $SCRIPT_DIR/presets/aggressive.mjs"
elif [ "$WEB_SAFE" = true ]; then
  SVGO_ARGS="$SVGO_ARGS --config $SCRIPT_DIR/presets/web-safe.mjs"
fi

# Initialize report
if [ "$REPORT" = true ]; then
  echo "file,original_bytes,optimized_bytes,reduction_pct" > "$REPORT_FILE"
fi

# Track totals
TOTAL_ORIGINAL=0
TOTAL_OPTIMIZED=0
FILE_COUNT=0

optimize_file() {
  local src="$1"
  local dst="$2"

  local original_size=$(stat -c%s "$src" 2>/dev/null || stat -f%z "$src")

  # Run svgo
  svgo $SVGO_ARGS --input "$src" --output "$dst" --quiet 2>/dev/null

  local optimized_size=$(stat -c%s "$dst" 2>/dev/null || stat -f%z "$dst")
  local reduction=0
  if [ "$original_size" -gt 0 ]; then
    reduction=$(echo "scale=1; (1 - $optimized_size / $original_size) * 100" | bc 2>/dev/null || echo "0")
  fi

  local orig_kb=$(echo "scale=1; $original_size / 1024" | bc 2>/dev/null || echo "$original_size")
  local opt_kb=$(echo "scale=1; $optimized_size / 1024" | bc 2>/dev/null || echo "$optimized_size")
  local basename=$(basename "$src")

  echo "✅ $basename: ${orig_kb} KB → ${opt_kb} KB (${reduction}% reduction)"

  TOTAL_ORIGINAL=$((TOTAL_ORIGINAL + original_size))
  TOTAL_OPTIMIZED=$((TOTAL_OPTIMIZED + optimized_size))
  FILE_COUNT=$((FILE_COUNT + 1))

  if [ "$REPORT" = true ]; then
    echo "$basename,$original_size,$optimized_size,$reduction" >> "$REPORT_FILE"
  fi
}

# Watch mode
if [ "$WATCH" = true ]; then
  if ! command -v chokidar &>/dev/null; then
    echo "❌ Watch mode requires chokidar-cli. Install: npm i -g chokidar-cli"
    exit 1
  fi
  echo "👁️  Watching $INPUT for changes... (Ctrl+C to stop)"
  chokidar "$INPUT/**/*.svg" -c "svgo $SVGO_ARGS --input {path} --output ${OUTPUT}/{event.filename} --quiet && echo '✅ Optimized: {path}'"
  exit 0
fi

# Single file mode
if [ -f "$INPUT" ]; then
  if [ "$INPLACE" = true ]; then
    optimize_file "$INPUT" "$INPUT"
  else
    mkdir -p "$(dirname "$OUTPUT")"
    optimize_file "$INPUT" "$OUTPUT"
  fi
else
  # Directory mode
  if [ ! -d "$INPUT" ]; then
    echo "❌ Input not found: $INPUT"
    exit 1
  fi

  if [ "$INPLACE" = true ]; then
    echo "⚠️  In-place mode: originals will be overwritten"
    for svg in "$INPUT"/*.svg "$INPUT"/**/*.svg; do
      [ -f "$svg" ] || continue
      optimize_file "$svg" "$svg"
    done
  else
    mkdir -p "$OUTPUT"
    for svg in "$INPUT"/*.svg "$INPUT"/**/*.svg; do
      [ -f "$svg" ] || continue
      local_path="${svg#$INPUT/}"
      dst_dir="$OUTPUT/$(dirname "$local_path")"
      mkdir -p "$dst_dir"
      optimize_file "$svg" "$OUTPUT/$local_path"
    done
  fi
fi

# Summary
if [ "$FILE_COUNT" -gt 1 ]; then
  total_orig_kb=$(echo "scale=1; $TOTAL_ORIGINAL / 1024" | bc 2>/dev/null || echo "$TOTAL_ORIGINAL")
  total_opt_kb=$(echo "scale=1; $TOTAL_OPTIMIZED / 1024" | bc 2>/dev/null || echo "$TOTAL_OPTIMIZED")
  total_reduction=0
  if [ "$TOTAL_ORIGINAL" -gt 0 ]; then
    total_reduction=$(echo "scale=1; (1 - $TOTAL_OPTIMIZED / $TOTAL_ORIGINAL) * 100" | bc 2>/dev/null || echo "0")
  fi
  echo "─────────────────────────────────"
  echo "Total: ${total_orig_kb} KB → ${total_opt_kb} KB (${total_reduction}% reduction, $FILE_COUNT files)"
fi

if [ "$REPORT" = true ]; then
  echo "📊 Report saved to: $REPORT_FILE"
fi
