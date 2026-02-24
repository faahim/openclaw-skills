#!/bin/bash
# Cloudflare Tunnel Manager — main entry point
set -e

CONFIG_DIR="${CLOUDFLARED_CONFIG_DIR:-$HOME/.cloudflared}"

usage() {
  cat <<EOF
Cloudflare Tunnel Manager

USAGE:
  bash scripts/run.sh <command> [options]

COMMANDS:
  auth                          Authenticate with Cloudflare
  create <name>                 Create a new tunnel
  list                          List all tunnels
  status <name>                 Show tunnel status
  route <name> <hostname>       Create DNS route for tunnel
  start <name> [options]        Start a tunnel
  stop <name>                   Stop a running tunnel
  delete <name>                 Delete a tunnel (and DNS routes)
  quick [--url URL]             Quick temporary tunnel (*.trycloudflare.com)
  service-install <name>        Install as systemd service
  service-uninstall <name>      Remove systemd service
  metrics <name>                Show tunnel connection metrics

START OPTIONS:
  --url <origin>                Local service URL (e.g., http://localhost:3000)
  --config <path>               Use YAML config for multi-service routing

EXAMPLES:
  bash scripts/run.sh auth
  bash scripts/run.sh create my-app
  bash scripts/run.sh route my-app app.example.com
  bash scripts/run.sh start my-app --url http://localhost:3000
  bash scripts/run.sh quick --url http://localhost:8080
EOF
  exit 1
}

check_cloudflared() {
  if ! command -v cloudflared &>/dev/null; then
    echo "❌ cloudflared not installed. Run: bash scripts/install.sh"
    exit 1
  fi
}

check_auth() {
  if [ ! -f "$CONFIG_DIR/cert.pem" ]; then
    echo "❌ Not authenticated. Run: bash scripts/run.sh auth"
    exit 1
  fi
}

get_tunnel_id() {
  local name="$1"
  cloudflared tunnel list -o json 2>/dev/null | jq -r ".[] | select(.name == \"$name\") | .id" | head -1
}

# ─── Commands ───

cmd_auth() {
  check_cloudflared
  echo "🔐 Authenticating with Cloudflare..."
  echo "   A browser URL will appear — click it to authorize."
  echo ""
  cloudflared tunnel login
  echo ""
  echo "✅ Authenticated. Certificate saved to $CONFIG_DIR/cert.pem"
}

cmd_create() {
  local name="$1"
  [ -z "$name" ] && { echo "❌ Usage: create <tunnel-name>"; exit 1; }
  check_cloudflared
  check_auth

  # Check if tunnel already exists
  EXISTING=$(get_tunnel_id "$name")
  if [ -n "$EXISTING" ]; then
    echo "⚠️  Tunnel '$name' already exists (ID: $EXISTING)"
    exit 0
  fi

  echo "🔨 Creating tunnel '$name'..."
  cloudflared tunnel create "$name"
  
  TUNNEL_ID=$(get_tunnel_id "$name")
  echo ""
  echo "✅ Tunnel '$name' created (ID: $TUNNEL_ID)"
  echo "   Credentials: $CONFIG_DIR/${TUNNEL_ID}.json"
  echo ""
  echo "Next: bash scripts/run.sh route $name <hostname>"
}

cmd_list() {
  check_cloudflared
  check_auth

  echo "📋 Your Cloudflare Tunnels:"
  echo ""
  cloudflared tunnel list
}

cmd_status() {
  local name="$1"
  [ -z "$name" ] && { echo "❌ Usage: status <tunnel-name>"; exit 1; }
  check_cloudflared
  check_auth

  TUNNEL_ID=$(get_tunnel_id "$name")
  [ -z "$TUNNEL_ID" ] && { echo "❌ Tunnel '$name' not found"; exit 1; }

  echo "📊 Status for tunnel '$name' ($TUNNEL_ID):"
  echo ""
  cloudflared tunnel info "$name"
}

cmd_route() {
  local name="$1"
  local hostname="$2"
  [ -z "$name" ] || [ -z "$hostname" ] && { echo "❌ Usage: route <tunnel-name> <hostname>"; exit 1; }
  check_cloudflared
  check_auth

  TUNNEL_ID=$(get_tunnel_id "$name")
  [ -z "$TUNNEL_ID" ] && { echo "❌ Tunnel '$name' not found. Create it first."; exit 1; }

  echo "🌐 Creating DNS route: $hostname → tunnel '$name'..."
  cloudflared tunnel route dns "$name" "$hostname"
  echo ""
  echo "✅ DNS route created: $hostname → $name"
  echo "   (DNS propagation may take 1-5 minutes)"
  echo ""
  echo "Next: bash scripts/run.sh start $name --url http://localhost:PORT"
}

cmd_start() {
  local name="$1"
  shift || true
  [ -z "$name" ] && { echo "❌ Usage: start <tunnel-name> --url <origin> | --config <path>"; exit 1; }
  check_cloudflared
  check_auth

  local url=""
  local config=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --url) url="$2"; shift 2 ;;
      --config) config="$2"; shift 2 ;;
      *) echo "❌ Unknown option: $1"; exit 1 ;;
    esac
  done

  TUNNEL_ID=$(get_tunnel_id "$name")
  [ -z "$TUNNEL_ID" ] && { echo "❌ Tunnel '$name' not found"; exit 1; }

  if [ -n "$config" ]; then
    echo "🚀 Starting tunnel '$name' with config: $config"
    cloudflared tunnel --config "$config" run "$name"
  elif [ -n "$url" ]; then
    echo "🚀 Starting tunnel '$name': → $url"
    cloudflared tunnel run --url "$url" "$name"
  else
    echo "❌ Provide --url or --config"
    exit 1
  fi
}

cmd_stop() {
  local name="$1"
  [ -z "$name" ] && { echo "❌ Usage: stop <tunnel-name>"; exit 1; }

  # Find and kill cloudflared process for this tunnel
  PIDS=$(pgrep -f "cloudflared.*tunnel.*run.*$name" 2>/dev/null || true)
  if [ -z "$PIDS" ]; then
    echo "⚠️  No running process found for tunnel '$name'"
    # Check systemd
    if systemctl is-active "cloudflared-${name}" &>/dev/null; then
      echo "   Found systemd service. Stopping..."
      sudo systemctl stop "cloudflared-${name}"
      echo "✅ Service stopped."
    fi
  else
    echo "🛑 Stopping tunnel '$name' (PIDs: $PIDS)..."
    kill $PIDS 2>/dev/null || true
    sleep 2
    # Force kill if still running
    kill -9 $PIDS 2>/dev/null || true
    echo "✅ Tunnel '$name' stopped."
  fi
}

cmd_delete() {
  local name="$1"
  [ -z "$name" ] && { echo "❌ Usage: delete <tunnel-name>"; exit 1; }
  check_cloudflared
  check_auth

  TUNNEL_ID=$(get_tunnel_id "$name")
  [ -z "$TUNNEL_ID" ] && { echo "❌ Tunnel '$name' not found"; exit 1; }

  echo "⚠️  Deleting tunnel '$name' ($TUNNEL_ID)..."
  echo "   This will also remove associated DNS routes."
  
  # Cleanup connections first
  cloudflared tunnel cleanup "$name" 2>/dev/null || true
  
  # Delete tunnel
  cloudflared tunnel delete "$name"
  echo "✅ Tunnel '$name' deleted."
}

cmd_quick() {
  check_cloudflared
  local url="http://localhost:8080"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --url) url="$2"; shift 2 ;;
      *) echo "❌ Unknown option: $1"; exit 1 ;;
    esac
  done

  echo "⚡ Starting quick tunnel → $url"
  echo "   (A random *.trycloudflare.com URL will be assigned)"
  echo ""
  cloudflared tunnel --url "$url"
}

cmd_service_install() {
  local name="$1"
  shift || true
  [ -z "$name" ] && { echo "❌ Usage: service-install <tunnel-name> [--config <path>]"; exit 1; }
  check_cloudflared

  local config=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --config) config="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  TUNNEL_ID=$(get_tunnel_id "$name")
  [ -z "$TUNNEL_ID" ] && { echo "❌ Tunnel '$name' not found"; exit 1; }

  SERVICE_NAME="cloudflared-${name}"
  CONFIG_FLAG=""
  [ -n "$config" ] && CONFIG_FLAG="--config $config"

  cat <<EOF | sudo tee /etc/systemd/system/${SERVICE_NAME}.service >/dev/null
[Unit]
Description=Cloudflare Tunnel: $name
After=network.target

[Service]
Type=simple
User=$(whoami)
ExecStart=$(which cloudflared) tunnel $CONFIG_FLAG run $name
Restart=on-failure
RestartSec=5
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable "$SERVICE_NAME"
  sudo systemctl start "$SERVICE_NAME"

  echo "✅ Systemd service '$SERVICE_NAME' installed and started."
  echo "   Status: sudo systemctl status $SERVICE_NAME"
  echo "   Logs:   sudo journalctl -u $SERVICE_NAME -f"
}

cmd_service_uninstall() {
  local name="$1"
  [ -z "$name" ] && { echo "❌ Usage: service-uninstall <tunnel-name>"; exit 1; }

  SERVICE_NAME="cloudflared-${name}"
  
  sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
  sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true
  sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
  sudo systemctl daemon-reload

  echo "✅ Service '$SERVICE_NAME' uninstalled."
}

cmd_metrics() {
  local name="$1"
  [ -z "$name" ] && { echo "❌ Usage: metrics <tunnel-name>"; exit 1; }
  check_cloudflared
  check_auth

  echo "📈 Metrics for tunnel '$name':"
  cloudflared tunnel info "$name"
}

# ─── Main ───

[ $# -eq 0 ] && usage

COMMAND="$1"
shift

case "$COMMAND" in
  auth)              cmd_auth ;;
  create)            cmd_create "$@" ;;
  list)              cmd_list ;;
  status)            cmd_status "$@" ;;
  route)             cmd_route "$@" ;;
  start)             cmd_start "$@" ;;
  stop)              cmd_stop "$@" ;;
  delete)            cmd_delete "$@" ;;
  quick)             cmd_quick "$@" ;;
  service-install)   cmd_service_install "$@" ;;
  service-uninstall) cmd_service_uninstall "$@" ;;
  metrics)           cmd_metrics "$@" ;;
  help|--help|-h)    usage ;;
  *)                 echo "❌ Unknown command: $COMMAND"; usage ;;
esac
