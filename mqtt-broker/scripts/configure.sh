#!/bin/bash
# Configure Mosquitto MQTT broker options
set -euo pipefail

CONF_DIR="/etc/mosquitto/conf.d"
CONF_FILE="$CONF_DIR/default.conf"

enable_auth() {
  echo "🔐 Enabling authentication..."
  sudo sed -i 's/allow_anonymous true/allow_anonymous false/' "$CONF_FILE"
  
  if ! grep -q "password_file" "$CONF_FILE"; then
    echo "password_file /etc/mosquitto/passwd" | sudo tee -a "$CONF_FILE" > /dev/null
  fi
  
  echo "✅ Authentication enabled"
  echo "   Make sure you've added users: bash scripts/manage-users.sh add <user> <pass>"
  echo "   Restart: sudo systemctl restart mosquitto"
}

enable_acl() {
  echo "🔒 Setting up ACL..."
  
  if [ ! -f /etc/mosquitto/acl.conf ]; then
    sudo tee /etc/mosquitto/acl.conf > /dev/null << 'ACL'
# Mosquitto ACL Configuration
# Patterns:
#   topic [read|write|readwrite|deny] <topic-pattern>
#
# Per-user rules:
#   user <username>
#   topic readwrite home/sensors/#
#
# Pattern substitution:
#   pattern readwrite home/%u/#    (%u = username, %c = clientid)

# Default: deny all
# Uncomment and customize:

# user admin
# topic readwrite #

# user sensor1
# topic write home/sensors/#

# user dashboard
# topic read home/#
ACL
  fi
  
  if ! grep -q "acl_file" "$CONF_FILE"; then
    echo "acl_file /etc/mosquitto/acl.conf" | sudo tee -a "$CONF_FILE" > /dev/null
  fi
  
  echo "✅ ACL file created at /etc/mosquitto/acl.conf"
  echo "   Edit it, then restart: sudo systemctl restart mosquitto"
}

enable_websocket() {
  local WS_PORT="${1:-9001}"
  echo "🌐 Enabling WebSocket listener on port $WS_PORT..."
  
  if ! grep -q "protocol websockets" "$CONF_FILE"; then
    cat << WSCONF | sudo tee -a "$CONF_FILE" > /dev/null

# WebSocket listener
listener $WS_PORT
protocol websockets
WSCONF
  fi
  
  echo "✅ WebSocket enabled on port $WS_PORT"
  echo "   Restart: sudo systemctl restart mosquitto"
}

setup_bridge() {
  local REMOTE_HOST="" REMOTE_PORT="8883" REMOTE_USER="" REMOTE_PASS="" TOPICS=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --remote-host) REMOTE_HOST="$2"; shift 2 ;;
      --remote-port) REMOTE_PORT="$2"; shift 2 ;;
      --remote-user) REMOTE_USER="$2"; shift 2 ;;
      --remote-pass) REMOTE_PASS="$2"; shift 2 ;;
      --topics) TOPICS="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [ -z "$REMOTE_HOST" ]; then
    echo "Usage: $0 --bridge --remote-host <host> [--remote-port <port>] [--remote-user <user>] [--remote-pass <pass>] [--topics <topics>]"
    exit 1
  fi
  
  sudo tee /etc/mosquitto/conf.d/bridge.conf > /dev/null << BRIDGE
# MQTT Bridge to $REMOTE_HOST
connection bridge-remote
address $REMOTE_HOST:$REMOTE_PORT
${REMOTE_USER:+remote_username $REMOTE_USER}
${REMOTE_PASS:+remote_password $REMOTE_PASS}
${TOPICS:+topic $TOPICS}
bridge_protocol_version mqttv311
try_private false
cleansession true
start_type automatic
BRIDGE

  echo "✅ Bridge configured to $REMOTE_HOST:$REMOTE_PORT"
  echo "   Restart: sudo systemctl restart mosquitto"
}

# Parse arguments
WS_PORT="9001"
while [[ $# -gt 0 ]]; do
  case $1 in
    --auth) enable_auth; exit 0 ;;
    --acl) enable_acl; exit 0 ;;
    --websocket) shift; enable_websocket "${1:-9001}"; exit 0 ;;
    --ws-port) WS_PORT="$2"; shift 2 ;;
    --bridge) shift; setup_bridge "$@"; exit 0 ;;
    *)
      echo "Mosquitto Configuration Tool"
      echo ""
      echo "Usage:"
      echo "  $0 --auth                         Enable password authentication"
      echo "  $0 --acl                           Set up topic ACLs"
      echo "  $0 --websocket [--ws-port PORT]    Enable WebSocket listener"
      echo "  $0 --bridge --remote-host HOST ... Set up broker bridge"
      exit 0
      ;;
  esac
done
