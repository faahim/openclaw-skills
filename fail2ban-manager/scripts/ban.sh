#!/bin/bash
# Manual ban/unban IPs
set -e

JAIL=""
IP=""
UNBAN=false
UNBAN_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --jail) JAIL="$2"; shift 2 ;;
        --ip) IP="$2"; shift 2 ;;
        --unban) UNBAN=true; shift ;;
        --unban-all) UNBAN_ALL=true; shift ;;
        *) echo "Usage: $0 --jail <name> --ip <ip> [--unban] [--unban-all]"; exit 1 ;;
    esac
done

[ -z "$JAIL" ] && { echo "❌ --jail is required"; exit 1; }

if $UNBAN_ALL; then
    # Get all banned IPs and unban them
    banned=$(sudo fail2ban-client status "$JAIL" | grep "Banned IP list:" | sed 's/.*Banned IP list:\s*//')
    if [ -z "$banned" ] || [ "$banned" = " " ]; then
        echo "ℹ️  No banned IPs in jail [$JAIL]"
        exit 0
    fi
    
    count=0
    for ip in $banned; do
        sudo fail2ban-client set "$JAIL" unbanip "$ip"
        count=$((count + 1))
    done
    echo "✅ Unbanned $count IPs from jail [$JAIL]"

elif $UNBAN; then
    [ -z "$IP" ] && { echo "❌ --ip is required for unban"; exit 1; }
    sudo fail2ban-client set "$JAIL" unbanip "$IP"
    echo "✅ Unbanned $IP from jail [$JAIL]"

else
    [ -z "$IP" ] && { echo "❌ --ip is required for ban"; exit 1; }
    sudo fail2ban-client set "$JAIL" banip "$IP"
    echo "🚫 Banned $IP in jail [$JAIL]"
fi
