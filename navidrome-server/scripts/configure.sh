#!/bin/bash
# Navidrome Configuration Manager
# Modify Navidrome settings without editing TOML manually

set -euo pipefail

DATA_DIR="/var/lib/navidrome"
CONFIG_FILE="${DATA_DIR}/navidrome.toml"
SERVICE_NAME="navidrome"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[navidrome]${NC} $1"; }
warn() { echo -e "${YELLOW}[navidrome]${NC} $1"; }
err() { echo -e "${RED}[navidrome]${NC} $1" >&2; }

SUDO=""
[[ $EUID -ne 0 ]] && command -v sudo &>/dev/null && SUDO="sudo"

# Helper: set a TOML key
set_config() {
  local key="$1"
  local value="$2"
  local is_string="${3:-true}"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    err "Config not found: ${CONFIG_FILE}"
    exit 1
  fi

  if $SUDO grep -qE "^${key}" "$CONFIG_FILE"; then
    if [[ "$is_string" == "true" ]]; then
      $SUDO sed -i "s|^${key}.*|${key} = \"${value}\"|" "$CONFIG_FILE"
    else
      $SUDO sed -i "s|^${key}.*|${key} = ${value}|" "$CONFIG_FILE"
    fi
  else
    if [[ "$is_string" == "true" ]]; then
      echo "${key} = \"${value}\"" | $SUDO tee -a "$CONFIG_FILE" > /dev/null
    else
      echo "${key} = ${value}" | $SUDO tee -a "$CONFIG_FILE" > /dev/null
    fi
  fi

  log "Set ${key} = ${value}"
}

RESTART_NEEDED=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --show)
      echo ""
      log "Current configuration (${CONFIG_FILE}):"
      echo "---"
      $SUDO cat "$CONFIG_FILE"
      echo "---"
      exit 0
      ;;

    --music-folder)
      FOLDER="$2"; shift 2
      if [[ ! -d "$FOLDER" ]]; then
        warn "Directory ${FOLDER} does not exist. Creating..."
        mkdir -p "$FOLDER" 2>/dev/null || $SUDO mkdir -p "$FOLDER"
      fi
      set_config "MusicFolder" "$FOLDER"
      # Update systemd ReadOnlyPaths
      if [[ -f /etc/systemd/system/navidrome.service ]]; then
        $SUDO sed -i "s|ReadOnlyPaths=.*|ReadOnlyPaths=${FOLDER}|" /etc/systemd/system/navidrome.service
        $SUDO systemctl daemon-reload
      fi
      RESTART_NEEDED=true
      ;;

    --port)
      PORT="$2"; shift 2
      set_config "Port" "$PORT" false
      RESTART_NEEDED=true
      ;;

    --transcode)
      ENABLED="$2"; shift 2
      set_config "EnableTranscodingConfig" "$ENABLED" false
      # Check ffmpeg
      if [[ "$ENABLED" == "true" ]] && ! command -v ffmpeg &>/dev/null; then
        warn "ffmpeg not found! Transcoding won't work without it."
        warn "Install: sudo apt install ffmpeg (or brew install ffmpeg)"
      fi
      RESTART_NEEDED=true
      ;;

    --scan-interval)
      INTERVAL="$2"; shift 2
      set_config "ScanSchedule" "@every ${INTERVAL}"
      RESTART_NEEDED=true
      ;;

    --log-level)
      LEVEL="$2"; shift 2
      set_config "LogLevel" "$LEVEL"
      RESTART_NEEDED=true
      ;;

    --welcome-message)
      MSG="$2"; shift 2
      set_config "UIWelcomeMessage" "$MSG"
      RESTART_NEEDED=true
      ;;

    --session-timeout)
      TIMEOUT="$2"; shift 2
      set_config "SessionTimeout" "$TIMEOUT"
      RESTART_NEEDED=true
      ;;

    --nginx-config)
      DOMAIN="$2"; shift 2
      SSL=false
      [[ "${1:-}" == "--ssl" ]] && SSL=true && shift

      NGINX_CONF="/etc/nginx/sites-available/navidrome"
      PORT=$($SUDO grep -E "^Port" "$CONFIG_FILE" 2>/dev/null | sed 's/.*= *//' || echo "4533")

      if [[ "$SSL" == true ]]; then
        $SUDO tee "$NGINX_CONF" > /dev/null <<NGINX
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }
}
NGINX
      else
        $SUDO tee "$NGINX_CONF" > /dev/null <<NGINX
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }
}
NGINX
      fi

      log "✅ Nginx config written to ${NGINX_CONF}"
      echo "   Next steps:"
      echo "   sudo ln -sf ${NGINX_CONF} /etc/nginx/sites-enabled/navidrome"
      echo "   sudo nginx -t && sudo systemctl reload nginx"
      ;;

    --docker-compose)
      MUSIC="$2"; shift 2
      DATA="${DATA_DIR}"
      PORT=$($SUDO grep -E "^Port" "$CONFIG_FILE" 2>/dev/null | sed 's/.*= *//' || echo "4533")

      cat <<COMPOSE
# docker-compose.yml for Navidrome
version: "3"
services:
  navidrome:
    image: deluan/navidrome:latest
    ports:
      - "${PORT}:4533"
    environment:
      ND_SCANSCHEDULE: "@every 5m"
      ND_LOGLEVEL: info
      ND_SESSIONTIMEOUT: 24h
      ND_ENABLETRANSCODINGCONFIG: "true"
    volumes:
      - "${DATA}:/data"
      - "${MUSIC}:/music:ro"
    restart: unless-stopped
COMPOSE
      exit 0
      ;;

    -h|--help)
      echo "Navidrome Configuration"
      echo ""
      echo "Usage: configure.sh [options]"
      echo ""
      echo "Options:"
      echo "  --show                    Show current config"
      echo "  --music-folder <path>     Set music library path"
      echo "  --port <number>           Set server port"
      echo "  --transcode <true|false>  Enable/disable transcoding"
      echo "  --scan-interval <time>    Set scan interval (e.g. 5m, 1h)"
      echo "  --log-level <level>       Set log level (debug/info/warn/error)"
      echo "  --welcome-message <msg>   Set UI welcome message"
      echo "  --session-timeout <dur>   Set session timeout (e.g. 24h)"
      echo "  --nginx-config <domain>   Generate Nginx reverse proxy config"
      echo "  --docker-compose <music>  Generate Docker Compose file"
      exit 0
      ;;

    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ "$RESTART_NEEDED" == true ]]; then
  if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    log "Restarting Navidrome to apply changes..."
    $SUDO systemctl restart "$SERVICE_NAME"
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
      log "✅ Changes applied"
    else
      err "Restart failed. Check: sudo journalctl -u navidrome -n 20"
    fi
  else
    warn "Service not running. Start with: bash scripts/manage.sh start"
  fi
fi
