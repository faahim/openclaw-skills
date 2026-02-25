#!/bin/bash
# Rclone sync wrapper with logging and notifications
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${RCLONE_LOG_DIR:-/var/log/rclone}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

usage() {
  cat <<EOF
Usage: $(basename "$0") <source> <destination> [options]

Sync files from source to destination using rclone.

Arguments:
  source         Local path or remote:path
  destination    Local path or remote:path

Options:
  --dry-run         Show what would be transferred without doing it
  --bwlimit RATE    Bandwidth limit (e.g., 10M, 1G)
  --transfers N     Number of parallel transfers (default: 8)
  --exclude PAT     Exclude pattern (repeatable)
  --filter-from F   Filter file path
  --delete          Delete files in dest that don't exist in source (default: yes)
  --no-delete       Don't delete extra files in destination
  --checksum        Use checksum instead of mod-time for comparison
  --progress        Show real-time progress
  --log FILE        Log file path (default: $LOG_DIR/sync.log)
  -h, --help        Show this help

Examples:
  $(basename "$0") /home/user/docs mycloud:bucket/docs
  $(basename "$0") /home/user/docs mycloud:bucket/docs --dry-run
  $(basename "$0") /home/user/docs mycloud:bucket/docs --bwlimit 10M --transfers 16
  $(basename "$0") dropbox:Photos s3:my-bucket/photos
EOF
  exit 0
}

# Parse arguments
SOURCE=""
DEST=""
DRY_RUN=""
EXTRA_ARGS=()
LOG_FILE=""
DELETE_MODE="--delete-during"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    --dry-run) DRY_RUN="--dry-run"; shift ;;
    --bwlimit) EXTRA_ARGS+=("--bwlimit" "$2"); shift 2 ;;
    --transfers) EXTRA_ARGS+=("--transfers" "$2"); shift 2 ;;
    --exclude) EXTRA_ARGS+=("--exclude" "$2"); shift 2 ;;
    --filter-from) EXTRA_ARGS+=("--filter-from" "$2"); shift 2 ;;
    --delete) DELETE_MODE="--delete-during"; shift ;;
    --no-delete) DELETE_MODE=""; shift ;;
    --checksum) EXTRA_ARGS+=("--checksum"); shift ;;
    --progress) EXTRA_ARGS+=("--progress"); shift ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    -*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      if [[ -z "$SOURCE" ]]; then
        SOURCE="$1"
      elif [[ -z "$DEST" ]]; then
        DEST="$1"
      else
        echo "Too many arguments: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$SOURCE" || -z "$DEST" ]]; then
  echo "❌ Source and destination are required."
  echo "   Run: $(basename "$0") --help"
  exit 1
fi

# Ensure log directory exists
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG_FILE="${LOG_FILE:-$LOG_DIR/sync.log}"

# Build rclone command
CMD=(rclone sync "$SOURCE" "$DEST"
  --transfers "${RCLONE_TRANSFERS:-8}"
  --stats 0
  --stats-one-line
  --log-file "$LOG_FILE"
  --log-level INFO
  $DELETE_MODE
  $DRY_RUN
  "${EXTRA_ARGS[@]}"
)

# Run
echo "[${TIMESTAMP}] 📤 Syncing $SOURCE → $DEST"
if [[ -n "$DRY_RUN" ]]; then
  echo "   ⚠️  DRY RUN — no changes will be made"
fi

START_TIME=$(date +%s)

# Execute rclone
"${CMD[@]}" 2>&1

EXIT_CODE=$?
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# Format elapsed time
if [[ $ELAPSED -ge 3600 ]]; then
  ELAPSED_FMT="$((ELAPSED/3600))h$((ELAPSED%3600/60))m$((ELAPSED%60))s"
elif [[ $ELAPSED -ge 60 ]]; then
  ELAPSED_FMT="$((ELAPSED/60))m$((ELAPSED%60))s"
else
  ELAPSED_FMT="${ELAPSED}s"
fi

if [[ $EXIT_CODE -eq 0 ]]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ✅ Sync complete (${ELAPSED_FMT})"
else
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ❌ Sync failed with exit code $EXIT_CODE (${ELAPSED_FMT})"
  echo "   Check log: $LOG_FILE"
  exit $EXIT_CODE
fi
