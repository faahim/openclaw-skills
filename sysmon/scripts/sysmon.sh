#!/bin/bash
# sysmon — System Resource Monitor
# Monitors CPU, RAM, disk, swap, processes. Alerts on thresholds.
set -euo pipefail

# ── Defaults ──
CPU_WARN="${SYSMON_CPU_WARN:-80}"
RAM_WARN="${SYSMON_RAM_WARN:-90}"
DISK_WARN="${SYSMON_DISK_WARN:-85}"
SWAP_WARN="${SYSMON_SWAP_WARN:-80}"
ALERT_METHOD=""
JSON_OUTPUT=false
QUIET=false
WATCH=false
WATCH_INTERVAL=60
TOP_N=5
DISK_PATHS=()
HOSTNAME_LABEL="${SYSMON_HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"
COOLDOWN="${SYSMON_COOLDOWN:-30}"
COOLDOWN_FILE="/tmp/sysmon-cooldown"

# ── Parse Args ──
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cpu-warn) CPU_WARN="$2"; shift 2 ;;
    --ram-warn) RAM_WARN="$2"; shift 2 ;;
    --disk-warn) DISK_WARN="$2"; shift 2 ;;
    --swap-warn) SWAP_WARN="$2"; shift 2 ;;
    --disk) DISK_PATHS+=("$2"); shift 2 ;;
    --alert) ALERT_METHOD="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    --quiet) QUIET=true; shift ;;
    --watch) WATCH=true; shift ;;
    --interval) WATCH_INTERVAL="$2"; shift 2 ;;
    --top) TOP_N="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: sysmon.sh [OPTIONS]"
      echo "  --cpu-warn N     CPU threshold % (default: 80)"
      echo "  --ram-warn N     RAM threshold % (default: 90)"
      echo "  --disk-warn N    Disk threshold % (default: 85)"
      echo "  --swap-warn N    Swap threshold % (default: 80)"
      echo "  --disk PATH      Disk path to monitor (repeatable, default: /)"
      echo "  --alert TYPE     Alert: telegram, webhook, email"
      echo "  --json           Output JSON"
      echo "  --quiet          Only output on alerts"
      echo "  --watch          Continuous mode"
      echo "  --interval N     Watch interval in seconds (default: 60)"
      echo "  --top N          Top N processes (default: 5)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Default disk path
[[ ${#DISK_PATHS[@]} -eq 0 ]] && DISK_PATHS=("/")

# ── Gather Metrics ──
get_cpu() {
  # 1-second CPU sample
  local idle
  idle=$(top -bn2 -d1 2>/dev/null | grep '^%Cpu' | tail -1 | awk '{print $8}' 2>/dev/null) || true
  if [[ -z "$idle" || "$idle" == "" ]]; then
    # Fallback: /proc/stat
    local c1 c2 i1 i2
    read -r _ c1 _ _ i1 _ < <(head -1 /proc/stat)
    sleep 1
    read -r _ c2 _ _ i2 _ < <(head -1 /proc/stat)
    local total=$((c2 - c1 + i2 - i1))
    if [[ $total -gt 0 ]]; then
      echo "scale=1; (($c2 - $c1) * 100) / $total" | bc 2>/dev/null || echo "0.0"
    else
      echo "0.0"
    fi
  else
    echo "scale=1; 100 - $idle" | bc 2>/dev/null || echo "0.0"
  fi
}

get_ram() {
  free -b 2>/dev/null | awk '/^Mem:/ {
    total=$2; used=$3; available=$7
    pct=(total-available)/total*100
    printf "%.1f %s %s\n", pct, used, total
  }'
}

get_swap() {
  free -b 2>/dev/null | awk '/^Swap:/ {
    if ($2 > 0) { pct=$3/$2*100; printf "%.1f %s %s\n", pct, $3, $2 }
    else { print "0.0 0 0" }
  }'
}

get_disk() {
  local path="$1"
  df -B1 "$path" 2>/dev/null | awk 'NR==2 {
    gsub(/%/,"",$5)
    printf "%s %s %s\n", $5, $3, $2
  }'
}

get_load() {
  awk '{printf "%s %s %s", $1, $2, $3}' /proc/loadavg 2>/dev/null || echo "0 0 0"
}

get_uptime() {
  uptime -p 2>/dev/null | sed 's/^up //' || echo "unknown"
}

human_bytes() {
  local bytes=$1
  if [[ $bytes -ge 1073741824 ]]; then
    echo "$(echo "scale=1; $bytes / 1073741824" | bc)G"
  elif [[ $bytes -ge 1048576 ]]; then
    echo "$(echo "scale=1; $bytes / 1048576" | bc)M"
  else
    echo "${bytes}B"
  fi
}

get_top_processes() {
  ps aux --sort=-%cpu 2>/dev/null | head -$((TOP_N + 1)) | tail -$TOP_N | awk '{printf "  %-7s %-6s %-6s %s\n", $2, $3, $4, $11}'
}

# ── Run Check ──
run_check() {
  local cpu ram_line swap_line load_line uptime_str
  local alerts=()

  cpu=$(get_cpu)
  ram_line=$(get_ram)
  swap_line=$(get_swap)
  load_line=$(get_load)
  uptime_str=$(get_uptime)

  local ram_pct=$(echo "$ram_line" | awk '{print $1}')
  local ram_used=$(echo "$ram_line" | awk '{print $2}')
  local ram_total=$(echo "$ram_line" | awk '{print $3}')
  local swap_pct=$(echo "$swap_line" | awk '{print $1}')
  local swap_used=$(echo "$swap_line" | awk '{print $2}')
  local swap_total=$(echo "$swap_line" | awk '{print $3}')
  local load_1=$(echo "$load_line" | awk '{print $1}')
  local load_5=$(echo "$load_line" | awk '{print $2}')
  local load_15=$(echo "$load_line" | awk '{print $3}')

  # Status indicators
  local cpu_status="✅" ram_status="✅" swap_status="✅"
  if (( $(echo "$cpu > $CPU_WARN" | bc -l 2>/dev/null || echo 0) )); then
    cpu_status="⚠️"; alerts+=("CPU: ${cpu}% (threshold: ${CPU_WARN}%)")
  fi
  if (( $(echo "$ram_pct > $RAM_WARN" | bc -l 2>/dev/null || echo 0) )); then
    ram_status="⚠️"; alerts+=("RAM: ${ram_pct}% (threshold: ${RAM_WARN}%)")
  fi
  if (( $(echo "$swap_pct > $SWAP_WARN" | bc -l 2>/dev/null || echo 0) )); then
    swap_status="⚠️"; alerts+=("Swap: ${swap_pct}% (threshold: ${SWAP_WARN}%)")
  fi

  # Disk checks
  declare -A disk_data
  local disk_json_arr=""
  for dpath in "${DISK_PATHS[@]}"; do
    local dline=$(get_disk "$dpath")
    local dpct=$(echo "$dline" | awk '{print $1}')
    local dused=$(echo "$dline" | awk '{print $2}')
    local dtotal=$(echo "$dline" | awk '{print $3}')
    local dstatus="✅"
    if (( $(echo "$dpct > $DISK_WARN" | bc -l 2>/dev/null || echo 0) )); then
      dstatus="⚠️"; alerts+=("Disk $dpath: ${dpct}% (threshold: ${DISK_WARN}%)")
    fi
    disk_data["${dpath}_pct"]="$dpct"
    disk_data["${dpath}_used"]="$dused"
    disk_data["${dpath}_total"]="$dtotal"
    disk_data["${dpath}_status"]="$dstatus"
  done

  # ── JSON Output ──
  if $JSON_OUTPUT; then
    local disk_json="["
    local first=true
    for dpath in "${DISK_PATHS[@]}"; do
      $first || disk_json+=","
      first=false
      disk_json+="{\"path\":\"$dpath\",\"percent\":${disk_data[${dpath}_pct]},\"used\":\"$(human_bytes ${disk_data[${dpath}_used]})\",\"total\":\"$(human_bytes ${disk_data[${dpath}_total]})\"}"
    done
    disk_json+="]"

    local top_json="["
    local tfirst=true
    while IFS= read -r line; do
      $tfirst || top_json+=","
      tfirst=false
      local tpid=$(echo "$line" | awk '{print $1}')
      local tcpu=$(echo "$line" | awk '{print $2}')
      local tmem=$(echo "$line" | awk '{print $3}')
      local tcmd=$(echo "$line" | awk '{print $4}')
      top_json+="{\"pid\":$tpid,\"cpu\":$tcpu,\"mem\":$tmem,\"cmd\":\"$tcmd\"}"
    done < <(ps aux --sort=-%cpu 2>/dev/null | head -$((TOP_N + 1)) | tail -$TOP_N | awk '{print $2, $3, $4, $11}')
    top_json+="]"

    echo "{\"cpu\":$cpu,\"ram\":$ram_pct,\"ram_used\":\"$(human_bytes $ram_used)\",\"ram_total\":\"$(human_bytes $ram_total)\",\"swap\":$swap_pct,\"disks\":$disk_json,\"load_1\":$load_1,\"load_5\":$load_5,\"load_15\":$load_15,\"uptime\":\"$uptime_str\",\"alerts\":${#alerts[@]},\"top_processes\":$top_json}"
    return
  fi

  # ── Quiet Mode: only output if alerts ──
  if $QUIET && [[ ${#alerts[@]} -eq 0 ]]; then
    return
  fi

  # ── Formatted Output ──
  local now=$(date -u '+%Y-%m-%d %H:%M UTC')
  echo "═══════════════════════════════════════"
  echo "🖥  System Resource Report — $now"
  echo "    Host: $HOSTNAME_LABEL"
  echo "═══════════════════════════════════════"
  printf "CPU Usage:    %5s%%  %s\n" "$cpu" "$cpu_status"
  printf "RAM Usage:    %5s%%  (%s / %s)  %s\n" "$ram_pct" "$(human_bytes $ram_used)" "$(human_bytes $ram_total)" "$ram_status"
  printf "Swap Usage:   %5s%%  (%s / %s)  %s\n" "$swap_pct" "$(human_bytes $swap_used)" "$(human_bytes $swap_total)" "$swap_status"
  for dpath in "${DISK_PATHS[@]}"; do
    printf "Disk %-8s %5s%%  (%s / %s)  %s\n" "$dpath" "${disk_data[${dpath}_pct]}" "$(human_bytes ${disk_data[${dpath}_used]})" "$(human_bytes ${disk_data[${dpath}_total]})" "${disk_data[${dpath}_status]}"
  done
  printf "Load Avg:     %s / %s / %s\n" "$load_1" "$load_5" "$load_15"
  printf "Uptime:       %s\n" "$uptime_str"
  echo "═══════════════════════════════════════"
  echo "Top $TOP_N Processes by CPU:"
  printf "  %-7s %-6s %-6s %s\n" "PID" "CPU%" "MEM%" "COMMAND"
  get_top_processes
  echo "═══════════════════════════════════════"

  # ── Send Alerts ──
  if [[ ${#alerts[@]} -gt 0 && -n "$ALERT_METHOD" ]]; then
    # Cooldown check
    if [[ -f "$COOLDOWN_FILE" ]]; then
      local last_alert=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
      local now_epoch=$(date +%s)
      local diff=$(( (now_epoch - last_alert) / 60 ))
      if [[ $diff -lt $COOLDOWN ]]; then
        echo "⏳ Alert suppressed (cooldown: ${diff}m / ${COOLDOWN}m)"
        return
      fi
    fi

    local alert_msg="🚨 SYSMON ALERT — $HOSTNAME_LABEL"$'\n'
    for a in "${alerts[@]}"; do
      alert_msg+="  $a"$'\n'
    done
    alert_msg+=$'\n'"Top CPU consumers:"$'\n'
    alert_msg+="$(get_top_processes)"

    send_alert "$alert_msg"
    date +%s > "$COOLDOWN_FILE"
  fi
}

send_alert() {
  local msg="$1"
  case "$ALERT_METHOD" in
    telegram)
      local token="${SYSMON_TELEGRAM_BOT_TOKEN:-}"
      local chat_id="${SYSMON_TELEGRAM_CHAT_ID:-}"
      if [[ -z "$token" || -z "$chat_id" ]]; then
        echo "❌ Telegram alert: SYSMON_TELEGRAM_BOT_TOKEN and SYSMON_TELEGRAM_CHAT_ID required"
        return 1
      fi
      curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -d chat_id="$chat_id" \
        -d text="$msg" \
        -d parse_mode="HTML" > /dev/null 2>&1
      echo "📤 Alert sent to Telegram"
      ;;
    webhook)
      local url="${SYSMON_WEBHOOK_URL:-}"
      if [[ -z "$url" ]]; then
        echo "❌ Webhook alert: SYSMON_WEBHOOK_URL required"
        return 1
      fi
      curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"$msg\"}" > /dev/null 2>&1
      echo "📤 Alert sent to webhook"
      ;;
    email)
      local to="${SYSMON_EMAIL_TO:-}"
      if [[ -z "$to" ]]; then
        echo "❌ Email alert: SYSMON_EMAIL_TO required"
        return 1
      fi
      echo "$msg" | mail -s "🚨 SYSMON Alert — $HOSTNAME_LABEL" "$to" 2>/dev/null
      echo "📤 Alert sent to $to"
      ;;
    *) echo "❌ Unknown alert method: $ALERT_METHOD" ;;
  esac
}

# ── Main ──
if $WATCH; then
  echo "👁  Watching system resources every ${WATCH_INTERVAL}s (Ctrl+C to stop)"
  while true; do
    clear 2>/dev/null || true
    run_check
    sleep "$WATCH_INTERVAL"
  done
else
  run_check
fi
