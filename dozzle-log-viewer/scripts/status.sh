#!/bin/bash
# Dozzle Log Viewer — Status Check
set -euo pipefail

CONTAINER_NAME="${1:-dozzle}"

if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "❌ Dozzle is not deployed (no container named '${CONTAINER_NAME}')"
  exit 1
fi

STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
UPTIME=$(docker inspect -f '{{.State.StartedAt}}' "$CONTAINER_NAME" 2>/dev/null)
PORT=$(docker port "$CONTAINER_NAME" 8080 2>/dev/null | head -1 | cut -d: -f2)
IMAGE=$(docker inspect -f '{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null)
RESTART=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$CONTAINER_NAME" 2>/dev/null)

echo "📊 Dozzle Status"
echo "   Container: ${CONTAINER_NAME}"
echo "   Status:    ${STATUS}"
echo "   Image:     ${IMAGE}"
echo "   Port:      ${PORT:-unknown}"
echo "   Started:   ${UPTIME}"
echo "   Restart:   ${RESTART}"

# Health check
if [[ "$STATUS" == "running" ]]; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://localhost:${PORT:-8080}" 2>/dev/null || echo "000")
  if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 400 ]]; then
    echo "   Health:    ✅ Responding (HTTP ${HTTP_CODE})"
  else
    echo "   Health:    ⚠️  Not responding (HTTP ${HTTP_CODE})"
  fi

  # Resource usage
  STATS=$(docker stats "$CONTAINER_NAME" --no-stream --format "CPU: {{.CPUPerc}} | RAM: {{.MemUsage}}" 2>/dev/null)
  echo "   Resources: ${STATS}"
fi
