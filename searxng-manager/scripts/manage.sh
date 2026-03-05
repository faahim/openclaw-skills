#!/bin/bash
# SearXNG Management Script
# Status, engine management, search, update, backup/restore

set -euo pipefail

CONFIG_DIR="${SEARXNG_CONFIG_DIR:-$HOME/.config/searxng}"
CONTAINER_NAME="${SEARXNG_CONTAINER:-searxng}"
SETTINGS="$CONFIG_DIR/settings.yml"
PORT="${SEARXNG_PORT:-8080}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}✅${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
err() { echo -e "${RED}❌${NC} $1" >&2; }
info() { echo -e "${CYAN}ℹ️${NC} $1"; }

# Detect running method
detect_method() {
  if docker ps -q -f name="$CONTAINER_NAME" 2>/dev/null | grep -q .; then
    echo "docker"
  elif systemctl is-active --quiet searxng 2>/dev/null; then
    echo "systemd"
  elif pgrep -f "searx.webapp" >/dev/null 2>&1; then
    echo "process"
  else
    echo "none"
  fi
}

# Detect port from running instance
detect_port() {
  if [[ -f "$SETTINGS" ]]; then
    grep -E "^\s+port:" "$SETTINGS" 2>/dev/null | head -1 | awk '{print $2}' || echo "$PORT"
  else
    echo "$PORT"
  fi
}

# Status
cmd_status() {
  local method
  method=$(detect_method)
  local port
  port=$(detect_port)
  
  echo "🔎 SearXNG Status"
  echo "=================="
  
  if [[ "$method" == "none" ]]; then
    err "SearXNG is not running"
    echo "  Install: bash scripts/install.sh --method docker --port 8080"
    return 1
  fi
  
  log "SearXNG is running (method: $method)"
  
  # Check HTTP
  local http_status
  http_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}/" 2>/dev/null || echo "000")
  
  if [[ "$http_status" == "200" || "$http_status" == "302" ]]; then
    log "Web UI: http://localhost:${port} (HTTP $http_status)"
  else
    warn "Web UI not responding (HTTP $http_status)"
  fi
  
  # Docker-specific info
  if [[ "$method" == "docker" ]]; then
    local uptime
    uptime=$(docker inspect -f '{{.State.StartedAt}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
    local image
    image=$(docker inspect -f '{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
    echo "  Container: $CONTAINER_NAME"
    echo "  Image:     $image"
    echo "  Started:   $uptime"
  fi
  
  # Engine count
  if [[ -f "$SETTINGS" ]]; then
    local enabled disabled
    enabled=$(grep -c "disabled: false" "$SETTINGS" 2>/dev/null || echo "0")
    disabled=$(grep -c "disabled: true" "$SETTINGS" 2>/dev/null || echo "0")
    echo "  Engines:   ${enabled} enabled, ${disabled} disabled"
  fi
  
  echo "  Config:    $SETTINGS"
  echo "  Port:      $port"
}

# Engine management
cmd_engines() {
  local subcmd="${1:-list}"
  shift 2>/dev/null || true
  
  case "$subcmd" in
    list)
      echo "🔎 Available Search Engines"
      echo "==========================="
      if [[ -f "$SETTINGS" ]]; then
        # Parse engines from settings
        grep -A2 "- name:" "$SETTINGS" 2>/dev/null | while IFS= read -r line; do
          if echo "$line" | grep -q "name:"; then
            local name
            name=$(echo "$line" | sed 's/.*name: //' | tr -d '"')
            printf "  %s" "$name"
          elif echo "$line" | grep -q "disabled:"; then
            local status
            status=$(echo "$line" | sed 's/.*disabled: //' | tr -d ' ')
            if [[ "$status" == "false" ]]; then
              echo -e " ${GREEN}[enabled]${NC}"
            else
              echo -e " ${RED}[disabled]${NC}"
            fi
          fi
        done
      else
        warn "No config found at $SETTINGS"
      fi
      ;;
    
    enable)
      for engine in "$@"; do
        if grep -q "name: $engine" "$SETTINGS" 2>/dev/null; then
          # Find the engine block and set disabled: false
          python3 -c "
import yaml, sys
with open('$SETTINGS', 'r') as f:
    cfg = yaml.safe_load(f)
for e in cfg.get('engines', []):
    if e.get('name') == '$engine':
        e['disabled'] = False
        break
else:
    cfg.setdefault('engines', []).append({'name': '$engine', 'engine': '$engine', 'disabled': False})
with open('$SETTINGS', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, sort_keys=False)
" 2>/dev/null && log "Enabled: $engine" || {
            # Fallback: sed-based
            sed -i "/name: ${engine}/,/disabled:/{s/disabled: true/disabled: false/}" "$SETTINGS"
            log "Enabled: $engine"
          }
        else
          warn "Engine '$engine' not found in config. Add it manually to $SETTINGS"
        fi
      done
      warn "Restart SearXNG to apply: bash scripts/manage.sh restart"
      ;;
    
    disable)
      for engine in "$@"; do
        if grep -q "name: $engine" "$SETTINGS" 2>/dev/null; then
          sed -i "/name: ${engine}/,/disabled:/{s/disabled: false/disabled: true/}" "$SETTINGS"
          log "Disabled: $engine"
        else
          warn "Engine '$engine' not found in config"
        fi
      done
      warn "Restart SearXNG to apply: bash scripts/manage.sh restart"
      ;;
    
    status)
      cmd_engines list
      ;;
    
    test)
      echo "🧪 Testing engine connectivity..."
      local port
      port=$(detect_port)
      local result
      result=$(curl -s "http://localhost:${port}/search?q=test&format=json" 2>/dev/null)
      if [[ -n "$result" ]]; then
        echo "$result" | jq -r '.results[:5][] | "  ✅ [\(.engine)] \(.title[:60])"' 2>/dev/null || log "Search returned results"
      else
        err "No response from SearXNG"
      fi
      ;;
    
    benchmark)
      echo "⏱️ Benchmarking engines..."
      local port
      port=$(detect_port)
      local start end elapsed
      start=$(date +%s%3N)
      curl -s "http://localhost:${port}/search?q=benchmark+test&format=json" > /tmp/searxng-bench.json 2>/dev/null
      end=$(date +%s%3N)
      elapsed=$((end - start))
      echo "  Total search time: ${elapsed}ms"
      if [[ -f /tmp/searxng-bench.json ]]; then
        echo "  Results returned: $(jq '.results | length' /tmp/searxng-bench.json 2>/dev/null || echo 'unknown')"
        rm -f /tmp/searxng-bench.json
      fi
      ;;
    
    *)
      echo "Usage: manage.sh engines <list|enable|disable|status|test|benchmark> [engine-names...]"
      ;;
  esac
}

# Search
cmd_search() {
  local query=""
  local category=""
  local format="text"
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --category) category="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      *) query="$query $1"; shift ;;
    esac
  done
  
  query=$(echo "$query" | xargs)  # trim
  
  if [[ -z "$query" ]]; then
    err "Usage: manage.sh search [--category <cat>] [--format json|text] <query>"
    return 1
  fi
  
  local port
  port=$(detect_port)
  local url="http://localhost:${port}/search?q=$(echo "$query" | jq -sRr @uri)&format=json"
  
  if [[ -n "$category" ]]; then
    url="${url}&categories=${category}"
  fi
  
  local result
  result=$(curl -s "$url" 2>/dev/null)
  
  if [[ -z "$result" ]]; then
    err "No response from SearXNG. Is it running?"
    return 1
  fi
  
  if [[ "$format" == "json" ]]; then
    echo "$result" | jq .
  else
    echo "🔍 Results for: $query"
    echo "========================"
    echo "$result" | jq -r '.results[:10][] | "\(.title)\n  \(.url)\n  \(.content[:120])\n"' 2>/dev/null || echo "$result"
  fi
}

# Update
cmd_update() {
  local method
  method=$(detect_method)
  
  if [[ "$method" == "docker" ]]; then
    echo "📥 Updating SearXNG Docker image..."
    local old_id
    old_id=$(docker inspect -f '{{.Image}}' "$CONTAINER_NAME" 2>/dev/null || echo "")
    
    docker pull searxng/searxng:latest
    
    local new_id
    new_id=$(docker inspect --format='{{.Id}}' searxng/searxng:latest 2>/dev/null || echo "")
    
    if [[ "$old_id" != "$new_id" ]]; then
      echo "🔄 New version found. Restarting..."
      docker stop "$CONTAINER_NAME"
      docker rm "$CONTAINER_NAME"
      
      local port
      port=$(detect_port)
      docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p "${port}:8080" \
        -v "${CONFIG_DIR}:/etc/searxng" \
        searxng/searxng:latest
      
      log "SearXNG updated and restarted"
    else
      log "Already on latest version"
    fi
  else
    warn "Auto-update only supported for Docker installations"
    echo "  For bare-metal: cd ~/searxng && git pull && pip install -e ."
  fi
}

# Auto-update setup
cmd_auto_update() {
  local schedule="${1:-weekly}"
  local script_path
  script_path=$(realpath "$0")
  
  local cron_expr
  case "$schedule" in
    daily) cron_expr="0 3 * * *" ;;
    weekly) cron_expr="0 3 * * 0" ;;
    monthly) cron_expr="0 3 1 * *" ;;
    *) err "Unknown schedule: $schedule (use daily, weekly, monthly)"; return 1 ;;
  esac
  
  # Add to crontab
  (crontab -l 2>/dev/null | grep -v "searxng.*update"; echo "$cron_expr bash $script_path update >> /tmp/searxng-update.log 2>&1") | crontab -
  
  log "Auto-update scheduled: $schedule ($cron_expr)"
  echo "  Log: /tmp/searxng-update.log"
}

# Stop
cmd_stop() {
  local method
  method=$(detect_method)
  
  case "$method" in
    docker) docker stop "$CONTAINER_NAME"; log "Stopped container $CONTAINER_NAME" ;;
    systemd) sudo systemctl stop searxng; log "Stopped systemd service" ;;
    process) pkill -f "searx.webapp"; log "Stopped SearXNG process" ;;
    *) warn "SearXNG is not running" ;;
  esac
}

# Start
cmd_start() {
  local method
  method=$(detect_method)
  
  if [[ "$method" != "none" ]]; then
    warn "SearXNG is already running ($method)"
    return
  fi
  
  # Try Docker first
  if docker ps -a -q -f name="$CONTAINER_NAME" 2>/dev/null | grep -q .; then
    docker start "$CONTAINER_NAME"
    log "Started container $CONTAINER_NAME"
  elif systemctl list-unit-files | grep -q searxng; then
    sudo systemctl start searxng
    log "Started systemd service"
  else
    err "No SearXNG installation found. Run install.sh first."
  fi
}

# Restart
cmd_restart() {
  cmd_stop 2>/dev/null || true
  sleep 2
  cmd_start
}

# Backup
cmd_backup() {
  local backup_dir="$CONFIG_DIR/backups"
  mkdir -p "$backup_dir"
  
  local backup_file="$backup_dir/$(date +%Y-%m-%d_%H%M%S).tar.gz"
  tar -czf "$backup_file" -C "$CONFIG_DIR" settings.yml 2>/dev/null
  log "Config backed up to $backup_file"
}

# Restore
cmd_restore() {
  local backup_file="$1"
  
  if [[ ! -f "$backup_file" ]]; then
    err "Backup file not found: $backup_file"
    echo "  Available backups:"
    ls -la "$CONFIG_DIR/backups/" 2>/dev/null || echo "  None"
    return 1
  fi
  
  # Backup current config first
  cmd_backup
  
  tar -xzf "$backup_file" -C "$CONFIG_DIR"
  log "Config restored from $backup_file"
  warn "Restart SearXNG to apply: bash scripts/manage.sh restart"
}

# Proxy config generation
cmd_proxy_config() {
  local proxy_type="${1:-nginx}"
  local domain=""
  
  shift 2>/dev/null || true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --domain) domain="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -z "$domain" ]]; then
    err "Usage: manage.sh proxy-config <nginx|caddy> --domain <domain>"
    return 1
  fi
  
  local port
  port=$(detect_port)
  
  case "$proxy_type" in
    nginx)
      cat > /tmp/searxng-nginx.conf <<NGINX
server {
    listen 80;
    server_name ${domain};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${domain};

    # SSL certs (use Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }
}
NGINX
      log "Nginx config written to /tmp/searxng-nginx.conf"
      echo "  Copy: sudo cp /tmp/searxng-nginx.conf /etc/nginx/sites-available/searxng"
      echo "  Enable: sudo ln -s /etc/nginx/sites-available/searxng /etc/nginx/sites-enabled/"
      echo "  Reload: sudo nginx -t && sudo systemctl reload nginx"
      ;;
    
    caddy)
      cat > /tmp/searxng-Caddyfile <<CADDY
${domain} {
    reverse_proxy localhost:${port}
    
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy no-referrer
    }
}
CADDY
      log "Caddy config written to /tmp/searxng-Caddyfile"
      ;;
    
    *)
      err "Unknown proxy type: $proxy_type (use nginx or caddy)"
      ;;
  esac
}

# Uninstall
cmd_uninstall() {
  echo "🗑️ Uninstalling SearXNG..."
  
  local method
  method=$(detect_method)
  
  case "$method" in
    docker)
      docker stop "$CONTAINER_NAME" 2>/dev/null || true
      docker rm "$CONTAINER_NAME" 2>/dev/null || true
      log "Removed Docker container"
      ;;
    systemd)
      sudo systemctl stop searxng 2>/dev/null || true
      sudo systemctl disable searxng 2>/dev/null || true
      sudo rm -f /etc/systemd/system/searxng.service
      sudo systemctl daemon-reload
      log "Removed systemd service"
      ;;
  esac
  
  echo ""
  echo "Config preserved at: $CONFIG_DIR"
  echo "Remove manually: rm -rf $CONFIG_DIR"
}

# Main
case "${1:-help}" in
  status) cmd_status ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  restart) cmd_restart ;;
  engines) shift; cmd_engines "$@" ;;
  search) shift; cmd_search "$@" ;;
  update) cmd_update ;;
  auto-update) shift; cmd_auto_update "$@" ;;
  backup) cmd_backup ;;
  restore) shift; cmd_restore "$@" ;;
  proxy-config) shift; cmd_proxy_config "$@" ;;
  uninstall) cmd_uninstall ;;
  help|*)
    echo "SearXNG Manager"
    echo ""
    echo "Usage: $(basename "$0") <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status                    Show SearXNG status"
    echo "  start                     Start SearXNG"
    echo "  stop                      Stop SearXNG"
    echo "  restart                   Restart SearXNG"
    echo "  engines <subcmd>          Manage search engines (list|enable|disable|test|benchmark)"
    echo "  search <query>            Search from CLI"
    echo "  update                    Update SearXNG (Docker)"
    echo "  auto-update <schedule>    Set up auto-updates (daily|weekly|monthly)"
    echo "  backup                    Backup configuration"
    echo "  restore <file>            Restore from backup"
    echo "  proxy-config <type>       Generate reverse proxy config (nginx|caddy)"
    echo "  uninstall                 Remove SearXNG"
    ;;
esac
