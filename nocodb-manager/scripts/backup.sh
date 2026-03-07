#!/bin/bash
# NocoDB Backup & Restore Script
set -euo pipefail

CONFIG_FILE="$HOME/.nocodb/.nocodb-config"
ACTION="backup"
OUTPUT=""
SCHEDULE=""
KEEP=7
RESTORE_FILE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Backup and restore NocoDB data.

OPTIONS:
  --output <path>           Backup output path (default: auto-generated)
  --restore <file>          Restore from backup file
  --schedule <daily|weekly> Set up automated backup cron
  --keep <n>                Number of backups to keep (default: 7)
  -h, --help                Show this help
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --output) OUTPUT="$2"; shift 2 ;;
    --restore) ACTION="restore"; RESTORE_FILE="$2"; shift 2 ;;
    --schedule) SCHEDULE="$2"; shift 2 ;;
    --keep) KEEP="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

# Load config
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  DATA_DIR="$HOME/.nocodb"
  CONTAINER_NAME="nocodb"
  BACKEND="sqlite"
fi

case "$ACTION" in
  backup)
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    OUTPUT="${OUTPUT:-${DATA_DIR}/backups/nocodb-${TIMESTAMP}.tar.gz}"
    BACKUP_DIR=$(dirname "$OUTPUT")
    mkdir -p "$BACKUP_DIR"

    echo "📦 Backing up NocoDB..."

    # Create temp dir for backup assembly
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT

    # Backup NocoDB data volume
    echo "  📁 Exporting data volume..."
    docker cp "${CONTAINER_NAME}:/usr/app/data" "${TMP_DIR}/data" 2>/dev/null || true

    # Backup database if postgres/mysql
    if [[ "$BACKEND" == "postgres" ]]; then
      echo "  🐘 Dumping PostgreSQL..."
      docker exec "${CONTAINER_NAME}-db" pg_dump -U nocodb nocodb > "${TMP_DIR}/database.sql" 2>/dev/null || true
    elif [[ "$BACKEND" == "mysql" ]]; then
      echo "  🐬 Dumping MySQL..."
      docker exec "${CONTAINER_NAME}-db" mysqldump -u nocodb --password="${MYSQL_PASSWORD:-}" nocodb > "${TMP_DIR}/database.sql" 2>/dev/null || true
    fi

    # Copy config
    cp "$CONFIG_FILE" "${TMP_DIR}/.nocodb-config" 2>/dev/null || true
    [[ -f "${DATA_DIR}/docker-compose.yml" ]] && cp "${DATA_DIR}/docker-compose.yml" "${TMP_DIR}/" 2>/dev/null || true

    # Create tarball
    tar -czf "$OUTPUT" -C "$TMP_DIR" .

    SIZE=$(du -h "$OUTPUT" | cut -f1)
    echo "✅ Backup saved: $OUTPUT ($SIZE)"

    # Prune old backups
    if [[ -d "$BACKUP_DIR" ]]; then
      BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/nocodb-*.tar.gz 2>/dev/null | wc -l)
      if [[ $BACKUP_COUNT -gt $KEEP ]]; then
        PRUNE=$((BACKUP_COUNT - KEEP))
        ls -1t "$BACKUP_DIR"/nocodb-*.tar.gz | tail -n "$PRUNE" | xargs rm -f
        echo "🗑️  Pruned $PRUNE old backup(s) (keeping $KEEP)"
      fi
    fi

    # Schedule cron if requested
    if [[ -n "$SCHEDULE" ]]; then
      SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
      CRON_CMD="bash $SCRIPT_PATH --output ${BACKUP_DIR}/nocodb-\$(date +\%Y\%m\%d).tar.gz --keep $KEEP"

      case "$SCHEDULE" in
        daily)  CRON_EXPR="0 2 * * *" ;;
        weekly) CRON_EXPR="0 2 * * 0" ;;
        *) echo "❌ Invalid schedule: $SCHEDULE (use daily or weekly)"; exit 1 ;;
      esac

      # Add to crontab (avoid duplicates)
      (crontab -l 2>/dev/null | grep -v "nocodb.*backup" || true; echo "${CRON_EXPR} ${CRON_CMD}") | crontab -
      echo "⏰ Scheduled ${SCHEDULE} backup at 2:00 AM"
    fi
    ;;

  restore)
    if [[ ! -f "$RESTORE_FILE" ]]; then
      echo "❌ Backup file not found: $RESTORE_FILE"
      exit 1
    fi

    echo "🔄 Restoring NocoDB from: $RESTORE_FILE"
    echo "⚠️  This will stop NocoDB and replace current data!"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT

    tar -xzf "$RESTORE_FILE" -C "$TMP_DIR"

    # Stop NocoDB
    echo "  ⏹️  Stopping NocoDB..."
    if [[ -f "${DATA_DIR}/docker-compose.yml" ]]; then
      cd "$DATA_DIR" && docker compose down
    else
      docker stop "$CONTAINER_NAME" 2>/dev/null || true
      docker rm "$CONTAINER_NAME" 2>/dev/null || true
    fi

    # Restore data
    echo "  📁 Restoring data..."
    if [[ -d "${TMP_DIR}/data" ]]; then
      rm -rf "${DATA_DIR}/data"
      cp -r "${TMP_DIR}/data" "${DATA_DIR}/data"
    fi

    # Restore config
    [[ -f "${TMP_DIR}/.nocodb-config" ]] && cp "${TMP_DIR}/.nocodb-config" "$CONFIG_FILE"
    [[ -f "${TMP_DIR}/docker-compose.yml" ]] && cp "${TMP_DIR}/docker-compose.yml" "${DATA_DIR}/"

    # Restart
    echo "  🚀 Restarting NocoDB..."
    if [[ -f "${DATA_DIR}/docker-compose.yml" ]]; then
      cd "$DATA_DIR" && docker compose up -d
    else
      source "$CONFIG_FILE" 2>/dev/null || true
      docker run -d --name "$CONTAINER_NAME" --restart unless-stopped \
        -p "${PORT:-8080}:8080" \
        -e "NC_AUTH_JWT_SECRET=${NC_AUTH_JWT_SECRET:-}" \
        -v "${DATA_DIR}/data:/usr/app/data" \
        nocodb/nocodb:latest
    fi

    # Restore database dump if exists
    if [[ -f "${TMP_DIR}/database.sql" ]]; then
      echo "  💾 Restoring database dump..."
      sleep 5  # Wait for DB to be ready
      source "$CONFIG_FILE" 2>/dev/null || true
      if [[ "${BACKEND:-sqlite}" == "postgres" ]]; then
        docker exec -i "${CONTAINER_NAME}-db" psql -U nocodb nocodb < "${TMP_DIR}/database.sql"
      elif [[ "${BACKEND:-sqlite}" == "mysql" ]]; then
        docker exec -i "${CONTAINER_NAME}-db" mysql -u nocodb --password="${MYSQL_PASSWORD:-}" nocodb < "${TMP_DIR}/database.sql"
      fi
    fi

    echo "✅ Restore complete! NocoDB running at http://localhost:${PORT:-8080}"
    ;;
esac
