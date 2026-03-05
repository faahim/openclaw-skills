#!/bin/bash
set -euo pipefail

# Listmonk Newsletter Manager — Install Script
# Installs Listmonk via Docker Compose with PostgreSQL

INSTALL_DIR="${LISTMONK_DIR:-$HOME/listmonk}"
LISTMONK_PORT="${LISTMONK_PORT:-9000}"
LISTMONK_VERSION="${LISTMONK_VERSION:-latest}"

echo "📧 Listmonk Newsletter Manager — Installer"
echo "============================================"
echo ""

# 1. Check Docker
if ! command -v docker &>/dev/null; then
    echo "⚠️  Docker not found. Installing..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER" 2>/dev/null || true
    echo "✅ Docker installed. You may need to log out/in for group changes."
fi

if ! docker compose version &>/dev/null 2>&1 && ! docker-compose version &>/dev/null 2>&1; then
    echo "❌ Docker Compose not found. Please install docker-compose-plugin."
    exit 1
fi

# Use 'docker compose' or 'docker-compose'
COMPOSE="docker compose"
if ! docker compose version &>/dev/null 2>&1; then
    COMPOSE="docker-compose"
fi

echo "✅ Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"

# 2. Create install directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 3. Generate secure passwords
ADMIN_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)
DB_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 24)

# 4. Create .env file
if [ ! -f .env ]; then
    cat > .env <<EOF
# Listmonk Configuration
LISTMONK_PORT=${LISTMONK_PORT}
LISTMONK_ADMIN_USER=admin
LISTMONK_ADMIN_PASSWORD=${ADMIN_PASS}

# PostgreSQL
POSTGRES_USER=listmonk
POSTGRES_PASSWORD=${DB_PASS}
POSTGRES_DB=listmonk

# Version
LISTMONK_VERSION=${LISTMONK_VERSION}
EOF
    echo "✅ Config generated: $INSTALL_DIR/.env"
else
    echo "ℹ️  Using existing .env"
    source .env
fi

# 5. Create docker-compose.yml
cat > docker-compose.yml <<'YAML'
version: "3.7"

services:
  db:
    image: postgres:15-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - listmonk-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    image: listmonk/listmonk:${LISTMONK_VERSION:-latest}
    restart: unless-stopped
    ports:
      - "${LISTMONK_PORT:-9000}:9000"
    environment:
      TZ: UTC
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ./config.toml:/listmonk/config.toml
      - listmonk-uploads:/listmonk/uploads
    command: [sh, -c, "yes | ./listmonk --install --idempotent && ./listmonk"]

volumes:
  listmonk-data:
  listmonk-uploads:
YAML

# 6. Create config.toml
source .env
cat > config.toml <<EOF
[app]
address = "0.0.0.0:9000"
admin_username = "${LISTMONK_ADMIN_USER:-admin}"
admin_password = "${LISTMONK_ADMIN_PASSWORD:-${ADMIN_PASS}}"

[db]
host = "db"
port = 5432
user = "${POSTGRES_USER}"
password = "${POSTGRES_PASSWORD}"
database = "${POSTGRES_DB}"
ssl_mode = "disable"
max_open = 25
max_idle = 25
max_lifetime = "300s"
EOF

echo "✅ Docker Compose config created"

# 7. Pull and start
echo ""
echo "🚀 Starting Listmonk..."
$COMPOSE pull --quiet
$COMPOSE up -d

# 8. Wait for healthy
echo "⏳ Waiting for services to be ready..."
for i in $(seq 1 30); do
    if curl -sf "http://localhost:${LISTMONK_PORT}/api/health" &>/dev/null; then
        break
    fi
    sleep 2
done

# 9. Check status
if curl -sf "http://localhost:${LISTMONK_PORT}/api/health" &>/dev/null; then
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
    echo ""
    echo "✅ Listmonk is running!"
    echo "============================================"
    echo "🌐 Admin panel: http://${SERVER_IP}:${LISTMONK_PORT}"
    echo "👤 Username:    admin"
    echo "🔑 Password:    ${ADMIN_PASS}"
    echo "📁 Install dir: ${INSTALL_DIR}"
    echo ""
    echo "⚠️  NEXT STEPS:"
    echo "  1. Change the admin password in the admin panel"
    echo "  2. Configure SMTP: bash scripts/configure-smtp.sh --host <smtp-host> --port 587 --user <email> --password <pass>"
    echo "  3. Create your first subscriber list in the admin panel"
    echo ""
else
    echo "❌ Listmonk failed to start. Check logs:"
    echo "  cd $INSTALL_DIR && $COMPOSE logs --tail 50"
    exit 1
fi
