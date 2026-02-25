#!/bin/bash
# Pandoc Document Converter — Convert from URL
# Usage: bash url-convert.sh <url> <output-file> [pandoc-options...]

set -e

URL="$1"
OUTPUT="$2"
shift 2 2>/dev/null || true

if [[ -z "$URL" || -z "$OUTPUT" ]]; then
  echo "Usage: bash url-convert.sh <url> <output-file> [pandoc-options...]"
  echo ""
  echo "Examples:"
  echo "  bash url-convert.sh https://example.com/page output.md"
  echo "  bash url-convert.sh https://example.com/docs output.pdf"
  exit 1
fi

if ! command -v pandoc &>/dev/null; then
  echo "❌ Pandoc not found. Run: bash scripts/install.sh"
  exit 1
fi

# Fetch URL
TMPFILE=$(mktemp /tmp/pandoc-url-XXXXXX.html)
trap "rm -f $TMPFILE" EXIT

echo "⬇️  Fetching: $URL"
curl -sL --max-time 30 "$URL" -o "$TMPFILE"

if [[ ! -s "$TMPFILE" ]]; then
  echo "❌ Failed to fetch URL or empty response"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/convert.sh" "$TMPFILE" "$OUTPUT" "$@"
