#!/bin/bash
# Radicale Server Status
set -e

RADICALE_CONFIG_DIR="${RADICALE_CONFIG_DIR:-$HOME/.config/radicale}"
RADICALE_DATA_DIR="${RADICALE_DATA_DIR:-$HOME/.local/share/radicale/collections}"
RADICALE_PORT="${RADICALE_PORT:-5232}"

echo "🗓️  Radicale Server Status"
echo "─────────────────────────"

# Check if running
PID=$(pgrep -f "python.*radicale" 2>/dev/null | head -1)
if [ -n "$PID" ]; then
  echo "Status:     ✅ Running (PID $PID)"
  # Uptime
  if [ -f "/proc/$PID/stat" ]; then
    START=$(stat -c %Y "/proc/$PID" 2>/dev/null || echo "")
    if [ -n "$START" ]; then
      NOW=$(date +%s)
      UPTIME_SECS=$((NOW - START))
      DAYS=$((UPTIME_SECS / 86400))
      HOURS=$(((UPTIME_SECS % 86400) / 3600))
      echo "Uptime:     ${DAYS}d ${HOURS}h"
    fi
  fi
elif systemctl --user is-active radicale &>/dev/null 2>&1; then
  echo "Status:     ✅ Running (systemd)"
else
  echo "Status:     ❌ Stopped"
fi

# Config
if [ -f "$RADICALE_CONFIG_DIR/config" ]; then
  HOST=$(grep "^hosts" "$RADICALE_CONFIG_DIR/config" 2>/dev/null | awk -F'=' '{print $2}' | xargs)
  echo "Address:    http://${HOST:-localhost:$RADICALE_PORT}"
fi

# Users
if [ -f "$RADICALE_CONFIG_DIR/users" ]; then
  USER_COUNT=$(wc -l < "$RADICALE_CONFIG_DIR/users" 2>/dev/null || echo 0)
  echo "Users:      $USER_COUNT"
fi

# Storage stats
if [ -d "$RADICALE_DATA_DIR" ]; then
  CAL_COUNT=$(find "$RADICALE_DATA_DIR" -name "*.ics" -type f 2>/dev/null | wc -l)
  CONTACT_COUNT=$(find "$RADICALE_DATA_DIR" -name "*.vcf" -type f 2>/dev/null | wc -l)
  STORAGE_SIZE=$(du -sh "$RADICALE_DATA_DIR" 2>/dev/null | cut -f1)
  echo "Calendars:  $CAL_COUNT item(s)"
  echo "Contacts:   $CONTACT_COUNT item(s)"
  echo "Storage:    $STORAGE_SIZE in $RADICALE_DATA_DIR"
else
  echo "Storage:    Not initialized"
fi

echo ""
echo "Config:     $RADICALE_CONFIG_DIR/config"
echo "Data:       $RADICALE_DATA_DIR"
