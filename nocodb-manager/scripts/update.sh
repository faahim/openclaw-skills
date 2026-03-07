#!/bin/bash
# NocoDB Update Script
set -euo pipefail

CONFIG_FILE="$HOME/.nocodb/.nocodb-config"
ROLLBACK=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --rollback) ROLLBACK=true; shift ;;
    *) shift ;;
  esac
done

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  CONTAINER_NAME="nocodb"
  DATA_DIR="$HOME/.nocodb"
  BACKEND="sqlite"
fi

if $ROLLBACK; then
  PREV_IMAGE=$(cat "${DATA_DIR}/.nocodb-prev-image" 2>/dev/null || echo "")
  if [[ -z "$PREV_IMAGE" ]]; then
    echo "❌ No previous image found to rollback to"
    exit 1
  fi
  echo "🔄 Rolling back to: $PREV_IMAGE"

  if [[ -f "${DATA_DIR}/docker-compose.yml" ]]; then
    sed -i "s|image: nocodb/nocodb:.*|image: ${PREV_IMAGE}|" "${DATA_DIR}/docker-compose.yml"
    cd "$DATA_DIR" && docker compose up -d
  else
    docker stop "$CONTAINER_NAME" && docker rm "$CONTAINER_NAME"
    source "$CONFIG_FILE"
    docker run -d --name "$CONTAINER_NAME" --restart unless-stopped \
      -p "${PORT}:8080" \
      -e "NC_AUTH_JWT_SECRET=${NC_AUTH_JWT_SECRET}" \
      -v "${DATA_DIR}:/usr/app/data" \
      "$PREV_IMAGE"
  fi
  echo "✅ Rolled back successfully"
  exit 0
fi

# Save current image for rollback
CURRENT_IMAGE=$(docker inspect "$CONTAINER_NAME" --format '{{.Config.Image}}' 2>/dev/null || echo "")
[[ -n "$CURRENT_IMAGE" ]] && echo "$CURRENT_IMAGE" > "${DATA_DIR}/.nocodb-prev-image"

echo "🔄 Updating NocoDB..."
echo "  📥 Pulling latest image..."
docker pull nocodb/nocodb:latest

NEW_ID=$(docker inspect nocodb/nocodb:latest --format '{{.Id}}' 2>/dev/null)
OLD_ID=$(docker inspect "$CONTAINER_NAME" --format '{{.Image}}' 2>/dev/null)

if [[ "$NEW_ID" == "$OLD_ID" ]]; then
  echo "✅ Already running latest version"
  exit 0
fi

echo "  🔄 Restarting with new image..."
if [[ -f "${DATA_DIR}/docker-compose.yml" ]]; then
  cd "$DATA_DIR" && docker compose up -d --force-recreate
else
  docker stop "$CONTAINER_NAME" && docker rm "$CONTAINER_NAME"
  source "$CONFIG_FILE"
  docker run -d --name "$CONTAINER_NAME" --restart unless-stopped \
    -p "${PORT}:8080" \
    -e "NC_AUTH_JWT_SECRET=${NC_AUTH_JWT_SECRET}" \
    -v "${DATA_DIR}:/usr/app/data" \
    nocodb/nocodb:latest
fi

# Verify
sleep 3
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "✅ NocoDB updated successfully"
  echo "   Previous: ${CURRENT_IMAGE}"
  echo "   Current: nocodb/nocodb:latest"
  echo "   Rollback: bash scripts/update.sh --rollback"
else
  echo "❌ Update failed! Rolling back..."
  bash "$0" --rollback
fi
