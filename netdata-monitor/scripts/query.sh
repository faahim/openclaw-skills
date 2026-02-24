#!/bin/bash
# Query Netdata metrics via API
set -e

API="http://localhost:19999/api/v1"
CHART="${1:-}"
AFTER=""
FORMAT="csv"

shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --after) AFTER="$2"; shift 2 ;;
        --format) FORMAT="$2"; shift 2 ;;
        --list) CHART="__list__"; shift ;;
        *) shift ;;
    esac
done

if ! curl -sf "$API/info" >/dev/null 2>&1; then
    echo "❌ Netdata not running. Start with: sudo systemctl start netdata"
    exit 1
fi

if [ -z "$CHART" ]; then
    echo "Usage: bash scripts/query.sh <chart> [--after SECONDS] [--format csv|json]"
    echo "       bash scripts/query.sh --list"
    echo ""
    echo "Common charts:"
    echo "  system.cpu       - CPU usage"
    echo "  system.ram       - RAM usage"
    echo "  system.net       - Network traffic"
    echo "  system.io        - Disk I/O"
    echo "  system.load      - System load"
    echo "  disk_space._     - Disk space"
    exit 0
fi

if [ "$CHART" = "__list__" ]; then
    curl -sf "$API/charts" | python3 -c "
import json,sys
data=json.load(sys.stdin)
for cid,c in sorted(data.get('charts',{}).items()):
    print(f\"  {cid:40s} {c.get('title','')}\")
" 2>/dev/null || curl -sf "$API/charts" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | sort
    exit 0
fi

PARAMS="chart=$CHART&format=$FORMAT&options=abs"
[ -n "$AFTER" ] && PARAMS="$PARAMS&after=$AFTER"

echo "📊 $CHART"
echo "---"
curl -sf "$API/data?$PARAMS" 2>/dev/null || {
    echo "❌ Chart '$CHART' not found"
    echo "   Use --list to see available charts"
    exit 1
}
echo ""
