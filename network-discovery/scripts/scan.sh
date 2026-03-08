#!/bin/bash
# Network Device Discovery — Main Scanner
# Requires: arp-scan, jq, curl (for alerts), nmap (for deep scan)
set -euo pipefail

# --- Config ---
DATA_DIR="${NETDISC_DATA_DIR:-$HOME/.network-discovery}"
KNOWN_FILE="$DATA_DIR/known-devices.json"
SCANS_DIR="$DATA_DIR/scans"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SCAN_FILE="$SCANS_DIR/$(date -u +%Y%m%d-%H%M%S).json"

# --- Defaults ---
SUBNET=""
ALERT=""
DEEP=false
WATCH=false
INTERVAL=300
OUTPUT="table"

# --- Parse Args ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --subnet) SUBNET="$2"; shift 2 ;;
    --alert) ALERT="$2"; shift 2 ;;
    --deep) DEEP=true; shift ;;
    --watch) WATCH=true; shift ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: sudo bash scan.sh [OPTIONS]"
      echo "  --subnet CIDR    Subnet to scan (auto-detected if omitted)"
      echo "  --alert telegram  Send alerts for new devices"
      echo "  --deep            Enable port scanning via nmap"
      echo "  --watch           Continuous monitoring mode"
      echo "  --interval SEC    Seconds between scans (default: 300)"
      echo "  --output FORMAT   Output format: table, json, csv"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Init ---
mkdir -p "$SCANS_DIR"
[[ -f "$KNOWN_FILE" ]] || echo '[]' > "$KNOWN_FILE"

# --- Auto-detect subnet ---
detect_subnet() {
  # Try ip route first, fall back to ifconfig
  if command -v ip &>/dev/null; then
    ip -4 route show default 2>/dev/null | awk '{print $3}' | head -1 | sed 's/\.[0-9]*$/.0\/24/'
  elif command -v ifconfig &>/dev/null; then
    ifconfig | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | sed 's/\.[0-9]*$/.0\/24/'
  else
    echo ""
  fi
}

if [[ -z "$SUBNET" ]]; then
  SUBNET=$(detect_subnet)
  if [[ -z "$SUBNET" ]]; then
    echo "❌ Could not auto-detect subnet. Use --subnet 192.168.1.0/24"
    exit 1
  fi
fi

# --- Dependency check ---
for cmd in arp-scan jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Required tool '$cmd' not found. Install it first."
    exit 1
  fi
done

if [[ "$DEEP" == true ]] && ! command -v nmap &>/dev/null; then
  echo "❌ Deep scan requires 'nmap'. Install it or remove --deep."
  exit 1
fi

# --- Send Telegram alert ---
send_telegram() {
  local msg="$1"
  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    echo "⚠️  Telegram credentials not set (TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID)"
    return 1
  fi
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="$msg" \
    -d parse_mode="Markdown" > /dev/null 2>&1
}

# --- Run single scan ---
run_scan() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔍 Scanning $SUBNET..."

  # Run arp-scan
  local raw
  raw=$(arp-scan --localnet --interface="$(ip -4 route show default 2>/dev/null | awk '{print $5}' | head -1)" "$SUBNET" 2>/dev/null || arp-scan "$SUBNET" 2>/dev/null || true)

  # Parse results into JSON
  local devices='[]'
  while IFS=$'\t' read -r ip mac vendor; do
    # Skip header/footer lines
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
    
    local ports="[]"
    if [[ "$DEEP" == true ]]; then
      # Quick nmap scan for common ports
      local nmap_out
      nmap_out=$(nmap -F --open -T4 "$ip" 2>/dev/null | grep '^[0-9]' || true)
      if [[ -n "$nmap_out" ]]; then
        ports=$(echo "$nmap_out" | awk '{print $1}' | jq -R -s 'split("\n") | map(select(length > 0))')
      fi
    fi

    devices=$(echo "$devices" | jq --arg ip "$ip" --arg mac "$mac" --arg vendor "$vendor" --argjson ports "$ports" \
      '. += [{"ip": $ip, "mac": ($mac | ascii_downcase), "vendor": $vendor, "ports": $ports}]')
  done <<< "$raw"

  local count
  count=$(echo "$devices" | jq 'length')
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Found $count devices"

  # Save scan
  echo "$devices" | jq --arg ts "$TIMESTAMP" --arg subnet "$SUBNET" \
    '{timestamp: $ts, subnet: $subnet, device_count: (. | length), devices: .}' > "$SCAN_FILE"

  # Load known devices
  local known
  known=$(cat "$KNOWN_FILE")

  # Check for new devices
  local new_devices='[]'
  local all_macs
  all_macs=$(echo "$devices" | jq -r '.[].mac')

  while read -r mac; do
    [[ -z "$mac" ]] && continue
    local is_known
    is_known=$(echo "$known" | jq --arg m "$mac" '[.[] | select(.mac == $m)] | length')
    if [[ "$is_known" == "0" ]]; then
      local dev_info
      dev_info=$(echo "$devices" | jq --arg m "$mac" '[.[] | select(.mac == $m)][0]')
      new_devices=$(echo "$new_devices" | jq --argjson d "$dev_info" '. += [$d]')
    fi
  done <<< "$all_macs"

  local new_count
  new_count=$(echo "$new_devices" | jq 'length')

  # --- Output ---
  case "$OUTPUT" in
    json)
      echo "$devices" | jq .
      ;;
    csv)
      echo "ip,mac,vendor"
      echo "$devices" | jq -r '.[] | [.ip, .mac, .vendor] | @csv'
      ;;
    table|*)
      printf "\n%-18s %-20s %-25s %s\n" "IP Address" "MAC Address" "Manufacturer" "Status"
      printf "%-18s %-20s %-25s %s\n" "----------" "-----------" "------------" "------"
      echo "$devices" | jq -r '.[] | [.ip, .mac, .vendor] | @tsv' | while IFS=$'\t' read -r ip mac vendor; do
        local is_known
        is_known=$(echo "$known" | jq --arg m "$mac" '[.[] | select(.mac == $m)] | length')
        local status="✅ Known"
        if [[ "$is_known" == "0" ]]; then
          status="⚠️  NEW"
        fi
        printf "%-18s %-20s %-25s %s\n" "$ip" "$mac" "${vendor:0:25}" "$status"
      done
      echo ""
      ;;
  esac

  # --- Alerts ---
  if [[ "$new_count" -gt 0 && "$ALERT" == "telegram" ]]; then
    local alert_msg="🔍 *Network Discovery Alert*\n\n"
    alert_msg+="Found *$new_count* new device(s) on \`$SUBNET\`:\n\n"
    echo "$new_devices" | jq -r '.[] | "• \(.ip) — \(.mac)\n  Vendor: \(.vendor)"' | while read -r line; do
      alert_msg+="$line\n"
    done
    alert_msg+="\nUse \`manage.sh add <mac> <name>\` to mark as known."
    send_telegram "$alert_msg"
    echo "📱 Alert sent to Telegram ($new_count new device(s))"
  elif [[ "$new_count" -gt 0 ]]; then
    echo "⚠️  $new_count new/unknown device(s) detected"
  fi

  # --- Diff with previous scan ---
  local prev_scan
  prev_scan=$(ls -1t "$SCANS_DIR"/*.json 2>/dev/null | sed -n '2p')
  if [[ -n "$prev_scan" ]]; then
    local prev_macs cur_macs
    prev_macs=$(jq -r '.devices[].mac' "$prev_scan" 2>/dev/null | sort)
    cur_macs=$(echo "$devices" | jq -r '.[].mac' | sort)

    local gone
    gone=$(comm -23 <(echo "$prev_macs") <(echo "$cur_macs"))
    if [[ -n "$gone" ]]; then
      echo "📤 Devices no longer seen:"
      echo "$gone" | while read -r mac; do
        local name
        name=$(echo "$known" | jq -r --arg m "$mac" '.[] | select(.mac == $m) | .name // "(unknown)"')
        echo "   ➖ $mac ($name)"
      done
    fi
  fi
}

# --- Main ---
if [[ "$WATCH" == true ]]; then
  echo "👁️  Watching network (interval: ${INTERVAL}s). Ctrl+C to stop."
  while true; do
    SCAN_FILE="$SCANS_DIR/$(date -u +%Y%m%d-%H%M%S).json"
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    run_scan
    echo "---"
    sleep "$INTERVAL"
  done
else
  run_scan
fi
