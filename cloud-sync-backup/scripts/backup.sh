#!/bin/bash
# Cloud Sync & Backup — Main backup script
set -euo pipefail

# Defaults
SOURCE=""
REMOTE=""
CONFIG=""
MODE="copy"
COMPRESS=false
ENCRYPT=false
PASSWORD="${BACKUP_PASSWORD:-}"
DRY_RUN=false
LOG_FILE=""
BWLIMIT=""
TRANSFERS=4
EXCLUDES=()
PRE_CMD=""
POST_CMD=""
ALERT=""
TELEGRAM_BOT="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT="${TELEGRAM_CHAT_ID:-}"

usage() {
  echo "Usage: backup.sh --source <path> --remote <remote:path> [options]"
  echo ""
  echo "Options:"
  echo "  --source <path>       Local path to back up"
  echo "  --remote <remote>     rclone remote destination (e.g., s3:bucket/path)"
  echo "  --config <file>       YAML config file (alternative to --source/--remote)"
  echo "  --mode <sync|copy>    sync (mirror) or copy (additive). Default: copy"
  echo "  --compress            Create tar.gz archive before uploading"
  echo "  --encrypt             Encrypt with gpg (requires --password or \$BACKUP_PASSWORD)"
  echo "  --password <pass>     Encryption password"
  echo "  --dry-run             Preview without making changes"
  echo "  --log <file>          Log output to file"
  echo "  --bwlimit <rate>      Bandwidth limit (e.g., 10M)"
  echo "  --transfers <n>       Parallel transfers (default: 4)"
  echo "  --exclude <pattern>   Exclude pattern (repeatable)"
  echo "  --pre-cmd <cmd>       Run command before backup"
  echo "  --post-cmd <cmd>      Run command after backup"
  echo "  --alert <telegram>    Send alert on completion/failure"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --source)     SOURCE="$2"; shift 2 ;;
    --remote)     REMOTE="$2"; shift 2 ;;
    --config)     CONFIG="$2"; shift 2 ;;
    --mode)       MODE="$2"; shift 2 ;;
    --compress)   COMPRESS=true; shift ;;
    --encrypt)    ENCRYPT=true; shift ;;
    --password)   PASSWORD="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --log)        LOG_FILE="$2"; shift 2 ;;
    --bwlimit)    BWLIMIT="$2"; shift 2 ;;
    --transfers)  TRANSFERS="$2"; shift 2 ;;
    --exclude)    EXCLUDES+=("$2"); shift 2 ;;
    --pre-cmd)    PRE_CMD="$2"; shift 2 ;;
    --post-cmd)   POST_CMD="$2"; shift 2 ;;
    --alert)      ALERT="$2"; shift 2 ;;
    -h|--help)    usage ;;
    *)            echo "Unknown: $1"; usage ;;
  esac
done

# Logging
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg"
  [[ -n "$LOG_FILE" ]] && echo "$msg" >> "$LOG_FILE"
}

send_alert() {
  local status="$1" message="$2"
  if [[ "$ALERT" == "telegram" && -n "$TELEGRAM_BOT" && -n "$TELEGRAM_CHAT" ]]; then
    local emoji="✅"
    [[ "$status" == "fail" ]] && emoji="❌"
    curl -s "https://api.telegram.org/bot${TELEGRAM_BOT}/sendMessage" \
      -d chat_id="$TELEGRAM_CHAT" \
      -d text="${emoji} Backup: ${message}" \
      -d parse_mode="Markdown" > /dev/null 2>&1 || true
  fi
}

# Validate
if [[ -z "$SOURCE" || -z "$REMOTE" ]] && [[ -z "$CONFIG" ]]; then
  echo "❌ Either --source + --remote or --config required"
  usage
fi

# Config-based backup (TODO: parse YAML with yq)
if [[ -n "$CONFIG" ]]; then
  echo "❌ Config-based backup requires yq. Install: sudo apt install yq"
  echo "   Or use --source and --remote flags directly."
  exit 1
fi

# Check rclone
if ! command -v rclone &>/dev/null; then
  echo "❌ rclone not installed. Run: bash scripts/install.sh"
  exit 1
fi

# Validate source
if [[ ! -e "$SOURCE" ]]; then
  echo "❌ Source not found: $SOURCE"
  exit 1
fi

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
START_TIME=$(date +%s)

log "🔄 Starting backup: $SOURCE → $REMOTE"

# Pre-command
if [[ -n "$PRE_CMD" ]]; then
  log "⚙️  Running pre-command: $PRE_CMD"
  eval "$PRE_CMD"
fi

# Build rclone args
RCLONE_ARGS=("--transfers" "$TRANSFERS" "--stats" "0" "--stats-one-line")
[[ -n "$BWLIMIT" ]] && RCLONE_ARGS+=("--bwlimit" "$BWLIMIT")
[[ "$DRY_RUN" == true ]] && RCLONE_ARGS+=("--dry-run")

for exc in "${EXCLUDES[@]}"; do
  RCLONE_ARGS+=("--exclude" "$exc")
done

CLEANUP_FILES=()

trap 'for f in "${CLEANUP_FILES[@]}"; do rm -f "$f"; done' EXIT

if [[ "$COMPRESS" == true || "$ENCRYPT" == true ]]; then
  # Archive mode: create tar.gz, optionally encrypt, upload single file
  ARCHIVE_NAME="backup-${TIMESTAMP}.tar.gz"
  ARCHIVE_PATH="/tmp/$ARCHIVE_NAME"
  CLEANUP_FILES+=("$ARCHIVE_PATH")

  log "📦 Compressing: $SOURCE → $ARCHIVE_NAME"
  
  # Build tar exclude args
  TAR_EXCLUDES=()
  for exc in "${EXCLUDES[@]}"; do
    TAR_EXCLUDES+=("--exclude=$exc")
  done

  tar czf "$ARCHIVE_PATH" "${TAR_EXCLUDES[@]}" -C "$(dirname "$SOURCE")" "$(basename "$SOURCE")"
  ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
  log "📦 Archive size: $ARCHIVE_SIZE"

  if [[ "$ENCRYPT" == true ]]; then
    if [[ -z "$PASSWORD" ]]; then
      echo "❌ Encryption requires --password or \$BACKUP_PASSWORD"
      exit 1
    fi

    ENCRYPTED_PATH="${ARCHIVE_PATH}.gpg"
    CLEANUP_FILES+=("$ENCRYPTED_PATH")
    log "🔐 Encrypting archive..."
    gpg --batch --yes --symmetric --cipher-algo AES256 \
      --passphrase "$PASSWORD" \
      -o "$ENCRYPTED_PATH" "$ARCHIVE_PATH"
    rm -f "$ARCHIVE_PATH"
    UPLOAD_FILE="$ENCRYPTED_PATH"
    UPLOAD_NAME="${ARCHIVE_NAME}.gpg"
  else
    UPLOAD_FILE="$ARCHIVE_PATH"
    UPLOAD_NAME="$ARCHIVE_NAME"
  fi

  # Upload single file
  log "☁️  Uploading: $UPLOAD_NAME"
  if rclone copyto "$UPLOAD_FILE" "${REMOTE}/${UPLOAD_NAME}" "${RCLONE_ARGS[@]}" 2>&1; then
    RESULT="success"
  else
    RESULT="fail"
  fi
else
  # Direct sync/copy mode
  log "☁️  Running rclone $MODE..."
  if rclone "$MODE" "$SOURCE" "$REMOTE" "${RCLONE_ARGS[@]}" 2>&1; then
    RESULT="success"
  else
    RESULT="fail"
  fi
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Post-command
if [[ -n "$POST_CMD" ]]; then
  log "⚙️  Running post-command: $POST_CMD"
  eval "$POST_CMD"
fi

# Report
if [[ "$RESULT" == "success" ]]; then
  log "✅ Backup complete! Duration: ${DURATION}s"
  send_alert "ok" "$SOURCE → $REMOTE (${DURATION}s)"
else
  log "❌ Backup FAILED after ${DURATION}s"
  send_alert "fail" "$SOURCE → $REMOTE FAILED (${DURATION}s)"
  exit 1
fi
