#!/usr/bin/env bash
# USB Guard — Monitor USB device connections and alert on unknown devices
# Version: 1.0.0

set -euo pipefail

VERSION="1.0.0"
CONFIG_DIR="${USB_GUARD_CONFIG_DIR:-$HOME/.config/usb-guard}"
ALLOWLIST="$CONFIG_DIR/allowlist.conf"
CONFIG_FILE="$CONFIG_DIR/config.conf"
LOG_FILE="$CONFIG_DIR/events.log"
PID_FILE="$CONFIG_DIR/usb-guard.pid"
LAST_CHECK="$CONFIG_DIR/last-check"

# Defaults (overridden by config file)
ALERT_METHODS="log,stdout"
TELEGRAM_BOT_TOKEN="${USB_GUARD_TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT_ID="${USB_GUARD_TELEGRAM_CHAT:-}"
WEBHOOK_URL="${USB_GUARD_WEBHOOK_URL:-}"
AUTO_BLOCK=false
POLL_INTERVAL=2
MAX_LOG_ENTRIES=10000

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}" >&2; }
err() { echo -e "${RED}❌ $*${NC}" >&2; }

ensure_config_dir() {
    mkdir -p "$CONFIG_DIR"
    touch "$ALLOWLIST" "$LOG_FILE"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'CONF'
# USB Guard Configuration
ALERT_METHODS="log,stdout"
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
WEBHOOK_URL=""
AUTO_BLOCK=false
POLL_INTERVAL=2
MAX_LOG_ENTRIES=10000
CONF
    fi
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi
    # Env vars override config file
    TELEGRAM_BOT_TOKEN="${USB_GUARD_TELEGRAM_TOKEN:-$TELEGRAM_BOT_TOKEN}"
    TELEGRAM_CHAT_ID="${USB_GUARD_TELEGRAM_CHAT:-$TELEGRAM_CHAT_ID}"
    WEBHOOK_URL="${USB_GUARD_WEBHOOK_URL:-$WEBHOOK_URL}"
}

# Get list of currently connected USB devices as VENDOR:PRODUCT
get_current_devices() {
    lsusb 2>/dev/null | awk '{print $6}' | sort -u
}

# Get device name from lsusb output
get_device_name() {
    local vid_pid="$1"
    lsusb 2>/dev/null | grep "$vid_pid" | head -1 | sed 's/.*ID [0-9a-f]*:[0-9a-f]* //'
}

# Check if device is in allowlist
is_allowed() {
    local vid_pid="$1"
    grep -q "^${vid_pid}" "$ALLOWLIST" 2>/dev/null
}

# -------------------------------------------------------------------
# Alerting
# -------------------------------------------------------------------

send_alert() {
    local device_id="$1"
    local device_name="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname
    hostname=$(hostname)

    local message="🚨 UNKNOWN USB DEVICE
Device: ${device_name} (${device_id})
Time: ${timestamp}
Host: ${hostname}"

    IFS=',' read -ra methods <<< "$ALERT_METHODS"
    for method in "${methods[@]}"; do
        method=$(echo "$method" | tr -d ' ')
        case "$method" in
            stdout)
                echo ""
                echo -e "${RED}🚨 [${timestamp}] UNKNOWN USB DEVICE DETECTED${NC}"
                echo -e "   Vendor:Product: ${device_id}"
                echo -e "   Name: ${device_name}"
                echo ""
                ;;
            log)
                echo "${timestamp} | UNKNOWN | ${device_id} | ${device_name}" >> "$LOG_FILE"
                ;;
            telegram)
                if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
                    curl -s -X POST \
                        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                        -d "chat_id=${TELEGRAM_CHAT_ID}" \
                        -d "text=${message}" \
                        -d "parse_mode=Markdown" > /dev/null 2>&1 || warn "Telegram alert failed"
                else
                    warn "Telegram configured but missing token/chat_id"
                fi
                ;;
            webhook)
                if [[ -n "$WEBHOOK_URL" ]]; then
                    curl -s -X POST "$WEBHOOK_URL" \
                        -H "Content-Type: application/json" \
                        -d "{\"event\":\"unknown_usb\",\"device_id\":\"${device_id}\",\"device_name\":\"${device_name}\",\"timestamp\":\"${timestamp}\",\"hostname\":\"${hostname}\"}" \
                        > /dev/null 2>&1 || warn "Webhook alert failed"
                fi
                ;;
        esac
    done
}

log_allowed() {
    local device_id="$1"
    local device_name="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | ALLOWED | ${device_id} | ${device_name}" >> "$LOG_FILE"
}

# -------------------------------------------------------------------
# Auto-block (requires root)
# -------------------------------------------------------------------

block_device() {
    local device_id="$1"
    local device_name="$2"

    if [[ "$AUTO_BLOCK" != "true" ]]; then
        return
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "Auto-block requires root. Skipping block for ${device_id}"
        return
    fi

    # Find the USB device path and unbind it
    local vid="${device_id%%:*}"
    local pid="${device_id##*:}"

    for devpath in /sys/bus/usb/devices/*/idVendor; do
        local dir
        dir=$(dirname "$devpath")
        local dev_vid dev_pid
        dev_vid=$(cat "$dir/idVendor" 2>/dev/null || echo "")
        dev_pid=$(cat "$dir/idProduct" 2>/dev/null || echo "")

        if [[ "$dev_vid" == "$vid" && "$dev_pid" == "$pid" ]]; then
            local busdev
            busdev=$(basename "$dir")
            echo "$busdev" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null && \
                log "🔒 Blocked and unbound device: ${device_name} (${device_id})" || \
                warn "Failed to unbind ${device_id}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') | BLOCKED | ${device_id} | ${device_name}" >> "$LOG_FILE"
            return
        fi
    done

    warn "Could not find sysfs path for ${device_id} to block"
}

# -------------------------------------------------------------------
# Core Commands
# -------------------------------------------------------------------

cmd_init() {
    ensure_config_dir
    echo "📋 Scanning connected USB devices..."

    local count=0
    while IFS= read -r vid_pid; do
        [[ -z "$vid_pid" ]] && continue
        local name
        name=$(get_device_name "$vid_pid")
        if ! is_allowed "$vid_pid"; then
            echo "${vid_pid} # ${name}" >> "$ALLOWLIST"
            echo -e "${GREEN}✅ Added:${NC} ${vid_pid} ${name}"
            count=$((count + 1))
        else
            echo -e "${BLUE}⏭️  Already trusted:${NC} ${vid_pid} ${name}"
        fi
    done <<< "$(get_current_devices)"

    echo -e "\n📝 Allowlist saved to ${ALLOWLIST} (${count} new devices added)"
}

cmd_monitor() {
    ensure_config_dir
    load_config

    log "🛡️  USB Guard monitoring started (v${VERSION})"
    log "Allowlist: $(grep -c '^[0-9a-f]' "$ALLOWLIST" 2>/dev/null || echo 0) trusted devices"
    log "Alerts: ${ALERT_METHODS}"
    [[ "$AUTO_BLOCK" == "true" ]] && log "⚠️  Auto-block ENABLED"

    # Track known devices
    local known_devices
    known_devices=$(get_current_devices)

    # Try inotifywait on /dev/bus/usb, fall back to polling
    if command -v inotifywait &>/dev/null && [[ -d /dev/bus/usb ]]; then
        log "Using inotify mode (watching /dev/bus/usb)"
        while true; do
            inotifywait -r -q -e create -e delete /dev/bus/usb 2>/dev/null || true
            sleep 0.5  # Brief settle time
            check_devices "$known_devices"
            known_devices=$(get_current_devices)
        done
    else
        log "Using polling mode (interval: ${POLL_INTERVAL}s)"
        while true; do
            sleep "$POLL_INTERVAL"
            check_devices "$known_devices"
            known_devices=$(get_current_devices)
        done
    fi
}

check_devices() {
    local old_devices="$1"
    local new_devices
    new_devices=$(get_current_devices)

    # Find newly added devices
    local added
    added=$(comm -23 <(echo "$new_devices") <(echo "$old_devices"))

    while IFS= read -r vid_pid; do
        [[ -z "$vid_pid" ]] && continue
        local name
        name=$(get_device_name "$vid_pid")

        if is_allowed "$vid_pid"; then
            log_allowed "$vid_pid" "$name"
        else
            send_alert "$vid_pid" "$name"
            block_device "$vid_pid" "$name"
        fi
    done <<< "$added"

    # Find removed devices
    local removed
    removed=$(comm -23 <(echo "$old_devices") <(echo "$new_devices"))
    while IFS= read -r vid_pid; do
        [[ -z "$vid_pid" ]] && continue
        local name="${vid_pid}"  # Can't get name of disconnected device
        echo "$(date '+%Y-%m-%d %H:%M:%S') | REMOVED | ${vid_pid} | (disconnected)" >> "$LOG_FILE"
    done <<< "$removed"
}

cmd_daemon() {
    ensure_config_dir
    load_config

    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            err "USB Guard already running (PID: $old_pid)"
            exit 1
        fi
    fi

    log "Starting USB Guard daemon..."
    nohup bash "$0" --monitor "$@" > "$CONFIG_DIR/daemon.log" 2>&1 &
    echo $! > "$PID_FILE"
    log "Daemon started (PID: $!). Log: $CONFIG_DIR/daemon.log"
}

cmd_stop() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            log "USB Guard stopped (PID: $pid)"
        else
            rm -f "$PID_FILE"
            warn "Stale PID file removed (process $pid not running)"
        fi
    else
        warn "No PID file found. USB Guard may not be running."
    fi
}

cmd_list() {
    ensure_config_dir
    if [[ ! -s "$ALLOWLIST" ]]; then
        echo "Allowlist is empty. Run --init to scan current devices."
        return
    fi

    echo "📋 Trusted USB Devices:"
    echo "========================"
    local count=0
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        local vid_pid="${line%% *}"
        local comment="${line#*# }"
        printf "  %-12s %s\n" "$vid_pid" "$comment"
        count=$((count + 1))
    done < "$ALLOWLIST"
    echo "========================"
    echo "Total: $count devices"
}

cmd_allow() {
    local vid_pid="$1"
    local name="${2:-$(get_device_name "$vid_pid")}"
    name="${name:-Unknown device}"

    ensure_config_dir

    if is_allowed "$vid_pid"; then
        warn "Device ${vid_pid} is already in allowlist"
        return
    fi

    echo "${vid_pid} # ${name}" >> "$ALLOWLIST"
    echo -e "${GREEN}✅ Added to allowlist:${NC} ${vid_pid} (${name})"
}

cmd_revoke() {
    local vid_pid="$1"
    ensure_config_dir

    if ! is_allowed "$vid_pid"; then
        warn "Device ${vid_pid} not found in allowlist"
        return
    fi

    sed -i "/^${vid_pid}/d" "$ALLOWLIST"
    echo -e "${RED}🗑️  Removed from allowlist:${NC} ${vid_pid}"
}

cmd_history() {
    local format="${1:-text}"

    if [[ ! -s "$LOG_FILE" ]]; then
        echo "No USB events recorded yet."
        return
    fi

    if [[ "$format" == "csv" ]]; then
        echo "timestamp,status,device_id,device_name"
        tail -100 "$LOG_FILE" | sed 's/ | /,/g'
    else
        echo "📊 Recent USB Events:"
        echo "======================================"
        tail -50 "$LOG_FILE"
        echo "======================================"
        echo "Total events: $(wc -l < "$LOG_FILE")"
    fi
}

cmd_check_once() {
    ensure_config_dir
    load_config

    local current
    current=$(get_current_devices)
    local unknown=0

    while IFS= read -r vid_pid; do
        [[ -z "$vid_pid" ]] && continue
        if ! is_allowed "$vid_pid"; then
            local name
            name=$(get_device_name "$vid_pid")
            send_alert "$vid_pid" "$name"
            unknown=$((unknown + 1))
        fi
    done <<< "$current"

    date +%s > "$LAST_CHECK"

    if [[ $unknown -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

cmd_trust_current() {
    ensure_config_dir
    local count=0

    while IFS= read -r vid_pid; do
        [[ -z "$vid_pid" ]] && continue
        if ! is_allowed "$vid_pid"; then
            local name
            name=$(get_device_name "$vid_pid")
            echo "${vid_pid} # ${name}" >> "$ALLOWLIST"
            echo -e "${GREEN}✅ Trusted:${NC} ${vid_pid} ${name}"
            count=$((count + 1))
        fi
    done <<< "$(get_current_devices)"

    echo "Added ${count} devices to allowlist."
}

cmd_export() {
    cat "$ALLOWLIST" 2>/dev/null || err "No allowlist found"
}

cmd_import() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        err "File not found: $file"
        exit 1
    fi
    ensure_config_dir
    cat "$file" >> "$ALLOWLIST"
    # Deduplicate
    sort -u -o "$ALLOWLIST" "$ALLOWLIST"
    log "Imported allowlist from $file"
}

cmd_install_service() {
    if [[ $EUID -ne 0 ]]; then
        err "Service installation requires root"
        exit 1
    fi

    local script_path
    script_path=$(readlink -f "$0")
    local user="${SUDO_USER:-root}"

    cat > /etc/systemd/system/usb-guard-monitor.service << EOF
[Unit]
Description=USB Guard — USB Device Monitor
After=network.target

[Service]
Type=simple
User=${user}
ExecStart=/bin/bash ${script_path} --monitor
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log "Service installed: usb-guard-monitor.service"
    log "Start with: sudo systemctl start usb-guard-monitor"
    log "Enable on boot: sudo systemctl enable usb-guard-monitor"
}

# -------------------------------------------------------------------
# Trim log
# -------------------------------------------------------------------

trim_log() {
    if [[ -f "$LOG_FILE" ]]; then
        local lines
        lines=$(wc -l < "$LOG_FILE")
        if [[ $lines -gt $MAX_LOG_ENTRIES ]]; then
            tail -n "$MAX_LOG_ENTRIES" "$LOG_FILE" > "$LOG_FILE.tmp"
            mv "$LOG_FILE.tmp" "$LOG_FILE"
        fi
    fi
}

# -------------------------------------------------------------------
# Usage & Main
# -------------------------------------------------------------------

usage() {
    cat << EOF
USB Guard v${VERSION} — Monitor USB device connections

USAGE:
  usb-guard.sh [COMMAND] [OPTIONS]

COMMANDS:
  --init              Scan current devices and build allowlist
  --monitor           Start real-time USB monitoring (foreground)
  --daemon            Start monitoring as background daemon
  --stop              Stop the background daemon
  --check-once        One-shot check (for cron jobs). Exit 1 if unknown found.
  --list              Show allowlist
  --allow ID [NAME]   Add device to allowlist (e.g. --allow 0781:5567)
  --revoke ID         Remove device from allowlist
  --trust-current     Trust all currently connected devices
  --history [FORMAT]  Show USB event history (text or csv)
  --export            Export allowlist to stdout
  --import FILE       Import allowlist from file
  --install-service   Install as systemd service (requires root)
  --version           Show version

OPTIONS:
  --alert METHOD      Override alert method (telegram, webhook, log, stdout)
  --auto-block        Enable auto-block mode (requires root)
  --poll              Force polling mode (instead of inotify)

ENVIRONMENT:
  USB_GUARD_TELEGRAM_TOKEN   Telegram bot token
  USB_GUARD_TELEGRAM_CHAT    Telegram chat ID
  USB_GUARD_WEBHOOK_URL      Webhook URL for alerts
  USB_GUARD_CONFIG_DIR       Config directory (default: ~/.config/usb-guard)

EXAMPLES:
  usb-guard.sh --init                     # Build initial allowlist
  usb-guard.sh --monitor --alert telegram # Monitor with Telegram alerts
  usb-guard.sh --daemon                   # Run as background daemon
  usb-guard.sh --allow 0781:5567 "SanDisk Cruzer"
  usb-guard.sh --history --format csv > events.csv
EOF
}

main() {
    [[ $# -eq 0 ]] && { usage; exit 0; }

    ensure_config_dir
    load_config
    trim_log

    local cmd=""
    local extra_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --init)         cmd="init"; shift ;;
            --monitor)      cmd="monitor"; shift ;;
            --daemon)       cmd="daemon"; shift ;;
            --stop)         cmd="stop"; shift ;;
            --check-once)   cmd="check_once"; shift ;;
            --list)         cmd="list"; shift ;;
            --allow)        cmd="allow"; shift; extra_args+=("$1"); shift;
                            [[ $# -gt 0 && "$1" != --* ]] && { extra_args+=("$1"); shift; } ;;
            --revoke)       cmd="revoke"; shift; extra_args+=("$1"); shift ;;
            --trust-current) cmd="trust_current"; shift ;;
            --history)      cmd="history"; shift;
                            [[ $# -gt 0 && "$1" == "--format" ]] && { shift; extra_args+=("$1"); shift; } ;;
            --export)       cmd="export"; shift ;;
            --import)       cmd="import"; shift; extra_args+=("$1"); shift ;;
            --install-service) cmd="install_service"; shift ;;
            --alert)        shift; ALERT_METHODS="$1"; shift ;;
            --auto-block)   AUTO_BLOCK=true; shift ;;
            --poll)         POLL_INTERVAL="${2:-2}"; shift;
                            [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]] && shift ;;
            --version|-v)   echo "USB Guard v${VERSION}"; exit 0 ;;
            --help|-h)      usage; exit 0 ;;
            --name)         shift; extra_args+=("$1"); shift ;;  # used with --allow
            *)              warn "Unknown option: $1"; shift ;;
        esac
    done

    [[ -z "$cmd" ]] && { usage; exit 1; }

    "cmd_${cmd}" "${extra_args[@]}"
}

main "$@"
