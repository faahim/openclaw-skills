#!/bin/bash
# Backup Minecraft server world data
set -euo pipefail

MC_DIR="${MC_DIR:-$HOME/minecraft-server}"
MC_BACKUP_DIR="${MC_BACKUP_DIR:-$MC_DIR/backups}"
MC_BACKUP_KEEP="${MC_BACKUP_KEEP:-10}"
MC_SCREEN="${MC_SCREEN:-minecraft}"
ACTION="backup"

while [[ $# -gt 0 ]]; do
  case $1 in
    --list) ACTION="list"; shift ;;
    --restore) ACTION="restore"; RESTORE_FILE="$2"; shift 2 ;;
    --schedule) ACTION="schedule"; INTERVAL="$2"; shift 2 ;;
    --dir) MC_BACKUP_DIR="$2"; shift 2 ;;
    --keep) MC_BACKUP_KEEP="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

mkdir -p "$MC_BACKUP_DIR"
cd "$MC_DIR"

case "$ACTION" in
  backup)
    TIMESTAMP=$(date +%Y-%m-%d_%H-%M)
    BACKUP_FILE="$MC_BACKUP_DIR/${TIMESTAMP}.tar.gz"
    
    # Tell server to save and disable auto-save during backup
    if screen -list | grep -q "\.$MC_SCREEN\b"; then
      screen -S "$MC_SCREEN" -X stuff "save-all\n"
      sleep 3
      screen -S "$MC_SCREEN" -X stuff "save-off\n"
      sleep 1
    fi
    
    # Compress world data + config
    tar -czf "$BACKUP_FILE" \
      --exclude='backups' \
      --exclude='logs' \
      --exclude='*.jar' \
      --exclude='cache' \
      world/ world_nether/ world_the_end/ \
      server.properties whitelist.json ops.json banned-players.json banned-ips.json \
      2>/dev/null || true
    
    # Re-enable auto-save
    if screen -list | grep -q "\.$MC_SCREEN\b"; then
      screen -S "$MC_SCREEN" -X stuff "save-on\n"
    fi
    
    SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    echo "✅ Backup saved to $BACKUP_FILE ($SIZE)"
    
    # Prune old backups
    BACKUP_COUNT=$(ls -1 "$MC_BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
    if [[ "$BACKUP_COUNT" -gt "$MC_BACKUP_KEEP" ]]; then
      REMOVE_COUNT=$((BACKUP_COUNT - MC_BACKUP_KEEP))
      ls -1t "$MC_BACKUP_DIR"/*.tar.gz | tail -n "$REMOVE_COUNT" | xargs rm -f
      echo "🗑️  Pruned $REMOVE_COUNT old backups (keeping $MC_BACKUP_KEEP)"
    fi
    ;;
    
  list)
    echo "📦 Backups in $MC_BACKUP_DIR:"
    if ls "$MC_BACKUP_DIR"/*.tar.gz &>/dev/null; then
      ls -lhS "$MC_BACKUP_DIR"/*.tar.gz | awk '{print "  " $NF " (" $5 ")"}'
      TOTAL=$(du -sh "$MC_BACKUP_DIR" | cut -f1)
      echo "  Total: $TOTAL"
    else
      echo "  (none)"
    fi
    ;;
    
  restore)
    if [[ "$RESTORE_FILE" == "latest" ]]; then
      RESTORE_FILE=$(ls -1t "$MC_BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
      if [[ -z "$RESTORE_FILE" ]]; then
        echo "❌ No backups found"
        exit 1
      fi
    elif [[ ! "$RESTORE_FILE" == /* ]]; then
      RESTORE_FILE="$MC_BACKUP_DIR/$RESTORE_FILE"
    fi
    
    if [[ ! -f "$RESTORE_FILE" ]]; then
      echo "❌ Backup not found: $RESTORE_FILE"
      exit 1
    fi
    
    # Stop server if running
    if screen -list | grep -q "\.$MC_SCREEN\b"; then
      echo "🛑 Stopping server for restore..."
      SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      bash "$SCRIPT_DIR/stop.sh"
      sleep 3
    fi
    
    echo "📦 Restoring from $(basename "$RESTORE_FILE")..."
    tar -xzf "$RESTORE_FILE" -C "$MC_DIR"
    echo "✅ Restore complete. Start the server to use restored world."
    ;;
    
  schedule)
    HOURS="${INTERVAL%h}"
    if [[ ! "$HOURS" =~ ^[0-9]+$ ]]; then
      echo "❌ Invalid interval: $INTERVAL (use format: 6h)"
      exit 1
    fi
    SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backup.sh"
    CRON_EXPR="0 */$HOURS * * *"
    (crontab -l 2>/dev/null | grep -v "minecraft.*backup"; echo "$CRON_EXPR MC_DIR=$MC_DIR bash $SCRIPT_PATH >> $MC_DIR/logs/backup.log 2>&1") | crontab -
    echo "✅ Cron job added: backup every ${HOURS}h"
    ;;
esac
