#!/bin/bash
# System Inventory Tool — Generates comprehensive system reports
# Usage: bash inventory.sh [--section <name>] [--format markdown|json|tsv] [--filter <pattern>]

set -euo pipefail

# --- Argument Parsing ---
SECTIONS=()
FORMAT="${INVENTORY_FORMAT:-markdown}"
FILTER=""
USE_SUDO="${INVENTORY_SUDO:-false}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --section) SECTIONS+=("$2"); shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --filter) FILTER="$2"; shift 2 ;;
    --sudo) USE_SUDO=true; shift ;;
    -h|--help)
      echo "Usage: inventory.sh [--section <name>] [--format markdown|json|tsv] [--filter <pattern>]"
      echo "Sections: system, hardware, storage, network, services, packages, users, cron, docker"
      echo "Formats: markdown (default), json, tsv"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Default: all sections
if [[ ${#SECTIONS[@]} -eq 0 ]]; then
  SECTIONS=(system hardware storage network services packages users cron docker)
fi

# --- Helpers ---
cmd_exists() { command -v "$1" &>/dev/null; }
try_sudo() {
  if [[ "$USE_SUDO" == "true" ]] && cmd_exists sudo; then
    sudo "$@" 2>/dev/null
  else
    "$@" 2>/dev/null
  fi
}
apply_filter() {
  if [[ -n "$FILTER" ]]; then
    grep -i "$FILTER" || true
  else
    cat
  fi
}
timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# --- JSON accumulator ---
JSON_PARTS=()
json_add() { JSON_PARTS+=("\"$1\": $2"); }

# --- Section: System ---
collect_system() {
  local hostname=$(hostname 2>/dev/null || echo "unknown")
  local os="unknown"
  [[ -f /etc/os-release ]] && os=$(. /etc/os-release && echo "$PRETTY_NAME")
  local kernel=$(uname -r)
  local arch=$(uname -m)
  local uptime=$(uptime -p 2>/dev/null || uptime | sed 's/.*up /up /' | sed 's/,.*load.*//')
  local tz=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "unknown")
  local boot=$(who -b 2>/dev/null | awk '{print $3, $4}' || echo "unknown")

  if [[ "$FORMAT" == "json" ]]; then
    json_add "system" "{\"hostname\": \"$hostname\", \"os\": \"$os\", \"kernel\": \"$kernel\", \"arch\": \"$arch\", \"uptime\": \"$uptime\", \"timezone\": \"$tz\"}"
  else
    echo "## System"
    echo ""
    echo "| Property | Value |"
    echo "|----------|-------|"
    echo "| Hostname | $hostname |"
    echo "| OS | $os |"
    echo "| Kernel | $kernel |"
    echo "| Architecture | $arch |"
    echo "| Uptime | $uptime |"
    echo "| Timezone | $tz |"
    echo "| Last Boot | $boot |"
    echo ""
  fi
}

# --- Section: Hardware ---
collect_hardware() {
  local cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "unknown")
  local cpu_cores=$(nproc 2>/dev/null || echo "unknown")
  local ram_total=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "unknown")
  local ram_used=$(free -h 2>/dev/null | awk '/^Mem:/{print $3}' || echo "unknown")
  local swap_total=$(free -h 2>/dev/null | awk '/^Swap:/{print $2}' || echo "0")
  local swap_used=$(free -h 2>/dev/null | awk '/^Swap:/{print $3}' || echo "0")

  # DMI data (needs sudo usually)
  local manufacturer="" product=""
  if cmd_exists dmidecode; then
    manufacturer=$(try_sudo dmidecode -s system-manufacturer 2>/dev/null | head -1 || echo "")
    product=$(try_sudo dmidecode -s system-product-name 2>/dev/null | head -1 || echo "")
  fi

  if [[ "$FORMAT" == "json" ]]; then
    json_add "hardware" "{\"cpu_model\": \"$cpu_model\", \"cpu_cores\": $cpu_cores, \"ram_total\": \"$ram_total\", \"ram_used\": \"$ram_used\", \"swap_total\": \"$swap_total\", \"swap_used\": \"$swap_used\", \"manufacturer\": \"$manufacturer\", \"product\": \"$product\"}"
  else
    echo "## Hardware"
    echo ""
    echo "| Property | Value |"
    echo "|----------|-------|"
    echo "| CPU | $cpu_model |"
    echo "| Cores | $cpu_cores |"
    echo "| RAM Total | $ram_total |"
    echo "| RAM Used | $ram_used |"
    echo "| Swap Total | $swap_total |"
    echo "| Swap Used | $swap_used |"
    [[ -n "$manufacturer" ]] && echo "| Manufacturer | $manufacturer |"
    [[ -n "$product" ]] && echo "| Product | $product |"
    echo ""
  fi
}

# --- Section: Storage ---
collect_storage() {
  if [[ "$FORMAT" == "json" ]]; then
    local disks="["
    local first=true
    while IFS= read -r line; do
      local fs=$(echo "$line" | awk '{print $1}')
      local size=$(echo "$line" | awk '{print $2}')
      local used=$(echo "$line" | awk '{print $3}')
      local avail=$(echo "$line" | awk '{print $4}')
      local pct=$(echo "$line" | awk '{print $5}')
      local mount=$(echo "$line" | awk '{print $6}')
      [[ "$first" == "true" ]] && first=false || disks+=","
      disks+="{\"filesystem\": \"$fs\", \"size\": \"$size\", \"used\": \"$used\", \"available\": \"$avail\", \"use_percent\": \"$pct\", \"mount\": \"$mount\"}"
    done < <(df -h --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n +2 | grep -v "^tmpfs\|^devtmpfs\|^udev\|^shm" | apply_filter)
    disks+="]"
    json_add "storage" "$disks"
  else
    echo "## Storage"
    echo ""
    echo '```'
    df -h --output=source,size,used,avail,pcent,target 2>/dev/null | grep -v "^tmpfs\|^devtmpfs\|^udev\|^shm" | apply_filter || df -h | apply_filter
    echo '```'
    echo ""

    # Inode usage
    echo "### Inode Usage"
    echo ""
    echo '```'
    df -i --output=source,itotal,iused,iavail,ipcent,target 2>/dev/null | grep -v "^tmpfs\|^devtmpfs\|^udev\|^shm" | head -20 || echo "inode info unavailable"
    echo '```'
    echo ""
  fi
}

# --- Section: Network ---
collect_network() {
  if [[ "$FORMAT" == "json" ]]; then
    local interfaces="["
    local first=true
    while IFS= read -r iface; do
      [[ -z "$iface" || "$iface" == "lo" ]] && continue
      local ip4=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1 || echo "")
      local ip6=$(ip -6 addr show "$iface" 2>/dev/null | grep -oP 'inet6 \K[0-9a-f:]+' | head -1 || echo "")
      local state=$(ip link show "$iface" 2>/dev/null | grep -oP 'state \K\w+' || echo "unknown")
      [[ "$first" == "true" ]] && first=false || interfaces+=","
      interfaces+="{\"name\": \"$iface\", \"ipv4\": \"$ip4\", \"ipv6\": \"$ip6\", \"state\": \"$state\"}"
    done < <(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d@ -f1)
    interfaces+="]"
    json_add "network" "{\"interfaces\": $interfaces}"
  else
    echo "## Network"
    echo ""
    echo "### Interfaces"
    echo ""
    echo '```'
    ip -br addr 2>/dev/null | apply_filter || ifconfig 2>/dev/null | apply_filter || echo "network info unavailable"
    echo '```'
    echo ""

    echo "### DNS"
    echo ""
    echo '```'
    grep -v '^#' /etc/resolv.conf 2>/dev/null | grep -v '^$' || echo "DNS info unavailable"
    echo '```'
    echo ""

    echo "### Listening Ports"
    echo ""
    echo '```'
    (ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null) | apply_filter | head -30
    echo '```'
    echo ""

    echo "### Default Route"
    echo ""
    echo '```'
    ip route show default 2>/dev/null || route -n 2>/dev/null | head -5
    echo '```'
    echo ""
  fi
}

# --- Section: Services ---
collect_services() {
  if ! cmd_exists systemctl; then
    [[ "$FORMAT" != "json" ]] && echo "## Services" && echo "" && echo "*systemd not available*" && echo ""
    [[ "$FORMAT" == "json" ]] && json_add "services" "[]"
    return
  fi

  if [[ "$FORMAT" == "json" ]]; then
    local svcs="["
    local first=true
    while IFS= read -r line; do
      local unit=$(echo "$line" | awk '{print $1}')
      local load=$(echo "$line" | awk '{print $2}')
      local active=$(echo "$line" | awk '{print $3}')
      local sub=$(echo "$line" | awk '{print $4}')
      local desc=$(echo "$line" | awk '{$1=$2=$3=$4=""; print}' | xargs)
      [[ "$first" == "true" ]] && first=false || svcs+=","
      svcs+="{\"unit\": \"$unit\", \"load\": \"$load\", \"active\": \"$active\", \"sub\": \"$sub\", \"description\": \"$(echo "$desc" | sed 's/"/\\"/g')\"}"
    done < <(systemctl list-units --type=service --no-pager --no-legend 2>/dev/null | apply_filter)
    svcs+="]"
    json_add "services" "$svcs"
  else
    echo "## Services"
    echo ""
    echo "### Running Services"
    echo ""
    echo '```'
    systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | apply_filter | head -50
    echo '```'
    echo ""
    local enabled_count=$(systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend 2>/dev/null | wc -l)
    local running_count=$(systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | wc -l)
    echo "**Total:** $running_count running, $enabled_count enabled"
    echo ""
  fi
}

# --- Section: Packages ---
collect_packages() {
  local pkg_manager=""
  local pkg_count=0
  local pkg_list=""

  if cmd_exists dpkg; then
    pkg_manager="dpkg"
    pkg_count=$(dpkg -l 2>/dev/null | grep '^ii' | wc -l)
    pkg_list=$(dpkg -l 2>/dev/null | grep '^ii' | awk '{print $2 "\t" $3}' | apply_filter | head -100)
  elif cmd_exists rpm; then
    pkg_manager="rpm"
    pkg_count=$(rpm -qa 2>/dev/null | wc -l)
    pkg_list=$(rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\n' 2>/dev/null | sort | apply_filter | head -100)
  elif cmd_exists pacman; then
    pkg_manager="pacman"
    pkg_count=$(pacman -Q 2>/dev/null | wc -l)
    pkg_list=$(pacman -Q 2>/dev/null | apply_filter | head -100)
  elif cmd_exists apk; then
    pkg_manager="apk"
    pkg_count=$(apk list --installed 2>/dev/null | wc -l)
    pkg_list=$(apk list --installed 2>/dev/null | apply_filter | head -100)
  fi

  if [[ "$FORMAT" == "json" ]]; then
    json_add "packages" "{\"manager\": \"$pkg_manager\", \"count\": $pkg_count}"
  elif [[ "$FORMAT" == "tsv" ]]; then
    echo "$pkg_list"
  else
    echo "## Packages"
    echo ""
    echo "**Package Manager:** $pkg_manager"
    echo "**Total Installed:** $pkg_count"
    echo ""
    if [[ -n "$FILTER" ]]; then
      echo "### Matching \"$FILTER\""
      echo ""
      echo '```'
      echo "$pkg_list"
      echo '```'
      echo ""
    fi
  fi
}

# --- Section: Users ---
collect_users() {
  if [[ "$FORMAT" == "json" ]]; then
    local users="["
    local first=true
    while IFS=: read -r name _ uid gid _ home shell; do
      [[ $uid -lt 1000 && $uid -ne 0 ]] && continue
      [[ "$first" == "true" ]] && first=false || users+=","
      local has_sudo="false"
      groups "$name" 2>/dev/null | grep -qE '\b(sudo|wheel|admin)\b' && has_sudo="true"
      users+="{\"name\": \"$name\", \"uid\": $uid, \"home\": \"$home\", \"shell\": \"$shell\", \"sudo\": $has_sudo}"
    done < /etc/passwd
    users+="]"
    json_add "users" "$users"
  else
    echo "## Users"
    echo ""
    echo "| Username | UID | Home | Shell | Sudo |"
    echo "|----------|-----|------|-------|------|"
    while IFS=: read -r name _ uid gid _ home shell; do
      [[ $uid -lt 1000 && $uid -ne 0 ]] && continue
      local sudo_flag=""
      groups "$name" 2>/dev/null | grep -qE '\b(sudo|wheel|admin)\b' && sudo_flag="✅" || sudo_flag=""
      echo "| $name | $uid | $home | $shell | $sudo_flag |" | apply_filter
    done < /etc/passwd
    echo ""
  fi
}

# --- Section: Cron ---
collect_cron() {
  if [[ "$FORMAT" == "json" ]]; then
    json_add "cron" "\"see cron section in markdown format\""
    return
  fi

  echo "## Cron Jobs"
  echo ""
  echo '```'
  # System crontabs
  for f in /etc/crontab /etc/cron.d/*; do
    [[ -f "$f" ]] && echo "# $f" && grep -v '^#\|^$\|^SHELL\|^PATH\|^MAILTO' "$f" 2>/dev/null
  done
  # User crontabs
  if [[ "$USE_SUDO" == "true" ]]; then
    for user in $(cut -d: -f1 /etc/passwd); do
      local crontab=$(try_sudo crontab -l -u "$user" 2>/dev/null | grep -v '^#\|^$')
      [[ -n "$crontab" ]] && echo "# user: $user" && echo "$crontab"
    done
  else
    crontab -l 2>/dev/null | grep -v '^#\|^$' || echo "(current user has no crontab)"
  fi
  echo '```'
  echo ""
}

# --- Section: Docker ---
collect_docker() {
  if ! cmd_exists docker; then
    [[ "$FORMAT" != "json" ]] && return
    json_add "docker" "null"
    return
  fi

  if [[ "$FORMAT" == "json" ]]; then
    local containers=$(docker ps -a --format '{{json .}}' 2>/dev/null | head -50 | paste -sd ',' || echo "")
    json_add "docker" "{\"containers\": [$containers]}"
  else
    echo "## Docker"
    echo ""
    echo "### Containers"
    echo ""
    echo '```'
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | apply_filter | head -30 || echo "Docker not accessible"
    echo '```'
    echo ""

    local img_count=$(docker images -q 2>/dev/null | wc -l)
    local vol_count=$(docker volume ls -q 2>/dev/null | wc -l)
    echo "**Images:** $img_count | **Volumes:** $vol_count"
    echo ""
  fi
}

# --- Main ---
if [[ "$FORMAT" == "markdown" || "$FORMAT" == "tsv" ]]; then
  [[ "$FORMAT" == "markdown" ]] && echo "# System Inventory: $(hostname)" && echo "" && echo "**Generated:** $(timestamp)" && echo ""

  for section in "${SECTIONS[@]}"; do
    case "$section" in
      system) collect_system ;;
      hardware) collect_hardware ;;
      storage) collect_storage ;;
      network) collect_network ;;
      services) collect_services ;;
      packages) collect_packages ;;
      users) collect_users ;;
      cron) collect_cron ;;
      docker) collect_docker ;;
      *) echo "Unknown section: $section" ;;
    esac
  done

elif [[ "$FORMAT" == "json" ]]; then
  json_add "generated_at" "\"$(timestamp)\""
  json_add "hostname" "\"$(hostname)\""

  for section in "${SECTIONS[@]}"; do
    case "$section" in
      system) collect_system ;;
      hardware) collect_hardware ;;
      storage) collect_storage ;;
      network) collect_network ;;
      services) collect_services ;;
      packages) collect_packages ;;
      users) collect_users ;;
      cron) collect_cron ;;
      docker) collect_docker ;;
    esac
  done

  echo "{"
  first_json=true
  for part in "${JSON_PARTS[@]}"; do
    [[ "$first_json" == "true" ]] && first_json=false || echo ","
    echo "  $part"
  done
  echo ""
  echo "}"
fi
