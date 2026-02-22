#!/bin/bash
# WireGuard VPN Manager — Main management script
# Usage: bash wg-manager.sh <command> [options]

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────
WG_CONFIG_DIR="${WG_CONFIG_DIR:-/etc/wireguard}"
WG_CLIENT_DIR="${WG_CLIENT_DIR:-/etc/wireguard/clients}"
WG_DEFAULT_PORT="${WG_DEFAULT_PORT:-51820}"
WG_DEFAULT_DNS="${WG_DEFAULT_DNS:-1.1.1.1,1.0.0.1}"
WG_DEFAULT_SUBNET="${WG_DEFAULT_SUBNET:-10.0.0.0/24}"
WG_PEER_DB="${WG_CONFIG_DIR}/peers.json"

# ─── Colors ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'
log()  { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; exit 1; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# ─── Helpers ──────────────────────────────────────────────────────────
check_root() {
  [[ $EUID -ne 0 ]] && err "Must run as root (sudo)"
}

check_wg() {
  command -v wg &>/dev/null || err "WireGuard not installed. Run: bash scripts/install.sh"
}

generate_keypair() {
  local privkey=$(wg genkey)
  local pubkey=$(echo "$privkey" | wg pubkey)
  echo "$privkey|$pubkey"
}

generate_psk() {
  wg genpsk
}

get_next_ip() {
  local interface=$1
  local subnet_base=$(echo "$WG_DEFAULT_SUBNET" | cut -d'/' -f1 | sed 's/\.[0-9]*$//')

  if [ ! -f "$WG_PEER_DB" ]; then
    echo "${subnet_base}.2"
    return
  fi

  local max_ip=$(jq -r --arg iface "$interface" \
    '[.peers[] | select(.interface == $iface) | .address | split("/")[0] | split(".")[3] | tonumber] | max // 1' \
    "$WG_PEER_DB" 2>/dev/null || echo "1")

  echo "${subnet_base}.$((max_ip + 1))"
}

init_peer_db() {
  if [ ! -f "$WG_PEER_DB" ]; then
    echo '{"peers":[]}' > "$WG_PEER_DB"
    chmod 600 "$WG_PEER_DB"
  fi
}

add_to_peer_db() {
  local name=$1 interface=$2 address=$3 pubkey=$4
  init_peer_db
  local tmp=$(mktemp)
  jq --arg name "$name" --arg iface "$interface" --arg addr "$address" --arg pub "$pubkey" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.peers += [{"name": $name, "interface": $iface, "address": $addr, "public_key": $pub, "created_at": $ts}]' \
    "$WG_PEER_DB" > "$tmp" && mv "$tmp" "$WG_PEER_DB"
  chmod 600 "$WG_PEER_DB"
}

remove_from_peer_db() {
  local name=$1 interface=$2
  local tmp=$(mktemp)
  jq --arg name "$name" --arg iface "$interface" \
    '.peers |= [.[] | select(.name != $name or .interface != $iface)]' \
    "$WG_PEER_DB" > "$tmp" && mv "$tmp" "$WG_PEER_DB"
}

get_peer_pubkey() {
  local name=$1 interface=$2
  jq -r --arg name "$name" --arg iface "$interface" \
    '.peers[] | select(.name == $name and .interface == $iface) | .public_key' \
    "$WG_PEER_DB" 2>/dev/null
}

get_outbound_iface() {
  ip route | grep default | awk '{print $5}' | head -1
}

# ─── Commands ─────────────────────────────────────────────────────────

cmd_init_server() {
  local interface="" address="" port="" endpoint=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --interface) interface="$2"; shift 2 ;;
      --address)   address="$2"; shift 2 ;;
      --port)      port="$2"; shift 2 ;;
      --endpoint)  endpoint="$2"; shift 2 ;;
      --help) echo "Usage: init-server --interface wg0 --address 10.0.0.1/24 --port 51820 --endpoint <ip>"; return ;;
      *) err "Unknown option: $1" ;;
    esac
  done

  [[ -z "$interface" ]] && interface="wg0"
  [[ -z "$address" ]] && address="10.0.0.1/24"
  [[ -z "$port" ]] && port="$WG_DEFAULT_PORT"
  [[ -z "$endpoint" ]] && endpoint=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

  local conf_file="${WG_CONFIG_DIR}/${interface}.conf"

  [[ -f "$conf_file" ]] && err "Config already exists: $conf_file. Remove it first or use a different interface."

  # Generate server keypair
  local keypair=$(generate_keypair)
  local privkey=$(echo "$keypair" | cut -d'|' -f1)
  local pubkey=$(echo "$keypair" | cut -d'|' -f2)

  local out_iface=$(get_outbound_iface)

  # Write server config
  cat > "$conf_file" << EOF
[Interface]
PrivateKey = ${privkey}
Address = ${address}
ListenPort = ${port}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${out_iface} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${out_iface} -j MASQUERADE
EOF

  chmod 600 "$conf_file"
  log "Generated server keypair"
  log "Created ${conf_file}"

  # Enable IP forwarding (if not already)
  sysctl -w net.ipv4.ip_forward=1 &>/dev/null
  log "Enabled IP forwarding"

  # Start interface
  wg-quick up "$interface" 2>/dev/null && log "Started ${interface} interface" || warn "Could not auto-start (might need reboot or manual start)"

  # Enable on boot
  systemctl enable wg-quick@${interface} 2>/dev/null && log "Enabled on boot" || true

  mkdir -p "$WG_CLIENT_DIR"
  init_peer_db

  echo ""
  echo -e "${BOLD}Server public key:${NC} ${pubkey}"
  echo -e "${BOLD}Endpoint:${NC} ${endpoint}:${port}"
  echo -e "${BOLD}Subnet:${NC} ${address}"
  echo ""
  echo "Next: bash scripts/wg-manager.sh add-peer --interface ${interface} --name \"my-device\""
}

cmd_add_peer() {
  local interface="" name="" dns="" kill_switch=false allowed_ips="0.0.0.0/0,::/0"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --interface)   interface="$2"; shift 2 ;;
      --name)        name="$2"; shift 2 ;;
      --dns)         dns="$2"; shift 2 ;;
      --kill-switch) kill_switch=true; shift ;;
      --allowed-ips) allowed_ips="$2"; shift 2 ;;
      --help) echo "Usage: add-peer --interface wg0 --name laptop [--dns 1.1.1.1] [--kill-switch]"; return ;;
      *) err "Unknown option: $1" ;;
    esac
  done

  [[ -z "$interface" ]] && interface="wg0"
  [[ -z "$name" ]] && err "Peer --name is required"
  [[ -z "$dns" ]] && dns="$WG_DEFAULT_DNS"

  local conf_file="${WG_CONFIG_DIR}/${interface}.conf"
  [[ ! -f "$conf_file" ]] && err "Server config not found: $conf_file. Run init-server first."

  # Get server info
  local server_pubkey=$(wg show "$interface" public-key 2>/dev/null || grep -A1 '\[Interface\]' "$conf_file" | grep PrivateKey | awk '{print $3}' | wg pubkey)
  local server_port=$(grep ListenPort "$conf_file" | awk '{print $3}')
  local server_endpoint=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

  # Generate peer keypair and PSK
  local keypair=$(generate_keypair)
  local peer_privkey=$(echo "$keypair" | cut -d'|' -f1)
  local peer_pubkey=$(echo "$keypair" | cut -d'|' -f2)
  local psk=$(generate_psk)

  # Get next available IP
  local peer_ip=$(get_next_ip "$interface")

  # Add peer to server config
  cat >> "$conf_file" << EOF

[Peer]
# ${name}
PublicKey = ${peer_pubkey}
PresharedKey = ${psk}
AllowedIPs = ${peer_ip}/32
EOF

  log "Generated peer keypair for \"${name}\""

  # Reload server if running
  if wg show "$interface" &>/dev/null; then
    wg syncconf "$interface" <(wg-quick strip "$interface")
    log "Added peer to ${interface} (live)"
  else
    log "Added peer to ${interface} config"
  fi

  # Build client config
  local client_conf="${WG_CLIENT_DIR}/${name}.conf"
  cat > "$client_conf" << EOF
[Interface]
PrivateKey = ${peer_privkey}
Address = ${peer_ip}/32
DNS = ${dns}
EOF

  if $kill_switch; then
    cat >> "$client_conf" << 'EOF'
PostUp = iptables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
PreDown = iptables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
EOF
  fi

  cat >> "$client_conf" << EOF

[Peer]
PublicKey = ${server_pubkey}
PresharedKey = ${psk}
Endpoint = ${server_endpoint}:${server_port}
AllowedIPs = ${allowed_ips}
PersistentKeepalive = 25
EOF

  chmod 600 "$client_conf"
  log "Client config saved to ${client_conf}"

  # Generate QR code if qrencode is available
  if command -v qrencode &>/dev/null; then
    qrencode -t png -o "${WG_CLIENT_DIR}/${name}.png" < "$client_conf"
    qrencode -t ansiutf8 < "$client_conf" 2>/dev/null || true
    log "QR code saved to ${WG_CLIENT_DIR}/${name}.png"
  fi

  # Track peer
  add_to_peer_db "$name" "$interface" "${peer_ip}/32" "$peer_pubkey"

  echo ""
  echo -e "${BOLD}Client config:${NC}"
  cat "$client_conf"
}

cmd_remove_peer() {
  local interface="" name=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --interface) interface="$2"; shift 2 ;;
      --name)      name="$2"; shift 2 ;;
      *) err "Unknown option: $1" ;;
    esac
  done

  [[ -z "$interface" ]] && interface="wg0"
  [[ -z "$name" ]] && err "Peer --name is required"

  local pubkey=$(get_peer_pubkey "$name" "$interface")
  [[ -z "$pubkey" ]] && err "Peer '${name}' not found in database"

  # Remove from WireGuard
  if wg show "$interface" &>/dev/null; then
    wg set "$interface" peer "$pubkey" remove
    log "Removed peer from live interface"
  fi

  # Remove from config file (remove the [Peer] block with matching comment)
  local conf_file="${WG_CONFIG_DIR}/${interface}.conf"
  if [ -f "$conf_file" ]; then
    local tmp=$(mktemp)
    awk -v name="$name" '
      /^# '"$name"'$/ { skip=1; getline; next }
      /^\[Peer\]/ { if (skip) { skip=0; next } else { header=1 } }
      skip && /^\[/ { skip=0 }
      !skip { print }
    ' "$conf_file" > "$tmp"
    # Simpler: remove by pubkey
    python3 -c "
import re, sys
conf = open('$conf_file').read()
# Find and remove the peer block containing this pubkey
pattern = r'\n\[Peer\]\n# ${name}\n.*?(?=\n\[|$)'
conf = re.sub(pattern, '', conf, flags=re.DOTALL)
open('$conf_file', 'w').write(conf)
" 2>/dev/null || warn "Could not auto-remove from config file — edit manually"
    log "Removed from config"
  fi

  # Remove client files
  rm -f "${WG_CLIENT_DIR}/${name}.conf" "${WG_CLIENT_DIR}/${name}.png"
  remove_from_peer_db "$name" "$interface"

  log "Removed peer '${name}' completely"
}

cmd_list_peers() {
  local interface=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --interface) interface="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$interface" ]] && interface="wg0"

  echo -e "${BOLD}Peers on ${interface}:${NC}"
  echo ""

  if ! wg show "$interface" &>/dev/null; then
    warn "Interface ${interface} is not running. Showing config data only."
    if [ -f "$WG_PEER_DB" ]; then
      jq -r --arg iface "$interface" '.peers[] | select(.interface == $iface) | "\(.name)\t\(.address)\t\(.public_key[:20])...\t\(.created_at)"' "$WG_PEER_DB" | \
        column -t -s $'\t' -N "Name,Address,Public Key,Created"
    fi
    return
  fi

  # Get live data
  printf "%-15s %-20s %-18s %-15s %s\n" "Name" "Public Key" "IP Address" "Last Handshake" "Transfer"
  printf "%-15s %-20s %-18s %-15s %s\n" "───────────" "──────────────────" "──────────────" "──────────────" "────────────────"

  wg show "$interface" dump | tail -n +2 | while IFS=$'\t' read -r pubkey psk endpoint allowed_ips handshake rx tx keepalive; do
    # Look up name from peer db
    local name=$(jq -r --arg pub "$pubkey" '.peers[] | select(.public_key == $pub) | .name' "$WG_PEER_DB" 2>/dev/null || echo "unknown")

    # Format handshake
    local hs_str="never"
    if [[ "$handshake" != "0" ]]; then
      local age=$(( $(date +%s) - handshake ))
      if (( age < 60 )); then hs_str="${age}s ago"
      elif (( age < 3600 )); then hs_str="$((age/60))m ago"
      else hs_str="$((age/3600))h ago"
      fi
    fi

    # Format transfer
    local rx_h=$(numfmt --to=iec "$rx" 2>/dev/null || echo "${rx}B")
    local tx_h=$(numfmt --to=iec "$tx" 2>/dev/null || echo "${tx}B")

    printf "%-15s %-20s %-18s %-15s %s ↓ %s ↑\n" "$name" "${pubkey:0:16}..." "$allowed_ips" "$hs_str" "$rx_h" "$tx_h"
  done
}

cmd_status() {
  local interface=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --interface) interface="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$interface" ]] && interface="wg0"

  echo -e "${BOLD}WireGuard Status: ${interface}${NC}"
  echo ""

  if wg show "$interface" &>/dev/null; then
    echo -e "Status: ${GREEN}UP${NC}"
    echo "Public Key: $(wg show "$interface" public-key)"
    echo "Listen Port: $(wg show "$interface" listen-port)"

    local addr=$(ip addr show "$interface" 2>/dev/null | grep 'inet ' | awk '{print $2}')
    echo "Address: ${addr:-unknown}"

    local peer_count=$(wg show "$interface" peers | wc -l)
    echo "Peers: ${peer_count}"

    local rx_total=0 tx_total=0
    while IFS=$'\t' read -r _ _ _ _ _ rx tx _; do
      rx_total=$((rx_total + rx))
      tx_total=$((tx_total + tx))
    done < <(wg show "$interface" dump | tail -n +2)

    local rx_h=$(numfmt --to=iec "$rx_total" 2>/dev/null || echo "${rx_total}B")
    local tx_h=$(numfmt --to=iec "$tx_total" 2>/dev/null || echo "${tx_total}B")
    echo "Total Transfer: ${rx_h} received, ${tx_h} sent"
  else
    echo -e "Status: ${RED}DOWN${NC}"
    if [ -f "${WG_CONFIG_DIR}/${interface}.conf" ]; then
      echo "Config exists. Start with: wg-quick up ${interface}"
    else
      echo "No config found. Initialize with: bash scripts/wg-manager.sh init-server"
    fi
  fi
}

cmd_qr() {
  local interface="" name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --interface) interface="$2"; shift 2 ;;
      --name)      name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$name" ]] && err "--name is required"

  local client_conf="${WG_CLIENT_DIR}/${name}.conf"
  [[ ! -f "$client_conf" ]] && err "Client config not found: ${client_conf}"

  command -v qrencode &>/dev/null || err "qrencode not installed. Run: apt install qrencode"

  echo -e "${BOLD}QR Code for ${name}:${NC}"
  echo ""
  qrencode -t ansiutf8 < "$client_conf"
  echo ""
  info "Scan this with WireGuard mobile app"
}

cmd_backup() {
  local output=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$output" ]] && output="/tmp/wireguard-backup-$(date +%F).tar.gz"

  tar -czf "$output" -C / etc/wireguard/ 2>/dev/null
  chmod 600 "$output"
  log "Backup saved to ${output}"
  echo "Size: $(du -h "$output" | awk '{print $1}')"
}

cmd_restore() {
  local input=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$input" ]] && err "--input is required"
  [[ ! -f "$input" ]] && err "File not found: $input"

  # Stop all WG interfaces first
  for conf in /etc/wireguard/*.conf; do
    local iface=$(basename "$conf" .conf)
    wg-quick down "$iface" 2>/dev/null || true
  done

  tar -xzf "$input" -C /
  chmod 700 /etc/wireguard
  chmod 600 /etc/wireguard/*.conf 2>/dev/null || true

  # Restart interfaces
  for conf in /etc/wireguard/*.conf; do
    local iface=$(basename "$conf" .conf)
    [[ "$iface" == "peers" ]] && continue
    wg-quick up "$iface" 2>/dev/null && log "Started ${iface}" || warn "Could not start ${iface}"
  done

  log "Restore complete"
}

cmd_site_to_site() {
  local interface="" local_address="" remote_endpoint="" remote_pubkey="" allowed_ips=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --interface)       interface="$2"; shift 2 ;;
      --local-address)   local_address="$2"; shift 2 ;;
      --remote-endpoint) remote_endpoint="$2"; shift 2 ;;
      --remote-pubkey)   remote_pubkey="$2"; shift 2 ;;
      --allowed-ips)     allowed_ips="$2"; shift 2 ;;
      *) err "Unknown: $1" ;;
    esac
  done

  [[ -z "$interface" ]] && interface="wg0"
  [[ -z "$local_address" ]] && err "--local-address required"
  [[ -z "$remote_endpoint" ]] && err "--remote-endpoint required"
  [[ -z "$remote_pubkey" ]] && err "--remote-pubkey required"
  [[ -z "$allowed_ips" ]] && allowed_ips="10.0.0.0/24"

  local keypair=$(generate_keypair)
  local privkey=$(echo "$keypair" | cut -d'|' -f1)
  local pubkey=$(echo "$keypair" | cut -d'|' -f2)

  local conf_file="${WG_CONFIG_DIR}/${interface}.conf"

  cat > "$conf_file" << EOF
[Interface]
PrivateKey = ${privkey}
Address = ${local_address}

[Peer]
PublicKey = ${remote_pubkey}
Endpoint = ${remote_endpoint}
AllowedIPs = ${allowed_ips}
PersistentKeepalive = 25
EOF

  chmod 600 "$conf_file"
  log "Site-to-site config created: ${conf_file}"
  echo -e "${BOLD}Local public key:${NC} ${pubkey}"
  echo "(Add this to the remote server's peer config)"

  wg-quick up "$interface" 2>/dev/null && log "Started ${interface}" || warn "Start manually: wg-quick up ${interface}"
}

cmd_enable_boot() {
  local interface=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --interface) interface="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$interface" ]] && interface="wg0"

  systemctl enable wg-quick@${interface}
  log "Enabled ${interface} on boot (systemd)"
}

# ─── Main ─────────────────────────────────────────────────────────────
cmd_help() {
  echo "WireGuard VPN Manager"
  echo ""
  echo "Usage: bash wg-manager.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  init-server    Initialize a WireGuard VPN server"
  echo "  add-peer       Add a client peer"
  echo "  remove-peer    Remove a peer"
  echo "  list-peers     List all peers with stats"
  echo "  status         Show interface status"
  echo "  qr             Show QR code for a peer"
  echo "  site-to-site   Configure site-to-site tunnel"
  echo "  backup         Backup all WireGuard configs"
  echo "  restore        Restore from backup"
  echo "  enable-boot    Enable auto-start on boot"
  echo ""
  echo "Examples:"
  echo "  bash wg-manager.sh init-server --endpoint 1.2.3.4"
  echo "  bash wg-manager.sh add-peer --name laptop --dns 1.1.1.1"
  echo "  bash wg-manager.sh list-peers"
  echo "  bash wg-manager.sh qr --name phone"
}

main() {
  check_root
  check_wg

  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    init-server)  cmd_init_server "$@" ;;
    add-peer)     cmd_add_peer "$@" ;;
    remove-peer)  cmd_remove_peer "$@" ;;
    regen-peer)   cmd_remove_peer "$@"; cmd_add_peer "$@" ;;
    list-peers)   cmd_list_peers "$@" ;;
    status)       cmd_status "$@" ;;
    qr)           cmd_qr "$@" ;;
    site-to-site) cmd_site_to_site "$@" ;;
    backup)       cmd_backup "$@" ;;
    restore)      cmd_restore "$@" ;;
    enable-boot)  cmd_enable_boot "$@" ;;
    ping-peer)    info "Use: ping <peer-ip> to test connectivity" ;;
    help|--help)  cmd_help ;;
    *)            err "Unknown command: $cmd. Run: bash wg-manager.sh help" ;;
  esac
}

main "$@"
