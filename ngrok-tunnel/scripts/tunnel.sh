#!/bin/bash
# Ngrok Tunnel Manager — Start, stop, list, inspect, and replay tunnels
set -euo pipefail

NGROK_API="http://127.0.0.1:4040/api"
NGROK_BIN="${NGROK_BIN:-ngrok}"
LOG_DIR="${HOME}/.local/share/ngrok-tunnel"
PID_FILE="${LOG_DIR}/ngrok.pid"
LOG_FILE="${LOG_DIR}/ngrok.log"

mkdir -p "$LOG_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
Ngrok Tunnel Manager

Usage: $(basename "$0") <command> [options]

Commands:
  install             Install ngrok CLI
  start               Start a tunnel
  stop                Stop tunnels
  list                List active tunnels
  inspect             View captured requests
  replay              Replay a captured request
  status              Show tunnel status
  logs                Show ngrok logs

Start Options:
  --port PORT         Local port to expose (default: 3000)
  --proto PROTO       Protocol: http, tcp, tls (default: http)
  --auth USER:PASS    Basic auth credentials
  --domain DOMAIN     Custom domain (e.g. myapp.ngrok-free.app)
  --name NAME         Named tunnel from config
  --all               Start all tunnels from config
  --background        Run in background
  --region REGION     Region: us, eu, ap, au, sa, jp, in (default: us)
  --cidr-allow CIDRS  Comma-separated allowed CIDRs

Inspect Options:
  --limit N           Number of requests to show (default: 20)

Replay Options:
  --id REQUEST_ID     Request ID to replay

Stop Options:
  --name NAME         Stop specific named tunnel (default: all)

Examples:
  $(basename "$0") start --port 3000
  $(basename "$0") start --port 8080 --auth admin:secret
  $(basename "$0") start --port 22 --proto tcp
  $(basename "$0") list
  $(basename "$0") inspect --limit 10
  $(basename "$0") stop
EOF
}

check_ngrok() {
  if ! command -v "$NGROK_BIN" &>/dev/null; then
    echo -e "${RED}❌ ngrok not found. Run: $(basename "$0") install${NC}"
    exit 1
  fi
}

cmd_install() {
  if command -v ngrok &>/dev/null; then
    echo -e "${GREEN}✅ ngrok already installed: $(ngrok version)${NC}"
    return 0
  fi

  local ARCH
  ARCH=$(uname -m)
  local OS
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')

  case "$ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l)  ARCH="arm" ;;
    *) echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"; exit 1 ;;
  esac

  case "$OS" in
    linux|darwin) ;;
    *) echo -e "${RED}❌ Unsupported OS: $OS${NC}"; exit 1 ;;
  esac

  local URL="https://ngrok-agent.s3.amazonaws.com/ngrok-v3-stable-${OS}-${ARCH}.tgz"
  local INSTALL_DIR="/usr/local/bin"

  if [ ! -w "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
  fi

  echo -e "${BLUE}📦 Downloading ngrok for ${OS}/${ARCH}...${NC}"
  curl -sSL "$URL" | tar xz -C "$INSTALL_DIR"

  if command -v ngrok &>/dev/null; then
    echo -e "${GREEN}✅ ngrok installed: $(ngrok version)${NC}"
    echo -e "${YELLOW}💡 Next: ngrok config add-authtoken YOUR_TOKEN${NC}"
  else
    echo -e "${GREEN}✅ ngrok installed to ${INSTALL_DIR}/ngrok${NC}"
    echo -e "${YELLOW}💡 Add to PATH: export PATH=\"${INSTALL_DIR}:\$PATH\"${NC}"
  fi
}

cmd_start() {
  check_ngrok

  local PORT="${NGROK_DEFAULT_PORT:-3000}"
  local PROTO="http"
  local AUTH=""
  local DOMAIN=""
  local NAME=""
  local ALL=false
  local BACKGROUND=false
  local REGION="${NGROK_DEFAULT_REGION:-us}"
  local CIDR_ALLOW=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --port) PORT="$2"; shift 2 ;;
      --proto) PROTO="$2"; shift 2 ;;
      --auth) AUTH="$2"; shift 2 ;;
      --domain) DOMAIN="$2"; shift 2 ;;
      --name) NAME="$2"; shift 2 ;;
      --all) ALL=true; shift ;;
      --background) BACKGROUND=true; shift ;;
      --region) REGION="$2"; shift 2 ;;
      --cidr-allow) CIDR_ALLOW="$2"; shift 2 ;;
      *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
  done

  # Build ngrok command
  local CMD=("$NGROK_BIN")

  if [[ "$ALL" == true ]]; then
    CMD+=(start --all)
  elif [[ -n "$NAME" ]]; then
    CMD+=(start "$NAME")
  else
    CMD+=("$PROTO" "$PORT")

    if [[ -n "$AUTH" ]]; then
      CMD+=(--basic-auth "$AUTH")
    fi
    if [[ -n "$DOMAIN" ]]; then
      CMD+=(--domain "$DOMAIN")
    fi
    if [[ -n "$CIDR_ALLOW" ]]; then
      CMD+=(--cidr-allow "$CIDR_ALLOW")
    fi
    CMD+=(--region "$REGION")
  fi

  if [[ "$BACKGROUND" == true ]]; then
    echo -e "${BLUE}🚀 Starting ngrok in background...${NC}"
    nohup "${CMD[@]}" > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 2

    # Try to get the URL
    local PUBLIC_URL
    PUBLIC_URL=$(curl -s "$NGROK_API/tunnels" 2>/dev/null | jq -r '.tunnels[0].public_url // empty' 2>/dev/null || true)

    if [[ -n "$PUBLIC_URL" ]]; then
      echo -e "${GREEN}✅ Tunnel started${NC}"
      echo -e "${GREEN}🌐 Public URL: ${PUBLIC_URL}${NC}"
      echo -e "${BLUE}📊 Inspector: http://127.0.0.1:4040${NC}"
    else
      echo -e "${YELLOW}⏳ Tunnel starting... check with: $(basename "$0") status${NC}"
    fi
  else
    echo -e "${BLUE}🚀 Starting ngrok tunnel...${NC}"
    echo -e "${YELLOW}💡 Press Ctrl+C to stop${NC}"
    "${CMD[@]}"
  fi
}

cmd_stop() {
  local NAME=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) NAME="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -n "$NAME" ]]; then
    # Stop specific tunnel via API
    local RESULT
    RESULT=$(curl -s -X DELETE "$NGROK_API/tunnels/$NAME" 2>/dev/null) || true
    echo -e "${GREEN}✅ Tunnel '$NAME' stopped${NC}"
  else
    # Kill all ngrok processes
    if [[ -f "$PID_FILE" ]]; then
      local PID
      PID=$(cat "$PID_FILE")
      kill "$PID" 2>/dev/null || true
      rm -f "$PID_FILE"
    fi
    pkill -f "ngrok" 2>/dev/null || true
    echo -e "${GREEN}✅ All tunnels stopped${NC}"
  fi
}

cmd_list() {
  local TUNNELS
  TUNNELS=$(curl -s "$NGROK_API/tunnels" 2>/dev/null) || {
    echo -e "${YELLOW}⚠️  No active ngrok session found${NC}"
    return 0
  }

  local COUNT
  COUNT=$(echo "$TUNNELS" | jq '.tunnels | length')

  if [[ "$COUNT" -eq 0 ]]; then
    echo -e "${YELLOW}No active tunnels${NC}"
    return 0
  fi

  echo -e "${GREEN}Active Tunnels:${NC}"
  echo "$TUNNELS" | jq -r '.tunnels[] | "  \(.proto)://\(.public_url | sub("https?://"; "")) → \(.config.addr) (\(.proto))"'
}

cmd_inspect() {
  local LIMIT=20
  while [[ $# -gt 0 ]]; do
    case $1 in
      --limit) LIMIT="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local REQUESTS
  REQUESTS=$(curl -s "$NGROK_API/requests/http?limit=$LIMIT" 2>/dev/null) || {
    echo -e "${YELLOW}⚠️  No active ngrok session or no requests captured${NC}"
    return 0
  }

  local COUNT
  COUNT=$(echo "$REQUESTS" | jq '.requests | length')

  if [[ "$COUNT" -eq 0 ]]; then
    echo -e "${YELLOW}No requests captured yet${NC}"
    return 0
  fi

  echo -e "${GREEN}Captured Requests (last $LIMIT):${NC}"
  echo "$REQUESTS" | jq -r '.requests[] | 
    "\(.start | split("T")[1] | split(".")[0]) \(.request.method) \(.request.uri) \(.response.status_code) (\(.duration / 1000000 | floor)ms) — \(.response.headers["Content-Length"][0] // "?")B" + 
    (if .response.status_code >= 400 then " ⚠️" else "" end)'
}

cmd_replay() {
  local ID=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id) ID="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$ID" ]]; then
    echo -e "${RED}❌ --id required. Get IDs from: $(basename "$0") inspect${NC}"
    exit 1
  fi

  curl -s -X POST "$NGROK_API/requests/http" \
    -H "Content-Type: application/json" \
    -d "{\"id\": \"$ID\"}" 2>/dev/null || {
    echo -e "${RED}❌ Failed to replay request${NC}"
    exit 1
  }

  echo -e "${GREEN}✅ Request $ID replayed${NC}"
}

cmd_status() {
  # Check if ngrok is running
  if pgrep -x ngrok &>/dev/null; then
    echo -e "${GREEN}✅ ngrok is running${NC}"

    local TUNNELS
    TUNNELS=$(curl -s "$NGROK_API/tunnels" 2>/dev/null) || {
      echo -e "${YELLOW}⚠️  Running but API not responding${NC}"
      return 0
    }

    local COUNT
    COUNT=$(echo "$TUNNELS" | jq '.tunnels | length')
    echo -e "   Tunnels: ${COUNT}"

    echo "$TUNNELS" | jq -r '.tunnels[] | "   🌐 \(.public_url) → \(.config.addr)"'
    echo -e "   📊 Inspector: http://127.0.0.1:4040"
  else
    echo -e "${YELLOW}⚠️  ngrok is not running${NC}"
  fi
}

cmd_logs() {
  if [[ -f "$LOG_FILE" ]]; then
    tail -50 "$LOG_FILE"
  else
    echo -e "${YELLOW}No logs found. Start a background tunnel first.${NC}"
  fi
}

# Main dispatch
COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  install)  cmd_install "$@" ;;
  start)    cmd_start "$@" ;;
  stop)     cmd_stop "$@" ;;
  list)     cmd_list "$@" ;;
  inspect)  cmd_inspect "$@" ;;
  replay)   cmd_replay "$@" ;;
  status)   cmd_status "$@" ;;
  logs)     cmd_logs "$@" ;;
  -h|--help|help|"") usage ;;
  *) echo -e "${RED}Unknown command: $COMMAND${NC}"; usage; exit 1 ;;
esac
