#!/bin/bash
# Network Scanner — Discover and monitor devices on your local network
# Requires: nmap, arp-scan, jq, curl (for alerts)
# Usage: sudo bash scan.sh [options]

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
NETWORK="${SCAN_NETWORK:-}"
DATA_DIR="${SCAN_DATA_DIR:-$HOME/.network-scanner}"
OUTPUT_FORMAT="table"
MONITOR_MODE=false
SAVE_BASELINE=false
SCAN_PORTS=false
FAST_MODE=false
ALERT_TYPE=""
WEBHOOK_URL=""
NETWORKS=()

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Parse Arguments ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --network) NETWORKS+=("$2"); shift 2 ;;
    --output) OUTPUT_FORMAT="$2"; shift 2 ;;
    --monitor) MONITOR_MODE=true; shift ;;
    --save-baseline) SAVE_BASELINE=true; shift ;;
    --ports) SCAN_PORTS=true; shift ;;
    --fast) FAST_MODE=true; shift ;;
    --alert) ALERT_TYPE="$2"; shift 2 ;;
    --webhook-url) WEBHOOK_URL="$2"; shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: sudo bash scan.sh [options]"
      echo ""
      echo "Options:"
      echo "  --network CIDR       Network to scan (e.g., 192.168.1.0/24). Repeatable."
      echo "  --output FORMAT      Output: table, json, csv (default: table)"
      echo "  --monitor            Compare against baseline, alert on new devices"
      echo "  --save-baseline      Save current scan as baseline"
      echo "  --ports              Also scan top 100 ports on discovered devices"
      echo "  --fast               Use aggressive timing for large networks"
      echo "  --alert TYPE         Alert type: telegram, webhook"
      echo "  --webhook-url URL    Webhook URL for alerts"
      echo "  --data-dir DIR       Data directory (default: ~/.network-scanner)"
      echo "  -h, --help           Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Setup ───────────────────────────────────────────────────────────────────
mkdir -p "$DATA_DIR/logs"

# Check dependencies
for cmd in nmap jq curl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${RED}Error: $cmd is not installed.${NC}"
    echo "Install with: sudo apt-get install -y $cmd"
    exit 1
  fi
done

HAS_ARPSCAN=true
if ! command -v arp-scan &>/dev/null; then
  HAS_ARPSCAN=false
  echo -e "${YELLOW}Warning: arp-scan not found. Using nmap only (less complete results).${NC}"
fi

# ─── Auto-detect network ────────────────────────────────────────────────────
auto_detect_network() {
  # Get default gateway interface and network
  local iface gateway network_addr
  
  if command -v ip &>/dev/null; then
    iface=$(ip route | grep default | head -1 | awk '{print $5}')
    network_addr=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d.]+/\d+' | head -1)
    if [[ -n "$network_addr" ]]; then
      # Convert to network address (e.g., 192.168.1.15/24 → 192.168.1.0/24)
      local ip_part prefix
      ip_part=$(echo "$network_addr" | cut -d/ -f1)
      prefix=$(echo "$network_addr" | cut -d/ -f2)
      local IFS='.'
      read -ra octets <<< "$ip_part"
      if [[ "$prefix" == "24" ]]; then
        echo "${octets[0]}.${octets[1]}.${octets[2]}.0/24"
      elif [[ "$prefix" == "16" ]]; then
        echo "${octets[0]}.${octets[1]}.0.0/16"
      else
        echo "${octets[0]}.${octets[1]}.${octets[2]}.0/24"
      fi
      return
    fi
  fi
  
  # Fallback: try route command (macOS)
  if command -v route &>/dev/null; then
    gateway=$(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')
    if [[ -n "$gateway" ]]; then
      local IFS='.'
      read -ra octets <<< "$gateway"
      echo "${octets[0]}.${octets[1]}.${octets[2]}.0/24"
      return
    fi
  fi
  
  echo "192.168.1.0/24"
}

if [[ ${#NETWORKS[@]} -eq 0 ]]; then
  if [[ -n "$NETWORK" ]]; then
    NETWORKS+=("$NETWORK")
  else
    detected=$(auto_detect_network)
    NETWORKS+=("$detected")
    echo -e "${CYAN}Auto-detected network: $detected${NC}"
  fi
fi

# ─── Scan Functions ──────────────────────────────────────────────────────────

scan_network() {
  local network="$1"
  local timestamp
  timestamp=$(date -u '+%Y-%m-%d %H:%M:%S')
  local results_file
  results_file=$(mktemp)
  
  echo -e "[${timestamp}] ${BLUE}🔍 Scanning ${network}...${NC}" >&2
  
  local nmap_timing="-T4"
  [[ "$FAST_MODE" == true ]] && nmap_timing="-T5"
  
  # Phase 1: ARP scan (if available — fastest, most reliable for local)
  local arp_results
  arp_results=$(mktemp)
  if [[ "$HAS_ARPSCAN" == true ]]; then
    arp-scan "$network" 2>/dev/null | grep -E '^[0-9]+\.' | awk '{print $1"\t"$2"\t"$3" "$4" "$5" "$6}' > "$arp_results" || true
  fi
  
  # Phase 2: Nmap ping sweep + vendor lookup
  local nmap_results
  nmap_results=$(mktemp)
  nmap -sn $nmap_timing "$network" -oG - 2>/dev/null | grep "Host:" | while read -r line; do
    local ip host_info
    ip=$(echo "$line" | grep -oP '\d+\.\d+\.\d+\.\d+')
    echo "$ip"
  done > "$nmap_results"
  
  # Phase 3: Merge results and enrich
  local all_ips
  all_ips=$(mktemp)
  
  # Combine IPs from both sources
  { cat "$arp_results" | awk '{print $1}'; cat "$nmap_results"; } | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | uniq > "$all_ips"
  
  # Build JSON results
  echo "[" > "$results_file"
  local first=true
  
  while IFS= read -r ip; do
    [[ -z "$ip" ]] && continue
    
    # Get MAC from arp-scan results or ARP table
    local mac=""
    if [[ "$HAS_ARPSCAN" == true ]]; then
      mac=$(grep "^$ip" "$arp_results" 2>/dev/null | awk '{print $2}' | head -1)
    fi
    if [[ -z "$mac" ]]; then
      mac=$(arp -n "$ip" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1 || true)
    fi
    [[ -z "$mac" ]] && mac="unknown"
    
    # Get vendor from MAC
    local vendor="Unknown"
    if [[ "$mac" != "unknown" ]]; then
      local mac_prefix
      mac_prefix=$(echo "$mac" | tr '[:lower:]' '[:upper:]' | cut -d: -f1-3 | tr ':' '-')
      vendor=$(grep -i "^$mac_prefix" /usr/share/nmap/nmap-mac-prefixes 2>/dev/null | cut -d' ' -f2- || echo "Unknown")
      [[ -z "$vendor" ]] && vendor="Unknown"
    fi
    
    # Get hostname
    local hostname=""
    hostname=$(nmap -sn "$ip" 2>/dev/null | grep "Nmap scan report" | sed 's/Nmap scan report for //' | grep -oP '^[^\s(]+' | head -1 || true)
    [[ "$hostname" == "$ip" ]] && hostname=""
    
    # Port scan if requested
    local ports=""
    if [[ "$SCAN_PORTS" == true ]]; then
      ports=$(nmap --top-ports 100 -T4 "$ip" 2>/dev/null | grep "^[0-9]" | grep "open" | awk '{printf "%s(%s), ", $1, $3}' | sed 's/, $//')
    fi
    
    [[ "$first" == true ]] && first=false || echo "," >> "$results_file"
    
    cat >> "$results_file" <<EOF
  {
    "ip": "$ip",
    "mac": "$mac",
    "vendor": "$vendor",
    "hostname": "$hostname",
    "ports": "$ports",
    "scanned_at": "$timestamp",
    "network": "$network"
  }
EOF
  done < "$all_ips"
  
  echo "]" >> "$results_file"
  
  # Cleanup
  rm -f "$arp_results" "$nmap_results" "$all_ips"
  
  local count
  count=$(jq length "$results_file")
  echo -e "[${timestamp}] ${GREEN}✅ Found ${count} devices${NC}" >&2
  
  cat "$results_file"
  rm -f "$results_file"
}

# ─── Output Formatters ──────────────────────────────────────────────────────

format_table() {
  local json="$1"
  printf "\n%-17s %-19s %-20s %-20s" "IP" "MAC" "Vendor" "Hostname"
  [[ "$SCAN_PORTS" == true ]] && printf " %-30s" "Ports"
  printf "\n"
  printf "%-17s %-19s %-20s %-20s" "─────────────────" "─────────────────" "────────────────────" "────────────────────"
  [[ "$SCAN_PORTS" == true ]] && printf " %-30s" "──────────────────────────────"
  printf "\n"
  
  echo "$json" | jq -r '.[] | [.ip, .mac, .vendor, .hostname, .ports] | @tsv' | while IFS=$'\t' read -r ip mac vendor hostname ports; do
    [[ -z "$hostname" ]] && hostname="—"
    vendor=$(echo "$vendor" | cut -c1-18)
    hostname=$(echo "$hostname" | cut -c1-18)
    printf "%-17s %-19s %-20s %-20s" "$ip" "$mac" "$vendor" "$hostname"
    [[ "$SCAN_PORTS" == true ]] && printf " %-30s" "${ports:-—}"
    printf "\n"
  done
  
  local count
  count=$(echo "$json" | jq length)
  echo ""
  echo "Found: $count devices"
}

format_csv() {
  local json="$1"
  echo "ip,mac,vendor,hostname,ports,scanned_at"
  echo "$json" | jq -r '.[] | [.ip, .mac, .vendor, .hostname, .ports, .scanned_at] | @csv'
}

# ─── Monitor / Baseline ─────────────────────────────────────────────────────

BASELINE_FILE="$DATA_DIR/known-devices.json"
SEEN_FILE="$DATA_DIR/seen-devices.json"

save_baseline() {
  local json="$1"
  echo "$json" | jq '[.[] | {mac: .mac, ip: .ip, vendor: .vendor, hostname: .hostname, label: "", trusted: false, first_seen: .scanned_at}]' > "$BASELINE_FILE"
  echo -e "${GREEN}✅ Baseline saved to $BASELINE_FILE with $(echo "$json" | jq length) devices${NC}"
  echo -e "${YELLOW}Edit $BASELINE_FILE to label devices and mark trusted ones.${NC}"
}

check_new_devices() {
  local json="$1"
  
  if [[ ! -f "$BASELINE_FILE" ]]; then
    echo -e "${YELLOW}No baseline found. Saving current scan as baseline.${NC}"
    save_baseline "$json"
    return
  fi
  
  # Load seen devices (to avoid re-alerting)
  [[ ! -f "$SEEN_FILE" ]] && echo "[]" > "$SEEN_FILE"
  
  local known_macs seen_macs
  known_macs=$(jq -r '.[].mac' "$BASELINE_FILE" | sort)
  seen_macs=$(jq -r '.[].mac' "$SEEN_FILE" | sort)
  
  local new_devices=()
  
  while read -r device_json; do
    local mac
    mac=$(echo "$device_json" | jq -r '.mac')
    [[ "$mac" == "unknown" ]] && continue
    
    # Check if in baseline
    if ! echo "$known_macs" | grep -qFx "$mac"; then
      # Check if already seen (don't re-alert)
      if ! echo "$seen_macs" | grep -qFx "$mac"; then
        new_devices+=("$device_json")
        # Add to seen
        local tmp
        tmp=$(mktemp)
        jq --argjson dev "$device_json" '. += [$dev]' "$SEEN_FILE" > "$tmp" && mv "$tmp" "$SEEN_FILE"
      fi
    fi
  done < <(echo "$json" | jq -c '.[]')
  
  if [[ ${#new_devices[@]} -eq 0 ]]; then
    echo -e "${GREEN}✅ No new unknown devices detected.${NC}"
    return
  fi
  
  echo -e "${RED}🆕 ${#new_devices[@]} NEW DEVICE(S) DETECTED:${NC}"
  local alert_msg="🆕 New device(s) on network:\n"
  
  for dev in "${new_devices[@]}"; do
    local ip mac vendor
    ip=$(echo "$dev" | jq -r '.ip')
    mac=$(echo "$dev" | jq -r '.mac')
    vendor=$(echo "$dev" | jq -r '.vendor')
    echo -e "  ${RED}→${NC} $ip ($mac) — $vendor"
    alert_msg+="• $ip ($mac) — $vendor\n"
  done
  
  # Send alerts
  if [[ "$ALERT_TYPE" == "telegram" ]]; then
    send_telegram_alert "$alert_msg"
  elif [[ "$ALERT_TYPE" == "webhook" ]]; then
    send_webhook_alert "$alert_msg"
  fi
}

# ─── Alert Functions ─────────────────────────────────────────────────────────

send_telegram_alert() {
  local message="$1"
  local token="${TELEGRAM_BOT_TOKEN:-}"
  local chat_id="${TELEGRAM_CHAT_ID:-}"
  
  if [[ -z "$token" || -z "$chat_id" ]]; then
    echo -e "${YELLOW}Warning: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set. Skipping alert.${NC}"
    return
  fi
  
  curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d "chat_id=${chat_id}" \
    -d "text=$(echo -e "$message")" \
    -d "parse_mode=HTML" > /dev/null 2>&1
  
  echo -e "${GREEN}📨 Telegram alert sent.${NC}"
}

send_webhook_alert() {
  local message="$1"
  local url="${WEBHOOK_URL:-}"
  
  if [[ -z "$url" ]]; then
    echo -e "${YELLOW}Warning: --webhook-url not set. Skipping alert.${NC}"
    return
  fi
  
  curl -s -X POST "$url" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"$(echo -e "$message")\"}" > /dev/null 2>&1
  
  echo -e "${GREEN}📨 Webhook alert sent.${NC}"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
  # Check root
  if [[ $EUID -ne 0 ]] && [[ "$HAS_ARPSCAN" == true ]]; then
    echo -e "${YELLOW}Warning: Running without root. ARP scan may be incomplete.${NC}"
    echo -e "${YELLOW}Run with: sudo bash scan.sh${NC}"
  fi
  
  local all_results="[]"
  
  for net in "${NETWORKS[@]}"; do
    local result
    result=$(scan_network "$net")
    all_results=$(echo "$all_results" "$result" | jq -s '.[0] + .[1]')
  done
  
  # Save baseline if requested
  if [[ "$SAVE_BASELINE" == true ]]; then
    save_baseline "$all_results"
    return
  fi
  
  # Monitor mode
  if [[ "$MONITOR_MODE" == true ]]; then
    check_new_devices "$all_results"
  fi
  
  # Output
  case "$OUTPUT_FORMAT" in
    json) echo "$all_results" | jq . ;;
    csv) format_csv "$all_results" ;;
    table) format_table "$all_results" ;;
    *) echo "Unknown format: $OUTPUT_FORMAT"; exit 1 ;;
  esac
  
  # Log
  local logfile="$DATA_DIR/logs/scan-$(date -u '+%Y-%m-%d').log"
  local count
  count=$(echo "$all_results" | jq length)
  echo "[$(date -u '+%Y-%m-%d %H:%M:%S')] Scanned ${NETWORKS[*]} — $count devices found" >> "$logfile"
}

main
