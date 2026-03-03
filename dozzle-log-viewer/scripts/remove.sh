#!/bin/bash
# Dozzle Log Viewer — Remove Script
set -euo pipefail

CONTAINER_NAME="${1:-dozzle}"

if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "ℹ️  No Dozzle container found (already removed?)"
  exit 0
fi

echo "🗑️  Removing Dozzle..."
docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true

# Optionally remove image
read -r -t 5 -p "Remove Dozzle image too? [y/N] " REMOVE_IMAGE < /dev/tty 2>/dev/null || REMOVE_IMAGE="n"
if [[ "$REMOVE_IMAGE" =~ ^[Yy]$ ]]; then
  docker rmi amir20/dozzle:latest > /dev/null 2>&1 || true
  echo "✅ Dozzle container and image removed."
else
  echo "✅ Dozzle container removed (image kept for faster redeploy)."
fi

# Clean auth files
rm -rf /tmp/dozzle-auth 2>/dev/null || true
