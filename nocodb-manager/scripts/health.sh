#!/bin/bash
# NocoDB Health Check Script
set -euo pipefail

CONFIG_FILE="$HOME/.nocodb/.nocodb-config"
VERBOSE=false
RESOURCES=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose) VERBOSE=true; shift ;;
    --resources) RESOURCES=true; shift ;;
    *) shift ;;
  esac
done

# Load config
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  CONTAINER_NAME="nocodb"
  PORT=8080
  BACKEND="sqlite"
fi

echo "🏥 NocoDB Health Check"
echo "====================="

# Check container
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  VERSION=$(docker inspect "$CONTAINER_NAME" --format '{{.Config.Image}}' | cut -d: -f2)
  UPTIME=$(docker inspect "$CONTAINER_NAME" --format '{{.State.StartedAt}}')
  START_EPOCH=$(date -d "$UPTIME" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${UPTIME%%.*}" +%s 2>/dev/null || echo 0)
  NOW_EPOCH=$(date +%s)
  DIFF=$((NOW_EPOCH - START_EPOCH))
  DAYS=$((DIFF / 86400))
  HOURS=$(( (DIFF % 86400) / 3600 ))
  MINS=$(( (DIFF % 3600) / 60 ))
  echo "✅ NocoDB: Running (${VERSION})"
  echo "✅ Uptime: ${DAYS}d ${HOURS}h ${MINS}m"
else
  echo "❌ NocoDB: Not running"
  echo "   Start with: bash scripts/deploy.sh"
  exit 1
fi

# Check HTTP
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:${PORT}/api/v1/health" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" ]]; then
  echo "✅ HTTP: Responding (port ${PORT})"
else
  echo "⚠️  HTTP: Status $HTTP_CODE (port ${PORT})"
fi

# Check database
if [[ "$BACKEND" == "postgres" ]]; then
  if docker exec "${CONTAINER_NAME}-db" pg_isready -U nocodb &>/dev/null; then
    PG_VER=$(docker exec "${CONTAINER_NAME}-db" psql -U nocodb -t -c "SELECT version();" 2>/dev/null | head -1 | xargs)
    echo "✅ Database: Connected (${PG_VER:-PostgreSQL})"
  else
    echo "❌ Database: PostgreSQL not responding"
  fi
elif [[ "$BACKEND" == "mysql" ]]; then
  if docker exec "${CONTAINER_NAME}-db" mysqladmin ping -h localhost &>/dev/null; then
    echo "✅ Database: Connected (MySQL)"
  else
    echo "❌ Database: MySQL not responding"
  fi
else
  echo "✅ Database: SQLite (embedded)"
fi

# Resource usage
if $RESOURCES || $VERBOSE; then
  echo ""
  echo "📊 Resources"
  echo "------------"
  docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" "$CONTAINER_NAME" "${CONTAINER_NAME}-db" 2>/dev/null || \
  docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" "$CONTAINER_NAME" 2>/dev/null
fi

# Disk usage
DATA_SIZE=$(docker exec "$CONTAINER_NAME" du -sh /usr/app/data 2>/dev/null | cut -f1 || echo "N/A")
echo "💾 Data: ${DATA_SIZE}"

# Verbose: show config
if $VERBOSE; then
  echo ""
  echo "⚙️  Config"
  echo "---------"
  echo "Backend: $BACKEND"
  echo "Port: $PORT"
  echo "Data dir: ${DATA_DIR:-~/.nocodb}"
  echo "Container: $CONTAINER_NAME"
fi

echo ""
echo "🔗 URL: http://localhost:${PORT}"
