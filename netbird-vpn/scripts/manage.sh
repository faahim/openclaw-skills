#!/bin/bash
# NetBird VPN Management Script
# Manage peers, routes, and network configuration

set -euo pipefail

NETBIRD_API_TOKEN="${NETBIRD_API_TOKEN:-}"
NETBIRD_MANAGEMENT_URL="${NETBIRD_MANAGEMENT_URL:-https://api.netbird.io}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

# Show peer list
cmd_peers() {
  echo ""
  echo "NETBIRD PEERS"
  echo "============="
  sudo netbird status --detail 2>/dev/null || sudo netbird status
}

# Get detailed peer info
cmd_peer_info() {
  local peer_name="${1:-}"
  if [[ -z "$peer_name" ]]; then
    echo "Usage: manage.sh peer-info <peer-name>"
    exit 1
  fi
  sudo netbird status --detail | grep -A 10 "$peer_name" || echo "Peer '$peer_name' not found"
}

# List routes
cmd_routes() {
  if [[ -z "$NETBIRD_API_TOKEN" ]]; then
    echo "❌ NETBIRD_API_TOKEN required for route management"
    echo "   Set: export NETBIRD_API_TOKEN='your-token'"
    exit 1
  fi

  echo ""
  echo "NETWORK ROUTES"
  echo "=============="
  curl -s "$NETBIRD_MANAGEMENT_URL/api/routes" \
    -H "Authorization: Token $NETBIRD_API_TOKEN" | jq -r '
    .[] | "\(.network_id)\t\(.network)\t\(.peer)\t\(.enabled)"
  ' | column -t -s $'\t' -N "ID,NETWORK,PEER,ENABLED"
}

# Add route
cmd_add_route() {
  local network="" peer=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --network) network="$2"; shift 2 ;;
      --peer) peer="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$network" || -z "$peer" ]]; then
    echo "Usage: manage.sh add-route --network 192.168.1.0/24 --peer peer-name"
    exit 1
  fi

  if [[ -z "$NETBIRD_API_TOKEN" ]]; then
    echo "❌ NETBIRD_API_TOKEN required"
    exit 1
  fi

  log "Adding route $network via $peer..."
  curl -s -X POST "$NETBIRD_MANAGEMENT_URL/api/routes" \
    -H "Authorization: Token $NETBIRD_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"network\": \"$network\",
      \"network_id\": \"route-$(date +%s)\",
      \"peer\": \"$peer\",
      \"enabled\": true,
      \"masquerade\": true
    }" | jq .
}

# List groups
cmd_groups() {
  if [[ -z "$NETBIRD_API_TOKEN" ]]; then
    echo "❌ NETBIRD_API_TOKEN required"
    exit 1
  fi

  echo ""
  echo "PEER GROUPS"
  echo "==========="
  curl -s "$NETBIRD_MANAGEMENT_URL/api/groups" \
    -H "Authorization: Token $NETBIRD_API_TOKEN" | jq -r '
    .[] | "\(.name)\t\(.peers_count)\t\(.id)"
  ' | column -t -s $'\t' -N "GROUP,PEERS,ID"
}

# List setup keys
cmd_keys() {
  if [[ -z "$NETBIRD_API_TOKEN" ]]; then
    echo "❌ NETBIRD_API_TOKEN required"
    exit 1
  fi

  echo ""
  echo "SETUP KEYS"
  echo "=========="
  curl -s "$NETBIRD_MANAGEMENT_URL/api/setup-keys" \
    -H "Authorization: Token $NETBIRD_API_TOKEN" | jq -r '
    .[] | "\(.name)\t\(.type)\t\(.state)\t\(.expires_at[:10])\t\(.used_times)/\(.usage_limit)"
  ' | column -t -s $'\t' -N "NAME,TYPE,STATE,EXPIRES,USED"
}

# Create setup key
cmd_create_key() {
  local name="${1:-server-key}" expires="${2:-86400}" key_type="${3:-reusable}"

  if [[ -z "$NETBIRD_API_TOKEN" ]]; then
    echo "❌ NETBIRD_API_TOKEN required"
    exit 1
  fi

  log "Creating $key_type setup key '$name' (expires in ${expires}s)..."
  curl -s -X POST "$NETBIRD_MANAGEMENT_URL/api/setup-keys" \
    -H "Authorization: Token $NETBIRD_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$name\",
      \"type\": \"$key_type\",
      \"expires_in\": $expires,
      \"auto_groups\": []
    }" | jq -r '"Setup Key: \(.key)\nExpires: \(.expires_at)"'
}

# Disconnect
cmd_down() {
  log "Disconnecting from NetBird..."
  sudo netbird down
  log "✅ Disconnected"
}

# Reconnect
cmd_up() {
  log "Connecting to NetBird..."
  sudo netbird up
  sleep 2
  sudo netbird status
}

# Show version and status
cmd_info() {
  echo ""
  echo "NETBIRD INFO"
  echo "============"
  echo "Version:    $(netbird version 2>/dev/null || echo 'not installed')"
  echo "Config:     /etc/netbird/config.json"
  echo "Management: $NETBIRD_MANAGEMENT_URL"
  echo ""
  sudo netbird status 2>/dev/null || echo "Daemon not running"
}

# Main
case "${1:-help}" in
  peers)       cmd_peers ;;
  peer-info)   shift; cmd_peer_info "$@" ;;
  routes)      cmd_routes ;;
  add-route)   shift; cmd_add_route "$@" ;;
  groups)      cmd_groups ;;
  keys)        cmd_keys ;;
  create-key)  shift; cmd_create_key "$@" ;;
  up)          cmd_up ;;
  down)        cmd_down ;;
  info)        cmd_info ;;
  help|*)
    cat <<EOF
NetBird VPN Manager

Usage: manage.sh <command> [options]

Commands:
  peers                     List connected peers
  peer-info <name>          Detailed peer info
  routes                    List network routes (API token required)
  add-route --network CIDR --peer NAME   Add a route
  groups                    List peer groups (API token required)
  keys                      List setup keys (API token required)
  create-key [name] [ttl]   Create setup key (API token required)
  up                        Connect to mesh
  down                      Disconnect from mesh
  info                      Show version and status
  help                      Show this help

Environment:
  NETBIRD_API_TOKEN         API token for management operations
  NETBIRD_MANAGEMENT_URL    Management server URL (default: https://api.netbird.io)
EOF
    ;;
esac
