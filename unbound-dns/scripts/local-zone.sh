#!/bin/bash
# Manage custom local DNS zones
set -euo pipefail

CONF_DIR="/etc/unbound"
LOCAL_FILE="$CONF_DIR/local-zones.conf"

ACTION="${1:---help}"

case "$ACTION" in
    add)
        DOMAIN="${2:-}"
        IP="${3:-}"
        if [ -z "$DOMAIN" ] || [ -z "$IP" ]; then
            echo "Usage: bash local-zone.sh add <domain> <ip>"
            exit 1
        fi
        
        # Create file if not exists
        sudo touch "$LOCAL_FILE"
        
        # Check for duplicates
        if grep -q "\"$DOMAIN\"" "$LOCAL_FILE" 2>/dev/null; then
            echo "[!] Domain $DOMAIN already exists. Removing old entry..."
            sudo sed -i "/\"$DOMAIN\"/d" "$LOCAL_FILE"
        fi
        
        echo "local-zone: \"$DOMAIN\" redirect" | sudo tee -a "$LOCAL_FILE" > /dev/null
        echo "local-data: \"$DOMAIN A $IP\"" | sudo tee -a "$LOCAL_FILE" > /dev/null
        
        # Ensure include in main config
        if ! grep -q "local-zones.conf" "$CONF_DIR/unbound.conf" 2>/dev/null; then
            sudo sed -i '/^server:/a\    include: "'"$LOCAL_FILE"'"' "$CONF_DIR/unbound.conf"
        fi
        
        sudo unbound-control reload 2>/dev/null || sudo systemctl restart unbound
        echo "[✓] Added: $DOMAIN → $IP"
        ;;
    
    remove)
        DOMAIN="${2:-}"
        if [ -z "$DOMAIN" ]; then
            echo "Usage: bash local-zone.sh remove <domain>"
            exit 1
        fi
        
        if [ -f "$LOCAL_FILE" ]; then
            sudo sed -i "/\"$DOMAIN\"/d" "$LOCAL_FILE"
            sudo unbound-control reload 2>/dev/null || sudo systemctl restart unbound
            echo "[✓] Removed: $DOMAIN"
        else
            echo "[!] No local zones configured"
        fi
        ;;
    
    list)
        if [ -f "$LOCAL_FILE" ] && [ -s "$LOCAL_FILE" ]; then
            echo "=== Custom Local Zones ==="
            grep "local-data:" "$LOCAL_FILE" | sed 's/local-data: "//;s/"$//' | while read -r line; do
                echo "  $line"
            done
        else
            echo "No custom local zones configured."
        fi
        ;;
    
    *)
        echo "Usage: bash local-zone.sh [add|remove|list]"
        echo ""
        echo "  add <domain> <ip>   Add a local DNS entry"
        echo "  remove <domain>     Remove a local DNS entry"
        echo "  list                List all local DNS entries"
        ;;
esac
