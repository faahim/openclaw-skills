#!/bin/bash
# NocoDB Deployment Script
# Deploys NocoDB via Docker with configurable backends

set -euo pipefail

# Defaults
BACKEND="sqlite"
PORT=8080
DATA_DIR="$HOME/.nocodb"
MEMORY=""
CONTAINER_NAME="nocodb"
SYSTEMD=false
EXTERNAL_DB=""
RESTART=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Deploy NocoDB — open-source Airtable alternative.

OPTIONS:
  --backend <sqlite|postgres|mysql>  Database backend (default: sqlite)
  --port <port>                      Port to expose (default: 8080)
  --data-dir <path>                  Data directory (default: ~/.nocodb)
  --memory <limit>                   Memory limit (e.g., 2g)
  --systemd                          Install as systemd service
  --external-db <url>                Connect to existing database
  --restart                          Restart existing deployment
  -h, --help                         Show this help

EXAMPLES:
  $(basename "$0")                              # SQLite quick start
  $(basename "$0") --backend postgres           # Production with PostgreSQL
  $(basename "$0") --backend mysql --port 9090  # MySQL on custom port
  $(basename "$0") --external-db "pg://host:5432?u=user&p=pass&d=mydb"
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --backend) BACKEND="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    --memory) MEMORY="$2"; shift 2 ;;
    --systemd) SYSTEMD=true; shift ;;
    --external-db) EXTERNAL_DB="$2"; shift 2 ;;
    --restart) RESTART=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check Docker
if ! command -v docker &>/dev/null; then
  echo "❌ Docker not found. Install: curl -fsSL https://get.docker.com | sh"
  exit 1
fi

mkdir -p "$DATA_DIR"

# Stop existing if restart
if $RESTART || docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
  echo "🔄 Stopping existing NocoDB..."
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Generate JWT secret if not set
NC_AUTH_JWT_SECRET="${NC_AUTH_JWT_SECRET:-$(openssl rand -hex 32)}"

# External DB mode
if [[ -n "$EXTERNAL_DB" ]]; then
  echo "🔗 Connecting to external database..."
  DOCKER_ARGS=(
    -d --name "$CONTAINER_NAME"
    -p "${PORT}:8080"
    -e "NC_DB=${EXTERNAL_DB}"
    -e "NC_AUTH_JWT_SECRET=${NC_AUTH_JWT_SECRET}"
    -v "${DATA_DIR}:/usr/app/data"
  )
  [[ -n "$MEMORY" ]] && DOCKER_ARGS+=(--memory "$MEMORY")
  docker run "${DOCKER_ARGS[@]}" nocodb/nocodb:latest
  echo "✅ NocoDB running at http://localhost:${PORT}"
  echo "🔗 Connected to external database"
  exit 0
fi

case "$BACKEND" in
  sqlite)
    echo "🚀 Deploying NocoDB with SQLite..."
    DOCKER_ARGS=(
      -d --name "$CONTAINER_NAME"
      --restart unless-stopped
      -p "${PORT}:8080"
      -e "NC_AUTH_JWT_SECRET=${NC_AUTH_JWT_SECRET}"
      -v "${DATA_DIR}:/usr/app/data"
    )
    [[ -n "$MEMORY" ]] && DOCKER_ARGS+=(--memory "$MEMORY")
    docker run "${DOCKER_ARGS[@]}" nocodb/nocodb:latest
    echo "✅ NocoDB running at http://localhost:${PORT}"
    echo "📧 Admin signup: http://localhost:${PORT}/#/signup"
    echo "💾 Data stored in: ${DATA_DIR}"
    ;;

  postgres)
    echo "🚀 Deploying NocoDB with PostgreSQL..."
    PG_PASSWORD="${PG_PASSWORD:-$(openssl rand -hex 16)}"

    cat > "${DATA_DIR}/docker-compose.yml" <<YAML
version: '3.8'
services:
  nocodb:
    image: nocodb/nocodb:latest
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped
    ports:
      - "${PORT}:8080"
    environment:
      NC_DB: "pg://db:5432?u=nocodb&p=${PG_PASSWORD}&d=nocodb"
      NC_AUTH_JWT_SECRET: "${NC_AUTH_JWT_SECRET}"
    volumes:
      - nc_data:/usr/app/data
    depends_on:
      db:
        condition: service_healthy
${MEMORY:+    mem_limit: ${MEMORY}}

  db:
    image: postgres:16-alpine
    container_name: ${CONTAINER_NAME}-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: nocodb
      POSTGRES_PASSWORD: ${PG_PASSWORD}
      POSTGRES_DB: nocodb
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nocodb"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  nc_data:
  pg_data:
YAML

    cd "$DATA_DIR"
    docker compose up -d
    echo "✅ NocoDB running at http://localhost:${PORT}"
    echo "🐘 PostgreSQL on port 5432 (internal)"
    echo "📧 Admin signup: http://localhost:${PORT}/#/signup"
    echo "🔑 PG Password: ${PG_PASSWORD}"
    echo "💾 Compose file: ${DATA_DIR}/docker-compose.yml"
    ;;

  mysql)
    echo "🚀 Deploying NocoDB with MySQL..."
    MYSQL_PASSWORD="${MYSQL_PASSWORD:-$(openssl rand -hex 16)}"

    cat > "${DATA_DIR}/docker-compose.yml" <<YAML
version: '3.8'
services:
  nocodb:
    image: nocodb/nocodb:latest
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped
    ports:
      - "${PORT}:8080"
    environment:
      NC_DB: "mysql2://db:3306?u=nocodb&p=${MYSQL_PASSWORD}&d=nocodb"
      NC_AUTH_JWT_SECRET: "${NC_AUTH_JWT_SECRET}"
    volumes:
      - nc_data:/usr/app/data
    depends_on:
      db:
        condition: service_healthy
${MEMORY:+    mem_limit: ${MEMORY}}

  db:
    image: mysql:8.0
    container_name: ${CONTAINER_NAME}-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_USER: nocodb
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_DATABASE: nocodb
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "nocodb", "-p${MYSQL_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  nc_data:
  mysql_data:
YAML

    cd "$DATA_DIR"
    docker compose up -d
    echo "✅ NocoDB running at http://localhost:${PORT}"
    echo "🐬 MySQL on port 3306 (internal)"
    echo "📧 Admin signup: http://localhost:${PORT}/#/signup"
    echo "🔑 MySQL Password: ${MYSQL_PASSWORD}"
    echo "💾 Compose file: ${DATA_DIR}/docker-compose.yml"
    ;;

  *)
    echo "❌ Unknown backend: $BACKEND (use sqlite, postgres, or mysql)"
    exit 1
    ;;
esac

# Systemd service
if $SYSTEMD; then
  echo "📦 Installing systemd service..."
  sudo tee /etc/systemd/system/nocodb.service > /dev/null <<EOF
[Unit]
Description=NocoDB
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${DATA_DIR}
ExecStart=$(which docker) compose up -d
ExecStop=$(which docker) compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable nocodb
  echo "✅ Systemd service installed (enabled on boot)"
fi

# Save config
cat > "${DATA_DIR}/.nocodb-config" <<EOF
BACKEND=${BACKEND}
PORT=${PORT}
DATA_DIR=${DATA_DIR}
CONTAINER_NAME=${CONTAINER_NAME}
NC_AUTH_JWT_SECRET=${NC_AUTH_JWT_SECRET}
DEPLOYED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo ""
echo "🎉 Deployment complete! Config saved to ${DATA_DIR}/.nocodb-config"
