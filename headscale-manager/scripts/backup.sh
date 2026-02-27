#!/bin/bash
# Headscale Backup — Backs up database and config
# Usage: bash backup.sh [backup-dir]

set -euo pipefail

BACKUP_DIR="${1:-/var/lib/headscale/backups}"
CONFIG_DIR="/etc/headscale"
DATA_DIR="/var/lib/headscale"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/headscale-backup-${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "[INFO] Backing up Headscale..."

# Create backup
tar czf "$BACKUP_FILE" \
    -C / \
    "${CONFIG_DIR#/}/config.yaml" \
    "${CONFIG_DIR#/}/acl.yaml" 2>/dev/null \
    "${DATA_DIR#/}/db.sqlite" \
    "${DATA_DIR#/}/private.key" \
    "${DATA_DIR#/}/noise_private.key" \
    2>/dev/null || \
tar czf "$BACKUP_FILE" \
    -C / \
    "${CONFIG_DIR#/}/config.yaml" \
    "${DATA_DIR#/}/db.sqlite" \
    2>/dev/null

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[INFO] ✅ Backup created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Prune old backups (keep last 10)
ls -t "${BACKUP_DIR}"/headscale-backup-*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
echo "[INFO] Old backups pruned (keeping last 10)"
