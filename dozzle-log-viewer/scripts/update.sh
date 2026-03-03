#!/bin/bash
# Dozzle Log Viewer — Update Script
set -euo pipefail

CONTAINER_NAME="${1:-dozzle}"
IMAGE="amir20/dozzle:latest"

if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "❌ No Dozzle container found. Deploy first: bash scripts/deploy.sh"
  exit 1
fi

echo "🔄 Updating Dozzle..."

# Get current config
OLD_IMAGE_ID=$(docker inspect -f '{{.Image}}' "$CONTAINER_NAME" 2>/dev/null)

# Pull latest
docker pull "$IMAGE" --quiet
NEW_IMAGE_ID=$(docker inspect -f '{{.Id}}' "$IMAGE" 2>/dev/null)

if [[ "$OLD_IMAGE_ID" == "$NEW_IMAGE_ID" ]]; then
  echo "✅ Already running latest version."
  exit 0
fi

# Get existing config for recreation
PORT=$(docker port "$CONTAINER_NAME" 8080 2>/dev/null | head -1 | cut -d: -f2)
PORT="${PORT:-8080}"

# Get environment variables
ENVS=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$CONTAINER_NAME" 2>/dev/null)

# Get volume mounts
VOLUMES=$(docker inspect -f '{{range .Mounts}}-v {{.Source}}:{{.Destination}}{{if eq .Mode "ro"}}:ro{{end}} {{end}}' "$CONTAINER_NAME" 2>/dev/null)

# Stop and remove
docker stop "$CONTAINER_NAME" > /dev/null
docker rm "$CONTAINER_NAME" > /dev/null

# Recreate with same config
DOCKER_CMD="docker run -d --name $CONTAINER_NAME --restart unless-stopped -p ${PORT}:8080 ${VOLUMES}"

while IFS= read -r env; do
  [[ -n "$env" ]] && DOCKER_CMD+=" -e \"${env}\""
done <<< "$ENVS"

DOCKER_CMD+=" $IMAGE"
eval "$DOCKER_CMD" > /dev/null

sleep 2
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "✅ Dozzle updated successfully!"
  echo "   🌐 URL: http://localhost:${PORT}"
else
  echo "❌ Update failed. Check: docker logs ${CONTAINER_NAME}"
  exit 1
fi

# Clean old image
docker image prune -f > /dev/null 2>&1 || true
