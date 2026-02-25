#!/usr/bin/env bash
# Wake-on-LAN Manager — Send magic packets to wake remote machines
# Supports: wakeonlan, etherwake, python, pure-bash /dev/udp fallback
set -euo pipefail

VERSION="1.0.0"
CONFIG_DIR="${WOL_CONFIG_DIR:-$HOME/.config/wol}"
DEVICES_FILE="$CONFIG_DIR/devices.json"
DEFAULT_BROADCAST="${WOL_BROADCAST:-255.255.255.255}"
DEFAULT_PORT="${WOL_PORT:-9}"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# --- Helpers ---

log()  { echo "$LOG_PREFIX $*"; }
err()  { echo "$LOG_PREFIX ❌ $*" >&2; }
ok()   { echo "$LOG_PREFIX ✅ $*"; }
info() { echo "$LOG_PREFIX ℹ️  $*"; }

ensure_config_dir() {
  mkdir -p "$CONFIG_DIR"
  if [ ! -f "$DEVICES_FILE" ]; then
    echo '{"devices":[]}' > "$DEVICES_FILE"
  fi
}

normalize_mac() {
  # Accept AA:BB:CC:DD:EE:FF or AA-BB-CC-DD-EE-FF or AABBCCDDEEFF
  local mac
  mac=$(echo "$1" | tr '[:lower:]' '[:upper:]' | tr -d ':-')
  if [ ${#mac} -ne 12 ]; then
    err "Invalid MAC address: $1"
    return 1
  fi
  echo "${mac:0:2}:${mac:2:2}:${mac:4:2}:${mac:6:2}:${mac:8:2}:${mac:10:2}"
}

# --- Magic Packet Senders ---

send_wakeonlan() {
  local mac="$1" broadcast="$2" port="$3"
  if command -v wakeonlan &>/dev/null; then
    wakeonlan -i "$broadcast" -p "$port" "$mac" &>/dev/null
    return 0
  fi
  return 1
}

send_etherwake() {
  local mac="$1"
  if command -v etherwake &>/dev/null; then
    sudo etherwake "$mac" 2>/dev/null
    return 0
  fi
  return 1
}

send_python() {
  local mac="$1" broadcast="$2" port="$3"
  if command -v python3 &>/dev/null; then
    python3 -c "
import socket, struct, binascii
mac = '$mac'.replace(':','')
data = b'\\xff' * 6 + binascii.unhexlify(mac) * 16
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
s.sendto(data, ('$broadcast', $port))
s.close()
" 2>/dev/null
    return 0
  fi
  return 1
}

send_bash_udp() {
  local mac="$1" broadcast="$2" port="$3"
  # Build magic packet: 6x FF + 16x MAC
  local clean_mac
  clean_mac=$(echo "$mac" | tr -d ':')
  local payload
  payload=$(printf 'ff%.0s' {1..6})
  for _ in {1..16}; do
    payload="${payload}${clean_mac}"
  done
  # Convert hex to binary and send via /dev/udp
  local binary
  binary=$(echo "$payload" | sed 's/../\\x&/g')
  (echo -ne "$binary" > /dev/udp/"$broadcast"/"$port") 2>/dev/null
  return $?
}

send_magic_packet() {
  local mac="$1" broadcast="${2:-$DEFAULT_BROADCAST}" port="${3:-$DEFAULT_PORT}"

  log "🔌 Sending magic packet to $mac ..."

  if send_wakeonlan "$mac" "$broadcast" "$port"; then
    ok "Magic packet sent to $mac (wakeonlan → $broadcast:$port)"
  elif send_etherwake "$mac"; then
    ok "Magic packet sent to $mac (etherwake)"
  elif send_python "$mac" "$broadcast" "$port"; then
    ok "Magic packet sent to $mac (python3 → $broadcast:$port)"
  elif send_bash_udp "$mac" "$broadcast" "$port"; then
    ok "Magic packet sent to $mac (bash/udp → $broadcast:$port)"
  else
    err "No WoL method available. Install: wakeonlan, etherwake, or python3"
    return 1
  fi
}

wait_for_host() {
  local ip="$1" timeout="${2:-120}"
  info "Waiting for $ip to come online (timeout: ${timeout}s)..."
  local start elapsed
  start=$(date +%s)
  while true; do
    if ping -c 1 -W 1 "$ip" &>/dev/null; then
      elapsed=$(( $(date +%s) - start ))
      ok "$ip is ONLINE (took ${elapsed}s)"
      return 0
    fi
    elapsed=$(( $(date +%s) - start ))
    if [ "$elapsed" -ge "$timeout" ]; then
      err "$ip did not come online within ${timeout}s"
      return 1
    fi
    sleep 2
  done
}

# --- Device Registry ---

get_device_field() {
  local name="$1" field="$2"
  if command -v jq &>/dev/null; then
    jq -r --arg n "$name" ".devices[] | select(.name == \$n) | .$field // empty" "$DEVICES_FILE"
  else
    # Simple grep fallback
    grep -A5 "\"name\":.*\"$name\"" "$DEVICES_FILE" | grep "\"$field\"" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/'
  fi
}

cmd_add() {
  local name="" mac="" ip="" broadcast="$DEFAULT_BROADCAST" port="$DEFAULT_PORT" desc=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --mac)  mac="$2"; shift 2 ;;
      --ip)   ip="$2"; shift 2 ;;
      --broadcast) broadcast="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --desc) desc="$2"; shift 2 ;;
      *) err "Unknown option: $1"; return 1 ;;
    esac
  done

  [ -z "$name" ] && { err "Missing --name"; return 1; }
  [ -z "$mac" ]  && { err "Missing --mac"; return 1; }

  mac=$(normalize_mac "$mac") || return 1
  ensure_config_dir

  if command -v jq &>/dev/null; then
    local tmp
    tmp=$(jq --arg n "$name" --arg m "$mac" --arg i "$ip" --arg b "$broadcast" \
             --argjson p "$port" --arg d "$desc" \
             '.devices = [.devices[] | select(.name != $n)] + [{name:$n,mac:$m,ip:$i,broadcast:$b,port:$p,description:$d}]' \
             "$DEVICES_FILE")
    echo "$tmp" > "$DEVICES_FILE"
  else
    err "jq required for device registry management"
    return 1
  fi

  ok "Added device '$name' ($mac)"
}

cmd_remove() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$name" ] && { err "Missing --name"; return 1; }
  ensure_config_dir

  if command -v jq &>/dev/null; then
    local tmp
    tmp=$(jq --arg n "$name" '.devices = [.devices[] | select(.name != $n)]' "$DEVICES_FILE")
    echo "$tmp" > "$DEVICES_FILE"
    ok "Removed device '$name'"
  else
    err "jq required"; return 1
  fi
}

cmd_list() {
  ensure_config_dir
  if command -v jq &>/dev/null; then
    local count
    count=$(jq '.devices | length' "$DEVICES_FILE")
    if [ "$count" -eq 0 ]; then
      info "No devices registered. Use: $0 add --name <name> --mac <mac> [--ip <ip>]"
      return 0
    fi
    printf "%-15s %-19s %-16s %-10s %s\n" "NAME" "MAC" "IP" "STATUS" "DESCRIPTION"
    printf "%-15s %-19s %-16s %-10s %s\n" "----" "---" "--" "------" "-----------"
    jq -r '.devices[] | "\(.name)|\(.mac)|\(.ip // "-")|\(.description // "-")"' "$DEVICES_FILE" | \
    while IFS='|' read -r n m i d; do
      local status="unknown"
      if [ "$i" != "-" ] && [ -n "$i" ]; then
        if ping -c 1 -W 1 "$i" &>/dev/null 2>&1; then
          status="online"
        else
          status="offline"
        fi
      fi
      printf "%-15s %-19s %-16s %-10s %s\n" "$n" "$m" "$i" "$status" "$d"
    done
  else
    cat "$DEVICES_FILE"
  fi
}

cmd_status() {
  cmd_list
}

cmd_wake() {
  local names=() mac="" ip="" broadcast="" port="" wait_timeout=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) names+=("$2"); shift 2 ;;
      --mac)  mac="$2"; shift 2 ;;
      --ip)   ip="$2"; shift 2 ;;
      --broadcast) broadcast="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --wait) wait_timeout="$2"; shift 2 ;;
      *) err "Unknown option: $1"; return 1 ;;
    esac
  done

  # Wake by MAC directly
  if [ -n "$mac" ]; then
    mac=$(normalize_mac "$mac") || return 1
    send_magic_packet "$mac" "${broadcast:-$DEFAULT_BROADCAST}" "${port:-$DEFAULT_PORT}"
    if [ -n "$ip" ] && [ -n "$wait_timeout" ]; then
      wait_for_host "$ip" "$wait_timeout"
    fi
    return $?
  fi

  # Wake by name(s) from registry
  if [ ${#names[@]} -eq 0 ]; then
    err "Specify --mac <address> or --name <device>"
    return 1
  fi

  ensure_config_dir
  local failures=0
  for name in "${names[@]}"; do
    local dev_mac dev_ip dev_broadcast dev_port
    dev_mac=$(get_device_field "$name" "mac")
    dev_ip=$(get_device_field "$name" "ip")
    dev_broadcast=$(get_device_field "$name" "broadcast")
    dev_port=$(get_device_field "$name" "port")

    if [ -z "$dev_mac" ]; then
      err "Device '$name' not found in registry"
      ((failures++))
      continue
    fi

    send_magic_packet "$dev_mac" "${broadcast:-${dev_broadcast:-$DEFAULT_BROADCAST}}" "${port:-${dev_port:-$DEFAULT_PORT}}"

    if [ -n "$dev_ip" ] && [ -n "$wait_timeout" ]; then
      wait_for_host "$dev_ip" "$wait_timeout" || ((failures++))
    fi
  done

  return $failures
}

cmd_wake_all() {
  ensure_config_dir
  if ! command -v jq &>/dev/null; then
    err "jq required for wake-all"; return 1
  fi

  local count
  count=$(jq '.devices | length' "$DEVICES_FILE")
  if [ "$count" -eq 0 ]; then
    info "No devices registered."
    return 0
  fi

  info "Waking all $count registered devices..."
  jq -r '.devices[] | "\(.mac)|\(.broadcast // "255.255.255.255")|\(.port // 9)"' "$DEVICES_FILE" | \
  while IFS='|' read -r m b p; do
    send_magic_packet "$m" "$b" "$p"
  done
}

# --- Main ---

usage() {
  cat <<EOF
Wake-on-LAN Manager v$VERSION

USAGE:
  $0 <command> [options]

COMMANDS:
  wake        Send magic packet to wake a machine
  wake-all    Wake all registered devices
  add         Add a device to the registry
  remove      Remove a device from the registry
  list        List all registered devices (with online status)
  status      Same as list
  version     Show version

WAKE OPTIONS:
  --mac <addr>       MAC address (AA:BB:CC:DD:EE:FF)
  --name <name>      Device name from registry (repeatable)
  --ip <addr>        IP address (for verification)
  --broadcast <addr> Broadcast address (default: 255.255.255.255)
  --port <num>       UDP port (default: 9)
  --wait <seconds>   Wait for host to come online after waking

ADD OPTIONS:
  --name <name>      Device name (required)
  --mac <addr>       MAC address (required)
  --ip <addr>        IP address (optional, for ping verification)
  --broadcast <addr> Broadcast address (default: 255.255.255.255)
  --port <num>       UDP port (default: 9)
  --desc <text>      Description (optional)

EXAMPLES:
  $0 wake --mac AA:BB:CC:DD:EE:FF
  $0 wake --mac AA:BB:CC:DD:EE:FF --ip 192.168.1.100 --wait 60
  $0 add --name nas --mac AA:BB:CC:DD:EE:FF --ip 192.168.1.100
  $0 wake --name nas --wait 120
  $0 wake --name server1 --name server2
  $0 wake-all
  $0 list
EOF
}

main() {
  local cmd="${1:-help}"
  shift 2>/dev/null || true

  case "$cmd" in
    wake)     cmd_wake "$@" ;;
    wake-all) cmd_wake_all "$@" ;;
    add)      cmd_add "$@" ;;
    remove)   cmd_remove "$@" ;;
    list)     cmd_list "$@" ;;
    status)   cmd_status "$@" ;;
    version)  echo "Wake-on-LAN Manager v$VERSION" ;;
    help|--help|-h) usage ;;
    *) err "Unknown command: $cmd"; usage; return 1 ;;
  esac
}

main "$@"
