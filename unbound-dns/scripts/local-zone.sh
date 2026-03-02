#!/bin/bash
# Manage local DNS zones
set -euo pipefail

CONF_DIR="/etc/unbound"
[[ "$(uname)" == "Darwin" ]] && CONF_DIR="$(brew --prefix)/etc/unbound"
LOCAL_FILE="$CONF_DIR/local-zones.conf"

ACTION="${1:-}"
DOMAIN="${2:-}"
IP="${3:-}"

# Ensure local zones file exists and is included
if [[ ! -f "$LOCAL_FILE" ]]; then
    echo "# Local DNS zones — managed by unbound-dns skill" > "$LOCAL_FILE"
    # Add include to main config if not present
    if ! grep -q "local-zones.conf" "$CONF_DIR/unbound.conf" 2>/dev/null; then
        echo "    include: \"$LOCAL_FILE\"" >> "$CONF_DIR/unbound.conf"
    fi
fi

case "$ACTION" in
    add)
        [[ -z "$DOMAIN" || -z "$IP" ]] && { echo "Usage: local-zone.sh add <domain> <ip>"; exit 1; }
        # Remove existing entry
        sed -i "/\"$DOMAIN\"/d" "$LOCAL_FILE" 2>/dev/null || true
        # Add new entry
        echo "local-zone: \"$DOMAIN\" redirect" >> "$LOCAL_FILE"
        echo "local-data: \"$DOMAIN A $IP\"" >> "$LOCAL_FILE"
        sudo unbound-control reload 2>/dev/null || sudo systemctl restart unbound
        echo "✅ Added: $DOMAIN → $IP"
        ;;
    remove)
        [[ -z "$DOMAIN" ]] && { echo "Usage: local-zone.sh remove <domain>"; exit 1; }
        sed -i "/\"$DOMAIN\"/d" "$LOCAL_FILE"
        sudo unbound-control reload 2>/dev/null || sudo systemctl restart unbound
        echo "✅ Removed: $DOMAIN"
        ;;
    list)
        echo "📋 Local DNS Zones"
        echo "==================="
        if [[ -s "$LOCAL_FILE" ]]; then
            grep "^local-data:" "$LOCAL_FILE" | sed 's/local-data: "//;s/"$//' | while read -r entry; do
                echo "  $entry"
            done
        else
            echo "  (none)"
        fi
        ;;
    *)
        echo "Usage: local-zone.sh [add|remove|list] [domain] [ip]"
        echo ""
        echo "Examples:"
        echo "  bash local-zone.sh add myserver.home 192.168.1.100"
        echo "  bash local-zone.sh remove myserver.home"
        echo "  bash local-zone.sh list"
        ;;
esac
