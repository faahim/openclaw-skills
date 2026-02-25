#!/bin/bash
set -euo pipefail

# Authelia Backup & Restore Script

ACTION="backup"
OUTPUT=""
RESTORE_FILE=""
DATA_DIR="authelia-data"

while [[ $# -gt 0 ]]; do
  case $1 in
    --output) OUTPUT="$2"; shift 2 ;;
    --restore) ACTION="restore"; RESTORE_FILE="$2"; shift 2 ;;
    --dir) DATA_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage:"
      echo "  Backup:  bash scripts/backup.sh --output /path/to/backup.tar.gz"
      echo "  Restore: bash scripts/backup.sh --restore /path/to/backup.tar.gz"
      exit 0
      ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

case "$ACTION" in
  backup)
    if [[ -z "$OUTPUT" ]]; then
      OUTPUT="authelia-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    fi

    echo "📦 Backing up Authelia..."
    echo "   Source: $DATA_DIR"
    echo "   Output: $OUTPUT"

    # Stop Authelia briefly for consistent backup
    if docker ps --format '{{.Names}}' | grep -q authelia; then
      echo "   Pausing Authelia for consistent backup..."
      docker compose -f "$DATA_DIR/docker-compose.yml" stop authelia 2>/dev/null || true
      RESTART=true
    else
      RESTART=false
    fi

    # Create backup
    tar -czf "$OUTPUT" \
      -C "$(dirname "$DATA_DIR")" \
      "$(basename "$DATA_DIR")/configuration.yml" \
      "$(basename "$DATA_DIR")/users_database.yml" \
      "$(basename "$DATA_DIR")/docker-compose.yml" \
      "$(basename "$DATA_DIR")/secrets/" \
      "$(basename "$DATA_DIR")/data/" 2>/dev/null || \
    tar -czf "$OUTPUT" \
      -C "$(dirname "$DATA_DIR")" \
      "$(basename "$DATA_DIR")/configuration.yml" \
      "$(basename "$DATA_DIR")/users_database.yml" \
      "$(basename "$DATA_DIR")/docker-compose.yml" \
      "$(basename "$DATA_DIR")/secrets/"

    # Restart if we stopped it
    if $RESTART; then
      docker compose -f "$DATA_DIR/docker-compose.yml" start authelia 2>/dev/null || true
    fi

    SIZE=$(du -h "$OUTPUT" | cut -f1)
    echo "✅ Backup complete: $OUTPUT ($SIZE)"
    ;;

  restore)
    if [[ -z "$RESTORE_FILE" || ! -f "$RESTORE_FILE" ]]; then
      echo "Error: Backup file not found: $RESTORE_FILE"
      exit 1
    fi

    echo "🔄 Restoring Authelia from $RESTORE_FILE..."
    echo "⚠️  This will overwrite current configuration!"
    echo -n "Continue? (y/N): "
    read -r CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
      echo "Aborted."
      exit 0
    fi

    # Stop Authelia
    if docker ps --format '{{.Names}}' | grep -q authelia; then
      docker compose -f "$DATA_DIR/docker-compose.yml" down 2>/dev/null || true
    fi

    # Extract backup
    tar -xzf "$RESTORE_FILE" -C "$(dirname "$DATA_DIR")"

    echo "✅ Restore complete!"
    echo "   Start with: cd $DATA_DIR && docker compose up -d"
    ;;
esac
