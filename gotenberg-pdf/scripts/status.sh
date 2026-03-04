#!/bin/bash
CONTAINER="${GOTENBERG_CONTAINER:-gotenberg}"
PORT="${GOTENBERG_PORT:-3000}"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "✅ Gotenberg is running"
  echo "   Container: $CONTAINER"
  echo "   Port: $PORT"
  docker ps --filter "name=$CONTAINER" --format "   Image: {{.Image}}\n   Status: {{.Status}}\n   Created: {{.CreatedAt}}"
  echo ""
  if curl -sf "http://localhost:${PORT}/health" >/dev/null 2>&1; then
    echo "   Health: OK"
  else
    echo "   Health: UNHEALTHY (port $PORT not responding)"
  fi
else
  echo "❌ Gotenberg is not running"
  echo "   Start with: bash scripts/start.sh"
fi
