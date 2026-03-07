#!/bin/bash
set -euo pipefail

# Linkding Installer
# Installs Linkding bookmark manager via Docker

LINKDING_PORT="${LINKDING_PORT:-9090}"
LINKDING_DATA_DIR="${LINKDING_DATA_DIR:-$HOME/.linkding}"
LINKDING_ADMIN="${LINKDING_ADMIN:-admin}"

echo "🔖 Installing Linkding Bookmark Manager..."
echo "   Port: $LINKDING_PORT"
echo "   Data: $LINKDING_DATA_DIR"
echo ""

# Check Docker
if ! command -v docker &>/dev/null; then
    echo "❌ Docker is not installed."
    echo "   Install: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &>/dev/null; then
    echo "❌ Docker daemon is not running."
    echo "   Start: sudo systemctl start docker"
    exit 1
fi

# Create data directory
mkdir -p "$LINKDING_DATA_DIR/data"
mkdir -p "$LINKDING_DATA_DIR/backups"

# Write docker-compose.yml
cat > "$LINKDING_DATA_DIR/docker-compose.yml" <<YAML
services:
  linkding:
    image: sissbruecker/linkding:latest
    container_name: linkding
    ports:
      - "${LINKDING_PORT}:9090"
    volumes:
      - ./data:/etc/linkding/data
    environment:
      - LD_SUPERUSER_NAME=${LINKDING_ADMIN}
    restart: unless-stopped
YAML

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q '^linkding$'; then
    echo "⏹️  Stopping existing Linkding container..."
    docker stop linkding 2>/dev/null || true
    docker rm linkding 2>/dev/null || true
fi

# Pull latest image
echo "📦 Pulling Linkding image..."
docker pull sissbruecker/linkding:latest

# Start container
echo "🚀 Starting Linkding..."
cd "$LINKDING_DATA_DIR"

if command -v docker-compose &>/dev/null; then
    docker-compose up -d
elif docker compose version &>/dev/null 2>&1; then
    docker compose up -d
else
    # Fallback to raw docker run
    docker run -d \
        --name linkding \
        -p "${LINKDING_PORT}:9090" \
        -v "$LINKDING_DATA_DIR/data:/etc/linkding/data" \
        -e "LD_SUPERUSER_NAME=${LINKDING_ADMIN}" \
        --restart unless-stopped \
        sissbruecker/linkding:latest
fi

# Wait for startup
echo "⏳ Waiting for Linkding to start..."
for i in $(seq 1 30); do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${LINKDING_PORT}" | grep -q "200\|302"; then
        break
    fi
    sleep 1
done

# Verify
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${LINKDING_PORT}" | grep -q "200\|302"; then
    echo ""
    echo "✅ Linkding is running!"
    echo "   Web UI: http://localhost:${LINKDING_PORT}"
    echo "   Data:   $LINKDING_DATA_DIR"
    echo ""
    echo "Next steps:"
    echo "  1. Create admin user:  bash scripts/manage.sh create-user --username admin --password yourpass"
    echo "  2. Get API token:      bash scripts/manage.sh get-token --username admin --password yourpass"
    echo "  3. Add a bookmark:     bash scripts/bookmarks.sh add --url https://example.com --tags test"
else
    echo ""
    echo "⚠️  Linkding may still be starting. Check:"
    echo "   docker logs linkding"
    echo "   curl http://localhost:${LINKDING_PORT}"
fi
