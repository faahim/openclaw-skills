#!/bin/bash
# PhotoPrism Manager — Install & Deploy Script
set -euo pipefail

# Defaults
PORT=2342
PASSWORD=""
STORAGE="$HOME/Photos"
DATA_DIR="/opt/photoprism"
DATABASE="sqlite"
GPU=""

usage() {
  cat <<EOF
PhotoPrism Manager — Install & Deploy

Usage:
  $(basename "$0") check                     Check prerequisites
  $(basename "$0") deploy [options]           Deploy PhotoPrism

Deploy Options:
  --port PORT           HTTP port (default: 2342)
  --password PASS       Admin password (required for deploy)
  --storage DIR         Photos storage directory (default: ~/Photos)
  --data-dir DIR        PhotoPrism data directory (default: /opt/photoprism)
  --database TYPE       Database: sqlite or mariadb (default: sqlite)
  --gpu TYPE            GPU acceleration: intel or nvidia (optional)

Examples:
  $(basename "$0") check
  $(basename "$0") deploy --password 'MyPass123!'
  $(basename "$0") deploy --port 8080 --password 'MyPass!' --database mariadb --storage /mnt/photos
EOF
  exit 1
}

check_prerequisites() {
  echo "🔍 Checking prerequisites..."
  local ok=true

  if command -v docker &>/dev/null; then
    echo "  ✅ Docker $(docker --version | grep -oP '\d+\.\d+\.\d+')"
  else
    echo "  ❌ Docker not found. Install: https://docs.docker.com/engine/install/"
    ok=false
  fi

  if docker compose version &>/dev/null 2>&1; then
    echo "  ✅ Docker Compose $(docker compose version --short 2>/dev/null || echo 'v2')"
  elif command -v docker-compose &>/dev/null; then
    echo "  ⚠️  docker-compose (legacy) found. Recommend upgrading to Docker Compose v2"
  else
    echo "  ❌ Docker Compose not found"
    ok=false
  fi

  if command -v curl &>/dev/null; then
    echo "  ✅ curl"
  else
    echo "  ❌ curl not found"
    ok=false
  fi

  # Check system resources
  local mem_mb=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo 0)
  if [ "$mem_mb" -ge 2048 ]; then
    echo "  ✅ RAM: ${mem_mb} MB (≥2048 MB)"
  elif [ "$mem_mb" -gt 0 ]; then
    echo "  ⚠️  RAM: ${mem_mb} MB (2048 MB+ recommended)"
  fi

  local disk_gb=$(df -BG "${DATA_DIR%/*}" 2>/dev/null | awk 'NR==2{gsub(/G/,"",$4); print $4}' || echo 0)
  if [ "$disk_gb" -ge 20 ]; then
    echo "  ✅ Free disk: ${disk_gb} GB"
  elif [ "$disk_gb" -gt 0 ]; then
    echo "  ⚠️  Free disk: ${disk_gb} GB (20 GB+ recommended)"
  fi

  local arch=$(uname -m)
  case "$arch" in
    x86_64|aarch64|arm64)
      echo "  ✅ Architecture: $arch"
      ;;
    *)
      echo "  ❌ Unsupported architecture: $arch (need amd64 or arm64)"
      ok=false
      ;;
  esac

  if $ok; then
    echo ""
    echo "✅ All prerequisites met. Ready to deploy!"
  else
    echo ""
    echo "❌ Some prerequisites missing. Fix the issues above before deploying."
    exit 1
  fi
}

generate_compose() {
  local compose_file="$DATA_DIR/docker-compose.yml"

  # Determine image tag based on architecture
  local arch=$(uname -m)
  local image_tag="photoprism/photoprism:latest"

  # GPU device mappings
  local gpu_section=""
  if [ "$GPU" = "intel" ]; then
    gpu_section="    devices:
      - /dev/dri:/dev/dri"
  elif [ "$GPU" = "nvidia" ]; then
    gpu_section="    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]"
  fi

  if [ "$DATABASE" = "mariadb" ]; then
    cat > "$compose_file" <<YAML
version: '3.5'

services:
  photoprism:
    image: ${image_tag}
    container_name: photoprism
    restart: unless-stopped
    stop_grace_period: 10s
    depends_on:
      - mariadb
    security_opt:
      - seccomp:unconfined
      - apparmor:unconfined
    ports:
      - "${PORT}:2342"
${gpu_section}
    environment:
      PHOTOPRISM_ADMIN_USER: "admin"
      PHOTOPRISM_ADMIN_PASSWORD: "${PASSWORD}"
      PHOTOPRISM_AUTH_MODE: "password"
      PHOTOPRISM_SITE_URL: "http://localhost:${PORT}/"
      PHOTOPRISM_ORIGINALS_LIMIT: 5000
      PHOTOPRISM_HTTP_COMPRESSION: "gzip"
      PHOTOPRISM_LOG_LEVEL: "info"
      PHOTOPRISM_READONLY: "false"
      PHOTOPRISM_EXPERIMENTAL: "false"
      PHOTOPRISM_DISABLE_CHOWN: "false"
      PHOTOPRISM_DISABLE_WEBDAV: "false"
      PHOTOPRISM_DISABLE_SETTINGS: "false"
      PHOTOPRISM_DISABLE_TENSORFLOW: "false"
      PHOTOPRISM_DISABLE_FACES: "false"
      PHOTOPRISM_DISABLE_CLASSIFICATION: "false"
      PHOTOPRISM_DISABLE_RAW: "false"
      PHOTOPRISM_RAW_PRESETS: "false"
      PHOTOPRISM_JPEG_QUALITY: 85
      PHOTOPRISM_DETECT_NSFW: "false"
      PHOTOPRISM_UPLOAD_NSFW: "true"
      PHOTOPRISM_DATABASE_DRIVER: "mysql"
      PHOTOPRISM_DATABASE_SERVER: "mariadb:3306"
      PHOTOPRISM_DATABASE_NAME: "photoprism"
      PHOTOPRISM_DATABASE_USER: "photoprism"
      PHOTOPRISM_DATABASE_PASSWORD: "photoprism_db_pass"
    volumes:
      - "${STORAGE}:/photoprism/originals"
      - "${DATA_DIR}/storage:/photoprism/storage"
      - "${DATA_DIR}/import:/photoprism/import"
    working_dir: "/photoprism"

  mariadb:
    image: mariadb:11
    container_name: photoprism-mariadb
    restart: unless-stopped
    stop_grace_period: 5s
    security_opt:
      - seccomp:unconfined
      - apparmor:unconfined
    command: >
      --innodb-buffer-pool-size=512M
      --transaction-isolation=READ-COMMITTED
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --max-connections=512
      --innodb-rollback-on-timeout=OFF
      --innodb-lock-wait-timeout=120
    volumes:
      - "${DATA_DIR}/database:/var/lib/mysql"
    environment:
      MARIADB_AUTO_UPGRADE: "1"
      MARIADB_INITDB_SKIP_TZINFO: "1"
      MARIADB_DATABASE: "photoprism"
      MARIADB_USER: "photoprism"
      MARIADB_PASSWORD: "photoprism_db_pass"
      MARIADB_ROOT_PASSWORD: "photoprism_root_pass"

volumes:
  database:
    driver: local
YAML
  else
    # SQLite mode (simpler)
    cat > "$compose_file" <<YAML
version: '3.5'

services:
  photoprism:
    image: ${image_tag}
    container_name: photoprism
    restart: unless-stopped
    stop_grace_period: 10s
    security_opt:
      - seccomp:unconfined
      - apparmor:unconfined
    ports:
      - "${PORT}:2342"
${gpu_section}
    environment:
      PHOTOPRISM_ADMIN_USER: "admin"
      PHOTOPRISM_ADMIN_PASSWORD: "${PASSWORD}"
      PHOTOPRISM_AUTH_MODE: "password"
      PHOTOPRISM_SITE_URL: "http://localhost:${PORT}/"
      PHOTOPRISM_ORIGINALS_LIMIT: 5000
      PHOTOPRISM_HTTP_COMPRESSION: "gzip"
      PHOTOPRISM_LOG_LEVEL: "info"
      PHOTOPRISM_READONLY: "false"
      PHOTOPRISM_EXPERIMENTAL: "false"
      PHOTOPRISM_DISABLE_CHOWN: "false"
      PHOTOPRISM_DISABLE_WEBDAV: "false"
      PHOTOPRISM_DISABLE_SETTINGS: "false"
      PHOTOPRISM_DISABLE_TENSORFLOW: "false"
      PHOTOPRISM_DISABLE_FACES: "false"
      PHOTOPRISM_DISABLE_CLASSIFICATION: "false"
      PHOTOPRISM_DISABLE_RAW: "false"
      PHOTOPRISM_JPEG_QUALITY: 85
      PHOTOPRISM_DETECT_NSFW: "false"
      PHOTOPRISM_UPLOAD_NSFW: "true"
      PHOTOPRISM_DATABASE_DRIVER: "sqlite"
    volumes:
      - "${STORAGE}:/photoprism/originals"
      - "${DATA_DIR}/storage:/photoprism/storage"
      - "${DATA_DIR}/import:/photoprism/import"
    working_dir: "/photoprism"
YAML
  fi

  echo "$compose_file"
}

deploy() {
  if [ -z "$PASSWORD" ]; then
    echo "❌ Admin password required. Use: --password 'YourPassword'"
    exit 1
  fi

  if [ ${#PASSWORD} -lt 8 ]; then
    echo "❌ Password must be at least 8 characters"
    exit 1
  fi

  echo "🚀 Deploying PhotoPrism..."
  echo "   Port: $PORT"
  echo "   Photos: $STORAGE"
  echo "   Data: $DATA_DIR"
  echo "   Database: $DATABASE"
  [ -n "$GPU" ] && echo "   GPU: $GPU"
  echo ""

  # Create directories
  mkdir -p "$DATA_DIR"/{storage,import}
  mkdir -p "$STORAGE"

  # Generate docker-compose.yml
  local compose_file
  compose_file=$(generate_compose)
  echo "   📝 Config written to: $compose_file"

  # Pull images
  echo "   📥 Pulling Docker images..."
  cd "$DATA_DIR"
  docker compose pull

  # Start
  echo "   ▶️  Starting containers..."
  docker compose up -d

  # Wait for health
  echo -n "   ⏳ Waiting for PhotoPrism to start"
  local retries=30
  while [ $retries -gt 0 ]; do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/api/v1/status" 2>/dev/null | grep -q "200"; then
      break
    fi
    echo -n "."
    sleep 2
    retries=$((retries - 1))
  done
  echo ""

  if [ $retries -gt 0 ]; then
    echo ""
    echo "✅ PhotoPrism deployed successfully!"
    echo ""
    echo "   🌐 URL: http://localhost:${PORT}"
    echo "   👤 Username: admin"
    echo "   🔑 Password: <the password you set>"
    echo "   📁 Photos: ${STORAGE}"
    echo "   💾 Data: ${DATA_DIR}"
    echo ""
    echo "   Next steps:"
    echo "   1. Open the URL in your browser"
    echo "   2. Log in with admin credentials"
    echo "   3. Import photos: bash scripts/manage.sh import /path/to/photos"
  else
    echo ""
    echo "⚠️  PhotoPrism started but may still be initializing."
    echo "   Check logs: docker compose -f $DATA_DIR/docker-compose.yml logs -f"
  fi
}

# Parse arguments
ACTION="${1:-}"
shift 2>/dev/null || true

case "$ACTION" in
  check)
    check_prerequisites
    ;;
  deploy)
    while [[ $# -gt 0 ]]; do
      case $1 in
        --port) PORT="$2"; shift 2 ;;
        --password) PASSWORD="$2"; shift 2 ;;
        --storage) STORAGE="$2"; shift 2 ;;
        --data-dir) DATA_DIR="$2"; shift 2 ;;
        --database) DATABASE="$2"; shift 2 ;;
        --gpu) GPU="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; usage ;;
      esac
    done
    check_prerequisites
    deploy
    ;;
  *)
    usage
    ;;
esac
