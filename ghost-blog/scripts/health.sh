#!/bin/bash
# Ghost Blog Manager — Health Check
set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass=0; fail=0

NAME="${1:-ghost}"
DEPLOY_DIR="$HOME/ghost-deployments/$NAME"

[ ! -d "$DEPLOY_DIR" ] && { echo "Deploy dir not found: $DEPLOY_DIR"; exit 1; }
cd "$DEPLOY_DIR"
source .env 2>/dev/null || true

echo ""
echo "Ghost Blog Health Check"
echo "═══════════════════════"

# Docker
if docker info > /dev/null 2>&1; then
    echo -e "${GREEN}✅${NC} Docker running"
    ((pass++))
else
    echo -e "${RED}❌${NC} Docker not running"
    ((fail++))
fi

# Ghost container
GHOST_STATUS=$(docker compose ps ghost --format json 2>/dev/null | grep -o '"Status":"[^"]*"' | head -1 || echo "")
if echo "$GHOST_STATUS" | grep -qi "running\|up\|healthy"; then
    UPTIME=$(docker inspect "$(docker compose ps -q ghost 2>/dev/null)" --format '{{.State.StartedAt}}' 2>/dev/null | head -1)
    echo -e "${GREEN}✅${NC} Ghost container: running (since $UPTIME)"
    ((pass++))
else
    echo -e "${RED}❌${NC} Ghost container: not running"
    ((fail++))
fi

# MySQL container
DB_STATUS=$(docker compose ps db --format json 2>/dev/null | grep -o '"Status":"[^"]*"' | head -1 || echo "")
if echo "$DB_STATUS" | grep -qi "running\|up\|healthy"; then
    echo -e "${GREEN}✅${NC} MySQL container: healthy"
    ((pass++))
else
    echo -e "${RED}❌${NC} MySQL container: not running"
    ((fail++))
fi

# Caddy (if exists)
if docker compose ps caddy > /dev/null 2>&1; then
    CADDY_STATUS=$(docker compose ps caddy --format json 2>/dev/null | grep -o '"Status":"[^"]*"' | head -1 || echo "")
    if echo "$CADDY_STATUS" | grep -qi "running\|up"; then
        echo -e "${GREEN}✅${NC} Caddy container: healthy"
        ((pass++))
    else
        echo -e "${RED}❌${NC} Caddy container: not running"
        ((fail++))
    fi
fi

# Ghost API
GHOST_PORT=${GHOST_PORT:-2368}
RESPONSE=$(curl -sf -o /dev/null -w "%{http_code}:%{time_total}" "http://localhost:$GHOST_PORT/" 2>/dev/null || echo "000:0")
HTTP_CODE=$(echo "$RESPONSE" | cut -d: -f1)
RESP_TIME=$(echo "$RESPONSE" | cut -d: -f2)
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
    echo -e "${GREEN}✅${NC} Ghost API: responding (${RESP_TIME}s)"
    ((pass++))
else
    echo -e "${RED}❌${NC} Ghost API: not responding (HTTP $HTTP_CODE)"
    ((fail++))
fi

# Last backup
LATEST_BACKUP=$(ls -t "$DEPLOY_DIR/backups/"*.tar.gz 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ]; then
    BACKUP_AGE=$(( ($(date +%s) - $(stat -c %Y "$LATEST_BACKUP" 2>/dev/null || stat -f %m "$LATEST_BACKUP" 2>/dev/null || echo 0)) / 3600 ))
    echo -e "${GREEN}✅${NC} Last backup: ${BACKUP_AGE}h ago ($(basename "$LATEST_BACKUP"))"
    ((pass++))
else
    echo -e "${YELLOW}⚠️${NC}  No backups found — run: bash scripts/backup.sh"
fi

# Disk usage
CONTENT_SIZE=$(docker exec "$(docker compose ps -q ghost 2>/dev/null)" du -sh /var/lib/ghost/content 2>/dev/null | cut -f1 || echo "?")
echo -e "${GREEN}ℹ️${NC}  Content size: $CONTENT_SIZE"

echo ""
echo "=== Results: ${pass} passed, ${fail} failed ==="
[ "$fail" -eq 0 ] && exit 0 || exit 1
