#!/bin/bash
# Unbound health check — returns non-zero if unhealthy
set -euo pipefail

PORT="${UNBOUND_PORT:-53}"
ERRORS=0

# Check process
if ! pgrep -x unbound &>/dev/null; then
    echo "CRITICAL: Unbound process not running"
    ((ERRORS++))
fi

# Check DNS resolution
RESULT=$(dig @127.0.0.1 -p "$PORT" example.com +short +time=3 2>/dev/null || echo "")
if [ -z "$RESULT" ]; then
    echo "CRITICAL: DNS resolution failed"
    ((ERRORS++))
fi

# Check response time
START=$(date +%s%3N 2>/dev/null || echo 0)
dig @127.0.0.1 -p "$PORT" google.com +short +time=5 &>/dev/null
END=$(date +%s%3N 2>/dev/null || echo 0)
LATENCY=$((END - START))
if [ "$LATENCY" -gt 5000 ] 2>/dev/null; then
    echo "WARNING: High latency (${LATENCY}ms)"
fi

if [ "$ERRORS" -gt 0 ]; then
    exit 1
else
    echo "OK: Unbound healthy (${LATENCY}ms)"
    exit 0
fi
