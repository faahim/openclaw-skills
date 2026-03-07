#!/usr/bin/env bash
# System Inventory Reporter — Collects comprehensive system information
# Usage: bash inventory.sh [--format json|md|html] [--output FILE] [--sections SECTIONS]

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
FORMAT="md"
OUTPUT=""
SECTIONS="system,cpu,memory,storage,network,ports,packages,services,users,docker"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --format)  FORMAT="$2"; shift 2 ;;
    --output)  OUTPUT="$2"; shift 2 ;;
    --sections) SECTIONS="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 [--format json|md|html] [--output FILE] [--sections sec1,sec2,...]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
has_cmd() { command -v "$1" &>/dev/null; }
safe_read() { cat "$1" 2>/dev/null || echo ""; }
trim() { sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<< "$1"; }

# JSON escaping
json_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

IFS=',' read -ra ACTIVE_SECTIONS <<< "$SECTIONS"
has_section() {
  local s
  for s in "${ACTIVE_SECTIONS[@]}"; do
    [[ "$s" == "$1" ]] && return 0
  done
  return 1
}

# ── Collectors ────────────────────────────────────────────────────────────────

collect_system() {
  local hostname kernel os_name os_version os_id uptime_sec uptime_human arch
  hostname="$(hostname 2>/dev/null || echo 'unknown')"
  kernel="$(uname -r 2>/dev/null || echo 'unknown')"
  arch="$(uname -m 2>/dev/null || echo 'unknown')"
  uptime_sec="$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo '0')"
  
  local days=$((uptime_sec / 86400))
  local hours=$(( (uptime_sec % 86400) / 3600 ))
  local mins=$(( (uptime_sec % 3600) / 60 ))
  uptime_human="${days}d ${hours}h ${mins}m"

  os_name="$(safe_read /etc/os-release | grep '^PRETTY_NAME=' | cut -d= -f2 | tr -d '"')"
  os_id="$(safe_read /etc/os-release | grep '^ID=' | cut -d= -f2 | tr -d '"')"
  os_version="$(safe_read /etc/os-release | grep '^VERSION_ID=' | cut -d= -f2 | tr -d '"')"

  cat <<ENDJSON
{
  "hostname": "$(json_str "$hostname")",
  "kernel": "$(json_str "$kernel")",
  "arch": "$(json_str "$arch")",
  "os_name": "$(json_str "${os_name:-unknown}")",
  "os_id": "$(json_str "${os_id:-unknown}")",
  "os_version": "$(json_str "${os_version:-unknown}")",
  "uptime_seconds": $uptime_sec,
  "uptime_human": "$(json_str "$uptime_human")",
  "timestamp": "$TIMESTAMP",
  "timezone": "$(date +%Z 2>/dev/null || echo 'UTC')"
}
ENDJSON
}

collect_cpu() {
  local model cores threads sockets freq_mhz
  if has_cmd lscpu; then
    model="$(lscpu | grep 'Model name:' | sed 's/Model name:[[:space:]]*//' || echo 'unknown')"
    cores="$(lscpu | grep '^CPU(s):' | awk '{print $2}' || echo '0')"
    threads="$(lscpu | grep 'Thread(s) per core:' | awk '{print $NF}' || echo '1')"
    sockets="$(lscpu | grep 'Socket(s):' | awk '{print $2}' || echo '1')"
    freq_mhz="$(lscpu | grep 'CPU max MHz:' | awk '{print $NF}' || lscpu | grep 'CPU MHz:' | awk '{print $NF}' || echo '0')"
  else
    model="$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo 'unknown')"
    cores="$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo '0')"
    threads="1"
    sockets="1"
    freq_mhz="0"
  fi

  cat <<ENDJSON
{
  "model": "$(json_str "$model")",
  "cores": $cores,
  "threads_per_core": $threads,
  "sockets": $sockets,
  "max_mhz": "${freq_mhz:-0}"
}
ENDJSON
}

collect_memory() {
  local total_kb used_kb available_kb swap_total_kb swap_used_kb
  total_kb="$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')"
  available_kb="$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}')"
  used_kb=$((total_kb - available_kb))
  swap_total_kb="$(grep '^SwapTotal:' /proc/meminfo | awk '{print $2}')"
  swap_used_kb="$((swap_total_kb - $(grep '^SwapFree:' /proc/meminfo | awk '{print $2}')))"

  cat <<ENDJSON
{
  "total_mb": $((total_kb / 1024)),
  "used_mb": $((used_kb / 1024)),
  "available_mb": $((available_kb / 1024)),
  "swap_total_mb": $((swap_total_kb / 1024)),
  "swap_used_mb": $((swap_used_kb / 1024)),
  "usage_percent": $(( (used_kb * 100) / total_kb ))
}
ENDJSON
}

collect_storage() {
  echo '{"devices": ['
  local first=true
  if has_cmd lsblk; then
    while IFS= read -r line; do
      local name size type mountpoint fstype
      name="$(echo "$line" | awk '{print $1}')"
      size="$(echo "$line" | awk '{print $2}')"
      type="$(echo "$line" | awk '{print $3}')"
      mountpoint="$(echo "$line" | awk '{print $4}')"
      fstype="$(echo "$line" | awk '{print $5}')"
      [[ -z "$name" ]] && continue
      $first || echo ","
      first=false
      printf '    {"name": "%s", "size": "%s", "type": "%s", "mount": "%s", "fstype": "%s"}' \
        "$(json_str "$name")" "$(json_str "$size")" "$(json_str "$type")" \
        "$(json_str "${mountpoint:--}")" "$(json_str "${fstype:--}")"
    done < <(lsblk -rno NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE 2>/dev/null | head -50)
  fi
  echo ''
  echo '],'

  # Filesystem usage
  echo '"filesystems": ['
  first=true
  while IFS= read -r line; do
    [[ "$line" == Filesystem* ]] && continue
    local fs size used avail pct mount
    fs="$(echo "$line" | awk '{print $1}')"
    size="$(echo "$line" | awk '{print $2}')"
    used="$(echo "$line" | awk '{print $3}')"
    avail="$(echo "$line" | awk '{print $4}')"
    pct="$(echo "$line" | awk '{print $5}')"
    mount="$(echo "$line" | awk '{print $6}')"
    [[ "$fs" == tmpfs || "$fs" == devtmpfs || "$fs" == udev || "$fs" == overlay ]] && continue
    $first || echo ","
    first=false
    printf '    {"filesystem": "%s", "size": "%s", "used": "%s", "available": "%s", "use_percent": "%s", "mount": "%s"}' \
      "$(json_str "$fs")" "$(json_str "$size")" "$(json_str "$used")" \
      "$(json_str "$avail")" "$(json_str "$pct")" "$(json_str "$mount")"
  done < <(df -h 2>/dev/null | head -20)
  echo ''
  echo ']}'
}

collect_network() {
  echo '{"interfaces": ['
  local first=true
  while IFS= read -r iface; do
    [[ -z "$iface" || "$iface" == "lo" ]] && continue
    local ipv4 mac state
    ipv4="$(ip -4 addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | head -1 || echo '')"
    mac="$(ip link show "$iface" 2>/dev/null | grep 'link/ether' | awk '{print $2}' || echo '')"
    state="$(ip link show "$iface" 2>/dev/null | grep -oP 'state \K\S+' || echo 'UNKNOWN')"
    $first || echo ","
    first=false
    printf '    {"name": "%s", "ipv4": "%s", "mac": "%s", "state": "%s"}' \
      "$(json_str "$iface")" "$(json_str "${ipv4:--}")" \
      "$(json_str "${mac:--}")" "$(json_str "$state")"
  done < <(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d@ -f1)
  echo ''
  echo '],'

  # Default gateway
  local gw
  gw="$(ip route 2>/dev/null | grep '^default' | awk '{print $3}' | head -1 || echo '')"
  echo "\"default_gateway\": \"$(json_str "${gw:--}")\"," 

  # DNS
  local dns
  dns="$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | head -3 | tr '\n' ',' | sed 's/,$//')"
  echo "\"dns_servers\": \"$(json_str "${dns:--}")\"}"
}

collect_ports() {
  echo '['
  local first=true
  if has_cmd ss; then
    while IFS= read -r line; do
      [[ "$line" == State* || "$line" == Netid* ]] && continue
      local proto addr port process
      proto="$(echo "$line" | awk '{print $1}')"
      addr="$(echo "$line" | awk '{print $5}')"
      process="$(echo "$line" | awk '{print $7}' | grep -oP 'users:\(\("\K[^"]+' || echo '-')"
      [[ -z "$addr" || "$addr" == "Local" ]] && continue
      $first || echo ","
      first=false
      printf '    {"proto": "%s", "address": "%s", "process": "%s"}' \
        "$(json_str "$proto")" "$(json_str "$addr")" "$(json_str "$process")"
    done < <(ss -tlnp 2>/dev/null | head -50)
  fi
  echo ''
  echo ']'
}

collect_packages() {
  local count=0 pkg_manager=""
  echo '{"manager": '
  if has_cmd dpkg; then
    pkg_manager="dpkg"
    count="$(dpkg -l 2>/dev/null | grep '^ii' | wc -l)"
  elif has_cmd rpm; then
    pkg_manager="rpm"
    count="$(rpm -qa 2>/dev/null | wc -l)"
  elif has_cmd apk; then
    pkg_manager="apk"
    count="$(apk list --installed 2>/dev/null | wc -l)"
  elif has_cmd pacman; then
    pkg_manager="pacman"
    count="$(pacman -Q 2>/dev/null | wc -l)"
  else
    pkg_manager="unknown"
  fi
  echo "\"$pkg_manager\","
  echo "\"total_packages\": $count,"

  # Top 20 largest packages (dpkg only)
  if [[ "$pkg_manager" == "dpkg" && "${INVENTORY_SKIP_PACKAGES:-0}" != "1" ]]; then
    echo '"largest": ['
    local first=true
    while IFS= read -r line; do
      local size name
      size="$(echo "$line" | awk '{print $1}')"
      name="$(echo "$line" | awk '{print $2}')"
      [[ -z "$name" ]] && continue
      $first || echo ","
      first=false
      printf '    {"name": "%s", "size_kb": %s}' "$(json_str "$name")" "$size"
    done < <(dpkg-query -W -f='${Installed-Size}\t${Package}\n' 2>/dev/null | sort -rn | head -20)
    echo ''
    echo ']'
  else
    echo '"largest": []'
  fi
  echo '}'
}

collect_services() {
  echo '['
  local first=true
  if has_cmd systemctl; then
    while IFS= read -r line; do
      local unit load active sub
      unit="$(echo "$line" | awk '{print $1}')"
      load="$(echo "$line" | awk '{print $2}')"
      active="$(echo "$line" | awk '{print $3}')"
      sub="$(echo "$line" | awk '{print $4}')"
      [[ -z "$unit" || "$unit" == "UNIT" ]] && continue
      $first || echo ","
      first=false
      printf '    {"unit": "%s", "load": "%s", "active": "%s", "sub": "%s"}' \
        "$(json_str "$unit")" "$(json_str "$load")" \
        "$(json_str "$active")" "$(json_str "$sub")"
    done < <(systemctl list-units --type=service --no-pager --no-legend 2>/dev/null | head -100)
  fi
  echo ''
  echo ']'
}

collect_users() {
  local total_users logged_in
  total_users="$(getent passwd 2>/dev/null | awk -F: '$3 >= 1000 && $3 < 65534' | wc -l)"
  logged_in="$(who 2>/dev/null | wc -l)"

  echo '{'
  echo "\"regular_users\": $total_users,"
  echo "\"logged_in\": $logged_in,"
  echo '"logged_in_details": ['
  local first=true
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    $first || echo ","
    first=false
    printf '    "%s"' "$(json_str "$line")"
  done < <(who 2>/dev/null)
  echo ''
  echo ']}'
}

collect_docker() {
  if ! has_cmd docker; then
    echo '{"installed": false}'
    return
  fi
  local running stopped images
  running="$(docker ps -q 2>/dev/null | wc -l || echo 0)"
  stopped="$(docker ps -aq 2>/dev/null | wc -l || echo 0)"
  stopped=$((stopped - running))
  images="$(docker images -q 2>/dev/null | wc -l || echo 0)"

  echo '{'
  echo '"installed": true,'
  echo "\"running_containers\": $running,"
  echo "\"stopped_containers\": $stopped,"
  echo "\"images\": $images,"
  echo '"containers": ['
  local first=true
  while IFS='|' read -r id name image status; do
    [[ -z "$id" ]] && continue
    $first || echo ","
    first=false
    printf '    {"id": "%s", "name": "%s", "image": "%s", "status": "%s"}' \
      "$(json_str "$id")" "$(json_str "$name")" "$(json_str "$image")" "$(json_str "$status")"
  done < <(docker ps -a --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}' 2>/dev/null | head -30)
  echo ''
  echo ']}'
}

# ── Assemble JSON ─────────────────────────────────────────────────────────────
assemble_json() {
  echo '{'
  local first=true
  for section in "${ACTIVE_SECTIONS[@]}"; do
    $first || echo ","
    first=false
    echo "\"$section\":"
    case "$section" in
      system)   collect_system ;;
      cpu)      collect_cpu ;;
      memory)   collect_memory ;;
      storage)  collect_storage ;;
      network)  collect_network ;;
      ports)    collect_ports ;;
      packages) collect_packages ;;
      services) collect_services ;;
      users)    collect_users ;;
      docker)   collect_docker ;;
      *) echo '"unsupported section"' ;;
    esac
  done
  echo '}'
}

# ── Format: Markdown ──────────────────────────────────────────────────────────
format_markdown() {
  local json="$1"
  echo "# System Inventory Report"
  echo ""
  echo "**Generated:** $TIMESTAMP"
  echo ""

  if has_section system; then
    echo "## System"
    echo "| Property | Value |"
    echo "|----------|-------|"
    echo "$json" | jq -r '.system | to_entries[] | "| \(.key) | \(.value) |"' 2>/dev/null || echo "| (error reading) | - |"
    echo ""
  fi

  if has_section cpu; then
    echo "## CPU"
    echo "| Property | Value |"
    echo "|----------|-------|"
    echo "$json" | jq -r '.cpu | to_entries[] | "| \(.key) | \(.value) |"' 2>/dev/null || true
    echo ""
  fi

  if has_section memory; then
    echo "## Memory"
    echo "| Property | Value |"
    echo "|----------|-------|"
    echo "$json" | jq -r '.memory | to_entries[] | "| \(.key) | \(.value) |"' 2>/dev/null || true
    echo ""
  fi

  if has_section storage; then
    echo "## Storage — Filesystems"
    echo "| Filesystem | Size | Used | Available | Use% | Mount |"
    echo "|------------|------|------|-----------|------|-------|"
    echo "$json" | jq -r '.storage.filesystems[]? | "| \(.filesystem) | \(.size) | \(.used) | \(.available) | \(.use_percent) | \(.mount) |"' 2>/dev/null || true
    echo ""
  fi

  if has_section network; then
    echo "## Network"
    echo "| Interface | IPv4 | MAC | State |"
    echo "|-----------|------|-----|-------|"
    echo "$json" | jq -r '.network.interfaces[]? | "| \(.name) | \(.ipv4) | \(.mac) | \(.state) |"' 2>/dev/null || true
    local gw dns
    gw="$(echo "$json" | jq -r '.network.default_gateway // "-"' 2>/dev/null)"
    dns="$(echo "$json" | jq -r '.network.dns_servers // "-"' 2>/dev/null)"
    echo ""
    echo "**Gateway:** $gw | **DNS:** $dns"
    echo ""
  fi

  if has_section ports; then
    echo "## Listening Ports"
    echo "| Proto | Address | Process |"
    echo "|-------|---------|---------|"
    echo "$json" | jq -r '.ports[]? | "| \(.proto) | \(.address) | \(.process) |"' 2>/dev/null || true
    echo ""
  fi

  if has_section packages; then
    local mgr count
    mgr="$(echo "$json" | jq -r '.packages.manager // "unknown"' 2>/dev/null)"
    count="$(echo "$json" | jq -r '.packages.total_packages // 0' 2>/dev/null)"
    echo "## Packages"
    echo "**Manager:** $mgr | **Total:** $count"
    echo ""
    echo "### Largest Packages"
    echo "| Package | Size (KB) |"
    echo "|---------|-----------|"
    echo "$json" | jq -r '.packages.largest[]? | "| \(.name) | \(.size_kb) |"' 2>/dev/null || true
    echo ""
  fi

  if has_section services; then
    local svc_count
    svc_count="$(echo "$json" | jq '.services | length' 2>/dev/null || echo 0)"
    echo "## Services ($svc_count running)"
    echo "| Unit | Active | Sub-state |"
    echo "|------|--------|-----------|"
    echo "$json" | jq -r '.services[]? | "| \(.unit) | \(.active) | \(.sub) |"' 2>/dev/null | head -30
    [[ "$svc_count" -gt 30 ]] && echo "| ... | ... | ... |"
    echo ""
  fi

  if has_section users; then
    echo "## Users"
    echo "$json" | jq -r '"**Regular users:** \(.users.regular_users) | **Logged in:** \(.users.logged_in)"' 2>/dev/null || true
    echo ""
  fi

  if has_section docker; then
    local docker_installed
    docker_installed="$(echo "$json" | jq -r '.docker.installed' 2>/dev/null)"
    echo "## Docker"
    if [[ "$docker_installed" == "true" ]]; then
      echo "$json" | jq -r '"**Running:** \(.docker.running_containers) | **Stopped:** \(.docker.stopped_containers) | **Images:** \(.docker.images)"' 2>/dev/null
      echo ""
      echo "| ID | Name | Image | Status |"
      echo "|----|------|-------|--------|"
      echo "$json" | jq -r '.docker.containers[]? | "| \(.id) | \(.name) | \(.image) | \(.status) |"' 2>/dev/null || true
    else
      echo "Docker not installed."
    fi
    echo ""
  fi
}

# ── Format: HTML ──────────────────────────────────────────────────────────────
format_html() {
  local md_content="$1"
  cat <<'HTMLHEAD'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>System Inventory Report</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 960px; margin: 2rem auto; padding: 0 1rem; color: #1a1a2e; background: #f8f9fa; }
h1 { color: #16213e; border-bottom: 3px solid #0f3460; padding-bottom: 0.5rem; }
h2 { color: #0f3460; margin-top: 2rem; }
table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
th, td { border: 1px solid #dee2e6; padding: 0.5rem 0.75rem; text-align: left; }
th { background: #0f3460; color: white; }
tr:nth-child(even) { background: #e8eaf6; }
strong { color: #16213e; }
code { background: #e8eaf6; padding: 0.15rem 0.4rem; border-radius: 3px; font-size: 0.9em; }
</style>
</head>
<body>
HTMLHEAD

  # Simple markdown→HTML (tables + headers + bold)
  echo "$md_content" | sed \
    -e 's/^# \(.*\)/<h1>\1<\/h1>/' \
    -e 's/^## \(.*\)/<h2>\1<\/h2>/' \
    -e 's/^### \(.*\)/<h3>\1<\/h3>/' \
    -e 's/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g' \
    -e '/^|.*|$/!b' \
    -e 's/^| /<tr><td>/; s/ | /<\/td><td>/g; s/ |$/<\/td><\/tr>/' \
    | awk '
    /^<tr><td>---/ { next }
    /<tr>/ && !in_table { print "<table>"; in_table=1 }
    !/<tr>/ && in_table { print "</table>"; in_table=0 }
    { print }
    END { if (in_table) print "</table>" }
    '

  echo "</body></html>"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  local json_data
  json_data="$(assemble_json)"

  local result
  case "$FORMAT" in
    json)
      if has_cmd jq; then
        result="$(echo "$json_data" | jq .)"
      else
        result="$json_data"
      fi
      ;;
    md|markdown)
      result="$(format_markdown "$json_data")"
      ;;
    html)
      local md
      md="$(format_markdown "$json_data")"
      result="$(format_html "$md")"
      ;;
    *)
      echo "Unknown format: $FORMAT (use json, md, or html)" >&2
      exit 1
      ;;
  esac

  if [[ -n "$OUTPUT" ]]; then
    echo "$result" > "$OUTPUT"
    echo "✅ Inventory saved to $OUTPUT" >&2
  else
    echo "$result"
  fi
}

main
