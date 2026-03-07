#!/bin/bash
# Ghost Blog Manager — View Logs
NAME="${GHOST_DEPLOY_NAME:-ghost}"
DEPLOY_DIR="$HOME/ghost-deployments/$NAME"
cd "$DEPLOY_DIR" 2>/dev/null || { echo "Deploy not found: $DEPLOY_DIR"; exit 1; }

SERVICE="${1:-}"
LINES="${2:-50}"

if [ -n "$SERVICE" ]; then
    docker compose logs --tail "$LINES" -f "$SERVICE" 2>/dev/null || docker-compose logs --tail "$LINES" -f "$SERVICE"
else
    docker compose logs --tail "$LINES" -f 2>/dev/null || docker-compose logs --tail "$LINES" -f
fi
