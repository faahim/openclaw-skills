#!/bin/bash
# Simple uptime monitor that alerts via ntfy
# Usage: bash monitor.sh --url https://example.com --topic alerts --interval 300
set -e

SERVER="${NTFY_SERVER:-https://ntfy.sh}"
TOPIC="${NTFY_TOPIC:-alerts}"
TOKEN="${NTFY_TOKEN:-}"
URL=""
INTERVAL=300
TIMEOUT=10
EXPECT_CODE=200
CONSECUTIVE_FAILURES=0
ALERT_THRESHOLD=2
ALERTED=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --server) SERVER="$2"; shift 2 ;;
        --topic) TOPIC="$2"; shift 2 ;;
        --token) TOKEN="$2"; shift 2 ;;
        --url) URL="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --expect) EXPECT_CODE="$2"; shift 2 ;;
        --threshold) ALERT_THRESHOLD="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [ -z "$URL" ]; then
    echo "Usage: monitor.sh --url <URL> --topic <TOPIC> [--interval 300] [--timeout 10]"
    exit 1
fi

send_alert() {
    local msg="$1"
    local priority="$2"
    local tags="$3"
    
    HEADERS=(-H "Priority: $priority" -H "Tags: $tags" -H "Title: Uptime Alert")
    [ -n "$TOKEN" ] && HEADERS+=(-H "Authorization: Bearer $TOKEN")
    
    curl -s "${HEADERS[@]}" -d "$msg" "${SERVER}/${TOPIC}" >/dev/null 2>&1
    echo "🚨 Alert sent: $msg"
}

echo "🔍 Monitoring $URL every ${INTERVAL}s (alert after $ALERT_THRESHOLD failures)"

while true; do
    START=$(date +%s%3N 2>/dev/null || date +%s)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$URL" 2>/dev/null || echo "000")
    END=$(date +%s%3N 2>/dev/null || date +%s)
    ELAPSED=$((END - START))
    
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$HTTP_CODE" -eq "$EXPECT_CODE" ] 2>/dev/null; then
        echo "[$TIMESTAMP] ✅ $URL — $HTTP_CODE (${ELAPSED}ms)"
        if [ "$ALERTED" = true ]; then
            send_alert "$URL is back UP ✅ (was down for $CONSECUTIVE_FAILURES checks)" "default" "white_check_mark"
            ALERTED=false
        fi
        CONSECUTIVE_FAILURES=0
    else
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        echo "[$TIMESTAMP] ❌ $URL — $HTTP_CODE (${ELAPSED}ms) [failure $CONSECUTIVE_FAILURES/$ALERT_THRESHOLD]"
        
        if [ "$CONSECUTIVE_FAILURES" -ge "$ALERT_THRESHOLD" ] && [ "$ALERTED" = false ]; then
            send_alert "$URL is DOWN ❌ (HTTP $HTTP_CODE, ${CONSECUTIVE_FAILURES} consecutive failures)" "urgent" "rotating_light"
            ALERTED=true
        fi
    fi
    
    sleep "$INTERVAL"
done
