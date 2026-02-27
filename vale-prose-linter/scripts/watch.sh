#!/bin/bash
# Watch directory for changes and auto-lint
set -euo pipefail

TARGET="${1:-.}"

if ! command -v vale &>/dev/null; then
  echo "❌ Vale not installed. Run: bash scripts/install.sh"
  exit 1
fi

if ! command -v inotifywait &>/dev/null; then
  echo "❌ inotifywait not found. Install: sudo apt-get install inotify-tools"
  exit 1
fi

echo "👁️  Watching $TARGET for changes... (Ctrl+C to stop)"
echo ""

inotifywait -m -r -e modify,create --include '\.(md|txt|html|rst)$' "$TARGET" 2>/dev/null |
while read -r dir event file; do
  FILEPATH="${dir}${file}"
  echo "───────────────────────────────"
  echo "📝 Changed: $FILEPATH"
  vale "$FILEPATH" 2>/dev/null || true
  echo ""
done
