#!/bin/bash
# Thermal Monitor — Main Script
# Monitors CPU/GPU/disk temperatures, logs data, sends alerts on overheating.
set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────
INTERVAL=60
WARN_THRESHOLD=85
CRIT_THRESHOLD=95
ALERT_METHOD=""
LOG_FILE=""
REPORT_MODE=""
ONE_SHOT=false
JSON_OUTPUT=false
QUIET=false
COOLDOWN=300
FALLBACK_SYSFS=false
SENSORS_FILTER=""
SENSORS_EXCLUDE=""
HOSTNAME=$(hostname 2>/dev/null || echo "unknown")

# Alert state tracking (avoid spam)
declare -A LAST_ALERT_TIME 2>/dev/null || true

# ── Parse Arguments ─────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --once)         ONE_SHOT=true; shift ;;
        --interval)     INTERVAL="$2"; shift 2 ;;
        --warn)         WARN_THRESHOLD="$2"; shift 2 ;;
        --crit)         CRIT_THRESHOLD="$2"; shift 2 ;;
        --alert)        ALERT_METHOD="$2"; shift 2 ;;
        --log)          LOG_FILE="$2"; shift 2 ;;
        --report)       REPORT_MODE="$2"; shift 2 ;;
        --json)         JSON_OUTPUT=true; shift ;;
        --quiet)        QUIET=true; shift ;;
        --cooldown)     COOLDOWN="$2"; shift 2 ;;
        --fallback-sysfs) FALLBACK_SYSFS=true; shift ;;
        --sensors)      SENSORS_FILTER="$2"; shift 2 ;;
        --exclude)      SENSORS_EXCLUDE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: bash run.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --once            Single check, then exit"
            echo "  --interval N      Check every N seconds (default: 60)"
            echo "  --warn N          Warning threshold °C (default: 85)"
            echo "  --crit N          Critical threshold °C (default: 95)"
            echo "  --alert TYPE      Alert: telegram, email, webhook, all"
            echo "  --log FILE        Log to CSV file"
            echo "  --report TYPE     Report: daily, weekly (needs --log)"
            echo "  --json            JSON output"
            echo "  --quiet           Only show warnings/criticals"
            echo "  --cooldown N      Min seconds between repeat alerts (default: 300)"
            echo "  --fallback-sysfs  Use /sys/class/thermal instead of lm-sensors"
            echo "  --sensors FILTER  Only monitor matching chips (glob pattern)"
            echo "  --exclude FILTER  Exclude matching chips (glob pattern)"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Report Mode ─────────────────────────────────────────────────
if [[ -n "$REPORT_MODE" ]]; then
    if [[ -z "$LOG_FILE" || ! -f "$LOG_FILE" ]]; then
        echo "❌ --report requires --log with an existing log file"
        exit 1
    fi

    DAYS=1
    [[ "$REPORT_MODE" == "weekly" ]] && DAYS=7
    CUTOFF=$(date -d "-${DAYS} days" '+%Y-%m-%d' 2>/dev/null || date -v-${DAYS}d '+%Y-%m-%d' 2>/dev/null || echo "")

    echo "📊 ${REPORT_MODE^} Thermal Summary ($(date '+%Y-%m-%d'))"
    echo "┌─────────────────────┬──────┬──────┬──────┐"
    echo "│ Sensor              │ Min  │ Avg  │ Max  │"
    echo "├─────────────────────┼──────┼──────┼──────┤"

    # Parse CSV log: timestamp,sensor,chip,temp
    awk -F',' -v cutoff="$CUTOFF" '
        $1 >= cutoff {
            sensor=$2
            temp=$4+0
            if (!(sensor in count)) { min[sensor]=temp; max[sensor]=temp; sum[sensor]=0; count[sensor]=0 }
            sum[sensor]+=temp; count[sensor]++
            if (temp < min[sensor]) min[sensor]=temp
            if (temp > max[sensor]) max[sensor]=temp
        }
        END {
            for (s in count) {
                avg = sum[s]/count[s]
                printf "│ %-19s │ %4d │ %4d │ %4d │\n", substr(s,1,19), min[s], avg, max[s]
            }
        }
    ' "$LOG_FILE"

    echo "└─────────────────────┴──────┴──────┴──────┘"
    exit 0
fi

# ── Sensor Reading Functions ────────────────────────────────────

read_sensors_lmsensors() {
    # Parse lm-sensors output into: sensor_name chip temp
    sensors -u 2>/dev/null | awk '
        /^[a-zA-Z]/ { chip=$0; sub(/:$/, "", chip) }
        /^  [a-zA-Z]/ {
            sensor=$0
            sub(/^  /, "", sensor)
            sub(/:$/, "", sensor)
        }
        /_input:/ {
            temp=$2+0
            if (temp > 0 && temp < 150) {
                printf "%s\t%s\t%.0f\n", sensor, chip, temp
            }
        }
    '
}

read_sensors_sysfs() {
    # Fallback: read from /sys/class/thermal
    for zone in /sys/class/thermal/thermal_zone*/; do
        [ -d "$zone" ] || continue
        type=$(cat "${zone}type" 2>/dev/null || echo "unknown")
        temp_raw=$(cat "${zone}temp" 2>/dev/null || echo "0")
        temp=$((temp_raw / 1000))
        if [[ $temp -gt 0 && $temp -lt 150 ]]; then
            printf "%s\tsysfs\t%d\n" "$type" "$temp"
        fi
    done

    # Also check NVIDIA GPU
    if command -v nvidia-smi &>/dev/null; then
        gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [[ -n "$gpu_temp" && "$gpu_temp" -gt 0 ]]; then
            printf "NVIDIA GPU\tnvidia-smi\t%d\n" "$gpu_temp"
        fi
    fi
}

read_sensors() {
    if [[ "$FALLBACK_SYSFS" == "true" ]] || ! command -v sensors &>/dev/null; then
        read_sensors_sysfs
    else
        read_sensors_lmsensors

        # Also add NVIDIA GPU if available
        if command -v nvidia-smi &>/dev/null; then
            gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
            if [[ -n "$gpu_temp" && "$gpu_temp" -gt 0 ]]; then
                printf "NVIDIA GPU\tnvidia-smi\t%d\n" "$gpu_temp"
            fi
        fi
    fi
}

# ── Alert Functions ─────────────────────────────────────────────

send_telegram() {
    local msg="$1"
    local token="${THERMAL_TELEGRAM_BOT_TOKEN:-}"
    local chat_id="${THERMAL_TELEGRAM_CHAT_ID:-}"

    if [[ -z "$token" || -z "$chat_id" ]]; then
        echo "⚠️  Telegram not configured (set THERMAL_TELEGRAM_BOT_TOKEN and THERMAL_TELEGRAM_CHAT_ID)" >&2
        return 1
    fi

    curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -d chat_id="$chat_id" \
        -d text="$msg" \
        -d parse_mode="HTML" >/dev/null 2>&1
}

send_email() {
    local msg="$1"
    local host="${THERMAL_SMTP_HOST:-}"
    local port="${THERMAL_SMTP_PORT:-587}"
    local user="${THERMAL_SMTP_USER:-}"
    local pass="${THERMAL_SMTP_PASS:-}"
    local to="${THERMAL_SMTP_TO:-}"

    if [[ -z "$host" || -z "$user" || -z "$to" ]]; then
        echo "⚠️  Email not configured" >&2
        return 1
    fi

    echo -e "Subject: Thermal Alert - $HOSTNAME\n\n$msg" | \
        curl -s --url "smtp://${host}:${port}" \
        --ssl-reqd \
        --mail-from "$user" \
        --mail-rcpt "$to" \
        --user "${user}:${pass}" \
        -T - 2>/dev/null
}

send_webhook() {
    local msg="$1"
    local url="${THERMAL_WEBHOOK_URL:-}"

    if [[ -z "$url" ]]; then
        echo "⚠️  Webhook not configured (set THERMAL_WEBHOOK_URL)" >&2
        return 1
    fi

    curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$msg\", \"hostname\": \"$HOSTNAME\"}" >/dev/null 2>&1
}

send_alert() {
    local sensor="$1"
    local temp="$2"
    local level="$3"  # warning or critical
    local threshold="$4"

    # Cooldown check
    local now=$(date +%s)
    local key="${sensor}_${level}"
    local last=${LAST_ALERT_TIME[$key]:-0}
    if (( now - last < COOLDOWN )); then
        return 0
    fi
    LAST_ALERT_TIME[$key]=$now

    local emoji="⚠️"
    local label="WARNING"
    [[ "$level" == "critical" ]] && emoji="🔥" && label="CRITICAL"

    local msg="${emoji} THERMAL ${label}: ${sensor} at ${temp}°C (threshold: ${threshold}°C) on ${HOSTNAME}"

    case "$ALERT_METHOD" in
        telegram)  send_telegram "$msg" ;;
        email)     send_email "$msg" ;;
        webhook)   send_webhook "$msg" ;;
        all)
            send_telegram "$msg" 2>/dev/null || true
            send_email "$msg" 2>/dev/null || true
            send_webhook "$msg" 2>/dev/null || true
            ;;
    esac
}

# ── Main Check Function ────────────────────────────────────────

do_check() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local timestamp_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local any_warning=false
    local json_sensors=""

    if [[ "$JSON_OUTPUT" != "true" && "$QUIET" != "true" ]]; then
        echo "[$timestamp] 🌡️ Thermal Report"
    fi

    while IFS=$'\t' read -r sensor chip temp; do
        # Apply filters
        if [[ -n "$SENSORS_FILTER" ]]; then
            local match=false
            IFS=',' read -ra FILTERS <<< "$SENSORS_FILTER"
            for f in "${FILTERS[@]}"; do
                [[ "$chip" == $f ]] && match=true
            done
            [[ "$match" == "false" ]] && continue
        fi

        if [[ -n "$SENSORS_EXCLUDE" ]]; then
            local excluded=false
            IFS=',' read -ra EXCLUDES <<< "$SENSORS_EXCLUDE"
            for e in "${EXCLUDES[@]}"; do
                [[ "$chip" == $e ]] && excluded=true
            done
            [[ "$excluded" == "true" ]] && continue
        fi

        # Determine status
        local status="ok"
        local status_icon="✅"
        if (( temp >= CRIT_THRESHOLD )); then
            status="critical"
            status_icon="🔥"
            any_warning=true
            [[ -n "$ALERT_METHOD" ]] && send_alert "$sensor" "$temp" "critical" "$CRIT_THRESHOLD"
        elif (( temp >= WARN_THRESHOLD )); then
            status="warning"
            status_icon="⚠️"
            any_warning=true
            [[ -n "$ALERT_METHOD" ]] && send_alert "$sensor" "$temp" "warning" "$WARN_THRESHOLD"
        fi

        # Output
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            [[ -n "$json_sensors" ]] && json_sensors+=","
            json_sensors+="{\"name\":\"$sensor\",\"chip\":\"$chip\",\"temp\":$temp,\"warn\":$WARN_THRESHOLD,\"crit\":$CRIT_THRESHOLD,\"status\":\"$status\"}"
        elif [[ "$QUIET" != "true" || "$status" != "ok" ]]; then
            printf "  %-18s %3d°C  (warn: %d°C, crit: %d°C) %s\n" "$sensor" "$temp" "$WARN_THRESHOLD" "$CRIT_THRESHOLD" "$status_icon"
        fi

        # Log to CSV
        if [[ -n "$LOG_FILE" ]]; then
            echo "${timestamp},${sensor},${chip},${temp},${status}" >> "$LOG_FILE"
        fi

    done < <(read_sensors)

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "{\"timestamp\":\"$timestamp_iso\",\"hostname\":\"$HOSTNAME\",\"sensors\":[$json_sensors]}"
    fi
}

# ── Main Loop ───────────────────────────────────────────────────

if [[ "$ONE_SHOT" == "true" ]]; then
    do_check
else
    echo "🌡️ Thermal Monitor started (interval: ${INTERVAL}s, warn: ${WARN_THRESHOLD}°C, crit: ${CRIT_THRESHOLD}°C)"
    echo "   Press Ctrl+C to stop"
    echo ""

    trap 'echo ""; echo "🛑 Thermal Monitor stopped."; exit 0' INT TERM

    while true; do
        do_check
        sleep "$INTERVAL"
    done
fi
