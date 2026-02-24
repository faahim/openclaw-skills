#!/bin/bash
# CrowdSec Whitelist Manager
# Usage: bash whitelist.sh <add|remove|list> [ip/cidr]
set -euo pipefail

ACTION="${1:-list}"
IP="${2:-}"
WHITELIST_FILE="/etc/crowdsec/parsers/s02-enrich/my-whitelists.yaml"

ensure_whitelist_file() {
    if [ ! -f "$WHITELIST_FILE" ]; then
        sudo tee "$WHITELIST_FILE" > /dev/null <<'EOF'
name: my-whitelists
description: "Custom IP whitelist"
whitelist:
  reason: "Manual whitelist"
  ip:
    - "127.0.0.1"
  cidr: []
EOF
    fi
}

add_ip() {
    if [ -z "$IP" ]; then
        echo "❌ Usage: bash whitelist.sh add <ip-or-cidr>"
        exit 1
    fi
    
    ensure_whitelist_file
    
    if echo "$IP" | grep -q "/"; then
        # CIDR range
        if grep -q "$IP" "$WHITELIST_FILE" 2>/dev/null; then
            echo "⚠️  $IP already whitelisted"
            return
        fi
        sudo sed -i "/^  cidr:/a\\    - \"$IP\"" "$WHITELIST_FILE"
    else
        # Single IP
        if grep -q "$IP" "$WHITELIST_FILE" 2>/dev/null; then
            echo "⚠️  $IP already whitelisted"
            return
        fi
        sudo sed -i "/^  ip:/a\\    - \"$IP\"" "$WHITELIST_FILE"
    fi
    
    # Also remove any active bans
    cscli decisions delete --ip "$IP" 2>/dev/null || true
    
    sudo systemctl reload crowdsec
    echo "✅ Whitelisted: $IP"
}

remove_ip() {
    if [ -z "$IP" ]; then
        echo "❌ Usage: bash whitelist.sh remove <ip-or-cidr>"
        exit 1
    fi
    
    ensure_whitelist_file
    sudo sed -i "/\"$IP\"/d" "$WHITELIST_FILE"
    sudo systemctl reload crowdsec
    echo "✅ Removed from whitelist: $IP"
}

list_ips() {
    ensure_whitelist_file
    echo "📋 Whitelisted IPs & CIDRs:"
    grep -E "^\s+-\s+\"" "$WHITELIST_FILE" 2>/dev/null | sed 's/.*"\(.*\)"/  \1/' || echo "  (none)"
}

case "$ACTION" in
    add) add_ip ;;
    remove|rm|delete) remove_ip ;;
    list|ls) list_ips ;;
    *)
        echo "Usage: bash whitelist.sh <add|remove|list> [ip/cidr]"
        exit 1
        ;;
esac
