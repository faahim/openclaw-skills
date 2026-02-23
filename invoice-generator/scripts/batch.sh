#!/bin/bash
# Batch Invoice Generator — Process multiple JSON invoice files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_DIR=""
OUTPUT_DIR="."
TEMPLATE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --input) INPUT_DIR="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --template) TEMPLATE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$INPUT_DIR" ]]; then
  echo "Usage: batch.sh --input DIR [--output DIR] [--template FILE]"
  exit 1
fi

COUNT=0
ERRORS=0

for json_file in "$INPUT_DIR"/*.json; do
  [[ ! -f "$json_file" ]] && continue
  echo "Processing: $(basename "$json_file")"
  
  EXTRA_ARGS=()
  [[ -n "$TEMPLATE" ]] && EXTRA_ARGS+=(--template "$TEMPLATE")
  
  if bash "$SCRIPT_DIR/generate.sh" --json "$json_file" --output "$OUTPUT_DIR" "${EXTRA_ARGS[@]}"; then
    ((COUNT++))
  else
    echo "  ❌ Failed: $(basename "$json_file")"
    ((ERRORS++))
  fi
done

echo ""
echo "Done: $COUNT generated, $ERRORS errors"
