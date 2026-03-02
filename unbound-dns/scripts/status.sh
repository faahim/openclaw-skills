#!/bin/bash
# Check Unbound status and stats
set -euo pipefail

JSON_OUTPUT=false
BLOCKLIST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_OUTPUT=true; shift ;;
        --blocklist) BLOCKLIST=true; shift ;;
        *) shift ;;
    esac
done

# Check if running
PID=$(pgrep unbound 2>/dev/null || echo "")
RUNNING=false
[[ -n "$PID" ]] && RUNNING=true

# Get stats via unbound-control
STATS=""
if command -v unbound-control &>/dev/null && $RUNNING; then
    STATS=$(sudo unbound-control stats_noreset 2>/dev/null || echo "")
fi

# Parse stats
CACHE_ENTRIES=$(echo "$STATS" | grep "^msg.cache.count=" | cut -d= -f2 || echo "0")
TOTAL_QUERIES=$(echo "$STATS" | grep "^total.num.queries=" | cut -d= -f2 || echo "0")
CACHE_HITS=$(echo "$STATS" | grep "^total.num.cachehits=" | cut -d= -f2 || echo "0")
AVG_RECURSIVE=$(echo "$STATS" | grep "^total.recursion.time.avg=" | cut -d= -f2 || echo "0")

# DNSSEC check
DNSSEC_OK=false
if $RUNNING; then
    TEST=$(dig @127.0.0.1 +dnssec sigok.verteiltesysteme.net A +short 2>/dev/null || echo "")
    [[ -n "$TEST" ]] && DNSSEC_OK=true
fi

# Listening check
LISTENING=$(ss -tlnp 2>/dev/null | grep ":53 " | head -1 || echo "")
LISTEN_ADDR="not listening"
if [[ -n "$LISTENING" ]]; then
    LISTEN_ADDR=$(echo "$LISTENING" | awk '{print $4}')
fi

# Blocklist count
BLOCKED_COUNT=0
if $BLOCKLIST; then
    CONF_DIR="/etc/unbound"
    [[ "$(uname)" == "Darwin" ]] && CONF_DIR="$(brew --prefix)/etc/unbound"
    if [[ -f "$CONF_DIR/blocklist.conf" ]]; then
        BLOCKED_COUNT=$(grep -c "local-zone:" "$CONF_DIR/blocklist.conf" 2>/dev/null || echo "0")
    fi
fi

if $JSON_OUTPUT; then
    cat <<EOF
{"running":$RUNNING,"pid":"$PID","dnssec":$DNSSEC_OK,"listen":"$LISTEN_ADDR","cache_entries":$CACHE_ENTRIES,"queries_total":$TOTAL_QUERIES,"cache_hits":$CACHE_HITS,"avg_recursive_ms":"$(echo "$AVG_RECURSIVE" | awk '{printf "%.0f", $1*1000}')","blocked_domains":$BLOCKED_COUNT}
EOF
else
    if $RUNNING; then
        echo "✅ Unbound is running (PID $PID)"
    else
        echo "❌ Unbound is NOT running"
        exit 1
    fi

    if $DNSSEC_OK; then
        echo "✅ DNSSEC validation: active"
    else
        echo "⚠️  DNSSEC validation: unknown"
    fi

    echo "✅ Listening on: $LISTEN_ADDR"
    echo "✅ Cache entries: $CACHE_ENTRIES"
    echo "✅ Total queries: $TOTAL_QUERIES"
    echo "✅ Cache hits: $CACHE_HITS"

    if [[ -n "$AVG_RECURSIVE" && "$AVG_RECURSIVE" != "0" ]]; then
        AVG_MS=$(echo "$AVG_RECURSIVE" | awk '{printf "%.0f", $1*1000}')
        echo "⏱️  Avg recursive: ${AVG_MS}ms"
    fi

    if $BLOCKLIST && [[ $BLOCKED_COUNT -gt 0 ]]; then
        echo "🚫 Blocked domains: $BLOCKED_COUNT"
    fi
fi
