#!/usr/bin/env bash
# cronwrap.sh — Cron job wrapper that tracks execution, alerts on failure
# Usage: cronwrap.sh <job-name> <schedule> [--timeout N] <command> [args...]
set -euo pipefail

BASE_DIR="${CRON_HEALTH_DIR:-/opt/cron-health-monitor}"
CONFIG="$BASE_DIR/config.env"
DATA_DIR="$BASE_DIR/data"

# Load config
[[ -f "$CONFIG" ]] && source "$CONFIG"

# Defaults
MAX_LOG_ENTRIES="${MAX_LOG_ENTRIES:-1000}"
CAPTURE_OUTPUT="${CAPTURE_OUTPUT:-true}"
MAX_OUTPUT_LINES="${MAX_OUTPUT_LINES:-50}"
DEFAULT_TIMEOUT="${DEFAULT_TIMEOUT:-0}"
ALERT_COOLDOWN_MINUTES="${ALERT_COOLDOWN_MINUTES:-30}"

# Parse args
JOB_NAME="$1"; shift
SCHEDULE="$1"; shift

TIMEOUT="$DEFAULT_TIMEOUT"
if [[ "${1:-}" == "--timeout" ]]; then
    shift; TIMEOUT="$1"; shift
fi

COMMAND=("$@")

# Ensure data dir
mkdir -p "$DATA_DIR"

# Register job in jobs.json
JOBS_FILE="$DATA_DIR/jobs.json"
if [[ ! -f "$JOBS_FILE" ]]; then
    echo '{}' > "$JOBS_FILE"
fi

# Update job registry (if jq available)
if command -v jq &>/dev/null; then
    NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq --arg name "$JOB_NAME" \
       --arg sched "$SCHEDULE" \
       --arg ts "$NOW_ISO" \
       --argjson timeout "$TIMEOUT" \
       'if .[$name] then .[$name].schedule = $sched | .[$name].timeout = $timeout
        else .[$name] = {"schedule": $sched, "registered": $ts, "timeout": $timeout, "alert_on_fail": true}
        end' "$JOBS_FILE" > "$JOBS_FILE.tmp" && mv "$JOBS_FILE.tmp" "$JOBS_FILE"
fi

# Temp files for output capture
STDOUT_FILE=$(mktemp)
STDERR_FILE=$(mktemp)
trap 'rm -f "$STDOUT_FILE" "$STDERR_FILE"' EXIT

# Run the command
START_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
START_EPOCH=$(date +%s)

EXIT_CODE=0
TIMED_OUT=false

if [[ "$TIMEOUT" -gt 0 ]]; then
    # Run with timeout
    timeout --signal=TERM --kill-after=10 "$TIMEOUT" "${COMMAND[@]}" \
        >"$STDOUT_FILE" 2>"$STDERR_FILE" || EXIT_CODE=$?
    # timeout returns 124 on SIGTERM, 137 on SIGKILL
    if [[ $EXIT_CODE -eq 124 || $EXIT_CODE -eq 137 ]]; then
        TIMED_OUT=true
    fi
else
    "${COMMAND[@]}" >"$STDOUT_FILE" 2>"$STDERR_FILE" || EXIT_CODE=$?
fi

END_EPOCH=$(date +%s)
DURATION=$((END_EPOCH - START_EPOCH))

# Count output lines
STDOUT_LINES=$(wc -l < "$STDOUT_FILE" 2>/dev/null || echo 0)
STDERR_LINES=$(wc -l < "$STDERR_FILE" 2>/dev/null || echo 0)

# Determine status
STATUS="ok"
[[ $EXIT_CODE -ne 0 ]] && STATUS="fail"
[[ "$TIMED_OUT" == "true" ]] && STATUS="timeout"

# Capture truncated output
STDERR_PREVIEW=""
if [[ "$CAPTURE_OUTPUT" == "true" && "$STDERR_LINES" -gt 0 ]]; then
    STDERR_PREVIEW=$(head -n "$MAX_OUTPUT_LINES" "$STDERR_FILE" | tr '\n' '\\n' | sed 's/"/\\"/g')
fi

# Log entry (JSON Lines)
LOG_FILE="$DATA_DIR/${JOB_NAME}.jsonl"
if command -v jq &>/dev/null; then
    jq -nc \
        --arg job "$JOB_NAME" \
        --arg ts "$START_TS" \
        --argjson dur "$DURATION" \
        --argjson exit_code "$EXIT_CODE" \
        --arg status "$STATUS" \
        --argjson stdout_lines "$STDOUT_LINES" \
        --argjson stderr_lines "$STDERR_LINES" \
        --arg stderr "$STDERR_PREVIEW" \
        --argjson timed_out "$TIMED_OUT" \
        '{job:$job,ts:$ts,duration_s:$dur,exit:$exit_code,status:$status,stdout_lines:$stdout_lines,stderr_lines:$stderr_lines,stderr_preview:$stderr,timed_out:$timed_out}' \
        >> "$LOG_FILE"
else
    echo "{\"job\":\"$JOB_NAME\",\"ts\":\"$START_TS\",\"duration_s\":$DURATION,\"exit\":$EXIT_CODE,\"status\":\"$STATUS\"}" >> "$LOG_FILE"
fi

# Prune old entries
if command -v jq &>/dev/null && [[ -f "$LOG_FILE" ]]; then
    TOTAL=$(wc -l < "$LOG_FILE")
    if [[ "$TOTAL" -gt "$MAX_LOG_ENTRIES" ]]; then
        KEEP=$((MAX_LOG_ENTRIES * 3 / 4))
        tail -n "$KEEP" "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
fi

# Send alert on failure
send_alert() {
    local MSG="$1"

    # Check cooldown
    COOLDOWN_FILE="$DATA_DIR/.cooldown_${JOB_NAME}"
    if [[ -f "$COOLDOWN_FILE" ]]; then
        LAST_ALERT=$(cat "$COOLDOWN_FILE")
        NOW_EPOCH=$(date +%s)
        DIFF=$(( (NOW_EPOCH - LAST_ALERT) / 60 ))
        if [[ "$DIFF" -lt "$ALERT_COOLDOWN_MINUTES" ]]; then
            return 0  # Still in cooldown
        fi
    fi
    date +%s > "$COOLDOWN_FILE"

    # Telegram
    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
        curl -sf "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${MSG}" \
            -d "parse_mode=HTML" \
            --max-time 10 >/dev/null 2>&1 || true
    fi

    # Webhook
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        curl -sf -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"${MSG}\"}" \
            --max-time 10 >/dev/null 2>&1 || true
    fi

    # Email
    if [[ -n "${ALERT_EMAIL:-}" ]] && command -v sendmail &>/dev/null; then
        echo -e "Subject: CRON FAIL: ${JOB_NAME}\n\n${MSG}" | sendmail "$ALERT_EMAIL" 2>/dev/null || true
    fi
}

if [[ "$STATUS" != "ok" ]]; then
    # Check if alerts enabled for this job
    ALERT_ENABLED=true
    if command -v jq &>/dev/null && [[ -f "$JOBS_FILE" ]]; then
        ALERT_ENABLED=$(jq -r --arg name "$JOB_NAME" '.[$name].alert_on_fail // true' "$JOBS_FILE")
    fi

    if [[ "$ALERT_ENABLED" == "true" ]]; then
        STDERR_MSG=""
        [[ -n "$STDERR_PREVIEW" ]] && STDERR_MSG="
stderr: $(head -n 3 "$STDERR_FILE")"

        if [[ "$TIMED_OUT" == "true" ]]; then
            ALERT_MSG="🚨 CRON TIMEOUT: ${JOB_NAME}
Duration: ${DURATION}s (limit: ${TIMEOUT}s)
Time: ${START_TS}${STDERR_MSG}"
        else
            ALERT_MSG="🚨 CRON FAIL: ${JOB_NAME}
Exit code: ${EXIT_CODE}
Duration: ${DURATION}s
Time: ${START_TS}${STDERR_MSG}"
        fi
        send_alert "$ALERT_MSG"
    fi
fi

# Pass through original stdout
cat "$STDOUT_FILE"

# Exit with original code
exit $EXIT_CODE
