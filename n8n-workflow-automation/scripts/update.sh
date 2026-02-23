#!/bin/bash
# Update n8n to latest version
set -euo pipefail

N8N_DIR="${N8N_DIR:-$HOME/.n8n}"

echo "🔄 Updating n8n..."
cd "$N8N_DIR"

# Get current version
OLD_VER=$(docker compose exec -T n8n n8n --version 2>/dev/null || echo "unknown")
echo "   Current: $OLD_VER"

# Pull latest
docker compose pull n8n

# Recreate with new image
docker compose up -d --force-recreate n8n

# Wait for healthy
for i in $(seq 1 30); do
  if curl -sf "http://localhost:${N8N_PORT:-5678}/healthz" >/dev/null 2>&1; then
    NEW_VER=$(docker compose exec -T n8n n8n --version 2>/dev/null || echo "unknown")
    echo "✅ Updated: $OLD_VER → $NEW_VER"
    exit 0
  fi
  sleep 2
done

echo "⚠️  n8n may still be starting. Check: docker compose -f $N8N_DIR/docker-compose.yml logs -f"
