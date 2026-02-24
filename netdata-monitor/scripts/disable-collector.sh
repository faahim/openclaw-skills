#!/bin/bash
# Disable a Netdata collector
set -e

COLLECTOR="${1:-}"
[ -z "$COLLECTOR" ] && {
    echo "Usage: bash scripts/disable-collector.sh <collector>"
    echo ""
    echo "List active collectors:"
    echo "  ls /etc/netdata/go.d/"
    exit 0
}

CONF="/etc/netdata/go.d/${COLLECTOR}.conf"
if [ -f "$CONF" ]; then
    sudo mv "$CONF" "${CONF}.disabled"
    echo "✅ Collector disabled: $COLLECTOR"
else
    echo "⚠️  Config not found: $CONF"
    echo "   Try: ls /etc/netdata/go.d/"
fi

echo "Restart: sudo systemctl restart netdata"
