#!/bin/bash
# Stunnel TLS Wrapper — Tunnel Manager
set -euo pipefail

CERT_DIR="${STUNNEL_CERT_DIR:-/etc/stunnel/certs}"
CONF_DIR="${STUNNEL_CONF_DIR:-/etc/stunnel/conf.d}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect stunnel binary
STUNNEL_BIN=$(command -v stunnel 2>/dev/null || command -v stunnel4 2>/dev/null || echo "stunnel")
SVC_NAME=""
if systemctl list-unit-files stunnel4.service &>/dev/null 2>&1; then
  SVC_NAME="stunnel4"
elif systemctl list-unit-files stunnel.service &>/dev/null 2>&1; then
  SVC_NAME="stunnel"
fi

usage() {
  cat << 'EOF'
Usage: tunnel.sh <command> [options]

Commands:
  create    Create a new TLS tunnel
  list      List all configured tunnels
  status    Show tunnel status with connection info
  health    Detailed health check of all tunnels
  start     Start a tunnel
  stop      Stop a tunnel
  restart   Restart a tunnel (or all)
  remove    Remove a tunnel configuration
  logs      Show tunnel logs

Create Options:
  --name <name>           Tunnel name (required)
  --accept <[host:]port>  Listen address (required)
  --connect <host:port>   Backend address (required, repeatable)
  --mode <server|client>  TLS mode (required)
  --cert <path|auto>      Certificate path or 'auto' for self-signed
  --key <path>            Private key path (if separate from cert)
  --ca <path>             CA certificate for verification
  --verify <0|1|2|3>      Verification level (0=none, 2=require valid cert)
  --protocol <smtp|...>   Application protocol for STARTTLS
EOF
}

create_tunnel() {
  local name="" accept="" mode="" cert="" key="" ca="" verify="" protocol=""
  local -a connects=()
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --accept) accept="$2"; shift 2 ;;
      --connect) connects+=("$2"); shift 2 ;;
      --mode) mode="$2"; shift 2 ;;
      --cert) cert="$2"; shift 2 ;;
      --key) key="$2"; shift 2 ;;
      --ca) ca="$2"; shift 2 ;;
      --verify) verify="$2"; shift 2 ;;
      --protocol) protocol="$2"; shift 2 ;;
      *) echo "❌ Unknown option: $1"; exit 1 ;;
    esac
  done
  
  # Validate
  if [ -z "$name" ] || [ -z "$accept" ] || [ ${#connects[@]} -eq 0 ] || [ -z "$mode" ]; then
    echo "❌ Missing required options: --name, --accept, --connect, --mode"
    usage
    exit 1
  fi
  
  # Check if tunnel already exists
  if [ -f "$CONF_DIR/$name.conf" ]; then
    echo "❌ Tunnel '$name' already exists. Remove it first: tunnel.sh remove $name"
    exit 1
  fi
  
  # Handle auto cert generation
  if [ "$cert" = "auto" ]; then
    echo "🔑 Generating self-signed certificate for '$name'..."
    bash "$SCRIPT_DIR/certs.sh" generate --name "$name" --cn "$name.local" --days 365
    cert="$CERT_DIR/$name.pem"
  fi
  
  # Build config
  local client_val="no"
  [ "$mode" = "client" ] && client_val="yes"
  
  local conf="; Tunnel: $name\n; Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)\n[$name]\nclient = $client_val\naccept = $accept\n"
  
  for c in "${connects[@]}"; do
    conf+="connect = $c\n"
  done
  
  if [ -n "$cert" ] && [ "$client_val" = "no" ]; then
    conf+="cert = $cert\n"
    if [ -n "$key" ]; then
      conf+="key = $key\n"
    fi
  fi
  
  if [ -n "$ca" ]; then
    conf+="CAfile = $ca\n"
  fi
  
  if [ -n "$verify" ]; then
    conf+="verify = $verify\n"
  fi
  
  if [ -n "$protocol" ]; then
    conf+="protocol = $protocol\n"
  fi
  
  # Write config
  echo -e "$conf" | sudo tee "$CONF_DIR/$name.conf" > /dev/null
  echo "✅ Tunnel '$name' created: TLS:$accept → TCP:${connects[0]}"
  
  # Reload stunnel
  reload_stunnel
}

list_tunnels() {
  echo "TUNNEL               MODE      ACCEPT              CONNECT"
  echo "-------------------------------------------------------------------"
  
  for conf_file in "$CONF_DIR"/*.conf; do
    [ -f "$conf_file" ] || continue
    local name=$(basename "$conf_file" .conf)
    local client=$(grep -i "^client" "$conf_file" | head -1 | awk -F= '{print $2}' | tr -d ' ')
    local mode="server"
    [ "$client" = "yes" ] && mode="client"
    local accept_val=$(grep -i "^accept" "$conf_file" | head -1 | awk -F= '{print $2}' | tr -d ' ')
    local connect_val=$(grep -i "^connect" "$conf_file" | head -1 | awk -F= '{print $2}' | tr -d ' ')
    
    printf "%-20s %-9s %-19s %s\n" "$name" "$mode" "$accept_val" "$connect_val"
  done
}

tunnel_status() {
  echo "TUNNEL               MODE      ACCEPT              CONNECT              STATUS"
  echo "---------------------------------------------------------------------------------"
  
  for conf_file in "$CONF_DIR"/*.conf; do
    [ -f "$conf_file" ] || continue
    local name=$(basename "$conf_file" .conf)
    local client=$(grep -i "^client" "$conf_file" | head -1 | awk -F= '{print $2}' | tr -d ' ')
    local mode="server"
    [ "$client" = "yes" ] && mode="client"
    local accept_val=$(grep -i "^accept" "$conf_file" | head -1 | awk -F= '{print $2}' | tr -d ' ')
    local connect_val=$(grep -i "^connect" "$conf_file" | head -1 | awk -F= '{print $2}' | tr -d ' ')
    
    # Check if port is listening
    local port=$(echo "$accept_val" | grep -oE '[0-9]+$')
    local status="❌ DOWN"
    if ss -tlnp 2>/dev/null | grep -q ":${port} " || netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
      status="✅ UP"
    fi
    
    printf "%-20s %-9s %-19s %-20s %s\n" "$name" "$mode" "$accept_val" "$connect_val" "$status"
  done
}

tunnel_health() {
  echo "TUNNEL               STATUS   CERT EXPIRY          LOG ERRORS (24h)"
  echo "----------------------------------------------------------------------"
  
  for conf_file in "$CONF_DIR"/*.conf; do
    [ -f "$conf_file" ] || continue
    local name=$(basename "$conf_file" .conf)
    local cert_file=$(grep -i "^cert" "$conf_file" | head -1 | awk -F= '{print $2}' | tr -d ' ')
    
    # Check port
    local accept_val=$(grep -i "^accept" "$conf_file" | head -1 | awk -F= '{print $2}' | tr -d ' ')
    local port=$(echo "$accept_val" | grep -oE '[0-9]+$')
    local status="❌ DOWN"
    if ss -tlnp 2>/dev/null | grep -q ":${port} " 2>/dev/null; then
      status="✅ UP"
    fi
    
    # Check cert expiry
    local cert_info="N/A"
    if [ -n "$cert_file" ] && [ -f "$cert_file" ]; then
      local expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
      local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
      local now_epoch=$(date +%s)
      local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
      if [ $days_left -lt 7 ]; then
        cert_info="🔴 ${days_left}d left"
      elif [ $days_left -lt 30 ]; then
        cert_info="⚠️  ${days_left}d left"
      else
        cert_info="✅ ${days_left}d left"
      fi
    fi
    
    # Count recent errors
    local errors=0
    if [ -f /var/log/stunnel/stunnel.log ]; then
      errors=$(grep -c "ERROR\|FAIL\|error" /var/log/stunnel/stunnel.log 2>/dev/null | tail -1 || echo 0)
    fi
    
    printf "%-20s %-8s %-20s %s\n" "$name" "$status" "$cert_info" "${errors} errors"
  done
}

start_tunnel() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    echo "Usage: tunnel.sh start <name>"
    exit 1
  fi
  reload_stunnel
  echo "✅ Tunnel '$name' started (stunnel reloaded)"
}

stop_tunnel() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    echo "Usage: tunnel.sh stop <name>"
    exit 1
  fi
  # Disable by renaming config
  if [ -f "$CONF_DIR/$name.conf" ]; then
    sudo mv "$CONF_DIR/$name.conf" "$CONF_DIR/$name.conf.disabled"
    reload_stunnel
    echo "✅ Tunnel '$name' stopped (config disabled)"
  else
    echo "❌ Tunnel '$name' not found"
    exit 1
  fi
}

restart_tunnel() {
  local name="${1:-all}"
  reload_stunnel
  echo "✅ Tunnel '$name' restarted"
}

remove_tunnel() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    echo "Usage: tunnel.sh remove <name>"
    exit 1
  fi
  
  sudo rm -f "$CONF_DIR/$name.conf" "$CONF_DIR/$name.conf.disabled"
  echo "✅ Tunnel '$name' removed"
  
  read -p "Remove certificates too? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo rm -f "$CERT_DIR/$name.pem" "$CERT_DIR/$name-ca.pem"
    echo "✅ Certificates removed"
  fi
  
  reload_stunnel
}

show_logs() {
  local name="${1:-}"
  local log_file="/var/log/stunnel/stunnel.log"
  
  if [ ! -f "$log_file" ]; then
    echo "❌ Log file not found: $log_file"
    exit 1
  fi
  
  if [ -n "$name" ]; then
    grep -i "$name" "$log_file" | tail -50
  else
    tail -50 "$log_file"
  fi
}

reload_stunnel() {
  if [ -n "$SVC_NAME" ] && command -v systemctl &>/dev/null; then
    sudo systemctl restart "$SVC_NAME" 2>/dev/null || true
  else
    # Manual restart
    sudo killall stunnel stunnel4 2>/dev/null || true
    sleep 1
    sudo $STUNNEL_BIN /etc/stunnel/stunnel.conf 2>/dev/null || true
  fi
}

# Main command dispatch
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  create)   create_tunnel "$@" ;;
  list)     list_tunnels ;;
  status)   tunnel_status ;;
  health)   tunnel_health ;;
  start)    start_tunnel "$@" ;;
  stop)     stop_tunnel "$@" ;;
  restart)  restart_tunnel "$@" ;;
  remove)   remove_tunnel "$@" ;;
  logs)     show_logs "$@" ;;
  *)        usage ;;
esac
