#!/usr/bin/env bash
# Cleanup old monitoring data
set -euo pipefail

DATA_DIR="./data"
OLDER_THAN=30

while [[ $# -gt 0 ]]; do
  case $1 in
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    --older-than) OLDER_THAN="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

count=$(find "$DATA_DIR" -name "*.csv" -mtime +"$OLDER_THAN" 2>/dev/null | wc -l)
if [[ "$count" -gt 0 ]]; then
  find "$DATA_DIR" -name "*.csv" -mtime +"$OLDER_THAN" -delete
  echo "Deleted $count CSV files older than $OLDER_THAN days"
  # Remove empty directories
  find "$DATA_DIR" -type d -empty -delete 2>/dev/null || true
else
  echo "No files older than $OLDER_THAN days found"
fi
