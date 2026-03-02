#!/bin/bash
# Display Unbound DNS resolver statistics
set -euo pipefail

echo "=== Unbound Statistics ==="
echo ""

# Check if unbound-control works
if ! sudo unbound-control status &>/dev/null; then
    echo "❌ Cannot connect to Unbound control interface."
    echo "   Make sure unbound-control is set up: sudo unbound-control-setup"
    exit 1
fi

# Get stats
STATS=$(sudo unbound-control stats_noreset 2>/dev/null)

if [ -z "$STATS" ]; then
    echo "❌ No stats available"
    exit 1
fi

# Parse key metrics
TOTAL=$(echo "$STATS" | grep "^total.num.queries=" | cut -d= -f2)
CACHE_HIT=$(echo "$STATS" | grep "^total.num.cachehits=" | cut -d= -f2)
CACHE_MISS=$(echo "$STATS" | grep "^total.num.cachemiss=" | cut -d= -f2)
PREFETCH=$(echo "$STATS" | grep "^total.num.prefetch=" | cut -d= -f2)
RECURSE_AVG=$(echo "$STATS" | grep "^total.recursion.time.avg=" | cut -d= -f2)
UPTIME=$(echo "$STATS" | grep "^time.up=" | cut -d= -f2)

# Calculate percentages
if [ -n "$TOTAL" ] && [ "$TOTAL" -gt 0 ] 2>/dev/null; then
    HIT_PCT=$(awk "BEGIN {printf \"%.1f\", ($CACHE_HIT / $TOTAL) * 100}")
    MISS_PCT=$(awk "BEGIN {printf \"%.1f\", ($CACHE_MISS / $TOTAL) * 100}")
else
    HIT_PCT="0.0"
    MISS_PCT="0.0"
fi

# Format uptime
if [ -n "$UPTIME" ]; then
    UPTIME_SEC=${UPTIME%%.*}
    DAYS=$((UPTIME_SEC / 86400))
    HOURS=$(( (UPTIME_SEC % 86400) / 3600 ))
    MINS=$(( (UPTIME_SEC % 3600) / 60 ))
    UPTIME_FMT="${DAYS}d ${HOURS}h ${MINS}m"
fi

# Format recursion time
if [ -n "$RECURSE_AVG" ]; then
    RECURSE_MS=$(awk "BEGIN {printf \"%.1f\", $RECURSE_AVG * 1000}")
fi

# Display
echo "  Total queries:     ${TOTAL:-N/A}"
echo "  Cache hits:        ${CACHE_HIT:-N/A} (${HIT_PCT}%)"
echo "  Cache misses:      ${CACHE_MISS:-N/A} (${MISS_PCT}%)"
echo "  Prefetches:        ${PREFETCH:-N/A}"
echo "  Avg recurse time:  ${RECURSE_MS:-N/A}ms"
echo "  Uptime:            ${UPTIME_FMT:-N/A}"
echo ""

# Ad-blocking stats (if enabled)
BLOCKLIST="/etc/unbound/blocklist.conf"
if [ -f "$BLOCKLIST" ]; then
    BLOCKED=$(grep -c "local-zone" "$BLOCKLIST" 2>/dev/null || echo 0)
    echo "  Ad-block domains:  $BLOCKED"
fi

# Memory stats
MEM_CACHE=$(echo "$STATS" | grep "^mem.cache.rrset=" | cut -d= -f2)
MEM_MSG=$(echo "$STATS" | grep "^mem.cache.message=" | cut -d= -f2)
if [ -n "$MEM_CACHE" ] && [ -n "$MEM_MSG" ]; then
    TOTAL_MEM=$(awk "BEGIN {printf \"%.1f\", ($MEM_CACHE + $MEM_MSG) / 1048576}")
    echo "  Cache memory:      ${TOTAL_MEM}MB"
fi

# Answer types
NOERROR=$(echo "$STATS" | grep "^num.answer.rcode.NOERROR=" | cut -d= -f2)
NXDOMAIN=$(echo "$STATS" | grep "^num.answer.rcode.NXDOMAIN=" | cut -d= -f2)
SERVFAIL=$(echo "$STATS" | grep "^num.answer.rcode.SERVFAIL=" | cut -d= -f2)
echo ""
echo "  Answer codes:"
echo "    NOERROR:   ${NOERROR:-0}"
echo "    NXDOMAIN:  ${NXDOMAIN:-0}"
echo "    SERVFAIL:  ${SERVFAIL:-0}"
