#!/bin/bash
# Bidirectional sync between two rclone paths
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <path1> <path2> [options]

Bidirectional sync — keeps both sides in sync (like Dropbox).

Options:
  --resync         Required on first run to establish baseline
  --dry-run        Show changes without applying
  --force          Force sync even on conflicts (newer wins)

Examples:
  $(basename "$0") /home/user/docs gdrive:Documents --resync   # First run
  $(basename "$0") /home/user/docs gdrive:Documents             # Subsequent runs
EOF
  exit 0
}

PATH1="${1:-}"
PATH2="${2:-}"
shift 2 2>/dev/null || true

if [[ -z "$PATH1" || -z "$PATH2" ]]; then
  usage
fi

EXTRA_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --resync) EXTRA_ARGS+=("--resync"); shift ;;
    --dry-run) EXTRA_ARGS+=("--dry-run"); shift ;;
    --force) EXTRA_ARGS+=("--force"); shift ;;
    -h|--help) usage ;;
    *) EXTRA_ARGS+=("$1"); shift ;;
  esac
done

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] 🔄 Bisync: $PATH1 ↔ $PATH2"

rclone bisync "$PATH1" "$PATH2" \
  --verbose \
  "${EXTRA_ARGS[@]}" \
  2>&1

EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ✅ Bisync complete"
else
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ❌ Bisync failed (exit $EXIT_CODE)"
  if [[ $EXIT_CODE -eq 2 ]]; then
    echo "   Hint: Run with --resync on first use"
  fi
  exit $EXIT_CODE
fi
