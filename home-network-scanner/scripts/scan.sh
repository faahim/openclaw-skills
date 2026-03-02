#!/usr/bin/env bash
# Home Network Scanner — Discover, track, and alert on network devices
# Requires: nmap, jq, bash 4+, curl (for alerts/vendor lookup)

set -euo pipefail

VERSION="1.0.0"
DATA_DIR="${HOME}/.config/home-network-scanner"
KNOWN_FILE="${DATA_DIR}/known-devices.json"
HISTORY_FILE="${DATA_DIR}/scan-history.json"
CONFIG_FILE="${DATA_DIR}/config.yaml"
LOG_DIR="${DATA_DIR}/logs"

# --- Defaults ---
SUBNET=""
ACTION="scan"
ALERT_METHOD=""
APPROVE_MAC=""
APPROVE_NAME=""
APPROVE_ALL=false
EXPORT_FMT=""
SHOW_PORTS=""
ON_NEW_CMD=""
TCP_PING=false
CRON_INTERVAL=""

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
Home Network Scanner v${VERSION}

Usage: bash scan.sh [OPTIONS]

Scan Options:
  --subnet CIDR       Subnet to scan (default: auto-detect)
  --tcp-ping          Use TCP SYN ping instead of ARP
  --ports PORTS       Also scan these ports (comma-separated)

Device Management:
  --list              List known/approved devices
  --approve MAC       Mark a MAC address as known
  --name NAME         Name for the approved device (use with --approve)
  --approve-all       Approve all currently seen devices
  --history           Show device first/last seen history

Alerts:
  --alert METHOD      Alert on new devices (telegram, webhook, command)
  --on-new CMD        Run custom command on new device

Export:
  --export FORMAT     Export devices (csv, json)
  --vendor            Show device vendor/manufacturer
  --diff              Show changes since last scan

Setup:
  --install-cron MIN  Install cron job (interval in minutes)

General:
  --help              Show this help
  --version           Show version
EOF
}

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --subnet) SUBNET="$2"; shift 2 ;;
    --tcp-ping) TCP_PING=true; shift ;;
    --ports) SHOW_PORTS="$2"; shift 2 ;;
    --list) ACTION="list"; shift ;;
    --approve) APPROVE_MAC="$2"; ACTION="approve"; shift 2 ;;
    --name) APPROVE_NAME="$2"; shift 2 ;;
    --approve-all) APPROVE_ALL=true; ACTION="approve-all"; shift ;;
    --history) ACTION="history"; shift ;;
    --alert) ALERT_METHOD="$2"; shift 2 ;;
    --on-new) ON_NEW_CMD="$2"; shift 2 ;;
    --export) EXPORT_FMT="$2"; ACTION="export"; shift 2 ;;
    --vendor) ACTION="vendor"; shift ;;
    --diff) ACTION="diff"; shift ;;
    --install-cron) CRON_INTERVAL="$2"; ACTION="install-cron"; shift 2 ;;
    --help) usage; exit 0 ;;
    --version) echo "Home Network Scanner v${VERSION}"; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# --- Init data directory ---
init_data() {
  mkdir -p "${DATA_DIR}" "${LOG_DIR}"
  [[ -f "${KNOWN_FILE}" ]] || echo '{"devices":{}}' > "${KNOWN_FILE}"
  [[ -f "${HISTORY_FILE}" ]] || echo '{"scans":[],"devices":{}}' > "${HISTORY_FILE}"
}

# --- Auto-detect subnet ---
detect_subnet() {
  if [[ -n "${NET_SCANNER_SUBNET:-}" ]]; then
    echo "${NET_SCANNER_SUBNET}"
    return
  fi
  # Try ip route first, then route
  if command -v ip &>/dev/null; then
    ip route | grep -oP 'src \K[0-9.]+' | head -1 | sed 's/\.[0-9]*$/.0\/24/'
  elif command -v route &>/dev/null; then
    local gw
    gw=$(route -n get default 2>/dev/null | grep 'interface' | awk '{print $2}')
    ifconfig "$gw" 2>/dev/null | grep -oP 'inet \K[0-9.]+' | sed 's/\.[0-9]*$/.0\/24/'
  else
    echo "192.168.1.0/24"
  fi
}

# --- Nmap scan ---
run_scan() {
  local subnet=$1
  local scan_type="-sn"  # Ping scan only

  if [[ "${TCP_PING}" == true ]]; then
    scan_type="-sn -PS22,80,443"
  fi

  local port_scan=""
  if [[ -n "${SHOW_PORTS}" ]]; then
    scan_type="-sS"
    port_scan="-p ${SHOW_PORTS}"
  fi

  # Run nmap, output XML for parsing
  local tmpxml
  tmpxml=$(mktemp /tmp/netscan-XXXXXX.xml)

  if [[ $(id -u) -eq 0 ]]; then
    nmap ${scan_type} ${port_scan} -oX "${tmpxml}" "${subnet}" >/dev/null 2>&1
  else
    # Try without sudo first, may miss some MACs
    nmap ${scan_type} ${port_scan} -oX "${tmpxml}" "${subnet}" >/dev/null 2>&1 || \
      sudo nmap ${scan_type} ${port_scan} -oX "${tmpxml}" "${subnet}" >/dev/null 2>&1 || true
  fi

  # Parse XML to JSON
  parse_nmap_xml "${tmpxml}"
  rm -f "${tmpxml}"
}

# --- Parse nmap XML output ---
parse_nmap_xml() {
  local xmlfile=$1
  local result='[]'

  if ! command -v python3 &>/dev/null; then
    # Fallback: basic grep parsing
    parse_nmap_xml_grep "${xmlfile}"
    return
  fi

  python3 -c "
import xml.etree.ElementTree as ET
import json, sys

tree = ET.parse('${xmlfile}')
root = tree.getroot()
devices = []

for host in root.findall('host'):
    status = host.find('status')
    if status is None or status.get('state') != 'up':
        continue

    ip = ''
    mac = ''
    vendor = ''
    hostname = ''
    ports = []

    for addr in host.findall('address'):
        if addr.get('addrtype') == 'ipv4':
            ip = addr.get('addr', '')
        elif addr.get('addrtype') == 'mac':
            mac = addr.get('addr', '').upper()
            vendor = addr.get('vendor', '')

    hostnames = host.find('hostnames')
    if hostnames is not None:
        hn = hostnames.find('hostname')
        if hn is not None:
            hostname = hn.get('name', '')

    port_elem = host.find('ports')
    if port_elem is not None:
        for p in port_elem.findall('port'):
            state = p.find('state')
            if state is not None and state.get('state') == 'open':
                ports.append(int(p.get('portid', 0)))

    if ip:
        devices.append({
            'ip': ip,
            'mac': mac,
            'vendor': vendor,
            'hostname': hostname or '(unknown)',
            'ports': ports
        })

print(json.dumps(devices))
" 2>/dev/null || echo '[]'
}

# --- Fallback grep-based XML parser ---
parse_nmap_xml_grep() {
  local xmlfile=$1
  echo '['
  local first=true
  local ip="" mac="" hostname="" vendor=""

  while IFS= read -r line; do
    if echo "$line" | grep -q '<host '; then
      ip=""; mac=""; hostname=""; vendor=""
    fi
    if echo "$line" | grep -q 'addrtype="ipv4"'; then
      ip=$(echo "$line" | grep -oP 'addr="\K[^"]+')
    fi
    if echo "$line" | grep -q 'addrtype="mac"'; then
      mac=$(echo "$line" | grep -oP 'addr="\K[^"]+' | tr 'a-f' 'A-F')
      vendor=$(echo "$line" | grep -oP 'vendor="\K[^"]*' || echo "")
    fi
    if echo "$line" | grep -q '<hostname '; then
      hostname=$(echo "$line" | grep -oP 'name="\K[^"]+')
    fi
    if echo "$line" | grep -q '</host>'; then
      if [[ -n "${ip}" ]]; then
        [[ "${first}" == true ]] || echo ","
        first=false
        printf '{"ip":"%s","mac":"%s","vendor":"%s","hostname":"%s","ports":[]}' \
          "${ip}" "${mac}" "${vendor}" "${hostname:-\(unknown\)}"
      fi
    fi
  done < "${xmlfile}"
  echo ']'
}

# --- Check if device is known ---
is_known() {
  local mac=$1
  jq -e --arg mac "${mac}" '.devices[$mac]' "${KNOWN_FILE}" >/dev/null 2>&1
}

# --- Get known device name ---
get_known_name() {
  local mac=$1
  jq -r --arg mac "${mac}" '.devices[$mac].name // "(unnamed)"' "${KNOWN_FILE}" 2>/dev/null
}

# --- Approve device ---
approve_device() {
  local mac=$1
  local name=${2:-"Device-${mac}"}
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  local tmp
  tmp=$(mktemp)
  jq --arg mac "${mac}" --arg name "${name}" --arg ts "${ts}" \
    '.devices[$mac] = {"name": $name, "approved_at": $ts}' \
    "${KNOWN_FILE}" > "${tmp}" && mv "${tmp}" "${KNOWN_FILE}"

  echo -e "${GREEN}✅ Approved:${NC} ${mac} → ${name}"
}

# --- Update history ---
update_history() {
  local devices_json=$1
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  local tmp
  tmp=$(mktemp)

  # Update per-device history
  echo "${devices_json}" | jq -c '.[]' | while IFS= read -r dev; do
    local mac ip hostname
    mac=$(echo "$dev" | jq -r '.mac')
    ip=$(echo "$dev" | jq -r '.ip')
    hostname=$(echo "$dev" | jq -r '.hostname')

    [[ -z "${mac}" || "${mac}" == "null" || "${mac}" == "" ]] && continue

    local htmp
    htmp=$(mktemp)
    jq --arg mac "${mac}" --arg ip "${ip}" --arg hn "${hostname}" --arg ts "${ts}" '
      .devices[$mac] = (
        (.devices[$mac] // {"first_seen": $ts, "times_seen": 0}) |
        .last_seen = $ts |
        .last_ip = $ip |
        .hostname = $hn |
        .times_seen = (.times_seen + 1)
      )
    ' "${HISTORY_FILE}" > "${htmp}" && mv "${htmp}" "${HISTORY_FILE}"
  done

  # Append scan record
  local scan_count
  scan_count=$(echo "${devices_json}" | jq 'length')
  htmp=$(mktemp)
  jq --arg ts "${ts}" --argjson count "${scan_count}" \
    '.scans += [{"timestamp": $ts, "device_count": $count}] | .scans = .scans[-100:]' \
    "${HISTORY_FILE}" > "${htmp}" && mv "${htmp}" "${HISTORY_FILE}"
}

# --- Send alert ---
send_alert() {
  local new_devices=$1
  local method=${ALERT_METHOD:-${2:-""}}
  local count
  count=$(echo "${new_devices}" | jq 'length')

  [[ "${count}" -eq 0 ]] && return

  local msg="🔔 Network Alert: ${count} new device(s) detected!\n\n"
  while IFS= read -r dev; do
    local ip mac hostname vendor
    ip=$(echo "$dev" | jq -r '.ip')
    mac=$(echo "$dev" | jq -r '.mac')
    hostname=$(echo "$dev" | jq -r '.hostname')
    vendor=$(echo "$dev" | jq -r '.vendor')
    msg+="• ${ip} — ${mac} (${hostname}) [${vendor}]\n"
  done < <(echo "${new_devices}" | jq -c '.[]')

  case "${method}" in
    telegram)
      local token="${NET_SCANNER_TELEGRAM_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}"
      local chat="${NET_SCANNER_TELEGRAM_CHAT:-${TELEGRAM_CHAT_ID:-}}"
      if [[ -n "${token}" && -n "${chat}" ]]; then
        curl -s "https://api.telegram.org/bot${token}/sendMessage" \
          -d "chat_id=${chat}" \
          -d "text=$(echo -e "${msg}")" \
          -d "parse_mode=HTML" >/dev/null 2>&1
        echo -e "${GREEN}📨 Telegram alert sent${NC}"
      else
        echo -e "${RED}❌ Telegram credentials not set (NET_SCANNER_TELEGRAM_TOKEN, NET_SCANNER_TELEGRAM_CHAT)${NC}"
      fi
      ;;
    webhook)
      local url="${NET_SCANNER_WEBHOOK_URL:-}"
      if [[ -n "${url}" ]]; then
        curl -s -X POST "${url}" \
          -H "Content-Type: application/json" \
          -d "{\"text\":\"$(echo -e "${msg}")\"}" >/dev/null 2>&1
        echo -e "${GREEN}📨 Webhook alert sent${NC}"
      fi
      ;;
    command)
      if [[ -n "${ON_NEW_CMD}" ]]; then
        while IFS= read -r dev; do
          export DEVICE_IP=$(echo "$dev" | jq -r '.ip')
          export DEVICE_MAC=$(echo "$dev" | jq -r '.mac')
          export DEVICE_HOSTNAME=$(echo "$dev" | jq -r '.hostname')
          eval "${ON_NEW_CMD}"
        done < <(echo "${new_devices}" | jq -c '.[]')
      fi
      ;;
  esac
}

# --- Main scan action ---
do_scan() {
  local subnet=${SUBNET:-$(detect_subnet)}
  echo -e "${BLUE}🔍 Scanning ${subnet}...${NC}"

  local devices_json
  devices_json=$(run_scan "${subnet}")

  local total
  total=$(echo "${devices_json}" | jq 'length')
  echo -e "Found ${GREEN}${total}${NC} devices:\n"

  # Header
  printf "  ${BLUE}%-16s %-19s %-22s %s${NC}\n" "IP" "MAC" "HOSTNAME" "STATUS"

  local new_devices='[]'

  while IFS= read -r dev; do
    local ip mac hostname status
    ip=$(echo "$dev" | jq -r '.ip')
    mac=$(echo "$dev" | jq -r '.mac')
    hostname=$(echo "$dev" | jq -r '.hostname')

    if [[ -z "${mac}" || "${mac}" == "null" || "${mac}" == "" ]]; then
      status="${YELLOW}⚠️  No MAC${NC}"
    elif is_known "${mac}"; then
      local name
      name=$(get_known_name "${mac}")
      status="${GREEN}✅ Known (${name})${NC}"
    else
      status="${RED}🆕 NEW${NC}"
      new_devices=$(echo "${new_devices}" | jq --argjson dev "${dev}" '. += [$dev]')
    fi

    printf "  %-16s %-19s %-22s %b\n" "${ip}" "${mac:-N/A}" "${hostname}" "${status}"
  done < <(echo "${devices_json}" | jq -c '.[] | sort_by(.ip)' 2>/dev/null || echo "${devices_json}" | jq -c '.[]')

  local new_count
  new_count=$(echo "${new_devices}" | jq 'length')

  echo ""
  if [[ "${new_count}" -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  ${new_count} new device(s) detected!${NC} Run with --approve MAC --name \"Device Name\" to mark as known."

    # Send alerts if configured
    if [[ -n "${ALERT_METHOD}" ]]; then
      send_alert "${new_devices}" "${ALERT_METHOD}"
    fi
    if [[ -n "${ON_NEW_CMD}" ]]; then
      send_alert "${new_devices}" "command"
    fi
  else
    echo -e "${GREEN}✅ All devices are known.${NC}"
  fi

  # Update history
  update_history "${devices_json}"

  # Log
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Scanned ${subnet}: ${total} devices, ${new_count} new" >> "${LOG_DIR}/scan-$(date -u +%Y-%m-%d).log"
}

# --- List known devices ---
do_list() {
  echo -e "${BLUE}Known Devices:${NC}\n"
  printf "  %-19s %-25s %s\n" "MAC" "NAME" "APPROVED"
  jq -r '.devices | to_entries[] | "  \(.key)  \(.value.name)  \(.value.approved_at)"' "${KNOWN_FILE}"
}

# --- Show history ---
do_history() {
  echo -e "${BLUE}Device History:${NC}\n"
  printf "  %-19s %-20s %-22s %-22s %s\n" "MAC" "HOSTNAME" "FIRST SEEN" "LAST SEEN" "TIMES"
  jq -r '.devices | to_entries[] | "  \(.key)  \(.value.hostname // "(unknown)")  \(.value.first_seen)  \(.value.last_seen)  \(.value.times_seen)"' \
    "${HISTORY_FILE}" 2>/dev/null | sort || echo "  No history yet. Run a scan first."
}

# --- Vendor scan ---
do_vendor() {
  local subnet=${SUBNET:-$(detect_subnet)}
  echo -e "${BLUE}🔍 Scanning ${subnet} with vendor lookup...${NC}\n"

  local devices_json
  devices_json=$(run_scan "${subnet}")

  printf "  %-19s %-20s %s\n" "MAC" "VENDOR" "HOSTNAME"
  echo "${devices_json}" | jq -c '.[]' | while IFS= read -r dev; do
    local mac vendor hostname
    mac=$(echo "$dev" | jq -r '.mac')
    vendor=$(echo "$dev" | jq -r '.vendor')
    hostname=$(echo "$dev" | jq -r '.hostname')

    # If nmap didn't get vendor, try API lookup
    if [[ -z "${vendor}" || "${vendor}" == "null" ]] && [[ -n "${mac}" && "${mac}" != "null" ]]; then
      local mac_prefix="${mac:0:8}"
      vendor=$(curl -s "https://api.macvendors.com/${mac_prefix}" 2>/dev/null | head -1 || echo "Unknown")
      sleep 0.5  # Rate limit
    fi

    printf "  %-19s %-20s %s\n" "${mac:-N/A}" "${vendor:-Unknown}" "${hostname}"
  done

  update_history "${devices_json}"
}

# --- Export ---
do_export() {
  local devices_json
  local subnet=${SUBNET:-$(detect_subnet)}
  devices_json=$(run_scan "${subnet}")

  case "${EXPORT_FMT}" in
    csv)
      echo "ip,mac,hostname,vendor,known"
      echo "${devices_json}" | jq -c '.[]' | while IFS= read -r dev; do
        local ip mac hostname vendor known
        ip=$(echo "$dev" | jq -r '.ip')
        mac=$(echo "$dev" | jq -r '.mac')
        hostname=$(echo "$dev" | jq -r '.hostname')
        vendor=$(echo "$dev" | jq -r '.vendor')
        known=$(is_known "${mac}" && echo "yes" || echo "no")
        echo "${ip},${mac},${hostname},${vendor},${known}"
      done
      ;;
    json)
      echo "${devices_json}" | jq '.'
      ;;
    *)
      echo "Unknown format: ${EXPORT_FMT}. Use csv or json."
      exit 1
      ;;
  esac
}

# --- Diff ---
do_diff() {
  local subnet=${SUBNET:-$(detect_subnet)}
  echo -e "${BLUE}🔍 Scanning and comparing...${NC}\n"

  local current
  current=$(run_scan "${subnet}")

  local previous_macs
  previous_macs=$(jq -r '.devices | keys[]' "${HISTORY_FILE}" 2>/dev/null || echo "")

  echo -e "${GREEN}Appeared (new since tracking):${NC}"
  echo "${current}" | jq -c '.[]' | while IFS= read -r dev; do
    local mac
    mac=$(echo "$dev" | jq -r '.mac')
    [[ -z "${mac}" || "${mac}" == "null" ]] && continue
    if ! echo "${previous_macs}" | grep -q "${mac}"; then
      local ip hostname
      ip=$(echo "$dev" | jq -r '.ip')
      hostname=$(echo "$dev" | jq -r '.hostname')
      echo "  + ${ip} ${mac} ${hostname}"
    fi
  done

  echo -e "\n${RED}Disappeared (tracked but not currently seen):${NC}"
  local current_macs
  current_macs=$(echo "${current}" | jq -r '.[].mac')
  echo "${previous_macs}" | while IFS= read -r mac; do
    [[ -z "${mac}" ]] && continue
    if ! echo "${current_macs}" | grep -q "${mac}"; then
      local hostname
      hostname=$(jq -r --arg mac "${mac}" '.devices[$mac].hostname // "(unknown)"' "${HISTORY_FILE}")
      echo "  - ${mac} ${hostname}"
    fi
  done

  update_history "${current}"
}

# --- Install cron ---
do_install_cron() {
  local interval=${CRON_INTERVAL}
  local script_path
  script_path=$(cd "$(dirname "$0")" && pwd)/scan.sh

  local cron_line="*/${interval} * * * * bash ${script_path} --alert telegram >> ${LOG_DIR}/cron.log 2>&1"

  # Check if already installed
  if crontab -l 2>/dev/null | grep -q "home-network-scanner\|${script_path}"; then
    echo -e "${YELLOW}Cron job already exists. Updating...${NC}"
    crontab -l 2>/dev/null | grep -v "${script_path}" | { cat; echo "${cron_line}"; } | crontab -
  else
    (crontab -l 2>/dev/null; echo "${cron_line}") | crontab -
  fi

  echo -e "${GREEN}✅ Cron job installed: scan every ${interval} minutes${NC}"
  echo "  Entry: ${cron_line}"
}

# --- Main ---
init_data

case "${ACTION}" in
  scan) do_scan ;;
  list) do_list ;;
  approve)
    [[ -z "${APPROVE_MAC}" ]] && { echo "Error: --approve requires a MAC address"; exit 1; }
    approve_device "${APPROVE_MAC}" "${APPROVE_NAME}"
    ;;
  approve-all)
    local subnet=${SUBNET:-$(detect_subnet)}
    echo -e "${BLUE}🔍 Scanning to approve all...${NC}"
    devices_json=$(run_scan "${subnet}")
    echo "${devices_json}" | jq -c '.[]' | while IFS= read -r dev; do
      local mac hostname
      mac=$(echo "$dev" | jq -r '.mac')
      hostname=$(echo "$dev" | jq -r '.hostname')
      [[ -z "${mac}" || "${mac}" == "null" ]] && continue
      approve_device "${mac}" "${hostname}"
    done
    ;;
  history) do_history ;;
  vendor) do_vendor ;;
  export) do_export ;;
  diff) do_diff ;;
  install-cron) do_install_cron ;;
  *) usage; exit 1 ;;
esac
