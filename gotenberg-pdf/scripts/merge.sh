#!/bin/bash
# Gotenberg PDF API — Merge multiple PDFs
set -e

PORT="${GOTENBERG_PORT:-3000}"
BASE_URL="http://localhost:${PORT}"
OUTPUT=""
FILES=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --output|-o) OUTPUT="$2"; shift 2 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

[[ ${#FILES[@]} -lt 2 ]] && echo "❌ Need at least 2 PDF files to merge" && echo "Usage: bash scripts/merge.sh file1.pdf file2.pdf --output merged.pdf" && exit 1
OUTPUT="${OUTPUT:-merged.pdf}"

echo "🔗 Merging ${#FILES[@]} PDFs..."

CURL_ARGS=(-f -X POST)
for f in "${FILES[@]}"; do
  [[ ! -f "$f" ]] && echo "❌ File not found: $f" && exit 1
  CURL_ARGS+=(-F "files=@${f}")
done
CURL_ARGS+=("${BASE_URL}/forms/pdfengines/merge" -o "$OUTPUT")

curl "${CURL_ARGS[@]}"

if [[ -f "$OUTPUT" ]]; then
  SIZE=$(du -h "$OUTPUT" | cut -f1)
  echo "✅ Merged: $OUTPUT ($SIZE)"
else
  echo "❌ Merge failed"
  exit 1
fi
