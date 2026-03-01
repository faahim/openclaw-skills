#!/bin/bash
# monitor.sh — Continuous cron job monitor with alerting
set -euo pipefail

DATA_DIR="${CRON_MONITOR_DATA:-$HOME/.cron-monitor/data}"
CONFIG_FILE=""
WATCHLIST=""
ALERT_STATE_FILE="$DATA_DIR/alert-state.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$DATA_DIR"

while [[ $# -gt 0 ]]; do
    case $1 in
        --config) CONFIG_FILE="$2"; shift 2 ;;
        --watchlist) WATCHLIST="$2"; shift 2 ;;
        --once) RUN_ONCE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

RUN_ONCE="${RUN_ONCE:-false}"

# Load config
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
WEBHOOK_URL=""
CHECK_HOURS=1
SLOW_THRESHOLD=300

if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    # Simple YAML parser for key values
    if command -v yq &>/dev/null; then
        TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-$(yq '.alerts.telegram.bot_token // ""' "$CONFIG_FILE" 2>/dev/null || echo "")}"
        TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-$(yq '.alerts.telegram.chat_id // ""' "$CONFIG_FILE" 2>/dev/null || echo "")}"
        WEBHOOK_URL=$(yq '.alerts.webhook.url // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
        SLOW_THRESHOLD=$(yq '.thresholds.slow_seconds // 300' "$CONFIG_FILE" 2>/dev/null || echo "300")
    fi
fi

# Initialize alert state
if [[ ! -f "$ALERT_STATE_FILE" ]]; then
    echo '{}' > "$ALERT_STATE_FILE"
fi

# Send Telegram alert
send_telegram() {
    local message="$1"
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        # Expand env vars in token/chat_id
        local token
        token=$(eval echo "$TELEGRAM_BOT_TOKEN" 2>/dev/null || echo "$TELEGRAM_BOT_TOKEN")
        local chat_id
        chat_id=$(eval echo "$TELEGRAM_CHAT_ID" 2>/dev/null || echo "$TELEGRAM_CHAT_ID")
        
        curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
            -d "chat_id=${chat_id}" \
            -d "text=${message}" \
            -d "parse_mode=HTML" \
            --max-time 10 >/dev/null 2>&1 || \
            echo "[WARN] Failed to send Telegram alert"
    fi
}

# Send webhook alert
send_webhook() {
    local message="$1"
    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"$message\"}" \
            --max-time 10 >/dev/null 2>&1 || \
            echo "[WARN] Failed to send webhook alert"
    fi
}

# Send alert through all configured channels
send_alert() {
    local message="$1"
    local job_key="$2"
    
    # Check if we already alerted for this (avoid spam)
    local last_alert
    last_alert=$(jq -r ".\"$job_key\" // 0" "$ALERT_STATE_FILE" 2>/dev/null || echo "0")
    local now
    now=$(date +%s)
    local cooldown=3600  # 1 hour between same alerts
    
    if [[ $((now - last_alert)) -lt $cooldown ]]; then
        echo "[INFO] Alert suppressed for $job_key (cooldown active)"
        return
    fi
    
    # Update alert state
    local tmp
    tmp=$(mktemp)
    jq ".\"$job_key\" = $now" "$ALERT_STATE_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$ALERT_STATE_FILE" || rm -f "$tmp"
    
    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")
    local full_message="🚨 CRON ALERT — $hostname

$message"
    
    send_telegram "$full_message"
    send_webhook "$full_message"
    echo "[ALERT] $message"
}

# Main monitoring logic
monitor_once() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] Running cron monitor check..."
    
    # Get recent cron log entries
    local logs=""
    if command -v journalctl &>/dev/null; then
        logs=$(journalctl -u cron --since "$CHECK_HOURS hours ago" --no-pager 2>/dev/null || \
               journalctl _COMM=cron --since "$CHECK_HOURS hours ago" --no-pager 2>/dev/null || \
               journalctl -t CRON --since "$CHECK_HOURS hours ago" --no-pager 2>/dev/null || \
               echo "")
    fi
    
    if [[ -z "$logs" ]] && [[ -r /var/log/syslog ]]; then
        logs=$(grep -i "cron" /var/log/syslog 2>/dev/null | tail -500 || echo "")
    fi
    
    if [[ -z "$logs" ]]; then
        echo "[$timestamp] No cron logs found"
        return
    fi
    
    # Check for failures (non-zero exit, errors)
    local failures
    failures=$(echo "$logs" | grep -iE "(error|fail|DEATH|no MTA|permission denied)" || echo "")
    
    if [[ -n "$failures" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            
            # Extract command if possible
            local cmd="unknown"
            if [[ "$line" =~ CMD[[:space:]]*\((.+)\) ]]; then
                cmd="${BASH_REMATCH[1]}"
            fi
            
            # Check watchlist filter
            if [[ -n "$WATCHLIST" && -f "$WATCHLIST" ]]; then
                local matched=false
                while IFS= read -r watch_item; do
                    [[ -z "$watch_item" || "$watch_item" =~ ^# ]] && continue
                    if [[ "$cmd" == *"$watch_item"* || "$line" == *"$watch_item"* ]]; then
                        matched=true
                        break
                    fi
                done < "$WATCHLIST"
                [[ "$matched" = false ]] && continue
            fi
            
            local alert_key
            alert_key=$(echo "$cmd" | md5sum | cut -c1-8)
            send_alert "❌ FAILED: $cmd
Line: $line" "fail_${alert_key}"
            
        done <<< "$failures"
    fi
    
    # Check for expected jobs that DIDN'T run (missed schedules)
    if [[ -f "$DATA_DIR/crontab-entries.json" ]]; then
        local expected_jobs
        expected_jobs=$(jq -r '.jobs[]? | .command' "$DATA_DIR/crontab-entries.json" 2>/dev/null || echo "")
        
        while IFS= read -r expected_cmd; do
            [[ -z "$expected_cmd" ]] && continue
            
            local base
            base=$(echo "$expected_cmd" | awk '{print $1}' | xargs basename 2>/dev/null || echo "")
            [[ -z "$base" ]] && continue
            
            # Check watchlist filter
            if [[ -n "$WATCHLIST" && -f "$WATCHLIST" ]]; then
                grep -q "$base" "$WATCHLIST" 2>/dev/null || continue
            fi
            
            # Check if it ran
            if ! echo "$logs" | grep -q "$base"; then
                # Might be missed — but only alert if it SHOULD have run in this window
                # For now, log a warning (schedule parsing is complex)
                echo "[$timestamp] ⚠️  No execution found for: $base (may be normal if not scheduled in this window)"
            fi
        done <<< "$expected_jobs"
    fi
    
    echo "[$timestamp] Monitor check complete"
}

# Run
monitor_once

if [[ "$RUN_ONCE" != "true" ]]; then
    echo ""
    echo "Single check complete. To run continuously, add to crontab:"
    echo "  */10 * * * * $SCRIPT_DIR/monitor.sh --once >> $DATA_DIR/../logs/monitor.log 2>&1"
fi
