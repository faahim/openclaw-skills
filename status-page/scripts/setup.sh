#!/bin/bash
# Status Page Manager — Gatus setup and management
# https://github.com/TwiN/gatus

set -euo pipefail

INSTALL_DIR="${STATUS_PAGE_DIR:-$HOME/status-page}"
CONFIG_DIR="$INSTALL_DIR/config"
DATA_DIR="$INSTALL_DIR/data"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
ENV_FILE="$INSTALL_DIR/.env"
DEFAULT_PORT="${GATUS_PORT:-8080}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[status-page]${NC} $1"; }
warn() { echo -e "${YELLOW}[status-page]${NC} $1"; }
err() { echo -e "${RED}[status-page]${NC} $1" >&2; }

check_docker() {
  if ! command -v docker &>/dev/null; then
    err "Docker not found. Install: https://docs.docker.com/engine/install/"
    exit 1
  fi
  if ! docker info &>/dev/null 2>&1; then
    err "Docker daemon not running or insufficient permissions."
    err "Try: sudo systemctl start docker"
    exit 1
  fi
}

cmd_init() {
  local port="${1:-$DEFAULT_PORT}"
  log "Initializing status page at $INSTALL_DIR..."

  mkdir -p "$CONFIG_DIR" "$DATA_DIR"

  # Generate docker-compose.yml
  cat > "$COMPOSE_FILE" <<YAML
services:
  gatus:
    image: twinproduction/gatus:latest
    container_name: gatus
    restart: unless-stopped
    ports:
      - "${port}:8080"
    volumes:
      - ./config:/config:ro
      - ./data:/data
    env_file:
      - .env
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
YAML

  # Generate default config
  if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    cat > "$CONFIG_DIR/config.yaml" <<YAML
# Gatus Status Page Configuration
# Docs: https://github.com/TwiN/gatus#configuration

storage:
  type: sqlite
  path: /data/gatus.db

ui:
  title: "Status Page"
  header: "Service Status"

# Uncomment and configure alert providers:
# alerting:
#   telegram:
#     token: "\${TELEGRAM_BOT_TOKEN}"
#     id: "\${TELEGRAM_CHAT_ID}"
#   slack:
#     webhook-url: "\${SLACK_WEBHOOK_URL}"
#   discord:
#     webhook-url: "\${DISCORD_WEBHOOK_URL}"

endpoints:
  - name: Example (replace me)
    group: Demo
    url: "https://example.com"
    interval: 5m
    conditions:
      - "[STATUS] == 200"
      - "[RESPONSE_TIME] < 3000"
YAML
    log "Created config at $CONFIG_DIR/config.yaml"
    log "Edit this file to add your endpoints."
  else
    warn "Config already exists, skipping."
  fi

  # Generate .env
  if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" <<ENV
# Alert provider credentials (uncomment as needed)
# TELEGRAM_BOT_TOKEN=your-bot-token
# TELEGRAM_CHAT_ID=your-chat-id
# SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
# DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
# SMTP_USER=email@example.com
# SMTP_PASS=your-password
ENV
    log "Created .env at $ENV_FILE"
  fi

  log "✅ Initialized. Edit $CONFIG_DIR/config.yaml, then run: $0 start"
}

cmd_start() {
  check_docker
  local port=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --port) port="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ ! -f "$COMPOSE_FILE" ]; then
    err "Not initialized. Run: $0 init"
    exit 1
  fi

  # Override port if specified
  if [ -n "$port" ]; then
    sed -i "s/\"[0-9]*:8080\"/\"${port}:8080\"/" "$COMPOSE_FILE"
    log "Port set to $port"
  fi

  cd "$INSTALL_DIR"
  docker compose up -d
  log "✅ Status page running at http://localhost:$(grep -oP '\d+(?=:8080)' "$COMPOSE_FILE")"
}

cmd_stop() {
  check_docker
  cd "$INSTALL_DIR"
  docker compose down
  log "✅ Stopped."
}

cmd_restart() {
  check_docker
  cd "$INSTALL_DIR"
  docker compose restart
  log "✅ Restarted."
}

cmd_logs() {
  check_docker
  cd "$INSTALL_DIR"
  docker compose logs -f --tail=100
}

cmd_status() {
  check_docker
  cd "$INSTALL_DIR"
  if docker compose ps --format '{{.Status}}' 2>/dev/null | grep -q "Up"; then
    local port
    port=$(grep -oP '\d+(?=:8080)' "$COMPOSE_FILE" 2>/dev/null || echo "8080")
    log "✅ Running on port $port"
    # Quick health check
    if curl -sf "http://localhost:$port/health" &>/dev/null; then
      log "Health: OK"
    else
      warn "Health endpoint not responding (may still be starting)"
    fi
    # Count endpoints
    local count
    count=$(grep -c "^\s*- name:" "$CONFIG_DIR/config.yaml" 2>/dev/null || echo "0")
    log "Monitoring $count endpoint(s)"
  else
    warn "Not running. Start with: $0 start"
  fi
}

cmd_validate() {
  if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    err "No config found at $CONFIG_DIR/config.yaml"
    exit 1
  fi

  # Basic YAML validation
  if command -v yq &>/dev/null; then
    if yq eval '.' "$CONFIG_DIR/config.yaml" >/dev/null 2>&1; then
      log "✅ YAML syntax valid"
    else
      err "❌ YAML syntax error in config.yaml"
      yq eval '.' "$CONFIG_DIR/config.yaml"
      exit 1
    fi
  elif command -v python3 &>/dev/null; then
    if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_DIR/config.yaml'))" 2>/dev/null; then
      log "✅ YAML syntax valid"
    else
      err "❌ YAML syntax error in config.yaml"
      exit 1
    fi
  else
    warn "No YAML validator available (install yq or python3-yaml)"
  fi

  # Check required fields
  if grep -q "endpoints:" "$CONFIG_DIR/config.yaml"; then
    local count
    count=$(grep -c "^\s*- name:" "$CONFIG_DIR/config.yaml" || echo "0")
    log "Found $count endpoint(s)"
  else
    err "No endpoints defined in config"
    exit 1
  fi

  # Check for placeholder values
  if grep -q "replace me\|YOUR_\|your-bot-token\|example\.com" "$CONFIG_DIR/config.yaml"; then
    warn "Config contains placeholder values — update before production use"
  fi

  log "✅ Config looks good"
}

cmd_add_endpoint() {
  if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    err "No config found. Run: $0 init"
    exit 1
  fi

  local name="" url="" group="" interval="2m"

  echo -e "${BLUE}Add a new endpoint${NC}"
  read -rp "Name (e.g., My Website): " name
  read -rp "URL (e.g., https://example.com): " url
  read -rp "Group (e.g., Production) [default: General]: " group
  read -rp "Check interval (e.g., 30s, 1m, 5m) [default: 2m]: " interval

  group="${group:-General}"
  interval="${interval:-2m}"

  # Determine conditions based on URL scheme
  local conditions='      - "[STATUS] == 200"
      - "[RESPONSE_TIME] < 3000"'

  if [[ "$url" == tcp://* ]]; then
    conditions='      - "[CONNECTED] == true"'
  fi

  cat >> "$CONFIG_DIR/config.yaml" <<YAML

  - name: $name
    group: $group
    url: "$url"
    interval: $interval
    conditions:
$conditions
YAML

  log "✅ Added '$name' to config. Restart to apply: $0 restart"
}

cmd_backup() {
  local backup_dir="$INSTALL_DIR/backups"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file="$backup_dir/status-page-backup-$timestamp.tar.gz"

  mkdir -p "$backup_dir"
  cd "$INSTALL_DIR"
  tar -czf "$backup_file" config/ data/ docker-compose.yml .env 2>/dev/null || \
    tar -czf "$backup_file" config/ docker-compose.yml 2>/dev/null

  log "✅ Backup saved to $backup_file"
  log "Size: $(du -h "$backup_file" | cut -f1)"
}

cmd_update() {
  check_docker
  cd "$INSTALL_DIR"
  log "Pulling latest Gatus image..."
  docker compose pull
  docker compose up -d
  log "✅ Updated to latest version"
}

# Main
case "${1:-help}" in
  init)         shift; cmd_init "$@" ;;
  start)        shift; cmd_start "$@" ;;
  stop)         cmd_stop ;;
  restart)      cmd_restart ;;
  logs)         cmd_logs ;;
  status)       cmd_status ;;
  validate)     cmd_validate ;;
  add-endpoint) cmd_add_endpoint ;;
  backup)       cmd_backup ;;
  update)       cmd_update ;;
  help|*)
    echo "Status Page Manager — Self-hosted monitoring dashboard"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  init [port]      Initialize status page (default port: 8080)"
    echo "  start [--port N] Start the status page"
    echo "  stop             Stop the status page"
    echo "  restart          Restart (apply config changes)"
    echo "  logs             View live logs"
    echo "  status           Check if running"
    echo "  validate         Validate config syntax"
    echo "  add-endpoint     Add endpoint interactively"
    echo "  backup           Backup config and data"
    echo "  update           Update Gatus to latest"
    echo "  help             Show this help"
    ;;
esac
