#!/bin/bash
# Process Watchdog — Monitor processes, auto-restart on crash, alert
# Usage: watchdog.sh --name <process> --restart <cmd> [--interval <secs>] [--alert telegram]

set -euo pipefail

# Defaults
PROCESS_NAME=""
SERVICE_NAME=""
PID_FILE=""
RESTART_CMD=""
HEALTH_CMD=""
INTERVAL=10
MAX_RESTARTS=5
COOLDOWN=60
ALERT_TYPE=""
CONFIG_FILE=""
LOG_FILE="${WATCHDOG_LOG:-/var/log/process-watchdog.log}"
DAEMON=false
ONCE=false
SHOW_STATS=false

# State
RESTART_COUNT=0
LAST_RESTART=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$msg"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

send_telegram() {
    local msg="$1"
    local token="${WATCHDOG_TELEGRAM_TOKEN:-}"
    local chat="${WATCHDOG_TELEGRAM_CHAT:-}"
    if [[ -n "$token" && -n "$chat" ]]; then
        curl -sf -X POST "https://api.telegram.org/bot${token}/sendMessage" \
            -d "chat_id=${chat}" \
            -d "text=${msg}" \
            -d "parse_mode=HTML" > /dev/null 2>&1 || true
    fi
}

send_webhook() {
    local msg="$1"
    local url="${WATCHDOG_WEBHOOK_URL:-}"
    if [[ -n "$url" ]]; then
        curl -sf -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"${msg}\"}" > /dev/null 2>&1 || true
    fi
}

send_email() {
    local msg="$1"
    local to="${WATCHDOG_EMAIL_TO:-}"
    local from="${WATCHDOG_EMAIL_FROM:-watchdog@$(hostname)}"
    if [[ -n "$to" ]] && command -v sendmail &>/dev/null; then
        echo -e "From: ${from}\nTo: ${to}\nSubject: Process Watchdog Alert\n\n${msg}" | sendmail "$to" 2>/dev/null || true
    fi
}

send_alert() {
    local msg="$1"
    local hostname=$(hostname)
    local full_msg="🔔 <b>Process Watchdog</b> [${hostname}]
${msg}"

    case "${ALERT_TYPE}" in
        telegram) send_telegram "$full_msg" ;;
        webhook)  send_webhook "$msg" ;;
        email)    send_email "$msg" ;;
        all)
            send_telegram "$full_msg"
            send_webhook "$msg"
            send_email "$msg"
            ;;
        "") ;; # no alerts configured
    esac
}

check_process() {
    if [[ -n "$SERVICE_NAME" ]]; then
        systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null
        return $?
    elif [[ -n "$PID_FILE" ]]; then
        if [[ -f "$PID_FILE" ]]; then
            local pid=$(cat "$PID_FILE")
            kill -0 "$pid" 2>/dev/null
            return $?
        fi
        return 1
    elif [[ -n "$PROCESS_NAME" ]]; then
        # Use bracket trick to avoid self-matching: [f]oo won't match the grep itself
        local first_char="${PROCESS_NAME:0:1}"
        local rest="${PROCESS_NAME:1}"
        local pattern="[${first_char}]${rest}"
        ps aux | grep -E "$pattern" | grep -v "watchdog\.sh" > /dev/null 2>&1
        return $?
    fi
    return 1
}

check_health() {
    if [[ -n "$HEALTH_CMD" ]]; then
        eval "$HEALTH_CMD" > /dev/null 2>&1
        return $?
    fi
    return 0  # No health check = healthy if running
}

get_pid() {
    if [[ -n "$SERVICE_NAME" ]]; then
        systemctl show -p MainPID --value "$SERVICE_NAME" 2>/dev/null || echo "?"
    elif [[ -n "$PID_FILE" && -f "$PID_FILE" ]]; then
        cat "$PID_FILE"
    elif [[ -n "$PROCESS_NAME" ]]; then
        local first_char="${PROCESS_NAME:0:1}"
        local rest="${PROCESS_NAME:1}"
        local pattern="[${first_char}]${rest}"
        ps aux | grep -E "$pattern" | grep -v "watchdog\.sh" | awk '{print $2}' | head -1 || echo "?"
    fi
}

restart_process() {
    local now=$(date +%s)
    local elapsed=$((now - LAST_RESTART))

    # Check cooldown
    if [[ $LAST_RESTART -gt 0 && $elapsed -lt $COOLDOWN ]]; then
        log "⏳ Cooldown active (${elapsed}s/${COOLDOWN}s). Skipping restart."
        return 1
    fi

    # Check max restarts
    if [[ $RESTART_COUNT -ge $MAX_RESTARTS ]]; then
        local msg="🚨 CRITICAL: ${PROCESS_NAME}${SERVICE_NAME} restarted ${RESTART_COUNT} times. Max reached. Manual intervention required."
        log "$msg"
        send_alert "$msg"
        return 2
    fi

    RESTART_COUNT=$((RESTART_COUNT + 1))
    LAST_RESTART=$now

    log "🔄 Restarting ${PROCESS_NAME}${SERVICE_NAME} (attempt ${RESTART_COUNT}/${MAX_RESTARTS})..."

    if [[ -n "$SERVICE_NAME" ]]; then
        if command -v systemctl &>/dev/null; then
            systemctl restart "$SERVICE_NAME" 2>&1 || sudo systemctl restart "$SERVICE_NAME" 2>&1 || true
        fi
    elif [[ -n "$RESTART_CMD" ]]; then
        eval "$RESTART_CMD" 2>&1 || true
    else
        log "❌ No restart command configured. Cannot restart."
        return 1
    fi

    # Verify restart
    sleep 2
    if check_process; then
        local pid=$(get_pid)
        local msg="✅ ${PROCESS_NAME}${SERVICE_NAME} restarted successfully (PID: ${pid}). Restart #${RESTART_COUNT}."
        log "$msg"
        send_alert "$msg"
        return 0
    else
        local msg="❌ ${PROCESS_NAME}${SERVICE_NAME} failed to restart (attempt ${RESTART_COUNT}/${MAX_RESTARTS})."
        log "$msg"
        send_alert "$msg"
        return 1
    fi
}

show_stats() {
    echo "Process Watchdog Statistics"
    echo "═══════════════════════════"
    if [[ -f "$LOG_FILE" ]]; then
        local restarts=$(grep -c "🔄 Restarting" "$LOG_FILE" 2>/dev/null || echo 0)
        local failures=$(grep -c "❌" "$LOG_FILE" 2>/dev/null || echo 0)
        local checks=$(grep -c "✅.*running" "$LOG_FILE" 2>/dev/null || echo 0)
        local total=$((checks + failures))
        local uptime_pct="100.0"
        if [[ $total -gt 0 ]]; then
            uptime_pct=$(awk "BEGIN {printf \"%.1f\", ($checks/$total)*100}")
        fi
        echo "Total checks:   $total"
        echo "Healthy:        $checks"
        echo "Failures:       $failures"
        echo "Restarts:       $restarts"
        echo "Uptime:         ${uptime_pct}%"
        echo ""
        echo "Recent events:"
        grep -E "🔄|❌|🚨" "$LOG_FILE" 2>/dev/null | tail -10 || echo "  (none)"
    else
        echo "No log file found at $LOG_FILE"
    fi
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)         PROCESS_NAME="$2"; shift 2 ;;
        --service)      SERVICE_NAME="$2"; shift 2 ;;
        --pidfile)      PID_FILE="$2"; shift 2 ;;
        --restart)      RESTART_CMD="$2"; shift 2 ;;
        --health-cmd)   HEALTH_CMD="$2"; shift 2 ;;
        --interval)     INTERVAL="$2"; shift 2 ;;
        --max-restarts) MAX_RESTARTS="$2"; shift 2 ;;
        --cooldown)     COOLDOWN="$2"; shift 2 ;;
        --alert)        ALERT_TYPE="$2"; shift 2 ;;
        --config)       CONFIG_FILE="$2"; shift 2 ;;
        --log)          LOG_FILE="$2"; shift 2 ;;
        --daemon)       DAEMON=true; shift ;;
        --once)         ONCE=true; shift ;;
        --stats)        SHOW_STATS=true; shift ;;
        -h|--help)
            echo "Usage: watchdog.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --name <proc>       Process name (pgrep -f match)"
            echo "  --service <name>    Systemd service name"
            echo "  --pidfile <path>    PID file to monitor"
            echo "  --restart <cmd>     Custom restart command"
            echo "  --health-cmd <cmd>  Health check command (in addition to process check)"
            echo "  --interval <secs>   Check interval (default: 10)"
            echo "  --max-restarts <n>  Max restarts before giving up (default: 5)"
            echo "  --cooldown <secs>   Min seconds between restarts (default: 60)"
            echo "  --alert <type>      Alert type: telegram, webhook, email, all"
            echo "  --config <file>     YAML config file for multi-process monitoring"
            echo "  --log <file>        Log file path (default: /var/log/process-watchdog.log)"
            echo "  --daemon            Daemonize (run in background)"
            echo "  --once              Check once and exit"
            echo "  --stats             Show restart statistics"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Stats mode
[[ "$SHOW_STATS" == true ]] && show_stats

# Validate input
if [[ -z "$PROCESS_NAME" && -z "$SERVICE_NAME" && -z "$PID_FILE" && -z "$CONFIG_FILE" ]]; then
    echo "Error: Specify --name, --service, --pidfile, or --config"
    exit 1
fi

# Config file mode (multi-process)
if [[ -n "$CONFIG_FILE" ]]; then
    if ! command -v yq &>/dev/null && ! command -v python3 &>/dev/null; then
        echo "Error: Config mode requires yq or python3 for YAML parsing"
        exit 1
    fi

    # Parse with python3 as fallback
    PROCS=$(python3 -c "
import yaml, json, sys
with open('$CONFIG_FILE') as f:
    cfg = yaml.safe_load(f)
for p in cfg.get('processes', []):
    print(json.dumps(p))
" 2>/dev/null || echo "")

    if [[ -z "$PROCS" ]]; then
        echo "Error: Failed to parse config file"
        exit 1
    fi

    log "👁️ Multi-process watchdog started from config: $CONFIG_FILE"

    while true; do
        while IFS= read -r proc_json; do
            name=$(echo "$proc_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('name',''))")
            ptype=$(echo "$proc_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('type','process'))")

            if [[ "$ptype" == "service" ]]; then
                if systemctl is-active --quiet "$name" 2>/dev/null; then
                    log "✅ ${name} — running (service)"
                else
                    log "❌ ${name} — DOWN"
                    systemctl restart "$name" 2>&1 || sudo systemctl restart "$name" 2>&1 || true
                    send_alert "🔄 Restarted service: ${name}"
                fi
            else
                local fc="${name:0:1}"
                local rr="${name:1}"
                local pp="[${fc}]${rr}"
                if ps aux | grep -E "$pp" | grep -v "watchdog\.sh" > /dev/null 2>&1; then
                    pid=$(ps aux | grep -E "$pp" | grep -v "watchdog\.sh" | awk '{print $2}' | head -1)
                    log "✅ ${name} — running (PID: ${pid})"
                else
                    log "❌ ${name} — DOWN"
                    rcmd=$(echo "$proc_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('restart_cmd',''))")
                    if [[ -n "$rcmd" ]]; then
                        eval "$rcmd" 2>&1 || true
                        send_alert "🔄 Restarted process: ${name}"
                    else
                        send_alert "❌ ${name} is down but no restart_cmd configured"
                    fi
                fi
            fi
        done <<< "$PROCS"

        [[ "$ONCE" == true ]] && exit 0
        sleep "$INTERVAL"
    done
    exit 0
fi

# Single process mode
DISPLAY_NAME="${PROCESS_NAME}${SERVICE_NAME}"
log "👁️ Watching: ${DISPLAY_NAME} (interval: ${INTERVAL}s, max_restarts: ${MAX_RESTARTS})"

# Daemonize if requested
if [[ "$DAEMON" == true ]]; then
    nohup "$0" --name "${PROCESS_NAME}" --service "${SERVICE_NAME}" \
        --restart "${RESTART_CMD}" --interval "$INTERVAL" \
        --max-restarts "$MAX_RESTARTS" --cooldown "$COOLDOWN" \
        --alert "${ALERT_TYPE}" --log "$LOG_FILE" \
        >> "$LOG_FILE" 2>&1 &
    echo "Watchdog started in background (PID: $!)"
    exit 0
fi

# Main loop
while true; do
    if check_process; then
        if check_health; then
            pid=$(get_pid)
            log "✅ ${DISPLAY_NAME} — running (PID: ${pid})"
            # Reset counter on sustained health (after 10 successful checks)
        else
            log "⚠️ ${DISPLAY_NAME} — running but unhealthy"
            restart_process
            ret=$?
            [[ $ret -eq 2 ]] && exit 1  # Max restarts exceeded
        fi
    else
        log "❌ ${DISPLAY_NAME} — DOWN"
        send_alert "❌ <b>${DISPLAY_NAME}</b> is DOWN on $(hostname)!"
        restart_process
        ret=$?
        [[ $ret -eq 2 ]] && exit 1  # Max restarts exceeded
    fi

    [[ "$ONCE" == true ]] && exit 0
    sleep "$INTERVAL"
done
