#!/bin/bash
# ClamAV — Watch directory for new files and scan in real-time
set -e

WATCH_PATH=""
QUARANTINE=false
ALERT=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
    case $1 in
        --path) WATCH_PATH="$2"; shift 2 ;;
        --quarantine) QUARANTINE=true; shift ;;
        --alert) ALERT="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$WATCH_PATH" ]]; then
    echo "Usage: bash watch.sh --path /var/www/uploads [--quarantine] [--alert telegram]"
    exit 1
fi

# Check for inotifywait
if ! command -v inotifywait &>/dev/null; then
    echo "❌ inotify-tools required. Install with:"
    echo "   sudo apt-get install inotify-tools"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 👁️  Watching $WATCH_PATH for new files..."
echo "Press Ctrl+C to stop"

SCAN_ARGS="--path"
[[ "$QUARANTINE" == true ]] && SCAN_EXTRA="--quarantine" || SCAN_EXTRA=""
[[ -n "$ALERT" ]] && SCAN_ALERT="--alert $ALERT" || SCAN_ALERT=""

inotifywait -m -r -e create -e moved_to "$WATCH_PATH" --format '%w%f' 2>/dev/null | while read -r NEW_FILE; do
    if [[ -f "$NEW_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔍 New file: $NEW_FILE"
        bash "$SCRIPT_DIR/scan.sh" --path "$NEW_FILE" $SCAN_EXTRA $SCAN_ALERT 2>&1 || true
    fi
done
