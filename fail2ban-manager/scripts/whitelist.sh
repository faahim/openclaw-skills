#!/bin/bash
# Manage Fail2ban IP whitelist
set -e

ACTION=""
IP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --add) ACTION="add"; IP="$2"; shift 2 ;;
        --remove) ACTION="remove"; IP="$2"; shift 2 ;;
        --list) ACTION="list"; shift ;;
        *) echo "Usage: $0 --add <ip> | --remove <ip> | --list"; exit 1 ;;
    esac
done

JAIL_FILE="/etc/fail2ban/jail.local"

case "$ACTION" in
    add)
        [ -z "$IP" ] && { echo "❌ Specify an IP address"; exit 1; }
        
        # Check if ignoreip line exists in DEFAULT section
        if sudo grep -q "^ignoreip" "$JAIL_FILE"; then
            # Append to existing ignoreip
            current=$(sudo grep "^ignoreip" "$JAIL_FILE" | head -1 | cut -d= -f2 | xargs)
            if echo "$current" | grep -q "$IP"; then
                echo "ℹ️  $IP is already whitelisted"
                exit 0
            fi
            sudo sed -i "s|^ignoreip.*|ignoreip = $current $IP|" "$JAIL_FILE"
        else
            # Add ignoreip line after [DEFAULT] section
            sudo sed -i "/^\[DEFAULT\]/a ignoreip = 127.0.0.1/8 ::1 $IP" "$JAIL_FILE"
        fi
        
        sudo fail2ban-client reload
        echo "✅ Whitelisted: $IP"
        ;;
    
    remove)
        [ -z "$IP" ] && { echo "❌ Specify an IP address"; exit 1; }
        
        if sudo grep -q "^ignoreip" "$JAIL_FILE"; then
            # Remove IP from ignoreip line
            sudo sed -i "s| $IP||g; s|$IP ||g; s|$IP||g" "$JAIL_FILE"
            sudo fail2ban-client reload
            echo "✅ Removed from whitelist: $IP"
        else
            echo "ℹ️  No whitelist configured"
        fi
        ;;
    
    list)
        echo "📋 Whitelisted IPs:"
        if sudo grep -q "^ignoreip" "$JAIL_FILE"; then
            sudo grep "^ignoreip" "$JAIL_FILE" | cut -d= -f2 | tr ' ' '\n' | grep -v '^$' | while read ip; do
                echo "  • $ip"
            done
        else
            echo "  (none configured)"
        fi
        ;;
    
    *)
        echo "Usage: $0 --add <ip> | --remove <ip> | --list"
        exit 1
        ;;
esac
