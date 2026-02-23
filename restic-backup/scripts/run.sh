#!/bin/bash
# Restic Backup Manager — main entry point
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${RESTIC_LOG_FILE:-/var/log/restic-backup.log}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

send_telegram() {
  local msg="$1"
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=${msg}" -d "parse_mode=HTML" >/dev/null 2>&1 || true
  fi
}

usage() {
  cat <<EOF
Restic Backup Manager

Usage: bash run.sh <command> [options]

Commands:
  init        Initialize a new backup repository
  backup      Run a backup
  restore     Restore files from a snapshot
  snapshots   List available snapshots
  prune       Remove old snapshots per retention policy
  check       Verify repository integrity
  unlock      Remove stale locks
  mount       Mount snapshots as filesystem
  schedule    Install cron job for automated backups
  status      Show repository stats

Options:
  --repo <repo>           Repository location (local path, s3:..., sftp:..., b2:...)
  --password <pw>         Repository password
  --password-file <file>  Read password from file
  --paths <p1,p2,...>     Comma-separated paths to back up
  --exclude <patterns>    Comma-separated exclude patterns
  --config <file>         YAML config file
  --snapshot <id>         Snapshot ID (for restore; "latest" supported)
  --target <dir>          Restore target directory
  --include <pattern>     Include pattern for partial restore
  --keep-daily <n>        Retention: daily snapshots to keep
  --keep-weekly <n>       Retention: weekly snapshots to keep
  --keep-monthly <n>      Retention: monthly snapshots to keep
  --keep-yearly <n>       Retention: yearly snapshots to keep
  --cron <expr>           Cron expression for schedule command
  --pre-hook <cmd>        Command to run before backup
  --limit-upload <kB/s>   Bandwidth limit for uploads
  --mountpoint <dir>      Mount point for mount command
  --dry-run               Show what would be backed up
EOF
}

# Parse args
COMMAND="${1:-}"
shift 2>/dev/null || true

REPO="" PASSWORD="" PASSWORD_FILE="" PATHS="" EXCLUDE="" CONFIG=""
SNAPSHOT="" TARGET="" INCLUDE="" CRON_EXPR="" PRE_HOOK="" LIMIT_UPLOAD=""
KEEP_DAILY="" KEEP_WEEKLY="" KEEP_MONTHLY="" KEEP_YEARLY="" MOUNTPOINT="" DRY_RUN=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --repo) REPO="$2"; shift 2 ;;
    --password) PASSWORD="$2"; shift 2 ;;
    --password-file) PASSWORD_FILE="$2"; shift 2 ;;
    --paths) PATHS="$2"; shift 2 ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --snapshot) SNAPSHOT="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --include) INCLUDE="$2"; shift 2 ;;
    --keep-daily) KEEP_DAILY="$2"; shift 2 ;;
    --keep-weekly) KEEP_WEEKLY="$2"; shift 2 ;;
    --keep-monthly) KEEP_MONTHLY="$2"; shift 2 ;;
    --keep-yearly) KEEP_YEARLY="$2"; shift 2 ;;
    --cron) CRON_EXPR="$2"; shift 2 ;;
    --pre-hook) PRE_HOOK="$2"; shift 2 ;;
    --limit-upload) LIMIT_UPLOAD="$2"; shift 2 ;;
    --mountpoint) MOUNTPOINT="$2"; shift 2 ;;
    --dry-run) DRY_RUN="1"; shift ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Set password env
setup_password() {
  if [[ -n "$PASSWORD" ]]; then
    export RESTIC_PASSWORD="$PASSWORD"
  elif [[ -n "$PASSWORD_FILE" ]]; then
    export RESTIC_PASSWORD_FILE="$PASSWORD_FILE"
  elif [[ -z "${RESTIC_PASSWORD:-}" && -z "${RESTIC_PASSWORD_FILE:-}" ]]; then
    echo "❌ No password provided. Use --password, --password-file, or set RESTIC_PASSWORD"
    exit 1
  fi
}

# Set repo env
setup_repo() {
  if [[ -n "$REPO" ]]; then
    export RESTIC_REPOSITORY="$REPO"
  elif [[ -z "${RESTIC_REPOSITORY:-}" ]]; then
    echo "❌ No repository provided. Use --repo or set RESTIC_REPOSITORY"
    exit 1
  fi
}

# Build exclude args
build_excludes() {
  local args=""
  if [[ -n "$EXCLUDE" ]]; then
    IFS=',' read -ra PATTERNS <<< "$EXCLUDE"
    for p in "${PATTERNS[@]}"; do
      args+=" --exclude $(printf '%q' "$p")"
    done
  fi
  echo "$args"
}

# Build retention args
build_retention() {
  local args=""
  [[ -n "$KEEP_DAILY" ]] && args+=" --keep-daily $KEEP_DAILY"
  [[ -n "$KEEP_WEEKLY" ]] && args+=" --keep-weekly $KEEP_WEEKLY"
  [[ -n "$KEEP_MONTHLY" ]] && args+=" --keep-monthly $KEEP_MONTHLY"
  [[ -n "$KEEP_YEARLY" ]] && args+=" --keep-yearly $KEEP_YEARLY"
  echo "$args"
}

cmd_init() {
  setup_password
  setup_repo
  log "🔧 Initializing repository: $RESTIC_REPOSITORY"
  restic init
  log "${GREEN}✅ Repository initialized${NC}"
}

cmd_backup() {
  setup_password
  setup_repo

  if [[ -z "$PATHS" ]]; then
    echo "❌ No paths specified. Use --paths '/home,/etc'"
    exit 1
  fi

  # Run pre-hook
  if [[ -n "$PRE_HOOK" ]]; then
    log "🔧 Running pre-hook: $PRE_HOOK"
    eval "$PRE_HOOK"
  fi

  IFS=',' read -ra PATH_ARRAY <<< "$PATHS"
  EXCLUDE_ARGS=$(build_excludes)
  LIMIT_ARGS=""
  [[ -n "$LIMIT_UPLOAD" ]] && LIMIT_ARGS="--limit-upload $LIMIT_UPLOAD"
  DRY_ARGS=""
  [[ -n "$DRY_RUN" ]] && DRY_ARGS="--dry-run"

  log "🔄 Starting backup to $RESTIC_REPOSITORY"
  log "   Paths: ${PATH_ARRAY[*]}"

  START_TIME=$(date +%s)
  if eval restic backup "${PATH_ARRAY[@]}" $EXCLUDE_ARGS $LIMIT_ARGS $DRY_ARGS --verbose; then
    ELAPSED=$(( $(date +%s) - START_TIME ))
    log "${GREEN}✅ Backup complete (${ELAPSED}s)${NC}"

    # Auto-prune if retention is set
    RETENTION_ARGS=$(build_retention)
    if [[ -n "$RETENTION_ARGS" ]]; then
      log "🧹 Applying retention policy..."
      eval restic forget $RETENTION_ARGS --prune
      log "${GREEN}✅ Retention applied${NC}"
    fi
  else
    log "${RED}❌ Backup FAILED${NC}"
    send_telegram "❌ Restic backup FAILED for $RESTIC_REPOSITORY at $(date '+%Y-%m-%d %H:%M')"
    exit 1
  fi
}

cmd_restore() {
  setup_password
  setup_repo

  SNAP="${SNAPSHOT:-latest}"
  TARG="${TARGET:-/tmp/restic-restore}"

  mkdir -p "$TARG"

  log "🔄 Restoring snapshot $SNAP to $TARG"

  INCLUDE_ARGS=""
  [[ -n "$INCLUDE" ]] && INCLUDE_ARGS="--include $INCLUDE"

  eval restic restore "$SNAP" --target "$TARG" $INCLUDE_ARGS
  log "${GREEN}✅ Restore complete → $TARG${NC}"
}

cmd_snapshots() {
  setup_password
  setup_repo
  restic snapshots
}

cmd_prune() {
  setup_password
  setup_repo

  RETENTION_ARGS=$(build_retention)
  if [[ -z "$RETENTION_ARGS" ]]; then
    RETENTION_ARGS="--keep-daily 7 --keep-weekly 4 --keep-monthly 12"
    log "ℹ️  Using default retention: 7 daily, 4 weekly, 12 monthly"
  fi

  log "🧹 Pruning old snapshots..."
  eval restic forget $RETENTION_ARGS --prune
  log "${GREEN}✅ Prune complete${NC}"
}

cmd_check() {
  setup_password
  setup_repo
  log "🔍 Checking repository integrity..."
  if restic check; then
    log "${GREEN}✅ Repository OK${NC}"
  else
    log "${RED}❌ Repository has errors!${NC}"
    send_telegram "⚠️ Restic repository integrity check FAILED for $RESTIC_REPOSITORY"
    exit 1
  fi
}

cmd_unlock() {
  setup_password
  setup_repo
  log "🔓 Removing stale locks..."
  restic unlock
  log "${GREEN}✅ Locks removed${NC}"
}

cmd_mount() {
  setup_password
  setup_repo
  MP="${MOUNTPOINT:-/mnt/restic-browse}"
  mkdir -p "$MP"
  log "📂 Mounting snapshots at $MP (Ctrl+C to unmount)"
  restic mount "$MP"
}

cmd_schedule() {
  setup_password
  setup_repo

  if [[ -z "$CRON_EXPR" ]]; then
    CRON_EXPR="0 2 * * *"
    log "ℹ️  Using default schedule: daily at 2am"
  fi

  # Build the backup command
  IFS=',' read -ra PATH_ARRAY <<< "$PATHS"
  EXCLUDE_ARGS=$(build_excludes)
  RETENTION_ARGS=$(build_retention)
  LIMIT_ARGS=""
  [[ -n "$LIMIT_UPLOAD" ]] && LIMIT_ARGS="--limit-upload $LIMIT_UPLOAD"

  PW_ARG=""
  [[ -n "$PASSWORD_FILE" ]] && PW_ARG="--password-file $PASSWORD_FILE"
  [[ -n "$PASSWORD" ]] && PW_ARG="--password '$PASSWORD'"

  CRON_CMD="$CRON_EXPR cd $(pwd) && bash $SCRIPT_DIR/run.sh backup --repo '$RESTIC_REPOSITORY' $PW_ARG --paths '$PATHS' $EXCLUDE_ARGS $RETENTION_ARGS $LIMIT_ARGS >> $LOG_FILE 2>&1"

  # Add to crontab
  (crontab -l 2>/dev/null | grep -v "restic-backup"; echo "$CRON_CMD") | crontab -

  log "${GREEN}✅ Cron job installed: $CRON_EXPR${NC}"
  log "   Log file: $LOG_FILE"
  echo ""
  echo "Verify with: crontab -l | grep restic"
}

cmd_status() {
  setup_password
  setup_repo
  echo "📊 Repository: $RESTIC_REPOSITORY"
  echo ""
  restic stats
  echo ""
  restic snapshots --last 5
}

# Dispatch
case "${COMMAND}" in
  init) cmd_init ;;
  backup) cmd_backup ;;
  restore) cmd_restore ;;
  snapshots) cmd_snapshots ;;
  prune) cmd_prune ;;
  check) cmd_check ;;
  unlock) cmd_unlock ;;
  mount) cmd_mount ;;
  schedule) cmd_schedule ;;
  status) cmd_status ;;
  -h|--help|help|"") usage ;;
  *) echo "Unknown command: $COMMAND"; usage; exit 1 ;;
esac
