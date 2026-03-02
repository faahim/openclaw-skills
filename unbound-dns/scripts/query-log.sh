#!/bin/bash
# Analyze Unbound query logs
set -euo pipefail

LOG_FILE="/var/log/unbound/unbound.log"
LAST=50
ACTION="recent"

while [[ $# -gt 0 ]]; do
    case $1 in
        --last) LAST="$2"; shift 2 ;;
        --top) ACTION="top"; LAST="$2"; shift 2 ;;
        --suspicious) ACTION="suspicious"; shift ;;
        *) shift ;;
    esac
done

if [[ ! -f "$LOG_FILE" ]]; then
    echo "❌ Query log not found at $LOG_FILE"
    echo "   Enable logging: sudo bash scripts/configure.sh --logging on"
    exit 1
fi

case "$ACTION" in
    recent)
        echo "📋 Recent queries (last $LAST)"
        echo "================================"
        tail -n "$LAST" "$LOG_FILE" | grep -E "query:" | awk '{print $1, $2, $NF}' | sed 's/info: //'
        ;;
    top)
        echo "🔝 Top $LAST queried domains"
        echo "============================"
        grep "query:" "$LOG_FILE" | awk -F'query: ' '{print $2}' | awk '{print $1}' | sort | uniq -c | sort -rn | head -n "$LAST" | while read -r count domain; do
            printf "  %6d  %s\n" "$count" "$domain"
        done
        ;;
    suspicious)
        echo "🔍 Suspicious queries"
        echo "====================="
        echo ""
        echo "--- High-frequency domains (>100 queries) ---"
        grep "query:" "$LOG_FILE" | awk -F'query: ' '{print $2}' | awk '{print $1}' | sort | uniq -c | sort -rn | awk '$1 > 100 {printf "  %6d  %s\n", $1, $2}'
        echo ""
        echo "--- TXT record queries (often used for C2/exfil) ---"
        grep "query:.*TXT" "$LOG_FILE" | tail -20 | awk '{print "  " $0}'
        echo ""
        echo "--- Very long domain names (possible tunneling) ---"
        grep "query:" "$LOG_FILE" | awk -F'query: ' '{print $2}' | awk '{print $1}' | awk 'length > 60 {print "  " $0}' | tail -20
        ;;
esac
