#!/bin/bash
# Install and start changedetection.io via Docker
set -euo pipefail

DATA_DIR="${CHANGEDETECTION_DATA:-/opt/changedetection/data}"
PORT="${CHANGEDETECTION_PORT:-5000}"

echo "🔍 Changedetection.io Installer"
echo "================================"

# Check Docker
if ! command -v docker &>/dev/null; then
  echo "❌ Docker not found. Installing..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  echo "✅ Docker installed. You may need to log out and back in."
fi

# Check docker compose
COMPOSE_CMD=""
if docker compose version &>/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
  COMPOSE_CMD="docker-compose"
fi

# Create data directory
mkdir -p "$DATA_DIR"

# Create docker-compose.yml
INSTALL_DIR="$(dirname "$DATA_DIR")"
mkdir -p "$INSTALL_DIR"

cat > "$INSTALL_DIR/docker-compose.yml" << YAML
version: '3'
services:
  changedetection:
    image: ghcr.io/dgtlmoon/changedetection.io
    container_name: changedetection
    restart: unless-stopped
    ports:
      - "${PORT}:5000"
    volumes:
      - ${DATA_DIR}:/datastore
    environment:
      - PLAYWRIGHT_DRIVER_URL=ws://playwright-chrome:3000
      - BASE_URL=http://localhost:${PORT}

  playwright-chrome:
    image: browserless/chrome
    container_name: changedetection-browser
    restart: unless-stopped
    environment:
      - SCREEN_WIDTH=1920
      - SCREEN_HEIGHT=1080
      - MAX_CONCURRENT_SESSIONS=4
YAML

echo "📦 Starting changedetection.io..."
cd "$INSTALL_DIR"

if [ -n "$COMPOSE_CMD" ]; then
  $COMPOSE_CMD up -d
else
  # Fallback: run without compose
  docker run -d \
    --name changedetection \
    --restart unless-stopped \
    -p "${PORT}:5000" \
    -v "${DATA_DIR}:/datastore" \
    ghcr.io/dgtlmoon/changedetection.io
fi

# Wait for startup
echo "⏳ Waiting for server to start..."
for i in $(seq 1 30); do
  if curl -s "http://localhost:${PORT}" >/dev/null 2>&1; then
    echo ""
    echo "✅ Changedetection.io is running!"
    echo "   URL: http://localhost:${PORT}"
    echo "   Data: ${DATA_DIR}"
    echo ""
    echo "Next steps:"
    echo "  1. Open http://localhost:${PORT} in your browser"
    echo "  2. Go to Settings → API to get your API key"
    echo "  3. Set: export CHANGEDETECTION_API_KEY='your-key'"
    echo "  4. Use: bash scripts/watch.sh add --url 'https://example.com'"
    exit 0
  fi
  printf "."
  sleep 2
done

echo ""
echo "⚠️  Server didn't respond in 60s. Check: docker logs changedetection"
exit 1
