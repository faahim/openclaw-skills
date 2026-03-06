#!/usr/bin/env bash
# cron-watchdog.sh — Detects missed cron runs by comparing last execution to expected schedule
set -euo pipefail

BASE_DIR="${CRON_HEALTH_DIR:-/opt/cron-health-monitor}"
CONFIG="$BASE_DIR/config.env"
DATA_DIR="$BASE_DIR/data"
JOBS_FILE="$DATA_DIR/jobs.json"

[[ -f "$CONFIG" ]] && source "$CONFIG"
OVERDUE_FACTOR="${OVERDUE_FACTOR:-2}"

if [[ ! -f "$JOBS_FILE" ]] || ! command -v jq &>/dev/null; then
    exit 0
fi

NOW_EPOCH=$(date +%s)

# Parse cron schedule to approximate interval in seconds
cron_to_interval() {
    local sched="$1"
    local min hour dom mon dow
    read -r min hour dom mon dow <<< "$sched"

    # Common patterns
    # */N * * * * → every N minutes
    if [[ "$min" == "*/"* && "$hour" == "*" ]]; then
        local n="${min#*/}"
        echo $((n * 60))
        return
    fi
    # * * * * * → every minute
    if [[ "$min" == "*" && "$hour" == "*" ]]; then
        echo 60
        return
    fi
    # N * * * * → every hour (at minute N)
    if [[ "$min" =~ ^[0-9]+$ && "$hour" == "*" ]]; then
        echo 3600
        return
    fi
    # */N in hours
    if [[ "$hour" == "*/"* && "$dom" == "*" ]]; then
        local n="${hour#*/}"
        echo $((n * 3600))
        return
    fi
    # Specific hour, every day
    if [[ "$min" =~ ^[0-9]+$ && "$hour" =~ ^[0-9]+$ && "$dom" == "*" && "$mon" == "*" ]]; then
        echo 86400
        return
    fi
    # Weekly
    if [[ "$dow" =~ ^[0-9]+$ && "$dom" == "*" ]]; then
        echo 604800
        return
    fi
    # Monthly (specific day)
    if [[ "$dom" =~ ^[0-9]+$ ]]; then
        echo 2592000
        return
    fi
    # Default: assume daily
    echo 86400
}

# Check each registered job
jq -r 'to_entries[] | "\(.key)\t\(.value.schedule)\t\(.value.alert_on_fail // true)"' "$JOBS_FILE" | while IFS=$'\t' read -r job_name schedule alert_on_fail; do
    [[ "$alert_on_fail" == "false" ]] && continue

    LOG_FILE="$DATA_DIR/${job_name}.jsonl"
    [[ ! -f "$LOG_FILE" ]] && continue

    # Get last run timestamp
    LAST_RUN=$(tail -1 "$LOG_FILE" | jq -r '.ts // empty' 2>/dev/null)
    [[ -z "$LAST_RUN" ]] && continue

    # Convert to epoch
    LAST_EPOCH=$(date -d "$LAST_RUN" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$LAST_RUN" +%s 2>/dev/null || echo 0)
    [[ "$LAST_EPOCH" -eq 0 ]] && continue

    # Calculate expected interval
    INTERVAL=$(cron_to_interval "$schedule")
    OVERDUE_THRESHOLD=$((INTERVAL * OVERDUE_FACTOR))

    # Check if overdue
    ELAPSED=$((NOW_EPOCH - LAST_EPOCH))
    if [[ "$ELAPSED" -gt "$OVERDUE_THRESHOLD" ]]; then
        HOURS_AGO=$((ELAPSED / 3600))
        MINS_AGO=$(( (ELAPSED % 3600) / 60 ))

        MSG="🚨 CRON MISSED: ${job_name}
Schedule: ${schedule}
Last run: ${LAST_RUN} (${HOURS_AGO}h ${MINS_AGO}m ago)
Expected interval: $((INTERVAL / 60))m
Status: OVERDUE"

        # Send alert (reuse alert logic)
        if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
            # Check cooldown
            COOLDOWN_FILE="$DATA_DIR/.cooldown_missed_${job_name}"
            SEND=true
            if [[ -f "$COOLDOWN_FILE" ]]; then
                LAST_ALERT=$(cat "$COOLDOWN_FILE")
                DIFF=$(( (NOW_EPOCH - LAST_ALERT) / 60 ))
                [[ "$DIFF" -lt "${ALERT_COOLDOWN_MINUTES:-30}" ]] && SEND=false
            fi

            if [[ "$SEND" == "true" ]]; then
                date +%s > "$COOLDOWN_FILE"
                curl -sf "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                    -d "chat_id=${TELEGRAM_CHAT_ID}" \
                    -d "text=${MSG}" \
                    --max-time 10 >/dev/null 2>&1 || true
            fi
        fi

        if [[ -n "${WEBHOOK_URL:-}" ]]; then
            curl -sf -X POST "$WEBHOOK_URL" \
                -H "Content-Type: application/json" \
                -d "{\"text\":\"${MSG}\"}" \
                --max-time 10 >/dev/null 2>&1 || true
        fi

        echo "$MSG"
    fi
done
