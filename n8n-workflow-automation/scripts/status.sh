#!/bin/bash
# Check n8n status
set -euo pipefail

N8N_DIR="${N8N_DIR:-$HOME/.n8n}"
N8N_PORT="${N8N_PORT:-5678}"

if ! docker compose -f "$N8N_DIR/docker-compose.yml" ps --status running 2>/dev/null | grep -q n8n; then
  echo "❌ n8n is not running"
  echo "   Start with: bash scripts/deploy.sh"
  exit 1
fi

# Get container info
CONTAINER_ID=$(docker compose -f "$N8N_DIR/docker-compose.yml" ps -q n8n 2>/dev/null)

# Health check
START=$(date +%s%3N)
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "http://localhost:$N8N_PORT/healthz" 2>/dev/null || echo "000")
END=$(date +%s%3N)
LATENCY=$((END - START))

if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ n8n is running at http://localhost:$N8N_PORT"
else
  echo "⚠️  n8n container running but API unhealthy (HTTP $HTTP_CODE)"
fi

# Version
VERSION=$(docker exec "$CONTAINER_ID" n8n --version 2>/dev/null || echo "unknown")
echo "📊 Version: $VERSION"

# Data location
echo "💾 Data: $N8N_DIR"

# Uptime
UPTIME=$(docker inspect --format='{{.State.StartedAt}}' "$CONTAINER_ID" 2>/dev/null)
if [ -n "$UPTIME" ]; then
  echo "⏱️  Started: $UPTIME"
fi

# Resource usage
STATS=$(docker stats "$CONTAINER_ID" --no-stream --format '{{.CPUPerc}} CPU | {{.MemUsage}} RAM' 2>/dev/null || echo "unavailable")
echo "📈 Resources: $STATS"

# API response time
echo "⚡ API latency: ${LATENCY}ms"

# Workflow count (via API if accessible)
WORKFLOWS=$(curl -sf "http://localhost:$N8N_PORT/api/v1/workflows?limit=0" 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | cut -d: -f2 || echo "?")
echo "📋 Workflows: $WORKFLOWS"
