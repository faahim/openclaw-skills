#!/bin/bash
# Cloud Sync & Backup — List, prune, and manage backups
set -euo pipefail

ACTION="${1:?Usage: manage.sh <list|prune|size> --remote <remote:path> [options]}"
shift

REMOTE=""
RETENTION=30

while [[ $# -gt 0 ]]; do
  case $1 in
    --remote)     REMOTE="$2"; shift 2 ;;
    --retention)  RETENTION="$2"; shift 2 ;;
    *)            echo "Unknown: $1"; exit 1 ;;
  esac
done

if [[ -z "$REMOTE" ]]; then
  echo "❌ --remote required"
  exit 1
fi

case "$ACTION" in
  list)
    echo "📋 Backups in $REMOTE:"
    echo ""
    rclone lsl "$REMOTE" --max-depth 1 | sort -k2,3
    echo ""
    TOTAL=$(rclone size "$REMOTE" --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{d[\"count\"]} files, {d[\"bytes\"]/1048576:.1f} MB')" 2>/dev/null || echo "unknown")
    echo "Total: $TOTAL"
    ;;

  prune)
    echo "🗑️  Pruning backups older than $RETENTION days in $REMOTE"
    CUTOFF=$(date -d "-${RETENTION} days" +%Y-%m-%d 2>/dev/null || date -v-${RETENTION}d +%Y-%m-%d)
    echo "   Cutoff date: $CUTOFF"
    echo ""

    # List files older than retention
    OLD_FILES=$(rclone lsf "$REMOTE" --files-only --min-age "${RETENTION}d" 2>/dev/null)

    if [[ -z "$OLD_FILES" ]]; then
      echo "✅ No files older than $RETENTION days"
      exit 0
    fi

    COUNT=$(echo "$OLD_FILES" | wc -l)
    echo "Found $COUNT file(s) to delete:"
    echo "$OLD_FILES" | head -20
    [[ $COUNT -gt 20 ]] && echo "... and $((COUNT - 20)) more"
    echo ""
    
    read -p "Delete these files? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rclone delete "$REMOTE" --min-age "${RETENTION}d" --progress
      echo "✅ Pruned $COUNT file(s)"
    else
      echo "Cancelled"
    fi
    ;;

  size)
    echo "📊 Storage usage for $REMOTE:"
    rclone size "$REMOTE"
    ;;

  *)
    echo "❌ Unknown action: $ACTION"
    echo "Usage: manage.sh <list|prune|size> --remote <remote:path>"
    exit 1
    ;;
esac
