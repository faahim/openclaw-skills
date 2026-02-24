#!/bin/bash
# Add custom Netdata health check
set -e

HEALTH_DIR="/etc/netdata/health.d"
NAME="" CHART="" LOOKUP="" WARN="" CRIT="" INFO="" EVERY="1m"

while [[ $# -gt 0 ]]; do
    case $1 in
        --name) NAME="$2"; shift 2 ;;
        --metric|--chart) CHART="$2"; shift 2 ;;
        --lookup) LOOKUP="$2"; shift 2 ;;
        --warn) WARN="$2"; shift 2 ;;
        --crit) CRIT="$2"; shift 2 ;;
        --info) INFO="$2"; shift 2 ;;
        --every) EVERY="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

[ -z "$NAME" ] && { echo "❌ --name required"; exit 1; }
[ -z "$CHART" ] && { echo "❌ --chart required"; exit 1; }
[ -z "$LOOKUP" ] && { echo "❌ --lookup required"; exit 1; }

CONF_FILE="$HEALTH_DIR/custom_${NAME}.conf"

sudo mkdir -p "$HEALTH_DIR"

sudo tee "$CONF_FILE" > /dev/null <<EOF
# Custom health check: $NAME
# Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)

alarm: $NAME
    on: $CHART
lookup: $LOOKUP
 every: $EVERY
$([ -n "$WARN" ] && echo "  warn: \$this $WARN")
$([ -n "$CRIT" ] && echo "  crit: \$this $CRIT")
  info: ${INFO:-Custom alert: $NAME}
    to: sysadmin
EOF

echo "✅ Health check created: $NAME"
echo "   File: $CONF_FILE"
echo "   Chart: $CHART"
[ -n "$WARN" ] && echo "   Warning: $WARN"
[ -n "$CRIT" ] && echo "   Critical: $CRIT"
echo ""
echo "Reload: sudo netdatacli reload-health"

# Auto-reload if netdata is running
if curl -sf http://localhost:19999/api/v1/info >/dev/null 2>&1; then
    sudo netdatacli reload-health 2>/dev/null && echo "✅ Health checks reloaded" || true
fi
