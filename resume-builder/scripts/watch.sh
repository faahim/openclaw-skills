#!/bin/bash
# Resume Builder — Watch Mode (auto-rebuild on changes)
set -e

INPUT="$1"
SHIFT_ARGS="${@:2}"

if [[ -z "$INPUT" ]]; then
    echo "Usage: bash watch.sh <resume.yaml> [build options...]"
    exit 1
fi

if ! command -v inotifywait &>/dev/null; then
    echo "❌ inotifywait not found. Install:"
    echo "   sudo apt-get install inotify-tools  # Debian/Ubuntu"
    echo "   sudo dnf install inotify-tools       # Fedora"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "👀 Watching $INPUT for changes... (Ctrl+C to stop)"
echo ""

# Initial build
bash "$SCRIPT_DIR/build.sh" "$INPUT" $SHIFT_ARGS

# Watch for changes
while inotifywait -q -e modify "$INPUT" >/dev/null 2>&1; do
    echo ""
    echo "🔄 Change detected, rebuilding..."
    bash "$SCRIPT_DIR/build.sh" "$INPUT" $SHIFT_ARGS
done
