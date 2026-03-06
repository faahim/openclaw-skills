#!/usr/bin/env bash
# cron-report.sh — Generate health reports for monitored cron jobs
set -euo pipefail

BASE_DIR="${CRON_HEALTH_DIR:-/opt/cron-health-monitor}"
CONFIG="$BASE_DIR/config.env"
DATA_DIR="$BASE_DIR/data"

[[ -f "$CONFIG" ]] && source "$CONFIG"

# Defaults
DAYS=7
JOB_FILTER=""
FAILURES_ONLY=false
EXPORT_FORMAT=""
SEND_TG=false
PRUNE=false
LIMIT=20

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --days) DAYS="$2"; shift 2 ;;
        --job) JOB_FILTER="$2"; shift 2 ;;
        --failures) FAILURES_ONLY=true; shift ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --export) EXPORT_FORMAT="$2"; shift 2 ;;
        --send-telegram) SEND_TG=true; shift ;;
        --prune) PRUNE=true; shift ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required. Install with: sudo apt-get install jq" >&2
    exit 1
fi

# Calculate cutoff date
CUTOFF=$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
         date -u -v-${DAYS}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
         echo "2000-01-01T00:00:00Z")

# Prune mode
if [[ "$PRUNE" == "true" ]]; then
    MAX="${MAX_LOG_ENTRIES:-1000}"
    for f in "$DATA_DIR"/*.jsonl; do
        [[ ! -f "$f" ]] && continue
        TOTAL=$(wc -l < "$f")
        if [[ "$TOTAL" -gt "$MAX" ]]; then
            KEEP=$((MAX * 3 / 4))
            tail -n "$KEEP" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
            echo "Pruned $(basename "$f"): $TOTAL → $KEEP entries"
        fi
    done
    exit 0
fi

# Failures-only mode
if [[ "$FAILURES_ONLY" == "true" ]]; then
    echo "Recent Failures:"
    echo "─────────────────────────────────────────────"

    for f in "$DATA_DIR"/*.jsonl; do
        [[ ! -f "$f" ]] && continue
        [[ -n "$JOB_FILTER" ]] && [[ "$(basename "$f" .jsonl)" != "$JOB_FILTER" ]] && continue

        jq -r --arg cutoff "$CUTOFF" \
            'select(.ts > $cutoff and .status != "ok") |
             "\(.ts) │ \(.job) │ exit \(.exit) │ \(.stderr_preview // "no details")[0:60]"' \
            "$f" 2>/dev/null
    done | sort -r | head -n "$LIMIT"
    exit 0
fi

# CSV export
if [[ "$EXPORT_FORMAT" == "csv" ]]; then
    echo "timestamp,job,duration_s,exit_code,status,stdout_lines,stderr_lines"
    for f in "$DATA_DIR"/*.jsonl; do
        [[ ! -f "$f" ]] && continue
        [[ -n "$JOB_FILTER" ]] && [[ "$(basename "$f" .jsonl)" != "$JOB_FILTER" ]] && continue

        jq -r --arg cutoff "$CUTOFF" \
            'select(.ts > $cutoff) |
             [.ts, .job, .duration_s, .exit, .status, .stdout_lines, .stderr_lines] | @csv' \
            "$f" 2>/dev/null
    done
    exit 0
fi

# Main report
REPORT=""
TOTAL_RUNS=0
TOTAL_PASS=0
TOTAL_FAIL=0

REPORT+="╔══════════════════════════════════════════════════════╗
║           CRON HEALTH REPORT — Last ${DAYS} Day(s)          ║
╠══════════════════════════════════════════════════════╣
║ Job              │ Runs │ Pass │ Fail │ Avg Time     ║
╠──────────────────┼──────┼──────┼──────┼──────────────╣
"

FAILURES=""

for f in "$DATA_DIR"/*.jsonl; do
    [[ ! -f "$f" ]] && continue
    JOB=$(basename "$f" .jsonl)
    [[ -n "$JOB_FILTER" ]] && [[ "$JOB" != "$JOB_FILTER" ]] && continue

    # Aggregate stats
    STATS=$(jq -s --arg cutoff "$CUTOFF" '
        [.[] | select(.ts > $cutoff)] |
        {
            runs: length,
            pass: [.[] | select(.status == "ok")] | length,
            fail: [.[] | select(.status != "ok")] | length,
            avg_dur: (if length > 0 then ([.[].duration_s] | add / length | floor) else 0 end)
        }
    ' "$f" 2>/dev/null)

    RUNS=$(echo "$STATS" | jq '.runs')
    PASS=$(echo "$STATS" | jq '.pass')
    FAIL=$(echo "$STATS" | jq '.fail')
    AVG=$(echo "$STATS" | jq '.avg_dur')

    [[ "$RUNS" -eq 0 ]] && continue

    TOTAL_RUNS=$((TOTAL_RUNS + RUNS))
    TOTAL_PASS=$((TOTAL_PASS + PASS))
    TOTAL_FAIL=$((TOTAL_FAIL + FAIL))

    # Format avg time
    if [[ "$AVG" -lt 1 ]]; then
        AVG_STR="<1s"
    elif [[ "$AVG" -lt 60 ]]; then
        AVG_STR="${AVG}s"
    else
        AVG_STR="$((AVG / 60))m $((AVG % 60))s"
    fi

    printf -v LINE "║ %-16s │ %4d │ %4d │ %4d │ %-12s ║\n" "$JOB" "$RUNS" "$PASS" "$FAIL" "$AVG_STR"
    REPORT+="$LINE"

    # Collect failure details
    if [[ "$FAIL" -gt 0 ]]; then
        FAIL_DETAILS=$(jq -r --arg cutoff "$CUTOFF" \
            'select(.ts > $cutoff and .status != "ok") |
             "  \(.job) — \(.ts) — exit \(.exit)\(if .stderr_preview != "" then "\n  stderr: \(.stderr_preview[0:80])" else "" end)"' \
            "$f" 2>/dev/null | head -n 10)
        FAILURES+="$FAIL_DETAILS
"
    fi
done

# Summary
if [[ "$TOTAL_RUNS" -gt 0 ]]; then
    PASS_PCT=$(( (TOTAL_PASS * 1000) / TOTAL_RUNS ))
    PASS_PCT_STR="$((PASS_PCT / 10)).$((PASS_PCT % 10))%"
else
    PASS_PCT_STR="N/A"
fi

REPORT+="╠──────────────────┼──────┼──────┼──────┼──────────────╣
"
printf -v SUMMARY "║ TOTAL            │ %4d │ %4d │ %4d │ %s pass    ║\n" "$TOTAL_RUNS" "$TOTAL_PASS" "$TOTAL_FAIL" "$PASS_PCT_STR"
REPORT+="$SUMMARY"
REPORT+="╚══════════════════════════════════════════════════════╝
"

if [[ -n "$FAILURES" ]]; then
    REPORT+="
⚠️  ${TOTAL_FAIL} failure(s) detected:
$FAILURES"
fi

echo "$REPORT"

# Send to Telegram if requested
if [[ "$SEND_TG" == "true" && -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    # Telegram has 4096 char limit, truncate if needed
    TG_MSG=$(echo "$REPORT" | head -c 4000)
    curl -sf "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=<pre>${TG_MSG}</pre>" \
        -d "parse_mode=HTML" \
        --max-time 10 >/dev/null 2>&1 || true
fi
