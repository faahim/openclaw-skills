#!/bin/bash
# Manage DNS-level ad-blocking for Unbound
set -euo pipefail

CONF_DIR="/etc/unbound"
BLOCKLIST_FILE="$CONF_DIR/blocklist.conf"
BLOCKLIST_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
CRON_COMMENT="# unbound-dns-adblock-update"

ACTION="${1:---help}"

case "$ACTION" in
    --enable)
        echo "=== Enabling DNS Ad-Blocking ==="
        
        # Download blocklist
        echo "[*] Downloading Steven Black's unified hosts list..."
        TEMP=$(mktemp)
        curl -sS "$BLOCKLIST_URL" -o "$TEMP"
        
        # Count blocked domains
        TOTAL=$(grep -c "^0.0.0.0" "$TEMP" || echo 0)
        echo "[✓] Downloaded blocklist: $TOTAL domains"
        
        # Convert to Unbound format
        echo "[*] Converting to Unbound local-zone format..."
        grep "^0.0.0.0" "$TEMP" | \
            awk '{print $2}' | \
            grep -v "0.0.0.0" | \
            sort -u | \
            while read -r domain; do
                echo "local-zone: \"$domain\" redirect"
                echo "local-data: \"$domain A 0.0.0.0\""
            done | sudo tee "$BLOCKLIST_FILE" > /dev/null
        
        rm -f "$TEMP"
        
        CONVERTED=$(grep -c "local-zone" "$BLOCKLIST_FILE" || echo 0)
        echo "[✓] Converted to Unbound format: $CONVERTED entries → $BLOCKLIST_FILE"
        
        # Ensure blocklist is included in main config
        if ! grep -q "blocklist.conf" "$CONF_DIR/unbound.conf" 2>/dev/null; then
            echo "[*] Adding blocklist include to unbound.conf..."
            sudo sed -i '/^server:/a\    include: "'"$BLOCKLIST_FILE"'"' "$CONF_DIR/unbound.conf"
        fi
        
        # Add daily cron job
        CRON_CMD="0 4 * * * curl -sS '$BLOCKLIST_URL' | grep '^0.0.0.0' | awk '{print \$2}' | grep -v '0.0.0.0' | sort -u | while read d; do echo \"local-zone: \\\"\$d\\\" redirect\"; echo \"local-data: \\\"\$d A 0.0.0.0\\\"\"; done > $BLOCKLIST_FILE && unbound-control reload $CRON_COMMENT"
        
        (crontab -l 2>/dev/null | grep -v "$CRON_COMMENT"; echo "$CRON_CMD") | crontab -
        echo "[✓] Cron job added: daily update at 4:00 AM"
        
        # Reload Unbound
        if command -v unbound-control &>/dev/null; then
            sudo unbound-control reload 2>/dev/null && echo "[✓] Unbound reloaded" || sudo systemctl restart unbound && echo "[✓] Unbound restarted"
        else
            sudo systemctl restart unbound
            echo "[✓] Unbound restarted"
        fi
        
        echo ""
        echo "=== Ad-Blocking Enabled ==="
        echo "Blocked domains: $CONVERTED"
        echo "Updates: Daily at 4:00 AM"
        ;;
    
    --disable)
        echo "=== Disabling DNS Ad-Blocking ==="
        
        # Remove blocklist file
        if [ -f "$BLOCKLIST_FILE" ]; then
            sudo rm -f "$BLOCKLIST_FILE"
            echo "[✓] Removed blocklist file"
        fi
        
        # Remove include from config
        sudo sed -i '/blocklist\.conf/d' "$CONF_DIR/unbound.conf" 2>/dev/null
        echo "[✓] Removed blocklist from config"
        
        # Remove cron job
        crontab -l 2>/dev/null | grep -v "$CRON_COMMENT" | crontab -
        echo "[✓] Removed cron job"
        
        # Reload
        sudo systemctl restart unbound 2>/dev/null || sudo unbound-control reload 2>/dev/null
        echo "[✓] Unbound reloaded"
        
        echo ""
        echo "=== Ad-Blocking Disabled ==="
        ;;
    
    --status)
        if [ -f "$BLOCKLIST_FILE" ]; then
            COUNT=$(grep -c "local-zone" "$BLOCKLIST_FILE" || echo 0)
            echo "Ad-blocking: ENABLED ($COUNT domains blocked)"
            if crontab -l 2>/dev/null | grep -q "$CRON_COMMENT"; then
                echo "Auto-update: ENABLED (daily at 4:00 AM)"
            else
                echo "Auto-update: DISABLED"
            fi
        else
            echo "Ad-blocking: DISABLED"
        fi
        ;;
    
    --update)
        echo "[*] Force-updating blocklist..."
        bash "$0" --enable
        ;;
    
    *)
        echo "Usage: bash adblock.sh [--enable|--disable|--status|--update]"
        echo ""
        echo "  --enable   Download blocklist and enable ad-blocking"
        echo "  --disable  Remove blocklist and disable ad-blocking"
        echo "  --status   Check current ad-blocking status"
        echo "  --update   Force-update the blocklist"
        ;;
esac
