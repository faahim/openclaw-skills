#!/bin/bash
# Kopia Backup Manager — Schedule snapshots via cron
# Usage: bash schedule.sh <path> <cron-expression>
# Example: bash schedule.sh /home "0 */6 * * *"

set -euo pipefail

BACKUP_PATH="${1:?Usage: schedule.sh <path> <cron-expression>}"
CRON_EXPR="${2:?Usage: schedule.sh <path> <cron-expression>}"
LOG_DIR="${KOPIA_LOG_DIR:-/var/log/kopia}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Ensure log directory exists
sudo mkdir -p "$LOG_DIR" 2>/dev/null || mkdir -p "$LOG_DIR"

# Build the cron command
CRON_CMD="$CRON_EXPR $(command -v kopia) snapshot create '$BACKUP_PATH' >> $LOG_DIR/snapshot.log 2>&1"

# Check if entry already exists
EXISTING=$(crontab -l 2>/dev/null || true)
if echo "$EXISTING" | grep -qF "kopia snapshot create '$BACKUP_PATH'"; then
  echo "⚠️  Cron entry for '$BACKUP_PATH' already exists. Updating..."
  EXISTING=$(echo "$EXISTING" | grep -vF "kopia snapshot create '$BACKUP_PATH'")
fi

# Add new cron entry
echo "$EXISTING
$CRON_CMD" | crontab -

echo "✅ Scheduled: kopia snapshot of '$BACKUP_PATH'"
echo "   Schedule: $CRON_EXPR"
echo "   Logs: $LOG_DIR/snapshot.log"
echo ""
echo "📋 Current cron entries:"
crontab -l | grep -i kopia || echo "  (none)"
