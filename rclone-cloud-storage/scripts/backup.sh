#!/bin/bash
# Automated backup with timestamped snapshots and retention
set -euo pipefail

LOG_DIR="${RCLONE_LOG_DIR:-/var/log/rclone}"
mkdir -p "$LOG_DIR" 2>/dev/null || true

usage() {
  cat <<EOF
Usage: $(basename "$0") <action> [options]

Actions:
  run      Run a backup now
  setup    Set up scheduled backup via crontab
  list     List backup snapshots for a destination
  prune    Manually prune old snapshots

Options:
  --source PATH        Source directory
  --dest REMOTE:PATH   Destination remote:path
  --schedule CRON      Cron expression (for setup)
  --keep-daily N       Keep N daily snapshots (default: 7)
  --keep-weekly N      Keep N weekly snapshots (default: 4)
  --keep-monthly N     Keep N monthly snapshots (default: 6)
  --bwlimit RATE       Bandwidth limit
  --exclude PAT        Exclude pattern (repeatable)

Examples:
  $(basename "$0") run --source /home/data --dest b2:backups/data
  $(basename "$0") setup --source /home/data --dest b2:backups/data --schedule "0 2 * * *"
  $(basename "$0") list --dest b2:backups/data
  $(basename "$0") prune --dest b2:backups/data --keep-daily 7 --keep-weekly 4
EOF
  exit 0
}

ACTION="${1:-}"
shift 2>/dev/null || true

SOURCE="" DEST="" SCHEDULE="" BWLIMIT=""
KEEP_DAILY=7 KEEP_WEEKLY=4 KEEP_MONTHLY=6
EXCLUDES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --dest) DEST="$2"; shift 2 ;;
    --schedule) SCHEDULE="$2"; shift 2 ;;
    --keep-daily) KEEP_DAILY="$2"; shift 2 ;;
    --keep-weekly) KEEP_WEEKLY="$2"; shift 2 ;;
    --keep-monthly) KEEP_MONTHLY="$2"; shift 2 ;;
    --bwlimit) BWLIMIT="$2"; shift 2 ;;
    --exclude) EXCLUDES+=("--exclude" "$2"); shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

do_prune() {
  local dest="$1"
  local keep_d="$2"
  local keep_w="$3"
  local keep_m="$4"

  echo "🗑️  Pruning old snapshots (policy: ${keep_d}d/${keep_w}w/${keep_m}m)..."

  # List all snapshot directories (format: YYYY-MM-DDTHHMMSS)
  SNAPSHOTS=$(rclone lsd "$dest" 2>/dev/null | awk '{print $NF}' | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' | sort -r)

  if [[ -z "$SNAPSHOTS" ]]; then
    echo "   No snapshots found."
    return
  fi

  TOTAL=$(echo "$SNAPSHOTS" | wc -l)
  KEEP=()
  PRUNED=0
  NOW=$(date +%s)

  while IFS= read -r snap; do
    # Parse date from snapshot name
    SNAP_DATE=$(echo "$snap" | sed 's/T.*//')
    SNAP_TS=$(date -d "$SNAP_DATE" +%s 2>/dev/null || echo 0)
    AGE_DAYS=$(( (NOW - SNAP_TS) / 86400 ))

    KEEP_THIS=false

    # Daily retention
    if [[ $AGE_DAYS -le $keep_d ]]; then
      KEEP_THIS=true
    fi

    # Weekly retention (keep Sundays within weekly window)
    DOW=$(date -d "$SNAP_DATE" +%u 2>/dev/null || echo 0)
    if [[ $AGE_DAYS -le $((keep_w * 7)) && "$DOW" == "7" ]]; then
      KEEP_THIS=true
    fi

    # Monthly retention (keep 1st of month within monthly window)
    DOM=$(echo "$SNAP_DATE" | cut -d- -f3)
    if [[ $AGE_DAYS -le $((keep_m * 30)) && "$DOM" == "01" ]]; then
      KEEP_THIS=true
    fi

    if $KEEP_THIS; then
      KEEP+=("$snap")
    else
      echo "   Removing: $snap"
      rclone purge "${dest}/${snap}" 2>/dev/null && PRUNED=$((PRUNED + 1))
    fi
  done <<< "$SNAPSHOTS"

  echo "   Kept: ${#KEEP[@]}, Pruned: $PRUNED"
}

case "$ACTION" in
  run)
    if [[ -z "$SOURCE" || -z "$DEST" ]]; then
      echo "❌ --source and --dest required for run"
      exit 1
    fi

    SNAPSHOT=$(date -u +%Y-%m-%dT%H%M%S)
    SNAP_DEST="${DEST}/${SNAPSHOT}"
    LOG_FILE="${LOG_DIR}/backup-$(date +%Y%m%d).log"
    START=$(date +%s)

    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] 🔄 Starting backup: $SOURCE → $DEST"
    echo "   📁 Snapshot: $SNAPSHOT"

    # Find latest snapshot for --copy-dest (incremental)
    LATEST=$(rclone lsd "$DEST" 2>/dev/null | awk '{print $NF}' | grep -E '^[0-9]{4}-[0-9]{2}' | sort -r | head -1)

    COPY_DEST_ARG=""
    if [[ -n "$LATEST" ]]; then
      COPY_DEST_ARG="--copy-dest ${DEST}/${LATEST}"
      echo "   📋 Incremental from: $LATEST"
    fi

    # Run backup
    rclone copy "$SOURCE" "$SNAP_DEST" \
      --transfers 8 \
      --log-file "$LOG_FILE" \
      --log-level INFO \
      ${BWLIMIT:+--bwlimit "$BWLIMIT"} \
      ${COPY_DEST_ARG} \
      "${EXCLUDES[@]}" \
      2>&1

    EXIT_CODE=$?
    END=$(date +%s)
    ELAPSED=$(( END - START ))

    if [[ $ELAPSED -ge 60 ]]; then
      ELAPSED_FMT="$((ELAPSED/60))m$((ELAPSED%60))s"
    else
      ELAPSED_FMT="${ELAPSED}s"
    fi

    if [[ $EXIT_CODE -eq 0 ]]; then
      # Get transfer stats
      SIZE=$(rclone size "$SNAP_DEST" 2>/dev/null | grep "Total size" | awk '{print $3, $4}' || echo "unknown")
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ✅ Backup complete: ${SIZE} (${ELAPSED_FMT})"

      # Auto-prune
      do_prune "$DEST" "$KEEP_DAILY" "$KEEP_WEEKLY" "$KEEP_MONTHLY"
    else
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ❌ Backup failed (exit $EXIT_CODE, ${ELAPSED_FMT})"
      echo "   Log: $LOG_FILE"
      exit $EXIT_CODE
    fi
    ;;

  setup)
    if [[ -z "$SOURCE" || -z "$DEST" || -z "$SCHEDULE" ]]; then
      echo "❌ --source, --dest, and --schedule required for setup"
      exit 1
    fi

    SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    CRON_CMD="$SCHEDULE $SCRIPT_PATH run --source '$SOURCE' --dest '$DEST' --keep-daily $KEEP_DAILY --keep-weekly $KEEP_WEEKLY --keep-monthly $KEEP_MONTHLY >> $LOG_DIR/backup-cron.log 2>&1"

    # Add to crontab (avoid duplicates)
    (crontab -l 2>/dev/null | grep -v "$DEST" ; echo "$CRON_CMD") | crontab -

    echo "✅ Scheduled backup configured!"
    echo "   Source: $SOURCE"
    echo "   Dest: $DEST"
    echo "   Schedule: $SCHEDULE"
    echo "   Retention: ${KEEP_DAILY}d / ${KEEP_WEEKLY}w / ${KEEP_MONTHLY}m"
    echo ""
    echo "   View crontab: crontab -l"
    echo "   Remove: crontab -e (delete the line)"
    ;;

  list)
    if [[ -z "$DEST" ]]; then
      echo "❌ --dest required for list"
      exit 1
    fi

    echo "📋 Backup snapshots in $DEST:"
    echo ""
    rclone lsd "$DEST" 2>/dev/null | while read -r line; do
      DIR=$(echo "$line" | awk '{print $NF}')
      SIZE=$(rclone size "${DEST}/${DIR}" 2>/dev/null | grep "Total size" | awk '{print $3, $4}' || echo "?")
      COUNT=$(rclone size "${DEST}/${DIR}" 2>/dev/null | grep "Total objects" | awk '{print $3}' || echo "?")
      echo "   📁 $DIR — $COUNT files, $SIZE"
    done
    ;;

  prune)
    if [[ -z "$DEST" ]]; then
      echo "❌ --dest required for prune"
      exit 1
    fi
    do_prune "$DEST" "$KEEP_DAILY" "$KEEP_WEEKLY" "$KEEP_MONTHLY"
    ;;

  -h|--help|help|"")
    usage
    ;;

  *)
    echo "❌ Unknown action: $ACTION"
    usage
    ;;
esac
