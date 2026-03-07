#!/bin/bash
# Ghost Blog Manager — Deploy Ghost with Docker
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${GREEN}[ghost-blog]${NC} $1"; }
warn() { echo -e "${YELLOW}[ghost-blog]${NC} $1"; }
err() { echo -e "${RED}[ghost-blog]${NC} $1" >&2; }

# Defaults
DOMAIN=""
EMAIL=""
PORT=2368
HTTPS_PORT=443
HTTP_PORT=80
NAME="ghost"
SSL=true
GHOST_IMAGE="ghost:5-alpine"
MYSQL_IMAGE="mysql:8.0"

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain) DOMAIN="$2"; shift 2 ;;
        --email) EMAIL="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --https-port) HTTPS_PORT="$2"; shift 2 ;;
        --http-port) HTTP_PORT="$2"; shift 2 ;;
        --name) NAME="$2"; shift 2 ;;
        --no-ssl) SSL=false; shift ;;
        --image) GHOST_IMAGE="$2"; shift 2 ;;
        *) err "Unknown: $1"; exit 1 ;;
    esac
done

[ -z "$DOMAIN" ] && { err "Missing --domain. Usage: $0 --domain blog.example.com --email you@example.com"; exit 1; }

# Generate passwords
MYSQL_ROOT_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
MYSQL_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)

# Determine URL
if [ "$SSL" = true ] && [ "$DOMAIN" != "localhost" ]; then
    GHOST_URL="https://$DOMAIN"
    [ -z "$EMAIL" ] && { err "Missing --email (required for SSL)"; exit 1; }
else
    if [ "$DOMAIN" = "localhost" ]; then
        GHOST_URL="http://localhost:$PORT"
    else
        GHOST_URL="http://$DOMAIN:$PORT"
    fi
fi

DEPLOY_DIR="$HOME/ghost-deployments/$NAME"
log "=== Deploying Ghost Blog ==="
log "Domain: $DOMAIN"
log "URL: $GHOST_URL"
log "Directory: $DEPLOY_DIR"

mkdir -p "$DEPLOY_DIR/backups"
cd "$DEPLOY_DIR"

# Write .env
cat > .env << ENV
# Ghost Blog Configuration — Generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
GHOST_DOMAIN=$DOMAIN
GHOST_URL=$GHOST_URL
GHOST_EMAIL=${EMAIL:-}
GHOST_IMAGE=$GHOST_IMAGE
MYSQL_IMAGE=$MYSQL_IMAGE
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASS
MYSQL_PASSWORD=$MYSQL_PASS
MYSQL_DATABASE=ghost_${NAME}
GHOST_PORT=$PORT
HTTPS_PORT=$HTTPS_PORT
HTTP_PORT=$HTTP_PORT
ENV

log "Credentials saved to .env"

# Write docker-compose.yml
cat > docker-compose.yml << 'COMPOSE'
version: "3.8"

services:
  ghost:
    image: ${GHOST_IMAGE:-ghost:5-alpine}
    container_name: ${COMPOSE_PROJECT_NAME:-ghost}-app
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      url: ${GHOST_URL}
      database__client: mysql
      database__connection__host: db
      database__connection__user: ghost
      database__connection__password: ${MYSQL_PASSWORD}
      database__connection__database: ${MYSQL_DATABASE:-ghost}
    volumes:
      - ghost_content:/var/lib/ghost/content
    networks:
      - ghost-net
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:2368/ghost/api/v4/admin/site/ || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  db:
    image: ${MYSQL_IMAGE:-mysql:8.0}
    container_name: ${COMPOSE_PROJECT_NAME:-ghost}-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_USER: ghost
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-ghost}
    volumes:
      - ghost_db:/var/lib/mysql
    networks:
      - ghost-net
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  ghost_content:
  ghost_db:

networks:
  ghost-net:
COMPOSE

# Add Caddy for SSL if needed
if [ "$SSL" = true ] && [ "$DOMAIN" != "localhost" ]; then
    cat >> docker-compose.yml << CADDY

  caddy:
    image: caddy:2-alpine
    container_name: ${COMPOSE_PROJECT_NAME:-ghost}-caddy
    restart: unless-stopped
    ports:
      - "${HTTP_PORT}:80"
      - "${HTTPS_PORT}:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - ghost-net
    depends_on:
      - ghost

CADDY
    # Add caddy volumes
    sed -i 's/^networks:/  caddy_data:\n  caddy_config:\n\nnetworks:/' docker-compose.yml

    # Write Caddyfile
    cat > Caddyfile << CADDYFILE
$DOMAIN {
    reverse_proxy ghost:2368
    encode gzip
    tls $EMAIL
}
CADDYFILE
    log "Caddy configured for HTTPS"
else
    # No SSL — expose Ghost directly
    cat >> docker-compose.yml << DIRECT

    ports:
      - "${PORT}:2368"
DIRECT
    # Patch: add ports to ghost service (hacky but works for simple case)
    sed -i "/container_name: .*-app/a\\    ports:\\n      - \"${PORT}:2368\"" docker-compose.yml 2>/dev/null || true
fi

# Set project name
export COMPOSE_PROJECT_NAME="$NAME"

# Deploy
log "Pulling images..."
docker compose pull 2>/dev/null || docker-compose pull

log "Starting services..."
docker compose up -d 2>/dev/null || docker-compose up -d

# Wait for Ghost to be healthy
log "Waiting for Ghost to start (up to 90s)..."
for i in $(seq 1 18); do
    if curl -sf "http://localhost:$PORT/ghost/api/v4/admin/site/" > /dev/null 2>&1; then
        break
    fi
    sleep 5
    echo -n "."
done
echo ""

# Status
if docker compose ps 2>/dev/null | grep -q "running" || docker-compose ps 2>/dev/null | grep -q "Up"; then
    log "=== ✅ Ghost Blog Deployed ==="
    echo ""
    echo -e "  ${CYAN}🌐 Blog:${NC}  $GHOST_URL"
    echo -e "  ${CYAN}👤 Admin:${NC} $GHOST_URL/ghost"
    echo ""
    log "First visit to /ghost to create your admin account."
    log "Deploy dir: $DEPLOY_DIR"
else
    err "Something went wrong. Check logs:"
    err "  docker compose -f $DEPLOY_DIR/docker-compose.yml logs"
    exit 1
fi
