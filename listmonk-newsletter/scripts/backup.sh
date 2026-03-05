#!/bin/bash
set -euo pipefail

INSTALL_DIR="${LISTMONK_DIR:-$HOME/listmonk}"
source "$INSTALL_DIR/.env" 2>/dev/null || true

COMPOSE="docker compose"
docker compose version &>/dev/null 2>&1 || COMPOSE="docker-compose"

OUTPUT="" RESTORE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --output) OUTPUT="$2"; shift 2 ;;
        --restore) RESTORE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [ -n "$RESTORE" ]; then
    [ ! -f "$RESTORE" ] && { echo "❌ Backup file not found: $RESTORE"; exit 1; }
    echo "🔄 Restoring from $RESTORE..."
    
    TMPDIR=$(mktemp -d)
    tar xzf "$RESTORE" -C "$TMPDIR"
    
    cd "$INSTALL_DIR"
    
    # Restore config files
    [ -f "$TMPDIR/env" ] && cp "$TMPDIR/env" .env
    [ -f "$TMPDIR/config.toml" ] && cp "$TMPDIR/config.toml" config.toml
    
    # Restore database
    if [ -f "$TMPDIR/db.sql" ]; then
        source .env
        $COMPOSE up -d db
        sleep 5
        docker exec -i $($COMPOSE ps -q db) psql -U "${POSTGRES_USER}" "${POSTGRES_DB}" < "$TMPDIR/db.sql"
        $COMPOSE up -d
    fi
    
    rm -rf "$TMPDIR"
    echo "✅ Restore complete. Listmonk restarted."
else
    [ -z "$OUTPUT" ] && OUTPUT="listmonk-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    echo "📦 Backing up Listmonk..."
    cd "$INSTALL_DIR"
    
    TMPDIR=$(mktemp -d)
    
    # Backup config
    cp .env "$TMPDIR/env" 2>/dev/null || true
    cp config.toml "$TMPDIR/config.toml" 2>/dev/null || true
    
    # Backup database
    source .env
    DB_CONTAINER=$($COMPOSE ps -q db)
    if [ -n "$DB_CONTAINER" ]; then
        docker exec "$DB_CONTAINER" pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" > "$TMPDIR/db.sql"
        echo "  ✅ Database dumped"
    fi
    
    # Package
    tar czf "$OUTPUT" -C "$TMPDIR" .
    rm -rf "$TMPDIR"
    
    SIZE=$(du -h "$OUTPUT" | cut -f1)
    echo "✅ Backup saved: $OUTPUT ($SIZE)"
fi
