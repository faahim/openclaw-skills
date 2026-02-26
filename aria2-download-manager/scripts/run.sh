#!/bin/bash
# Aria2 Download Manager — Main Script
set -e

# Defaults
URLS=()
SPLIT="${ARIA2_SPLIT:-16}"
DIR="${ARIA2_DIR:-$HOME/Downloads}"
MAX_SPEED="0"
MAX_CONCURRENT="5"
BATCH=""
TORRENT=""
HEADERS=()
SEED_RATIO="1.0"
EXTRA_ARGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --url) URLS+=("$2"); shift 2 ;;
        --split) SPLIT="$2"; shift 2 ;;
        --dir) DIR="$2"; shift 2 ;;
        --max-speed) MAX_SPEED="$2"; shift 2 ;;
        --max-concurrent) MAX_CONCURRENT="$2"; shift 2 ;;
        --batch) BATCH="$2"; shift 2 ;;
        --torrent) TORRENT="$2"; shift 2 ;;
        --header) HEADERS+=("--header=$2"); shift 2 ;;
        --seed-ratio) SEED_RATIO="$2"; shift 2 ;;
        *) EXTRA_ARGS+=("$1"); shift ;;
    esac
done

# Check aria2 is installed
if ! command -v aria2c &>/dev/null; then
    echo "❌ aria2c not found. Run: bash scripts/install.sh"
    exit 1
fi

# Build base args
BASE_ARGS=(
    --dir="$DIR"
    --split="$SPLIT"
    --max-connection-per-server="$SPLIT"
    --max-concurrent-downloads="$MAX_CONCURRENT"
    --max-overall-download-limit="$MAX_SPEED"
    --continue=true
    --min-split-size=1M
    --auto-file-renaming=true
    --console-log-level=notice
    --summary-interval=5
    --file-allocation=falloc
)

# Load config if exists
if [ -f ~/.aria2/aria2.conf ]; then
    BASE_ARGS+=(--conf-path="$HOME/.aria2/aria2.conf")
fi

# Add session for resume support
if [ -f ~/.aria2/aria2.session ]; then
    BASE_ARGS+=(--input-file="$HOME/.aria2/aria2.session")
    BASE_ARGS+=(--save-session="$HOME/.aria2/aria2.session")
fi

# Add headers
BASE_ARGS+=("${HEADERS[@]}")

# Add extra args
BASE_ARGS+=("${EXTRA_ARGS[@]}")

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Mode: Torrent
if [ -n "$TORRENT" ]; then
    echo "[$TIMESTAMP] 🧲 Downloading torrent: $TORRENT"
    aria2c "${BASE_ARGS[@]}" \
        --seed-ratio="$SEED_RATIO" \
        --enable-dht=true \
        --enable-peer-exchange=true \
        "$TORRENT"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Torrent download complete"
    exit 0
fi

# Mode: Batch
if [ -n "$BATCH" ]; then
    if [ ! -f "$BATCH" ]; then
        echo "❌ Batch file not found: $BATCH"
        exit 1
    fi
    TOTAL=$(wc -l < "$BATCH")
    echo "[$TIMESTAMP] 📦 Batch download: $TOTAL URLs from $BATCH"
    aria2c "${BASE_ARGS[@]}" --input-file="$BATCH"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Batch download complete ($TOTAL files)"
    exit 0
fi

# Mode: Direct URL(s)
if [ ${#URLS[@]} -gt 0 ]; then
    if [ ${#URLS[@]} -eq 1 ]; then
        FILENAME=$(basename "${URLS[0]%%\?*}")
        echo "[$TIMESTAMP] ⬇️  Downloading: $FILENAME"
        echo "[$TIMESTAMP] 📊 Connections: $SPLIT | Max speed: ${MAX_SPEED:-unlimited}"
    else
        echo "[$TIMESTAMP] 🔗 Mirror download from ${#URLS[@]} sources"
    fi
    aria2c "${BASE_ARGS[@]}" "${URLS[@]}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Download complete"
    exit 0
fi

echo "Usage: bash run.sh [OPTIONS]"
echo ""
echo "Options:"
echo "  --url URL          URL to download (repeat for mirrors)"
echo "  --torrent PATH     Torrent file or magnet link"
echo "  --batch FILE       Text file with URLs (one per line)"
echo "  --split N          Connections per file (default: 16)"
echo "  --dir PATH         Download directory (default: ~/Downloads)"
echo "  --max-speed LIMIT  Speed limit (e.g., 5M, 500K, 0=unlimited)"
echo "  --max-concurrent N Max simultaneous downloads (default: 5)"
echo "  --header 'K: V'    Custom HTTP header (repeat for multiple)"
echo "  --seed-ratio N     BitTorrent seed ratio (default: 1.0)"
exit 1
