#!/bin/bash
# Vikunja Manager — Install & Deploy Script
set -euo pipefail

VIKUNJA_DIR="${VIKUNJA_DIR:-$HOME/vikunja}"
VIKUNJA_PORT="${VIKUNJA_PORT:-3456}"
VIKUNJA_PUBLIC_URL="${VIKUNJA_PUBLIC_URL:-http://localhost:$VIKUNJA_PORT}"
DB_TYPE="${VIKUNJA_DB_TYPE:-sqlite}"

echo "🗂️  Vikunja Manager — Install"
echo "   Directory: $VIKUNJA_DIR"
echo "   Port: $VIKUNJA_PORT"
echo "   Database: $DB_TYPE"
echo ""

# Check Docker
if ! command -v docker &>/dev/null; then
    echo "❌ Docker not found. Installing..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER" 2>/dev/null || true
    echo "✅ Docker installed. You may need to log out and back in for group changes."
fi

if ! docker compose version &>/dev/null; then
    echo "❌ docker compose not available. Install the compose plugin."
    exit 1
fi

# Create directory
mkdir -p "$VIKUNJA_DIR"/{files,db}
cd "$VIKUNJA_DIR"

# Generate JWT secret
JWT_SECRET=$(openssl rand -hex 32)

# Write docker-compose.yml
if [ "$DB_TYPE" = "postgres" ]; then
    PG_PASS=$(openssl rand -hex 16)
    cat > docker-compose.yml << EOF
services:
  db:
    image: postgres:16-alpine
    container_name: vikunja-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: vikunja
      POSTGRES_PASSWORD: $PG_PASS
      POSTGRES_DB: vikunja
    volumes:
      - ./pgdata:/var/lib/postgresql/data

  vikunja:
    image: vikunja/vikunja:latest
    container_name: vikunja
    restart: unless-stopped
    ports:
      - "$VIKUNJA_PORT:3456"
    depends_on:
      - db
    environment:
      VIKUNJA_DATABASE_TYPE: "postgres"
      VIKUNJA_DATABASE_HOST: "db"
      VIKUNJA_DATABASE_USER: "vikunja"
      VIKUNJA_DATABASE_PASSWORD: "$PG_PASS"
      VIKUNJA_DATABASE_DATABASE: "vikunja"
      VIKUNJA_SERVICE_JWTSECRET: "$JWT_SECRET"
      VIKUNJA_SERVICE_PUBLICURL: "$VIKUNJA_PUBLIC_URL"
      VIKUNJA_SERVICE_ENABLEREGISTRATION: "true"
      VIKUNJA_MAILER_ENABLED: "false"
    volumes:
      - ./files:/app/vikunja/files
EOF
else
    cat > docker-compose.yml << EOF
services:
  vikunja:
    image: vikunja/vikunja:latest
    container_name: vikunja
    restart: unless-stopped
    ports:
      - "$VIKUNJA_PORT:3456"
    environment:
      VIKUNJA_SERVICE_JWTSECRET: "$JWT_SECRET"
      VIKUNJA_SERVICE_PUBLICURL: "$VIKUNJA_PUBLIC_URL"
      VIKUNJA_DATABASE_TYPE: "sqlite"
      VIKUNJA_DATABASE_PATH: "/db/vikunja.db"
      VIKUNJA_SERVICE_ENABLEREGISTRATION: "true"
      VIKUNJA_MAILER_ENABLED: "false"
    volumes:
      - ./files:/app/vikunja/files
      - ./db:/db
EOF
fi

# Pull and start
echo ""
echo "📦 Pulling Vikunja image..."
docker compose pull

echo ""
echo "🚀 Starting Vikunja..."
docker compose up -d

# Wait for startup
echo ""
echo "⏳ Waiting for Vikunja to start..."
for i in $(seq 1 30); do
    if curl -sf "http://localhost:$VIKUNJA_PORT/api/v1/info" &>/dev/null; then
        echo ""
        echo "✅ Vikunja is running!"
        echo ""
        echo "   Web UI:  http://localhost:$VIKUNJA_PORT"
        echo "   API:     http://localhost:$VIKUNJA_PORT/api/v1"
        echo "   CalDAV:  http://localhost:$VIKUNJA_PORT/dav/principals/<username>/"
        echo ""
        echo "   Next: Create your account at the web UI."
        echo "   Then disable registration: VIKUNJA_SERVICE_ENABLEREGISTRATION=false"
        exit 0
    fi
    sleep 1
    printf "."
done

echo ""
echo "⚠️  Vikunja may still be starting. Check: docker logs vikunja"
