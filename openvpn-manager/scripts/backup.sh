#!/bin/bash
# OpenVPN Manager — Backup & Restore
set -euo pipefail

OVPN_DIR="/etc/openvpn"
CONFIG_FILE="$OVPN_DIR/.ovpn-manager.conf"

[[ $EUID -eq 0 ]] || { echo "Run as root (use sudo)" >&2; exit 1; }
[[ -f "$CONFIG_FILE" ]] || { echo "OpenVPN Manager not installed." >&2; exit 1; }
source "$CONFIG_FILE"

RESTORE=false
[[ "${1:-}" == "--restore" ]] && { RESTORE=true; shift; }

BACKUP_PATH="${1:-}"
[[ -n "$BACKUP_PATH" ]] || { echo "Usage: backup.sh [--restore] <path>"; exit 1; }

if [ "$RESTORE" = true ]; then
  [[ -f "$BACKUP_PATH" ]] || { echo "Backup file not found: $BACKUP_PATH" >&2; exit 1; }
  
  echo "⚠️  This will OVERWRITE current OpenVPN configuration."
  echo "Press Ctrl+C to cancel, or wait 5 seconds..."
  sleep 5
  
  systemctl stop "openvpn@${SERVER_NAME}" 2>/dev/null || \
    systemctl stop "openvpn-server@${SERVER_NAME}" 2>/dev/null || true
  
  tar -xzf "$BACKUP_PATH" -C /
  
  systemctl start "openvpn@${SERVER_NAME}" 2>/dev/null || \
    systemctl start "openvpn-server@${SERVER_NAME}" 2>/dev/null
  
  echo "✅ Restored from $BACKUP_PATH"
else
  mkdir -p "$(dirname "$BACKUP_PATH")"
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  ARCHIVE="${BACKUP_PATH}/openvpn-backup-${TIMESTAMP}.tar.gz"
  
  tar -czf "$ARCHIVE" \
    "$OVPN_DIR/easy-rsa/pki/" \
    "$OVPN_DIR/server.conf" \
    "$OVPN_DIR/ta.key" \
    "$OVPN_DIR/ca.crt" \
    "$OVPN_DIR/clients/" \
    "$OVPN_DIR/.ovpn-manager.conf" \
    2>/dev/null
  
  chmod 600 "$ARCHIVE"
  SIZE=$(du -h "$ARCHIVE" | cut -f1)
  echo "✅ Backup created: $ARCHIVE ($SIZE)"
  echo "🔐 Contains private keys — store securely!"
fi
