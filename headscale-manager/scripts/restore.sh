#!/bin/bash
# Headscale Restore — Restores from a backup archive
# Usage: bash restore.sh /path/to/backup.tar.gz

set -euo pipefail

BACKUP_FILE="${1:?Usage: bash restore.sh /path/to/headscale-backup.tar.gz}"

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "[ERROR] Backup file not found: $BACKUP_FILE"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] This script must be run as root (use sudo)"
    exit 1
fi

echo "[WARN] This will overwrite your current Headscale database and config."
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo "[INFO] Stopping Headscale..."
systemctl stop headscale 2>/dev/null || true

echo "[INFO] Restoring from: $BACKUP_FILE"
tar xzf "$BACKUP_FILE" -C /

chown -R headscale:headscale /var/lib/headscale
chown headscale:headscale /etc/headscale/config.yaml

echo "[INFO] Starting Headscale..."
systemctl start headscale

echo "[INFO] ✅ Restore complete!"
echo "[INFO] Check status: sudo systemctl status headscale"
