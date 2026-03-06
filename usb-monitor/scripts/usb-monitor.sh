#!/bin/bash
# USB Monitor — Real-time USB device connection/disconnection monitoring
# Usage: bash usb-monitor.sh [--alert telegram|webhook] [--log FILE] [--whitelist FILE] [--snapshot] [--json] [--generate-whitelist]

set -euo pipefail

# --- Configuration ---
ALERT_TYPE="${USB_ALERT_TYPE:-none}"
LOG_FILE="${USB_LOG_FILE:-}"
WHITELIST_FILE=""
WEBHOOK_URL="${USB_WEBHOOK_URL:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
JSON_OUTPUT=false
SNAPSHOT_MODE=false
GENERATE_WHITELIST=false

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --alert) ALERT_TYPE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --whitelist) WHITELIST_FILE="$2"; shift 2 ;;
    --webhook-url) WEBHOOK_URL="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    --snapshot) SNAPSHOT_MODE=true; shift ;;
    --generate-whitelist) GENERATE_WHITELIST=true; shift ;;
    -h|--help)
      echo "USB Monitor — Real-time USB device monitoring"
      echo ""
      echo "Usage: bash usb-monitor.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --alert <type>       Alert type: telegram, webhook, none (default: none)"
      echo "  --log <file>         Log events to file"
      echo "  --whitelist <file>   Whitelist file (VID:PID per line)"
      echo "  --webhook-url <url>  Webhook URL for alerts"
      echo "  --json               Output in JSON format"
      echo "  --snapshot           List currently connected USB devices and exit"
      echo "  --generate-whitelist Generate whitelist from current devices"
      echo "  -h, --help           Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Dependency Check ---
check_deps() {
  local missing=()
  for cmd in udevadm lsusb; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required commands: ${missing[*]}"
    echo "Install with: sudo apt install udev usbutils"
    exit 1
  fi
}

# --- Logging ---
log_event() {
  local msg="$1"
  if [[ -n "$LOG_FILE" ]]; then
    echo "$msg" >> "$LOG_FILE"
  fi
  echo "$msg"
}

# --- Whitelist Check ---
is_whitelisted() {
  local vid_pid="$1"
  if [[ -z "$WHITELIST_FILE" || ! -f "$WHITELIST_FILE" ]]; then
    return 1  # No whitelist = nothing is whitelisted
  fi
  grep -q "^${vid_pid}" "$WHITELIST_FILE" 2>/dev/null
}

# --- Alert Functions ---
send_telegram() {
  local msg="$1"
  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "text=${msg}" \
      -d "parse_mode=HTML" >/dev/null 2>&1 || true
  fi
}

send_webhook() {
  local msg="$1"
  if [[ -n "$WEBHOOK_URL" ]]; then
    curl -s -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"${msg}\"}" >/dev/null 2>&1 || true
  fi
}

send_alert() {
  local msg="$1"
  case "$ALERT_TYPE" in
    telegram) send_telegram "$msg" ;;
    webhook) send_webhook "$msg" ;;
    none) ;;
    *) echo "Unknown alert type: $ALERT_TYPE" ;;
  esac
}

# --- Get Device Info from lsusb ---
get_device_info() {
  local vid="$1"
  local pid="$2"
  lsusb -d "${vid}:${pid}" 2>/dev/null | head -1 | sed 's/.*ID [0-9a-f]*:[0-9a-f]* //' || echo "Unknown Device"
}

# --- Snapshot Mode ---
do_snapshot() {
  echo "Currently connected USB devices:"
  local count=0
  while IFS= read -r line; do
    if [[ "$line" =~ Bus\ ([0-9]+)\ Device\ ([0-9]+):\ ID\ ([0-9a-f]+):([0-9a-f]+)\ (.*) ]]; then
      count=$((count + 1))
      local bus="${BASH_REMATCH[1]}"
      local dev="${BASH_REMATCH[2]}"
      local vid="${BASH_REMATCH[3]}"
      local pid="${BASH_REMATCH[4]}"
      local name="${BASH_REMATCH[5]}"
      if $JSON_OUTPUT; then
        echo "{\"bus\":\"${bus}\",\"device\":\"${dev}\",\"vid\":\"${vid}\",\"pid\":\"${pid}\",\"name\":\"${name}\"}"
      else
        echo "  ${count}. ${name} (${vid}:${pid}) — Bus ${bus} Device ${dev}"
      fi
    fi
  done < <(lsusb 2>/dev/null)
  if ! $JSON_OUTPUT; then
    echo "Total: ${count} devices"
  fi
}

# --- Generate Whitelist ---
do_generate_whitelist() {
  echo "# USB Whitelist — Generated $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# Format: VID:PID  # Device Name"
  while IFS= read -r line; do
    if [[ "$line" =~ ID\ ([0-9a-f]+):([0-9a-f]+)\ (.*) ]]; then
      local vid="${BASH_REMATCH[1]}"
      local pid="${BASH_REMATCH[2]}"
      local name="${BASH_REMATCH[3]}"
      echo "${vid}:${pid}  # ${name}"
    fi
  done < <(lsusb 2>/dev/null)
}

# --- Monitor Mode ---
do_monitor() {
  local timestamp
  log_event "[$(date '+%Y-%m-%d %H:%M:%S')] USB Monitor started. Watching for events..."

  # Use udevadm monitor to watch for USB events
  stdbuf -oL udevadm monitor --subsystem-match=usb --property 2>/dev/null | while IFS= read -r line; do
    # Detect add/remove events
    if [[ "$line" =~ ^UDEV ]]; then
      if [[ "$line" =~ "(add)" ]]; then
        # Small delay to let device settle
        sleep 0.5

        # Extract device path
        local devpath
        devpath=$(echo "$line" | grep -oP '/devices/\S+' || echo "")

        # Read device properties
        local vid="" pid="" product="" serial="" devnode=""
        if [[ -n "$devpath" ]]; then
          vid=$(cat "/sys${devpath}/idVendor" 2>/dev/null || echo "")
          pid=$(cat "/sys${devpath}/idProduct" 2>/dev/null || echo "")
          product=$(cat "/sys${devpath}/product" 2>/dev/null || echo "")
          serial=$(cat "/sys${devpath}/serial" 2>/dev/null || echo "")
        fi

        # Skip if no VID/PID (hub events, etc.)
        [[ -z "$vid" || -z "$pid" ]] && continue

        local vid_pid="${vid}:${pid}"
        [[ -z "$product" ]] && product=$(get_device_info "$vid" "$pid")

        timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        if $JSON_OUTPUT; then
          log_event "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"connect\",\"product\":\"${product}\",\"vid\":\"${vid}\",\"pid\":\"${pid}\",\"serial\":\"${serial}\"}"
        else
          log_event "[${timestamp}] 🔌 CONNECTED: ${product} (${vid_pid})"
        fi

        # Check whitelist and alert
        if [[ "$ALERT_TYPE" != "none" ]]; then
          if is_whitelisted "$vid_pid"; then
            : # Whitelisted, no alert
          else
            local alert_msg="🚨 USB DEVICE CONNECTED
Device: ${product} (${vid_pid})
Serial: ${serial:-N/A}
Time: ${timestamp}"
            if [[ -n "$WHITELIST_FILE" ]]; then
              alert_msg="${alert_msg}
⚠️ NOT in whitelist"
            fi
            send_alert "$alert_msg"
          fi
        fi

      elif [[ "$line" =~ "(remove)" ]]; then
        local devpath
        devpath=$(echo "$line" | grep -oP '/devices/\S+' || echo "")

        timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        if $JSON_OUTPUT; then
          log_event "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"disconnect\",\"path\":\"${devpath}\"}"
        else
          log_event "[${timestamp}] ⏏️  DISCONNECTED: device at ${devpath}"
        fi
      fi
    fi
  done
}

# --- Main ---
check_deps

if $SNAPSHOT_MODE; then
  do_snapshot
  exit 0
fi

if $GENERATE_WHITELIST; then
  do_generate_whitelist
  exit 0
fi

do_monitor
