#!/bin/bash
# Restore CrowdSec from backup
# Usage: bash restore.sh <backup-dir>
set -euo pipefail

BACKUP_DIR="${1:-}"

if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    echo "Usage: bash restore.sh <backup-dir>"
    exit 1
fi

echo "🔄 Restoring CrowdSec from $BACKUP_DIR..."

sudo systemctl stop crowdsec 2>/dev/null || true

# Restore config
if [ -d "$BACKUP_DIR/config" ]; then
    sudo cp -r "$BACKUP_DIR/config/"* /etc/crowdsec/
    echo "✅ Config restored"
fi

# Restore database
if [ -f "$BACKUP_DIR/crowdsec.db" ]; then
    sudo cp "$BACKUP_DIR/crowdsec.db" /var/lib/crowdsec/data/
    echo "✅ Database restored"
fi

# Reinstall hub items
if [ -f "$BACKUP_DIR/hub-state.json" ]; then
    echo "📚 Reinstalling hub items..."
    jq -r '.[] | select(.installed == true) | .name' "$BACKUP_DIR/hub-state.json" 2>/dev/null | while read item; do
        cscli install "$item" 2>/dev/null || true
    done
fi

sudo systemctl start crowdsec
echo "✅ CrowdSec restored and running"
