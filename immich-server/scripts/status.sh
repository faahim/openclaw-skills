#!/bin/bash
# Immich Server — Status & Health Check
set -euo pipefail

INSTALL_DIR="${IMMICH_DIR:-/opt/immich}"

cd "$INSTALL_DIR"

# Source env
source .env 2>/dev/null || true
PORT=$(grep -oP '(\d+):2283' docker-compose.yml 2>/dev/null | cut -d: -f1)
PORT="${PORT:-2283}"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║          Immich Server Status             ║"
echo "╠══════════════════════════════════════════╣"

# Check if server is responding
if curl -sf "http://localhost:${PORT}/api/server/ping" &>/dev/null; then
  STATUS="🟢 Running"
else
  STATUS="🔴 Down"
  echo "║ Status:      $STATUS"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "Container status:"
  docker compose ps 2>/dev/null || echo "  Cannot reach Docker"
  exit 1
fi

# Get version
VERSION=$(docker inspect immich_server 2>/dev/null | jq -r '.[0].Config.Image' | cut -d: -f2 || echo "unknown")

# Get uptime
STARTED=$(docker inspect immich_server 2>/dev/null | jq -r '.[0].State.StartedAt' || echo "")
if [ -n "$STARTED" ]; then
  START_TS=$(date -d "$STARTED" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${STARTED%%.*}" +%s 2>/dev/null || echo "0")
  NOW_TS=$(date +%s)
  UPTIME_S=$((NOW_TS - START_TS))
  DAYS=$((UPTIME_S / 86400))
  HOURS=$(((UPTIME_S % 86400) / 3600))
  MINS=$(((UPTIME_S % 3600) / 60))
  UPTIME="${DAYS}d ${HOURS}h ${MINS}m"
else
  UPTIME="unknown"
fi

# Get stats via API (if API key is set)
API_KEY="${IMMICH_API_KEY:-}"
PHOTOS="-"
VIDEOS="-"
USERS="-"
USAGE="-"

if [ -n "$API_KEY" ]; then
  STATS=$(curl -sf "http://localhost:${PORT}/api/server/statistics" -H "x-api-key: $API_KEY" 2>/dev/null || echo "{}")
  if [ "$STATS" != "{}" ]; then
    PHOTOS=$(echo "$STATS" | jq -r '.photos // "-"')
    VIDEOS=$(echo "$STATS" | jq -r '.videos // "-"')
    USAGE=$(echo "$STATS" | jq -r '.usage // 0' | awk '{printf "%.1f GB", $1/1073741824}')
  fi
  USERS=$(curl -sf "http://localhost:${PORT}/api/users" -H "x-api-key: $API_KEY" 2>/dev/null | jq 'length' || echo "-")
fi

# Storage info
UPLOAD_DIR="${UPLOAD_LOCATION:-$INSTALL_DIR/upload}"
if [ -d "$UPLOAD_DIR" ]; then
  DISK_USAGE=$(du -sh "$UPLOAD_DIR" 2>/dev/null | cut -f1)
  DISK_AVAIL=$(df -h "$UPLOAD_DIR" 2>/dev/null | tail -1 | awk '{print $4}')
  STORAGE="$DISK_USAGE used / $DISK_AVAIL avail"
else
  STORAGE="N/A"
fi

# Last backup
LAST_BACKUP=$(ls -t "$INSTALL_DIR/backups/"*.sql.gz 2>/dev/null | head -1)
if [ -n "$LAST_BACKUP" ]; then
  LAST_BACKUP_DATE=$(stat -c %y "$LAST_BACKUP" 2>/dev/null | cut -d. -f1 || echo "unknown")
else
  LAST_BACKUP_DATE="Never"
fi

printf "║ %-12s %-28s ║\n" "Version:" "$VERSION"
printf "║ %-12s %-28s ║\n" "Status:" "$STATUS"
printf "║ %-12s %-28s ║\n" "Uptime:" "$UPTIME"
printf "║ %-12s %-28s ║\n" "Photos:" "$PHOTOS"
printf "║ %-12s %-28s ║\n" "Videos:" "$VIDEOS"
printf "║ %-12s %-28s ║\n" "Users:" "$USERS"
printf "║ %-12s %-28s ║\n" "Storage:" "$STORAGE"
printf "║ %-12s %-28s ║\n" "Last Backup:" "$LAST_BACKUP_DATE"
echo "╚══════════════════════════════════════════╝"

echo ""
echo "Container Health:"
docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null | while IFS= read -r line; do
  if echo "$line" | grep -qi "healthy\|up"; then
    echo "  🟢 $line"
  elif echo "$line" | grep -qi "unhealthy\|exit\|dead"; then
    echo "  🔴 $line"
  else
    echo "  ⚪ $line"
  fi
done
echo ""
