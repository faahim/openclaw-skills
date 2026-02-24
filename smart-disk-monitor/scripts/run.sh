#!/bin/bash
# SMART Disk Health Monitor — Main Script
# Requires: smartmontools, jq, bash 4+
# Usage: sudo bash run.sh --all [--alert telegram] [--log /path/to/log.jsonl]

set -euo pipefail

# ─── Defaults ───
DISK=""
ALL=false
LIST=false
VERBOSE=false
ALERT=""
LOG_FILE=""
SELF_TEST=""
THRESHOLDS_FILE="${SMART_THRESHOLDS:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# ─── Default thresholds ───
TEMP_WARN=50
TEMP_CRIT=60
REALLOC_WARN=1
REALLOC_CRIT=10
PENDING_WARN=1
PENDING_CRIT=5
WEAR_WARN=20
WEAR_CRIT=10

# ─── Parse args ───
while [[ $# -gt 0 ]]; do
  case $1 in
    --disk) DISK="$2"; shift 2 ;;
    --all) ALL=true; shift ;;
    --list) LIST=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    --alert) ALERT="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --self-test) SELF_TEST="$2"; shift 2 ;;
    --thresholds) THRESHOLDS_FILE="$2"; shift 2 ;;
    -h|--help) echo "Usage: sudo bash run.sh [--all|--disk /dev/sdX|--list] [--alert telegram] [--log file.jsonl] [--verbose] [--self-test short|long]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Load custom thresholds ───
if [[ -n "$THRESHOLDS_FILE" && -f "$THRESHOLDS_FILE" ]]; then
  TEMP_WARN=$(jq -r '.temperature_warn // 50' "$THRESHOLDS_FILE")
  TEMP_CRIT=$(jq -r '.temperature_crit // 60' "$THRESHOLDS_FILE")
  REALLOC_WARN=$(jq -r '.reallocated_warn // 1' "$THRESHOLDS_FILE")
  REALLOC_CRIT=$(jq -r '.reallocated_crit // 10' "$THRESHOLDS_FILE")
  PENDING_WARN=$(jq -r '.pending_warn // 1' "$THRESHOLDS_FILE")
  PENDING_CRIT=$(jq -r '.pending_crit // 5' "$THRESHOLDS_FILE")
  WEAR_WARN=$(jq -r '.wear_level_warn // 20' "$THRESHOLDS_FILE")
  WEAR_CRIT=$(jq -r '.wear_level_crit // 10' "$THRESHOLDS_FILE")
fi

# ─── Check dependencies ───
for cmd in smartctl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Required: $cmd not found. Install smartmontools and jq."
    exit 1
  fi
done

if [[ $EUID -ne 0 && "$LIST" != true ]]; then
  echo "⚠️  SMART requires root. Run with: sudo bash $0 $*"
  exit 1
fi

# ─── Telegram alert ───
send_telegram() {
  local msg="$1"
  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="$TELEGRAM_CHAT_ID" \
      -d text="$msg" \
      -d parse_mode="HTML" >/dev/null 2>&1
  else
    echo "⚠️  Telegram not configured (set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID)"
  fi
}

# ─── Discover disks ───
discover_disks() {
  local disks=()
  # Standard SATA/SAS
  for d in /dev/sd[a-z]; do
    [[ -b "$d" ]] && disks+=("$d")
  done
  # NVMe
  for d in /dev/nvme[0-9]n[0-9]; do
    [[ -b "$d" ]] && disks+=("$d")
  done
  # Virtio (some VMs)
  for d in /dev/vd[a-z]; do
    [[ -b "$d" ]] && disks+=("$d")
  done
  echo "${disks[@]}"
}

# ─── List disks ───
if $LIST; then
  echo "Available disks:"
  for d in $(discover_disks); do
    model=$(smartctl -i "$d" 2>/dev/null | grep -i "device model\|model number" | head -1 | sed 's/.*: *//' || echo "unknown")
    size=$(lsblk -dno SIZE "$d" 2>/dev/null || echo "?")
    echo "  $d — $model ($size)"
  done
  exit 0
fi

# ─── Get SMART attribute value by ID ───
get_attr() {
  local data="$1" id="$2"
  echo "$data" | awk -v id="$id" '$1 == id {print $10}' | head -1
}

# ─── Get NVMe value ───
get_nvme_val() {
  local data="$1" key="$2"
  echo "$data" | grep -i "$key" | head -1 | sed 's/.*: *//' | tr -d ',' | awk '{print $1}'
}

# ─── Check one disk ───
TOTAL_DRIVES=0
TOTAL_WARNINGS=0
TOTAL_CRITICAL=0

check_disk() {
  local disk="$1"
  local warnings=()
  local criticals=()
  TOTAL_DRIVES=$((TOTAL_DRIVES + 1))

  # Get SMART info
  local info
  info=$(smartctl -i "$disk" 2>/dev/null) || { echo "  ⚠️  Cannot read SMART from $disk"; return; }

  local model
  model=$(echo "$info" | grep -i "device model\|model number" | head -1 | sed 's/.*: *//')
  local serial
  serial=$(echo "$info" | grep -i "serial" | head -1 | sed 's/.*: *//')

  # Check if SMART supported
  if ! echo "$info" | grep -qi "SMART support.*enabled\|SMART/Health"; then
    echo "  ⚠️  SMART not enabled on $disk ($model)"
    return
  fi

  # Health status
  local health
  health=$(smartctl -H "$disk" 2>/dev/null | grep -i "result\|status" | head -1 | sed 's/.*: *//')
  local health_ok=true
  if echo "$health" | grep -qi "fail"; then
    health_ok=false
    criticals+=("Health: FAILED")
  fi

  # Detect NVMe vs SATA
  local is_nvme=false
  [[ "$disk" == /dev/nvme* ]] && is_nvme=true

  local temp="" power_hours="" realloc="" pending="" wear="" written=""

  if $is_nvme; then
    local nvme_data
    nvme_data=$(smartctl -A "$disk" 2>/dev/null)
    temp=$(get_nvme_val "$nvme_data" "Temperature:")
    power_hours=$(get_nvme_val "$nvme_data" "Power On Hours")
    wear=$(get_nvme_val "$nvme_data" "Percentage Used")
    [[ -n "$wear" ]] && wear=$((100 - wear))
    written=$(get_nvme_val "$nvme_data" "Data Units Written")
  else
    local smart_data
    smart_data=$(smartctl -A "$disk" 2>/dev/null)
    temp=$(get_attr "$smart_data" "194")
    [[ -z "$temp" ]] && temp=$(get_attr "$smart_data" "190")
    power_hours=$(get_attr "$smart_data" "9")
    realloc=$(get_attr "$smart_data" "5")
    pending=$(get_attr "$smart_data" "197")
    wear=$(get_attr "$smart_data" "231")
    [[ -z "$wear" ]] && wear=$(get_attr "$smart_data" "233")
  fi

  # ─── Threshold checks ───
  if [[ -n "$temp" && "$temp" =~ ^[0-9]+$ ]]; then
    if ((temp >= TEMP_CRIT)); then
      criticals+=("Temperature: ${temp}°C (critical >=${TEMP_CRIT}°C)")
    elif ((temp >= TEMP_WARN)); then
      warnings+=("Temperature: ${temp}°C (warn >=${TEMP_WARN}°C)")
    fi
  fi

  if [[ -n "$realloc" && "$realloc" =~ ^[0-9]+$ ]]; then
    if ((realloc >= REALLOC_CRIT)); then
      criticals+=("Reallocated Sectors: $realloc (critical >=${REALLOC_CRIT})")
    elif ((realloc >= REALLOC_WARN)); then
      warnings+=("Reallocated Sectors: $realloc (warn >=${REALLOC_WARN})")
    fi
  fi

  if [[ -n "$pending" && "$pending" =~ ^[0-9]+$ ]]; then
    if ((pending >= PENDING_CRIT)); then
      criticals+=("Pending Sectors: $pending (critical >=${PENDING_CRIT})")
    elif ((pending >= PENDING_WARN)); then
      warnings+=("Pending Sectors: $pending (warn >=${PENDING_WARN})")
    fi
  fi

  if [[ -n "$wear" && "$wear" =~ ^[0-9]+$ ]]; then
    if ((wear <= WEAR_CRIT)); then
      criticals+=("Wear Level: ${wear}% remaining (critical <=${WEAR_CRIT}%)")
    elif ((wear <= WEAR_WARN)); then
      warnings+=("Wear Level: ${wear}% remaining (warn <=${WEAR_WARN}%)")
    fi
  fi

  # ─── Output ───
  local status_icon="✅"
  if [[ ${#criticals[@]} -gt 0 ]]; then
    status_icon="🔴"
    TOTAL_CRITICAL=$((TOTAL_CRITICAL + ${#criticals[@]}))
  elif [[ ${#warnings[@]} -gt 0 ]]; then
    status_icon="🟡"
    TOTAL_WARNINGS=$((TOTAL_WARNINGS + ${#warnings[@]}))
  fi

  echo ""
  echo "Drive: $disk ($model)"
  echo "  Health Status:    $status_icon ${health:-unknown}"
  [[ -n "$temp" ]] && echo "  Temperature:      ${temp}°C"
  [[ -n "$power_hours" ]] && printf "  Power-On Hours:   %'d\n" "$power_hours" 2>/dev/null || echo "  Power-On Hours:   $power_hours"
  [[ -n "$realloc" ]] && echo "  Reallocated:      $realloc sectors"
  [[ -n "$pending" ]] && echo "  Pending Sectors:  $pending"
  [[ -n "$wear" ]] && echo "  Wear Remaining:   ${wear}%"

  for w in "${warnings[@]}"; do echo "  ⚠️  $w"; done
  for c in "${criticals[@]}"; do echo "  🚨 $c"; done

  # ─── Log to JSONL ───
  if [[ -n "$LOG_FILE" ]]; then
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq -nc \
      --arg ts "$ts" \
      --arg disk "$disk" \
      --arg model "$model" \
      --arg health "${health:-unknown}" \
      --arg temp "${temp:-}" \
      --arg hours "${power_hours:-}" \
      --arg realloc "${realloc:-}" \
      --arg pending "${pending:-}" \
      --arg wear "${wear:-}" \
      --argjson warns "$(printf '%s\n' "${warnings[@]}" | jq -R . | jq -s .)" \
      --argjson crits "$(printf '%s\n' "${criticals[@]}" | jq -R . | jq -s .)" \
      '{timestamp:$ts, disk:$disk, model:$model, health:$health, temperature:$temp, power_on_hours:$hours, reallocated:$realloc, pending:$pending, wear_level:$wear, warnings:$warns, criticals:$crits}' \
      >> "$LOG_FILE"
  fi

  # ─── Alert ───
  if [[ "$ALERT" == "telegram" && ( ${#warnings[@]} -gt 0 || ${#criticals[@]} -gt 0 ) ]]; then
    local alert_msg="🚨 <b>SMART Alert: $disk</b>\nDrive: $model\n"
    for w in "${warnings[@]}"; do alert_msg+="⚠️ $w\n"; done
    for c in "${criticals[@]}"; do alert_msg+="🔴 $c\n"; done
    alert_msg+="\nAction: Back up data and investigate immediately."
    send_telegram "$alert_msg"
  fi

  # ─── Self-test ───
  if [[ -n "$SELF_TEST" ]]; then
    echo "  🔄 Starting $SELF_TEST self-test on $disk..."
    smartctl -t "$SELF_TEST" "$disk" 2>/dev/null | grep -i "complete\|seconds\|minutes" || true
  fi
}

# ─── Main ───
NOW=$(date '+%Y-%m-%d %H:%M:%S')

echo "═══════════════════════════════════════════════"
echo "  SMART Disk Health Report — $NOW"
echo "═══════════════════════════════════════════════"

if [[ -n "$DISK" ]]; then
  check_disk "$DISK"
elif $ALL; then
  for d in $(discover_disks); do
    check_disk "$d"
  done
else
  echo "Usage: sudo bash run.sh [--all|--disk /dev/sdX|--list]"
  echo "  --all              Check all detected disks"
  echo "  --disk /dev/sdX    Check specific disk"
  echo "  --list             List available disks"
  echo "  --alert telegram   Send alerts on issues"
  echo "  --log file.jsonl   Append results to JSONL log"
  echo "  --verbose          Show extra details"
  echo "  --self-test short|long  Run SMART self-test"
  echo "  --thresholds file.json  Custom warning thresholds"
  exit 0
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  Summary: $TOTAL_DRIVES drives, $TOTAL_WARNINGS warnings, $TOTAL_CRITICAL critical"
echo "═══════════════════════════════════════════════"

# Exit with error code if critical issues found
[[ $TOTAL_CRITICAL -gt 0 ]] && exit 2
[[ $TOTAL_WARNINGS -gt 0 ]] && exit 1
exit 0
