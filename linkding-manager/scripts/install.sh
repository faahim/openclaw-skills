#!/bin/bash
# Linkding Bookmark Manager — Installer
set -euo pipefail

LINKDING_PORT="${LINKDING_PORT:-9090}"
LINKDING_DATA="${LINKDING_DATA:-$HOME/.linkding}"
WITH_ARCHIVING=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --port) LINKDING_PORT="$2"; shift 2 ;;
    --data) LINKDING_DATA="$2"; shift 2 ;;
    --with-archiving) WITH_ARCHIVING=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check Docker
if ! command -v docker &>/dev/null; then
  echo "❌ Docker is required. Install: curl -fsSL https://get.docker.com | sh"
  exit 1
fi

if ! docker compose version &>/dev/null 2>&1 && ! docker-compose version &>/dev/null 2>&1; then
  echo "❌ Docker Compose is required."
  exit 1
fi

# Generate admin password
ADMIN_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)

# Create data directory
mkdir -p "$LINKDING_DATA/data" "$LINKDING_DATA/backups"

# Determine image
if [ "$WITH_ARCHIVING" = true ]; then
  IMAGE="sissbruecker/linkding:latest-plus"
  echo "📦 Using linkding-plus (with background archiving)"
else
  IMAGE="sissbruecker/linkding:latest"
fi

# Write docker-compose.yml
cat > "$LINKDING_DATA/docker-compose.yml" <<EOF
services:
  linkding:
    image: ${IMAGE}
    container_name: linkding
    ports:
      - "${LINKDING_PORT}:9090"
    volumes:
      - ./data:/etc/linkding/data
    environment:
      - LD_SUPERUSER_NAME=admin
      - LD_SUPERUSER_PASSWORD=${ADMIN_PASS}
    restart: unless-stopped
EOF

# Start container
cd "$LINKDING_DATA"
echo "🚀 Starting Linkding on port ${LINKDING_PORT}..."

if docker compose version &>/dev/null 2>&1; then
  docker compose up -d
else
  docker-compose up -d
fi

# Wait for startup
echo "⏳ Waiting for Linkding to be ready..."
for i in $(seq 1 30); do
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${LINKDING_PORT}" | grep -q "200\|302"; then
    break
  fi
  sleep 1
done

echo ""
echo "✅ Linkding is running!"
echo ""
echo "  🌐 URL:      http://localhost:${LINKDING_PORT}"
echo "  👤 Username:  admin"
echo "  🔑 Password:  ${ADMIN_PASS}"
echo "  📁 Data:      ${LINKDING_DATA}/data"
echo ""
echo "Next steps:"
echo "  1. Open the URL above and log in"
echo "  2. Go to Settings → Integrations → REST API"
echo "  3. Generate an API token"
echo "  4. Export it: export LINKDING_TOKEN=\"your-token\""
echo "  5. Export URL: export LINKDING_URL=\"http://localhost:${LINKDING_PORT}\""
echo ""
echo "Save these credentials — the password won't be shown again."

# Save credentials locally
cat > "$LINKDING_DATA/.credentials" <<EOF
LINKDING_URL=http://localhost:${LINKDING_PORT}
LINKDING_ADMIN_USER=admin
LINKDING_ADMIN_PASS=${ADMIN_PASS}
EOF
chmod 600 "$LINKDING_DATA/.credentials"
echo "💾 Credentials saved to ${LINKDING_DATA}/.credentials"
