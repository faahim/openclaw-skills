#!/bin/bash
# Check Netdata status
set -e

API="http://localhost:19999/api/v1"

if ! curl -sf "$API/info" >/dev/null 2>&1; then
    echo "❌ Netdata is not running"
    echo ""
    if command -v systemctl &>/dev/null; then
        echo "Service status:"
        systemctl is-active netdata 2>/dev/null || echo "  inactive"
        echo ""
        echo "Start with: sudo systemctl start netdata"
    fi
    exit 1
fi

INFO=$(curl -sf "$API/info")
VERSION=$(echo "$INFO" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
UPTIME=$(echo "$INFO" | grep -o '"hosts_count":[0-9]*' | cut -d: -f2)
IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

# Count active collectors
COLLECTORS=$(curl -sf "$API/charts" | grep -o '"id"' | wc -l)

# Get active alarms
ALARMS=$(curl -sf "$API/alarms?active" 2>/dev/null | grep -o '"status":"[^"]*"' | grep -c -v '"status":"CLEAR"' || echo "0")

echo "✅ Netdata is running"
echo "   Dashboard: http://${IP}:19999"
echo "   Version: ${VERSION:-unknown}"
echo "   Charts: ${COLLECTORS} active"
echo "   Active alerts: ${ALARMS}"
echo ""

# Quick resource summary
CPU=$(curl -sf "$API/data?chart=system.cpu&after=-1&format=csv&options=abs" 2>/dev/null | tail -1 | awk -F, '{sum=0; for(i=2;i<=NF;i++) sum+=$i; printf "%.1f%%", sum}')
RAM=$(curl -sf "$API/data?chart=system.ram&after=-1&format=csv" 2>/dev/null | tail -1 | awk -F, '{if(NF>1) printf "%.0f MB used", $2}')
echo "   CPU: ${CPU:-N/A}"
echo "   RAM: ${RAM:-N/A}"
