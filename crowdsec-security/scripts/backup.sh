#!/bin/bash
# Backup CrowdSec configuration and data
# Usage: bash backup.sh [backup-dir]
set -euo pipefail

BACKUP_DIR="${1:-/tmp/crowdsec-backup-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$BACKUP_DIR"

echo "💾 Backing up CrowdSec to $BACKUP_DIR..."

# Config files
sudo cp -r /etc/crowdsec "$BACKUP_DIR/config" 2>/dev/null || echo "⚠️  Config dir not found"

# Hub state (installed collections, scenarios, parsers)
cscli hub list -o json > "$BACKUP_DIR/hub-state.json" 2>/dev/null || true

# Current decisions
cscli decisions list -o json > "$BACKUP_DIR/decisions.json" 2>/dev/null || true

# Bouncers list
cscli bouncers list -o json > "$BACKUP_DIR/bouncers.json" 2>/dev/null || true

# Database
sudo cp /var/lib/crowdsec/data/crowdsec.db "$BACKUP_DIR/" 2>/dev/null || echo "⚠️  Database not found"

echo "✅ Backup complete: $BACKUP_DIR"
ls -lh "$BACKUP_DIR/"
