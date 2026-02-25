#!/bin/bash
# Mount rclone remote as local directory
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <remote:path> <mountpoint> [options]

Mount a remote storage location as a local directory.

Options:
  --vfs-cache-mode MODE   Cache mode: off|minimal|writes|full (default: writes)
  --vfs-cache-max-size S  Max cache size (e.g., 5G, 500M)
  --read-only             Mount as read-only
  --daemon                Run in background
  --allow-other           Allow other users to access mount

Examples:
  $(basename "$0") s3:my-bucket /mnt/s3
  $(basename "$0") gdrive:Documents /mnt/gdrive --vfs-cache-mode full --daemon
  $(basename "$0") b2:backups /mnt/backups --read-only

Unmount:
  fusermount -u /mnt/s3
  # or: umount /mnt/s3
EOF
  exit 0
}

REMOTE="${1:-}"
MOUNTPOINT="${2:-}"
shift 2 2>/dev/null || true

if [[ -z "$REMOTE" || -z "$MOUNTPOINT" ]]; then
  usage
fi

EXTRA_ARGS=()
CACHE_MODE="writes"
DAEMON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vfs-cache-mode) CACHE_MODE="$2"; shift 2 ;;
    --vfs-cache-max-size) EXTRA_ARGS+=("--vfs-cache-max-size" "$2"); shift 2 ;;
    --read-only) EXTRA_ARGS+=("--read-only"); shift ;;
    --daemon) DAEMON="--daemon"; shift ;;
    --allow-other) EXTRA_ARGS+=("--allow-other"); shift ;;
    -h|--help) usage ;;
    *) EXTRA_ARGS+=("$1"); shift ;;
  esac
done

# Check FUSE
if ! command -v fusermount3 &>/dev/null && ! command -v fusermount &>/dev/null; then
  echo "❌ FUSE not installed. Install with:"
  echo "   sudo apt-get install -y fuse3"
  exit 1
fi

# Create mountpoint
mkdir -p "$MOUNTPOINT"

# Check if already mounted
if mountpoint -q "$MOUNTPOINT" 2>/dev/null; then
  echo "⚠️  $MOUNTPOINT is already mounted"
  echo "   Unmount with: fusermount -u $MOUNTPOINT"
  exit 1
fi

echo "📂 Mounting $REMOTE → $MOUNTPOINT"
echo "   Cache mode: $CACHE_MODE"

rclone mount "$REMOTE" "$MOUNTPOINT" \
  --vfs-cache-mode "$CACHE_MODE" \
  --dir-cache-time 5m \
  --poll-interval 15s \
  $DAEMON \
  "${EXTRA_ARGS[@]}"

if [[ -n "$DAEMON" ]]; then
  echo "✅ Mounted in background"
  echo "   Unmount: fusermount -u $MOUNTPOINT"
else
  echo "✅ Mount active (Ctrl+C to unmount)"
fi
