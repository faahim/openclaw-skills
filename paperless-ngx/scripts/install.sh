#!/bin/bash
# Paperless-ngx Installer
# Deploys Paperless-ngx via Docker Compose with sensible defaults
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_DATA_DIR="${PAPERLESS_DATA_DIR:-$HOME/paperless-ngx}"
DEFAULT_PORT=8000
DEFAULT_OCR_LANG="eng"
DEFAULT_ADMIN_USER="admin"
DEFAULT_ADMIN_PASS="changeme"

usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
  check                  Check prerequisites
  deploy                 Deploy Paperless-ngx

Deploy Options:
  --port PORT            Web UI port (default: $DEFAULT_PORT)
  --ocr-languages LANGS  OCR languages, e.g. "eng+deu+fra" (default: $DEFAULT_OCR_LANG)
  --admin-user USER      Admin username (default: $DEFAULT_ADMIN_USER)
  --admin-pass PASS      Admin password (default: $DEFAULT_ADMIN_PASS)
  --data-dir DIR         Data directory (default: $DEFAULT_DATA_DIR)
EOF
  exit 1
}

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $*" >&2; }
ok()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $*"; }

check_prerequisites() {
  local issues=0

  # Docker
  if command -v docker &>/dev/null; then
    local docker_ver
    docker_ver=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
    ok "Docker installed: v$docker_ver"
  else
    err "Docker not installed. Install: https://docs.docker.com/engine/install/"
    ((issues++))
  fi

  # Docker Compose
  if docker compose version &>/dev/null 2>&1; then
    local compose_ver
    compose_ver=$(docker compose version --short 2>/dev/null || echo "unknown")
    ok "Docker Compose installed: v$compose_ver"
  elif command -v docker-compose &>/dev/null; then
    local compose_ver
    compose_ver=$(docker-compose version --short 2>/dev/null || echo "unknown")
    ok "Docker Compose (standalone) installed: v$compose_ver"
  else
    err "Docker Compose not installed."
    ((issues++))
  fi

  # curl
  if command -v curl &>/dev/null; then
    ok "curl installed"
  else
    err "curl not installed"
    ((issues++))
  fi

  # jq
  if command -v jq &>/dev/null; then
    ok "jq installed"
  else
    err "jq not installed (needed for API management)"
    ((issues++))
  fi

  # Disk space (need at least 2GB free)
  local free_gb
  free_gb=$(df -BG "${DEFAULT_DATA_DIR%/*}" 2>/dev/null | awk 'NR==2{print $4}' | tr -d 'G' || echo "0")
  if [ "${free_gb:-0}" -ge 2 ]; then
    ok "Disk space: ${free_gb}GB free"
  else
    err "Low disk space: ${free_gb}GB free (need ≥2GB)"
    ((issues++))
  fi

  # Port check
  if ! ss -tlnp 2>/dev/null | grep -q ":${DEFAULT_PORT} " && \
     ! netstat -tlnp 2>/dev/null | grep -q ":${DEFAULT_PORT} "; then
    ok "Port $DEFAULT_PORT available"
  else
    err "Port $DEFAULT_PORT in use"
    ((issues++))
  fi

  if [ $issues -eq 0 ]; then
    ok "All prerequisites met!"
    return 0
  else
    err "$issues issue(s) found"
    return 1
  fi
}

generate_secret() {
  openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | base64 | tr -d '\n/+=' | head -c 64
}

deploy() {
  local port="$DEFAULT_PORT"
  local ocr_lang="$DEFAULT_OCR_LANG"
  local admin_user="$DEFAULT_ADMIN_USER"
  local admin_pass="$DEFAULT_ADMIN_PASS"
  local data_dir="$DEFAULT_DATA_DIR"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --port) port="$2"; shift 2 ;;
      --ocr-languages) ocr_lang="$2"; shift 2 ;;
      --admin-user) admin_user="$2"; shift 2 ;;
      --admin-pass) admin_pass="$2"; shift 2 ;;
      --data-dir) data_dir="$2"; shift 2 ;;
      *) err "Unknown option: $1"; exit 1 ;;
    esac
  done

  log "Deploying Paperless-ngx to $data_dir..."

  # Create directories
  mkdir -p "$data_dir"/{consume,data,media,export,pgdata,redisdata}

  local secret_key
  secret_key=$(generate_secret)

  # Write docker-compose.yml
  cat > "$data_dir/docker-compose.yml" <<YAML
version: "3.8"
services:
  broker:
    image: docker.io/library/redis:7
    restart: unless-stopped
    volumes:
      - ${data_dir}/redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  db:
    image: docker.io/library/postgres:16
    restart: unless-stopped
    volumes:
      - ${data_dir}/pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: paperless
      POSTGRES_USER: paperless
      POSTGRES_PASSWORD: paperless
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U paperless"]
      interval: 10s
      timeout: 5s
      retries: 5

  webserver:
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      broker:
        condition: service_healthy
    ports:
      - "${port}:8000"
    volumes:
      - ${data_dir}/data:/usr/src/paperless/data
      - ${data_dir}/media:/usr/src/paperless/media
      - ${data_dir}/export:/usr/src/paperless/export
      - ${data_dir}/consume:/usr/src/paperless/consume
    environment:
      PAPERLESS_REDIS: redis://broker:6379
      PAPERLESS_DBHOST: db
      PAPERLESS_DBUSER: paperless
      PAPERLESS_DBPASS: paperless
      PAPERLESS_DBNAME: paperless
      PAPERLESS_SECRET_KEY: "${secret_key}"
      PAPERLESS_OCR_LANGUAGE: "${ocr_lang}"
      PAPERLESS_ADMIN_USER: "${admin_user}"
      PAPERLESS_ADMIN_PASSWORD: "${admin_pass}"
      PAPERLESS_URL: "http://localhost:${port}"
      PAPERLESS_CONSUMER_POLLING: 30
      PAPERLESS_CONSUMER_DELETE_DUPLICATES: "true"
      PAPERLESS_TASK_WORKERS: 2
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
YAML

  # Write .env file for run.sh
  cat > "$data_dir/.env" <<ENV
PAPERLESS_URL=http://localhost:${port}
PAPERLESS_DATA_DIR=${data_dir}
PAPERLESS_ADMIN_USER=${admin_user}
PAPERLESS_ADMIN_PASS=${admin_pass}
COMPOSE_PROJECT_NAME=paperless-ngx
ENV

  log "Pulling Docker images..."
  cd "$data_dir"

  if docker compose version &>/dev/null 2>&1; then
    docker compose pull
    docker compose up -d
  else
    docker-compose pull
    docker-compose up -d
  fi

  log "Waiting for Paperless-ngx to start (this may take 60-90s on first run)..."
  local attempts=0
  while [ $attempts -lt 30 ]; do
    if curl -sf "http://localhost:${port}/api/" &>/dev/null; then
      ok "Paperless-ngx is running!"
      ok "URL: http://localhost:${port}"
      ok "Login: ${admin_user} / ${admin_pass}"
      ok "Consume directory: ${data_dir}/consume"
      ok "Data directory: ${data_dir}"
      echo ""
      log "⚠️  Change the default password immediately!"
      log "Generate an API token: bash scripts/run.sh token --user ${admin_user} --pass ${admin_pass}"
      return 0
    fi
    sleep 5
    ((attempts++))
  done

  err "Paperless-ngx didn't start within 150s. Check logs:"
  err "  cd ${data_dir} && docker compose logs webserver"
  return 1
}

# Main
case "${1:-}" in
  check) check_prerequisites ;;
  deploy) shift; deploy "$@" ;;
  *) usage ;;
esac
