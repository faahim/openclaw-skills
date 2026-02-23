#!/bin/bash
# Deploy n8n workflow automation platform via Docker
set -euo pipefail

N8N_DIR="${N8N_DIR:-$HOME/.n8n}"
N8N_PORT="${N8N_PORT:-5678}"
N8N_VERSION="${N8N_VERSION:-latest}"
USE_POSTGRES=false
USE_HTTPS=false
DOMAIN=""
MULTI_USER=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --postgres) USE_POSTGRES=true; shift ;;
    --https) USE_HTTPS=true; shift ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --port) N8N_PORT="$2"; shift 2 ;;
    --version) N8N_VERSION="$2"; shift 2 ;;
    --multi-user) MULTI_USER=true; shift ;;
    --dir) N8N_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🚀 Deploying n8n..."
echo "   Directory: $N8N_DIR"
echo "   Port: $N8N_PORT"
echo "   Version: $N8N_VERSION"
echo "   PostgreSQL: $USE_POSTGRES"
echo "   HTTPS: $USE_HTTPS"

# Create data directory
mkdir -p "$N8N_DIR"

# Generate encryption key if not set
if [ -z "${N8N_ENCRYPTION_KEY:-}" ]; then
  if [ -f "$N8N_DIR/.encryption_key" ]; then
    N8N_ENCRYPTION_KEY=$(cat "$N8N_DIR/.encryption_key")
    echo "🔑 Using existing encryption key"
  else
    N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
    echo "$N8N_ENCRYPTION_KEY" > "$N8N_DIR/.encryption_key"
    chmod 600 "$N8N_DIR/.encryption_key"
    echo "🔑 Generated new encryption key (saved to $N8N_DIR/.encryption_key)"
    echo "⚠️  BACK UP THIS KEY — credentials are unrecoverable without it!"
  fi
fi

# Detect timezone
TZ="${GENERIC_TIMEZONE:-$(cat /etc/timezone 2>/dev/null || echo 'UTC')}"

# Create .env file
cat > "$N8N_DIR/.env" <<EOF
N8N_PORT=$N8N_PORT
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
GENERIC_TIMEZONE=$TZ
N8N_PROTOCOL=${N8N_PROTOCOL:-http}
N8N_HOST=${N8N_HOST:-localhost}
EXECUTIONS_DATA_PRUNE=${EXECUTIONS_DATA_PRUNE:-true}
EXECUTIONS_DATA_MAX_AGE=${EXECUTIONS_DATA_MAX_AGE:-168}
N8N_DIAGNOSTICS_ENABLED=false
N8N_VERSION_NOTIFICATIONS_ENABLED=true
N8N_HIRING_BANNER_ENABLED=false
EOF

if [ "$MULTI_USER" = true ]; then
  echo "N8N_USER_MANAGEMENT_DISABLED=false" >> "$N8N_DIR/.env"
fi

if [ -n "$DOMAIN" ]; then
  echo "WEBHOOK_URL=https://$DOMAIN" >> "$N8N_DIR/.env"
  echo "N8N_HOST=$DOMAIN" >> "$N8N_DIR/.env"
  echo "N8N_PROTOCOL=https" >> "$N8N_DIR/.env"
fi

# SMTP settings if provided
if [ -n "${N8N_SMTP_HOST:-}" ]; then
  cat >> "$N8N_DIR/.env" <<EOF
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=$N8N_SMTP_HOST
N8N_SMTP_PORT=${N8N_SMTP_PORT:-587}
N8N_SMTP_USER=${N8N_SMTP_USER:-}
N8N_SMTP_PASS=${N8N_SMTP_PASS:-}
N8N_SMTP_SENDER=${N8N_SMTP_SENDER:-$N8N_SMTP_USER}
EOF
fi

# Generate docker-compose.yml
if [ "$USE_POSTGRES" = true ]; then
  PG_PASSWORD=$(openssl rand -hex 16)
  cat > "$N8N_DIR/docker-compose.yml" <<YAML
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: $PG_PASSWORD
      POSTGRES_DB: n8n
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:$N8N_VERSION
    restart: unless-stopped
    ports:
      - "\${N8N_PORT}:5678"
    env_file: .env
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=$PG_PASSWORD
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy

volumes:
  postgres_data:
  n8n_data:
YAML
  echo "🐘 PostgreSQL configured (password saved in docker-compose.yml)"
else
  cat > "$N8N_DIR/docker-compose.yml" <<YAML
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:$N8N_VERSION
    restart: unless-stopped
    ports:
      - "\${N8N_PORT}:5678"
    env_file: .env
    environment:
      - DB_TYPE=sqlite
      - DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
YAML
fi

# Add Caddy reverse proxy if HTTPS requested
if [ "$USE_HTTPS" = true ] && [ -n "$DOMAIN" ]; then
  cat >> "$N8N_DIR/docker-compose.yml" <<YAML

  caddy:
    image: caddy:2-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - n8n
YAML
  # Append caddy volumes
  sed -i '/^volumes:/a\  caddy_data:\n  caddy_config:' "$N8N_DIR/docker-compose.yml"

  cat > "$N8N_DIR/Caddyfile" <<CADDY
$DOMAIN {
  reverse_proxy n8n:5678
}
CADDY
  echo "🔒 Caddy reverse proxy configured for $DOMAIN (auto-SSL)"
fi

# Stop existing if running
cd "$N8N_DIR"
docker compose down 2>/dev/null || true

# Pull and start
echo "📦 Pulling images..."
docker compose pull

echo "🔄 Starting n8n..."
docker compose up -d

# Wait for healthy
echo "⏳ Waiting for n8n to start..."
for i in $(seq 1 30); do
  if curl -sf "http://localhost:$N8N_PORT/healthz" >/dev/null 2>&1; then
    echo ""
    echo "✅ n8n is running!"
    if [ "$USE_HTTPS" = true ] && [ -n "$DOMAIN" ]; then
      echo "🌐 URL: https://$DOMAIN"
    else
      echo "🌐 URL: http://localhost:$N8N_PORT"
    fi
    echo "💾 Data: $N8N_DIR"
    echo "🔑 Encryption key: $N8N_DIR/.encryption_key"
    echo ""
    echo "👉 Open the URL above and create your admin account."
    exit 0
  fi
  printf "."
  sleep 2
done

echo ""
echo "⚠️  n8n may still be starting. Check logs:"
echo "   cd $N8N_DIR && docker compose logs -f n8n"
