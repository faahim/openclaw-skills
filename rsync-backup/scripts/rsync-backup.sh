#!/usr/bin/env bash
# Rsync Backup Manager — Automated backups with incremental snapshots
# Usage: bash rsync-backup.sh --source /path --dest /backup --name "label"

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-${HOME}/.local/log/rsync-backup}"
TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
DATE_DISPLAY=$(date +"%Y-%m-%d %H:%M:%S")

# Defaults
SOURCE=""
DEST=""
NAME="backup"
SSH_KEY=""
BWLIMIT=0
SNAPSHOTS=false
RETAIN=30
DRY_RUN=false
VERBOSE=false
COMPRESS=false
RESTORE=false
VERIFY=false
LIST=false
PRUNE=false
INSTALL_CRON=false
CONFIG=""
PRE_SCRIPT=""
POST_SCRIPT=""
EXCLUDES=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "[${DATE_DISPLAY}] $1"; }
log_ok() { log "${GREEN}✅ $1${NC}"; }
log_err() { log "${RED}❌ $1${NC}"; }
log_info() { log "${BLUE}🔄 $1${NC}"; }
log_warn() { log "${YELLOW}⚠️  $1${NC}"; }

usage() {
  cat <<EOF
Rsync Backup Manager v${VERSION}

USAGE:
  $(basename "$0") [OPTIONS]

BACKUP OPTIONS:
  --source PATH        Source directory to back up
  --dest PATH          Destination (local path or user@host:/path)
  --name LABEL         Backup job name (for logs/snapshots)
  --ssh-key PATH       SSH private key for remote backups
  --bwlimit KB/S       Bandwidth limit in KB/s (0=unlimited)
  --snapshots          Enable incremental snapshots with hard links
  --retain N           Keep last N snapshots (default: 30)
  --exclude PATTERN    Exclude pattern (repeatable)
  --compress           Enable compression for transfer
  --pre COMMAND        Run command before backup
  --post COMMAND       Run command after backup
  --dry-run            Preview without making changes
  --verbose            Show detailed rsync output

RESTORE/MANAGEMENT:
  --restore            Restore mode (swap source/dest meaning)
  --verify             Verify backup matches source
  --list               List available snapshots at dest
  --prune              Remove old snapshots beyond retain count
  --install-cron       Install cron jobs from config file
  --config FILE        Use YAML config file for multiple jobs

EXAMPLES:
  # Local backup
  $(basename "$0") --source /home/user --dest /mnt/backup/home --name home

  # Remote backup with snapshots
  $(basename "$0") --source /var/www --dest user@server:/backups/www \\
    --name website --ssh-key ~/.ssh/id_ed25519 --snapshots --retain 14

  # Restore from latest snapshot
  $(basename "$0") --restore --source /mnt/backup/home/latest --dest /home/user
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --source) SOURCE="$2"; shift 2 ;;
    --dest) DEST="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --ssh-key) SSH_KEY="$2"; shift 2 ;;
    --bwlimit) BWLIMIT="$2"; shift 2 ;;
    --snapshots) SNAPSHOTS=true; shift ;;
    --retain) RETAIN="$2"; shift 2 ;;
    --exclude) EXCLUDES+=("$2"); shift 2 ;;
    --compress) COMPRESS=true; shift ;;
    --pre) PRE_SCRIPT="$2"; shift 2 ;;
    --post) POST_SCRIPT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    --restore) RESTORE=true; shift ;;
    --verify) VERIFY=true; shift ;;
    --list) LIST=true; shift ;;
    --prune) PRUNE=true; shift ;;
    --install-cron) INSTALL_CRON=true; shift ;;
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Ensure log directory exists
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Alert functions
send_telegram() {
  local msg="$1"
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "text=${msg}" \
      -d "parse_mode=HTML" > /dev/null 2>&1 || true
  fi
}

send_email() {
  local subject="$1" body="$2"
  if [[ -n "${ALERT_EMAIL:-}" ]] && command -v mailx &>/dev/null; then
    echo "$body" | mailx -s "$subject" "$ALERT_EMAIL" 2>/dev/null || true
  fi
}

alert_failure() {
  local msg="🚨 <b>Backup Failed:</b> ${NAME}\n📅 ${DATE_DISPLAY}\n❌ $1"
  send_telegram "$msg"
  send_email "Backup Failed: ${NAME}" "$1"
}

alert_success() {
  local msg="✅ <b>Backup Complete:</b> ${NAME}\n📅 ${DATE_DISPLAY}\n📊 $1"
  # Only send success alerts if explicitly enabled
  if [[ "${ALERT_ON_SUCCESS:-false}" == "true" ]]; then
    send_telegram "$msg"
  fi
}

# Build rsync command
build_rsync_cmd() {
  local cmd="rsync -aHAX --delete --stats"

  # SSH transport
  if [[ -n "$SSH_KEY" ]]; then
    cmd+=" -e 'ssh -i ${SSH_KEY} -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30'"
  elif [[ "$DEST" == *@* ]] || [[ "$SOURCE" == *@* ]]; then
    cmd+=" -e 'ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30'"
  fi

  # Bandwidth limit
  if [[ $BWLIMIT -gt 0 ]]; then
    cmd+=" --bwlimit=${BWLIMIT}"
  fi

  # Compression
  if $COMPRESS; then
    cmd+=" -z"
  fi

  # Excludes
  for excl in "${EXCLUDES[@]}"; do
    cmd+=" --exclude='${excl}'"
  done

  # Dry run
  if $DRY_RUN; then
    cmd+=" --dry-run"
  fi

  # Verbose
  if $VERBOSE; then
    cmd+=" -v --progress"
  fi

  echo "$cmd"
}

# List snapshots
do_list() {
  if [[ -z "$DEST" ]]; then
    log_err "Need --dest to list snapshots"
    exit 1
  fi

  log_info "Snapshots at: ${DEST}"
  echo ""

  if [[ "$DEST" == *@* ]]; then
    local remote_host="${DEST%%:*}"
    local remote_path="${DEST#*:}"
    ssh "$remote_host" "ls -1dt ${remote_path}/20* 2>/dev/null | head -20" || echo "(no snapshots found)"
  else
    ls -1dt "${DEST}"/20* 2>/dev/null | head -20 || echo "(no snapshots found)"
  fi
}

# Prune old snapshots
do_prune() {
  if [[ -z "$DEST" ]]; then
    log_err "Need --dest to prune"
    exit 1
  fi

  log_info "Pruning snapshots at ${DEST}, keeping last ${RETAIN}..."

  if [[ "$DEST" == *@* ]]; then
    local remote_host="${DEST%%:*}"
    local remote_path="${DEST#*:}"
    local to_delete
    to_delete=$(ssh "$remote_host" "ls -1dt ${remote_path}/20* 2>/dev/null | tail -n +$((RETAIN + 1))")
    if [[ -n "$to_delete" ]]; then
      echo "$to_delete" | while read -r snap; do
        log_warn "Removing: $snap"
        ssh "$remote_host" "rm -rf '$snap'"
      done
    fi
  else
    local to_delete
    to_delete=$(ls -1dt "${DEST}"/20* 2>/dev/null | tail -n +$((RETAIN + 1))) || true
    if [[ -n "$to_delete" ]]; then
      echo "$to_delete" | while read -r snap; do
        log_warn "Removing: $snap"
        rm -rf "$snap"
      done
    fi
  fi

  log_ok "Prune complete"
}

# Verify backup
do_verify() {
  if [[ -z "$SOURCE" || -z "$DEST" ]]; then
    log_err "Need --source and --dest for verify"
    exit 1
  fi

  log_info "Verifying backup integrity..."
  local cmd
  cmd=$(build_rsync_cmd)
  cmd+=" --dry-run --itemize-changes"

  local diff_count
  diff_count=$(eval "$cmd '${SOURCE}/' '${DEST}/'" 2>&1 | grep -c '^[<>ch]' || true)

  if [[ $diff_count -eq 0 ]]; then
    log_ok "Backup verified — source and dest match"
  else
    log_warn "Found ${diff_count} differences between source and dest"
    if $VERBOSE; then
      eval "$cmd '${SOURCE}/' '${DEST}/'" 2>&1 | grep '^[<>ch]' | head -20
    fi
  fi
}

# Install cron from config
do_install_cron() {
  if [[ -z "$CONFIG" ]]; then
    log_err "Need --config for cron installation"
    exit 1
  fi

  log_info "Installing cron jobs from ${CONFIG}..."

  # Simple YAML parser for our config format
  local script_path
  script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

  # Remove existing rsync-backup cron entries
  crontab -l 2>/dev/null | grep -v "rsync-backup.sh" > /tmp/crontab_clean || true

  # Parse jobs from config (basic grep-based parser)
  local in_job=false
  local job_name="" job_source="" job_dest="" job_schedule="" job_ssh_key=""
  local job_snapshots="" job_retain="" job_excludes=""

  while IFS= read -r line; do
    line=$(echo "$line" | sed 's/#.*//' | sed 's/[[:space:]]*$//')
    [[ -z "$line" ]] && continue

    if echo "$line" | grep -q "^  - name:"; then
      # Save previous job
      if [[ -n "$job_name" && -n "$job_schedule" ]]; then
        local cron_cmd="${job_schedule} ${script_path} --source '${job_source}' --dest '${job_dest}' --name '${job_name}'"
        [[ -n "$job_ssh_key" ]] && cron_cmd+=" --ssh-key '${job_ssh_key}'"
        [[ "$job_snapshots" == "true" ]] && cron_cmd+=" --snapshots --retain ${job_retain:-30}"
        cron_cmd+=" >> ${LOG_DIR}/${job_name}.log 2>&1"
        echo "$cron_cmd" >> /tmp/crontab_clean
        log_ok "Added cron: ${job_name} (${job_schedule})"
      fi
      job_name=$(echo "$line" | sed 's/.*name:[[:space:]]*//')
      job_source="" job_dest="" job_schedule="" job_ssh_key=""
      job_snapshots="" job_retain=""
    elif echo "$line" | grep -q "source:"; then
      job_source=$(echo "$line" | sed 's/.*source:[[:space:]]*//')
    elif echo "$line" | grep -q "dest:"; then
      job_dest=$(echo "$line" | sed 's/.*dest:[[:space:]]*//')
    elif echo "$line" | grep -q "schedule:"; then
      job_schedule=$(echo "$line" | sed 's/.*schedule:[[:space:]]*//' | tr -d '"')
    elif echo "$line" | grep -q "ssh_key:"; then
      job_ssh_key=$(echo "$line" | sed 's/.*ssh_key:[[:space:]]*//')
    elif echo "$line" | grep -q "snapshots:"; then
      job_snapshots=$(echo "$line" | sed 's/.*snapshots:[[:space:]]*//')
    elif echo "$line" | grep -q "retain:"; then
      job_retain=$(echo "$line" | sed 's/.*retain:[[:space:]]*//')
    fi
  done < "$CONFIG"

  # Save last job
  if [[ -n "$job_name" && -n "$job_schedule" ]]; then
    local cron_cmd="${job_schedule} ${script_path} --source '${job_source}' --dest '${job_dest}' --name '${job_name}'"
    [[ -n "$job_ssh_key" ]] && cron_cmd+=" --ssh-key '${job_ssh_key}'"
    [[ "$job_snapshots" == "true" ]] && cron_cmd+=" --snapshots --retain ${job_retain:-30}"
    cron_cmd+=" >> ${LOG_DIR}/${job_name}.log 2>&1"
    echo "$cron_cmd" >> /tmp/crontab_clean
    log_ok "Added cron: ${job_name} (${job_schedule})"
  fi

  crontab /tmp/crontab_clean
  rm -f /tmp/crontab_clean
  log_ok "Cron jobs installed. View with: crontab -l"
}

# Main backup
do_backup() {
  if [[ -z "$SOURCE" || -z "$DEST" ]]; then
    log_err "Need --source and --dest"
    exit 1
  fi

  # Validate source exists
  if [[ ! "$SOURCE" == *@* ]] && [[ ! -d "$SOURCE" ]]; then
    log_err "Source directory not found: ${SOURCE}"
    exit 1
  fi

  local LOG_FILE="${LOG_DIR}/${NAME}-${TIMESTAMP}.log"
  local ACTUAL_DEST="$DEST"
  local LINK_DEST_OPT=""

  # Snapshot mode: create timestamped directory
  if $SNAPSHOTS; then
    local SNAP_DIR="${DEST}/${TIMESTAMP}"
    local LATEST="${DEST}/latest"

    # Find previous snapshot for hard-linking
    if [[ "$DEST" == *@* ]]; then
      local remote_host="${DEST%%:*}"
      local remote_path="${DEST#*:}"
      local latest_remote
      latest_remote=$(ssh "$remote_host" "readlink -f '${remote_path}/latest' 2>/dev/null" || echo "")
      if [[ -n "$latest_remote" ]]; then
        LINK_DEST_OPT="--link-dest='${latest_remote}'"
      fi
      ACTUAL_DEST="${remote_host}:${remote_path}/${TIMESTAMP}"
    else
      mkdir -p "$DEST"
      if [[ -L "$LATEST" ]] && [[ -d "$(readlink -f "$LATEST")" ]]; then
        LINK_DEST_OPT="--link-dest='$(readlink -f "$LATEST")'"
      fi
      ACTUAL_DEST="${SNAP_DIR}"
      mkdir -p "${SNAP_DIR}"
    fi
  fi

  log_info "Starting backup: ${NAME}"
  log "Source: ${SOURCE}"
  log "Dest:   ${ACTUAL_DEST}"
  $DRY_RUN && log_warn "DRY RUN — no changes will be made"

  # Pre-script
  if [[ -n "$PRE_SCRIPT" ]]; then
    log_info "Running pre-script..."
    if ! eval "$PRE_SCRIPT"; then
      log_err "Pre-script failed"
      alert_failure "Pre-script failed: ${PRE_SCRIPT}"
      exit 1
    fi
  fi

  # Build and run rsync
  local cmd
  cmd=$(build_rsync_cmd)
  [[ -n "$LINK_DEST_OPT" ]] && cmd+=" ${LINK_DEST_OPT}"

  local START_TIME=$(date +%s)

  if eval "$cmd '${SOURCE}/' '${ACTUAL_DEST}/'" 2>&1 | tee -a "$LOG_FILE"; then
    local END_TIME=$(date +%s)
    local ELAPSED=$((END_TIME - START_TIME))

    # Get transfer stats from log
    local TRANSFERRED
    TRANSFERRED=$(grep "Total transferred file size" "$LOG_FILE" 2>/dev/null | tail -1 || echo "unknown")

    log_ok "Backup complete: ${NAME} (${ELAPSED}s)"

    # Update latest symlink for snapshots
    if $SNAPSHOTS && ! $DRY_RUN; then
      if [[ "$DEST" == *@* ]]; then
        local remote_host="${DEST%%:*}"
        local remote_path="${DEST#*:}"
        ssh "$remote_host" "ln -sfn '${remote_path}/${TIMESTAMP}' '${remote_path}/latest'"
      else
        ln -sfn "${SNAP_DIR}" "${LATEST}"
      fi
      log "📊 Snapshot: ${ACTUAL_DEST}"

      # Prune old snapshots
      if [[ $RETAIN -gt 0 ]]; then
        do_prune
      fi
    fi

    alert_success "${ELAPSED}s elapsed"
  else
    local EXIT_CODE=$?
    log_err "Backup failed: ${NAME} (exit code: ${EXIT_CODE})"
    alert_failure "rsync exited with code ${EXIT_CODE}. Check ${LOG_FILE}"
    # Post-script runs even on failure
    if [[ -n "$POST_SCRIPT" ]]; then
      eval "$POST_SCRIPT" || true
    fi
    exit $EXIT_CODE
  fi

  # Post-script
  if [[ -n "$POST_SCRIPT" ]]; then
    log_info "Running post-script..."
    eval "$POST_SCRIPT" || log_warn "Post-script returned non-zero"
  fi
}

# Main dispatch
if $LIST; then
  do_list
elif $PRUNE; then
  do_prune
elif $VERIFY; then
  do_verify
elif $INSTALL_CRON; then
  do_install_cron
elif $RESTORE; then
  log_info "Restore mode"
  RESTORE=false  # Use same rsync logic, just swap semantics
  do_backup
else
  do_backup
fi
