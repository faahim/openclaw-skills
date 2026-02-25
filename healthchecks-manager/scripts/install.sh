#!/bin/bash
set -euo pipefail

# Healthchecks.io Self-Hosted Installer
# Deploys via Docker Compose with SQLite backend

INSTALL_DIR="${HC_INSTALL_DIR:-$HOME/healthchecks}"
PORT="${HC_PORT:-8000}"
EMAIL="${HC_EMAIL:-admin@localhost}"
PASSWORD="${HC_PASSWORD:-$(openssl rand -base64 16)}"
SECRET=$(openssl rand -hex 32)
SITE_ROOT="${HC_SITE_ROOT:-http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):${PORT}}"

echo "🏥 Healthchecks Manager — Self-Hosted Installer"
echo "================================================"

# Check Docker
if ! command -v docker &>/dev/null; then
  echo "❌ Docker not found. Installing..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  echo "⚠️  Docker installed. Log out and back in, then re-run this script."
  exit 1
fi

if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null 2>&1; then
  echo "❌ docker-compose not found. Installing plugin..."
  sudo apt-get update && sudo apt-get install -y docker-compose-plugin 2>/dev/null || {
    sudo pip3 install docker-compose 2>/dev/null || {
      echo "❌ Could not install docker-compose. Install manually."
      exit 1
    }
  }
fi

# Detect compose command
if docker compose version &>/dev/null 2>&1; then
  COMPOSE="docker compose"
else
  COMPOSE="docker-compose"
fi

# Create install directory
mkdir -p "${INSTALL_DIR}/data"
cd "$INSTALL_DIR"

# Write docker-compose.yml
cat > docker-compose.yml << YAML
version: "3"
services:
  healthchecks:
    image: healthchecks/healthchecks:latest
    restart: unless-stopped
    ports:
      - "${PORT}:8000"
    env_file: .env
    volumes:
      - ./data:/data
YAML

# Write .env
cat > .env << EOF
DB=sqlite
DB_NAME=/data/hc.sqlite
SECRET_KEY=${SECRET}
ALLOWED_HOSTS=*
SITE_ROOT=${SITE_ROOT}
SITE_NAME=Healthchecks
DEFAULT_FROM_EMAIL=healthchecks@localhost
SUPERUSER_EMAIL=${EMAIL}
SUPERUSER_PASSWORD=${PASSWORD}
REGISTRATION_OPEN=False
APPRISE_ENABLED=True
PING_BODY_LIMIT=10000
EOF

# Pull and start
echo "📦 Pulling Healthchecks image..."
$COMPOSE pull

echo "🚀 Starting Healthchecks..."
$COMPOSE up -d

# Wait for startup
echo "⏳ Waiting for service to be ready..."
for i in $(seq 1 30); do
  if curl -fsS "http://localhost:${PORT}/api/v3/checks/" -H "X-Api-Key: placeholder" 2>/dev/null | grep -q ""; then
    break
  fi
  sleep 2
done

echo ""
echo "✅ Healthchecks is running!"
echo "   URL:      ${SITE_ROOT}"
echo "   Email:    ${EMAIL}"
echo "   Password: ${PASSWORD}"
echo "   Data dir: ${INSTALL_DIR}/data"
echo ""
echo "Next steps:"
echo "  1. Log in at ${SITE_ROOT}"
echo "  2. Go to Project Settings → API Access to get your API key"
echo "  3. Create checks and add ping URLs to your cron jobs"
echo ""
echo "Manage:"
echo "  cd ${INSTALL_DIR}"
echo "  $COMPOSE logs -f        # View logs"
echo "  $COMPOSE restart        # Restart"
echo "  $COMPOSE pull && $COMPOSE up -d  # Update"
