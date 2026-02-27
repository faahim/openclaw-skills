#!/bin/bash
# Ngrok Tunnel Manager — main management script
set -e

NGROK_API="http://127.0.0.1:4040/api"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
  auth <token>           Set ngrok authtoken
  start [options]        Create a new tunnel
  start-config           Start tunnels from ngrok.yml config
  list                   List active tunnels
  stop --name <name>     Stop a specific tunnel
  stop-all               Stop all tunnels (kill ngrok process)
  inspect [--detail ID]  Inspect recent traffic
  status                 Show ngrok agent status
  logs                   Show ngrok agent logs
  edit-config            Open ngrok config for editing
  api-tunnels            List tunnels via ngrok cloud API

Start Options:
  --port <port>          Local port to expose (required)
  --proto <http|tcp|tls> Protocol (default: http)
  --name <name>          Tunnel name
  --subdomain <sub>      Custom subdomain (paid plans)
  --domain <domain>      Reserved domain (paid plans)
  --scheme <https|http>  URL scheme (default: https)
  --auth <user:pass>     HTTP basic auth
  --cidr-allow <cidrs>   Allowed IP ranges (comma-separated)
  --cidr-deny <cidrs>    Blocked IP ranges (comma-separated)
  --request-header <h>   Add request header
  --inspect              Enable traffic inspection (default: true)
  --verify-webhook <p>   Webhook verification provider
  --verify-webhook-secret <s>  Webhook secret

Examples:
  $(basename "$0") start --port 3000
  $(basename "$0") start --port 8080 --proto tcp
  $(basename "$0") start --port 3000 --auth "admin:secret"
  $(basename "$0") list
  $(basename "$0") inspect
EOF
  exit 1
}

check_ngrok() {
  if ! command -v ngrok &>/dev/null; then
    echo -e "${RED}❌ ngrok not found. Run: bash scripts/install.sh${NC}"
    exit 1
  fi
}

cmd_auth() {
  local token="$1"
  if [ -z "$token" ]; then
    # Check env
    token="${NGROK_AUTHTOKEN:-}"
    if [ -z "$token" ]; then
      echo -e "${RED}❌ Usage: $(basename "$0") auth <authtoken>${NC}"
      echo "Get your token at: https://dashboard.ngrok.com/get-started/your-authtoken"
      exit 1
    fi
  fi
  check_ngrok
  ngrok config add-authtoken "$token"
  echo -e "${GREEN}✅ Authtoken configured successfully${NC}"
}

cmd_start() {
  check_ngrok
  local port="" proto="http" name="" subdomain="" domain="" scheme=""
  local auth="" cidr_allow="" cidr_deny="" request_header=""
  local webhook_provider="" webhook_secret=""
  local extra_args=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --port) port="$2"; shift 2 ;;
      --proto) proto="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --subdomain) subdomain="$2"; shift 2 ;;
      --domain) domain="$2"; shift 2 ;;
      --scheme) scheme="$2"; shift 2 ;;
      --auth) auth="$2"; shift 2 ;;
      --cidr-allow) cidr_allow="$2"; shift 2 ;;
      --cidr-deny) cidr_deny="$2"; shift 2 ;;
      --request-header) request_header="$2"; shift 2 ;;
      --verify-webhook) webhook_provider="$2"; shift 2 ;;
      --verify-webhook-secret) webhook_secret="$2"; shift 2 ;;
      --inspect) shift ;;
      *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
  done

  if [ -z "$port" ]; then
    echo -e "${RED}❌ --port is required${NC}"
    exit 1
  fi

  # Build ngrok command
  local cmd="ngrok $proto $port"

  [ -n "$name" ] && extra_args+=("--log" "stdout" "--log-format" "json")
  [ -n "$subdomain" ] && extra_args+=("--subdomain" "$subdomain")
  [ -n "$domain" ] && extra_args+=("--domain" "$domain")
  [ -n "$scheme" ] && extra_args+=("--scheme" "$scheme")
  [ -n "$auth" ] && extra_args+=("--basic-auth" "$auth")
  [ -n "$cidr_allow" ] && extra_args+=("--cidr-allow" "$cidr_allow")
  [ -n "$cidr_deny" ] && extra_args+=("--cidr-deny" "$cidr_deny")
  [ -n "$request_header" ] && extra_args+=("--request-header-add" "$request_header")
  [ -n "$webhook_provider" ] && extra_args+=("--verify-webhook" "$webhook_provider")
  [ -n "$webhook_secret" ] && extra_args+=("--verify-webhook-secret" "$webhook_secret")

  echo -e "${BLUE}🚀 Starting ngrok tunnel...${NC}"
  echo -e "   Protocol: $proto"
  echo -e "   Port: $port"

  # Start ngrok in background
  ngrok "$proto" "$port" "${extra_args[@]}" --log stdout --log-format json &>/tmp/ngrok-output.log &
  NGROK_PID=$!

  # Wait for tunnel to be established
  echo -n "   Waiting for tunnel"
  for i in $(seq 1 30); do
    sleep 1
    echo -n "."

    # Try to get tunnel info from API
    TUNNEL_INFO=$(curl -s "$NGROK_API/tunnels" 2>/dev/null || true)
    if [ -n "$TUNNEL_INFO" ] && echo "$TUNNEL_INFO" | jq -e '.tunnels | length > 0' &>/dev/null; then
      echo ""

      # Extract tunnel details
      PUBLIC_URL=$(echo "$TUNNEL_INFO" | jq -r '.tunnels[0].public_url')
      FORWARD_TO=$(echo "$TUNNEL_INFO" | jq -r '.tunnels[0].config.addr')
      TUNNEL_NAME=$(echo "$TUNNEL_INFO" | jq -r '.tunnels[0].name')

      echo -e "${GREEN}✅ Tunnel created successfully${NC}"
      echo -e "🌐 Public URL: ${YELLOW}$PUBLIC_URL${NC}"
      echo -e "🔍 Inspector: ${BLUE}http://127.0.0.1:4040${NC}"
      echo -e "📊 Forwarding: $PUBLIC_URL → http://localhost:$port"
      echo -e "📛 Name: $TUNNEL_NAME"
      echo -e "🔑 PID: $NGROK_PID"

      # Save tunnel info
      mkdir -p /tmp/ngrok-tunnels
      echo "{\"pid\": $NGROK_PID, \"url\": \"$PUBLIC_URL\", \"port\": $port, \"proto\": \"$proto\", \"name\": \"$TUNNEL_NAME\", \"started_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "/tmp/ngrok-tunnels/$NGROK_PID.json"

      return 0
    fi
  done

  echo ""
  echo -e "${RED}❌ Tunnel failed to start within 30 seconds${NC}"
  echo "Check logs: cat /tmp/ngrok-output.log"
  kill $NGROK_PID 2>/dev/null || true
  exit 1
}

cmd_start_config() {
  check_ngrok
  echo -e "${BLUE}🚀 Starting tunnels from config...${NC}"
  ngrok start --all --log stdout --log-format json &>/tmp/ngrok-output.log &
  NGROK_PID=$!

  echo -n "   Waiting for tunnels"
  for i in $(seq 1 30); do
    sleep 1
    echo -n "."
    TUNNEL_INFO=$(curl -s "$NGROK_API/tunnels" 2>/dev/null || true)
    if [ -n "$TUNNEL_INFO" ] && echo "$TUNNEL_INFO" | jq -e '.tunnels | length > 0' &>/dev/null; then
      echo ""
      echo -e "${GREEN}✅ Tunnels started:${NC}"
      echo "$TUNNEL_INFO" | jq -r '.tunnels[] | "  🌐 \(.name): \(.public_url) → \(.config.addr)"'
      echo -e "🔍 Inspector: ${BLUE}http://127.0.0.1:4040${NC}"
      return 0
    fi
  done
  echo ""
  echo -e "${RED}❌ Failed to start tunnels${NC}"
  kill $NGROK_PID 2>/dev/null || true
  exit 1
}

cmd_list() {
  local tunnel_info
  tunnel_info=$(curl -s "$NGROK_API/tunnels" 2>/dev/null || true)

  if [ -z "$tunnel_info" ] || ! echo "$tunnel_info" | jq -e '.tunnels' &>/dev/null; then
    echo -e "${YELLOW}ℹ️  No active ngrok agent found${NC}"

    # Check for saved tunnel PIDs
    if [ -d /tmp/ngrok-tunnels ] && ls /tmp/ngrok-tunnels/*.json &>/dev/null; then
      echo "Saved tunnel records:"
      for f in /tmp/ngrok-tunnels/*.json; do
        local pid=$(jq -r '.pid' "$f")
        if kill -0 "$pid" 2>/dev/null; then
          echo -e "  🟢 PID $pid — $(jq -r '.url' "$f") → localhost:$(jq -r '.port' "$f")"
        else
          echo -e "  🔴 PID $pid — $(jq -r '.url' "$f") (dead)"
          rm "$f"
        fi
      done
    fi
    return
  fi

  local count
  count=$(echo "$tunnel_info" | jq '.tunnels | length')

  if [ "$count" -eq 0 ]; then
    echo -e "${YELLOW}ℹ️  No active tunnels${NC}"
    return
  fi

  echo -e "${GREEN}Active Tunnels ($count):${NC}"
  echo ""
  echo "$tunnel_info" | jq -r '.tunnels[] | "  📛 \(.name)\n  🌐 \(.public_url)\n  📊 → \(.config.addr)\n  🔧 Proto: \(.proto)\n"'
}

cmd_stop() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      *) name="$1"; shift ;;
    esac
  done

  if [ -z "$name" ]; then
    echo -e "${RED}❌ Usage: $(basename "$0") stop --name <tunnel-name>${NC}"
    exit 1
  fi

  local result
  result=$(curl -s -X DELETE "$NGROK_API/tunnels/$name" 2>/dev/null)
  echo -e "${GREEN}✅ Tunnel '$name' stopped${NC}"
}

cmd_stop_all() {
  # Kill all ngrok processes
  local killed=0
  for pid in $(pgrep -f "ngrok" 2>/dev/null || true); do
    kill "$pid" 2>/dev/null && killed=$((killed + 1))
  done

  # Clean saved tunnels
  rm -rf /tmp/ngrok-tunnels

  if [ "$killed" -gt 0 ]; then
    echo -e "${GREEN}✅ Stopped $killed ngrok process(es)${NC}"
  else
    echo -e "${YELLOW}ℹ️  No ngrok processes found${NC}"
  fi
}

cmd_inspect() {
  local detail=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --detail) detail="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local requests
  requests=$(curl -s "$NGROK_API/requests/http" 2>/dev/null || true)

  if [ -z "$requests" ] || ! echo "$requests" | jq -e '.requests' &>/dev/null; then
    echo -e "${YELLOW}ℹ️  No active ngrok agent or no requests yet${NC}"
    echo "Make sure a tunnel is running and has received traffic."
    return
  fi

  local count
  count=$(echo "$requests" | jq '.requests | length')

  if [ "$count" -eq 0 ]; then
    echo -e "${YELLOW}ℹ️  No requests captured yet${NC}"
    return
  fi

  if [ -n "$detail" ]; then
    if [ "$detail" = "LAST" ]; then
      echo "$requests" | jq '.requests[0]'
    else
      echo "$requests" | jq ".requests[] | select(.id == \"$detail\")"
    fi
    return
  fi

  echo -e "${GREEN}Recent Requests (last $count):${NC}"
  echo ""
  echo "$requests" | jq -r '.requests[:20][] | "\(.start | split(".")[0] | gsub("T"; " ")) | \(.request.method) \(.request.uri) | \(.response.status) | \(.duration / 1000000 | floor)ms"' | \
    while IFS='|' read -r time method status latency; do
      printf "  %-20s %-30s %-6s %s\n" "$time" "$method" "$status" "$latency"
    done
}

cmd_status() {
  check_ngrok

  echo -e "${BLUE}Ngrok Status${NC}"
  echo "─────────────"

  # Version
  echo -e "Version: $(ngrok version 2>/dev/null || echo 'unknown')"

  # Config location
  local config_path
  config_path=$(ngrok config check 2>&1 | grep -oP 'Valid config file at \K.*' || echo "~/.config/ngrok/ngrok.yml")
  echo -e "Config: $config_path"

  # Check if agent is running
  local agent_info
  agent_info=$(curl -s "$NGROK_API/" 2>/dev/null || true)
  if [ -n "$agent_info" ]; then
    echo -e "Agent: ${GREEN}Running${NC}"
    echo -e "Inspector: http://127.0.0.1:4040"

    # Tunnel count
    local tunnels
    tunnels=$(curl -s "$NGROK_API/tunnels" 2>/dev/null || true)
    local tcount
    tcount=$(echo "$tunnels" | jq '.tunnels | length' 2>/dev/null || echo "0")
    echo -e "Active tunnels: $tcount"
  else
    echo -e "Agent: ${YELLOW}Not running${NC}"
  fi

  # Auth check
  if ngrok config check &>/dev/null; then
    echo -e "Auth: ${GREEN}Configured${NC}"
  else
    echo -e "Auth: ${RED}Not configured${NC}"
  fi
}

cmd_logs() {
  if [ -f /tmp/ngrok-output.log ]; then
    tail -50 /tmp/ngrok-output.log | jq -r 'select(.msg) | "\(.t) [\(.lvl)] \(.msg)"' 2>/dev/null || tail -50 /tmp/ngrok-output.log
  else
    echo -e "${YELLOW}ℹ️  No log file found at /tmp/ngrok-output.log${NC}"
    echo "Logs are created when you start a tunnel via this script."
  fi
}

cmd_edit_config() {
  check_ngrok
  local config_path="${HOME}/.config/ngrok/ngrok.yml"
  if [ ! -f "$config_path" ]; then
    config_path="${HOME}/.ngrok2/ngrok.yml"
  fi

  if [ ! -f "$config_path" ]; then
    mkdir -p "$(dirname "$config_path")"
    cat > "$config_path" <<'YAML'
version: "3"
agent:
  authtoken: YOUR_TOKEN_HERE

tunnels:
  webapp:
    proto: http
    addr: 3000
    inspect: true
  api:
    proto: http
    addr: 8080
    inspect: true
YAML
    echo -e "${GREEN}✅ Created config template at: $config_path${NC}"
  fi

  echo "Config file: $config_path"
  echo "---"
  cat "$config_path"
}

cmd_api_tunnels() {
  local api_key="${NGROK_API_KEY:-}"
  if [ -z "$api_key" ]; then
    echo -e "${RED}❌ NGROK_API_KEY not set${NC}"
    echo "Get your API key at: https://dashboard.ngrok.com/api"
    exit 1
  fi

  curl -s -H "Authorization: Bearer $api_key" \
    -H "Ngrok-Version: 2" \
    "https://api.ngrok.com/tunnels" | jq .
}

# Main
COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
  auth) cmd_auth "$@" ;;
  start) cmd_start "$@" ;;
  start-config) cmd_start_config ;;
  list) cmd_list ;;
  stop) cmd_stop "$@" ;;
  stop-all) cmd_stop_all ;;
  inspect) cmd_inspect "$@" ;;
  status) cmd_status ;;
  logs) cmd_logs ;;
  edit-config) cmd_edit_config ;;
  api-tunnels) cmd_api_tunnels ;;
  *) usage ;;
esac
