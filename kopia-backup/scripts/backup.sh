#!/bin/bash
# Kopia automated backup script — designed for cron
set -euo pipefail

# Load config
CONFIG_FILE="${KOPIA_CONFIG:-/etc/kopia-backup.env}"
if [ -f "$CONFIG_FILE" ]; then
  set -a; source "$CONFIG_FILE"; set +a
fi

# Defaults
BACKUP_PATHS="${BACKUP_PATHS:-/home /etc}"
COMPRESSION="${COMPRESSION:-zstd}"
PARALLEL="${PARALLEL:-4}"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

send_notification() {
  local msg="$1"
  # Telegram
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    curl -sf -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="${TELEGRAM_CHAT_ID}" \
      -d text="$msg" \
      -d parse_mode="Markdown" >/dev/null 2>&1 || true
  fi
  # ntfy
  if [ -n "${NTFY_TOPIC:-}" ]; then
    curl -sf -d "$msg" "${NTFY_URL:-https://ntfy.sh}/${NTFY_TOPIC}" >/dev/null 2>&1 || true
  fi
  # Generic webhook
  if [ -n "${WEBHOOK_URL:-}" ]; then
    curl -sf -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{\"text\":\"$msg\"}" >/dev/null 2>&1 || true
  fi
}

# Check repository connection
if ! kopia repository status >/dev/null 2>&1; then
  echo "$LOG_PREFIX ❌ Kopia repository not connected"
  send_notification "❌ *Kopia Backup FAILED*: Repository not connected on $(hostname)"
  exit 1
fi

# Run backups
FAILED=0
SUCCEEDED=0
ERRORS=""

for path in $BACKUP_PATHS; do
  if [ ! -e "$path" ]; then
    echo "$LOG_PREFIX ⚠️  Path does not exist: $path"
    continue
  fi

  echo "$LOG_PREFIX 📦 Backing up: $path"
  if kopia snapshot create "$path" \
    --compression="$COMPRESSION" \
    --parallel="$PARALLEL" \
    2>&1; then
    echo "$LOG_PREFIX ✅ Done: $path"
    SUCCEEDED=$((SUCCEEDED + 1))
  else
    echo "$LOG_PREFIX ❌ Failed: $path"
    ERRORS="$ERRORS\n- $path"
    FAILED=$((FAILED + 1))
  fi
done

# Run maintenance (quick, not full)
echo "$LOG_PREFIX 🔧 Running maintenance..."
kopia maintenance run 2>&1 || true

# Summary
TOTAL=$((SUCCEEDED + FAILED))
echo "$LOG_PREFIX 📊 Backup complete: $SUCCEEDED/$TOTAL succeeded"

if [ "$FAILED" -gt 0 ]; then
  send_notification "⚠️ *Kopia Backup* on $(hostname): $SUCCEEDED/$TOTAL paths succeeded. Failed:$ERRORS"
  exit 1
else
  # Only notify on success if explicitly requested
  if [ "${NOTIFY_SUCCESS:-false}" = "true" ]; then
    # Get repo stats
    REPO_SIZE=$(kopia content stats 2>/dev/null | grep "Total size" | awk '{print $NF}' || echo "unknown")
    send_notification "✅ *Kopia Backup* on $(hostname): $SUCCEEDED paths backed up. Repo: $REPO_SIZE"
  fi
fi

echo "$LOG_PREFIX ✅ All backups completed successfully"
