#!/bin/bash
# Fail2ban Status Report
set -e

REMOTE_HOSTS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --remote) shift; while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do REMOTE_HOSTS+=("$1"); shift; done ;;
        *) shift ;;
    esac
done

print_status() {
    local host="${1:-local}"
    local prefix=""
    [ "$host" != "local" ] && prefix="ssh $host "

    # Check if fail2ban is running
    if ! ${prefix}sudo fail2ban-client status &>/dev/null; then
        echo "❌ Fail2ban is not running on $host"
        return 1
    fi

    local status=$(${prefix}sudo fail2ban-client status)
    local jails=$(echo "$status" | grep "Jail list:" | sed 's/.*Jail list:\s*//' | tr ',' '\n' | sed 's/^\s*//')

    echo "╔══════════════════════════════════════════════════╗"
    [ "$host" != "local" ] && echo "║  HOST: $host"
    echo "║          FAIL2BAN STATUS REPORT                  ║"
    echo "╠══════════════════════════════════════════════════╣"
    echo "║ Service: $(${prefix}sudo systemctl is-active fail2ban 2>/dev/null || echo 'unknown')                                    ║"

    local jail_count=$(echo "$jails" | grep -c .)
    echo "║ Jails:   $jail_count active                                    ║"

    for jail in $jails; do
        jail=$(echo "$jail" | xargs)
        [ -z "$jail" ] && continue

        echo "╠══════════════════════════════════════════════════╣"
        echo "║ Jail: $jail"

        local jail_status=$(${prefix}sudo fail2ban-client status "$jail" 2>/dev/null)
        local currently=$(echo "$jail_status" | grep "Currently banned:" | awk '{print $NF}')
        local total=$(echo "$jail_status" | grep "Total banned:" | awk '{print $NF}')
        local banned_ips=$(echo "$jail_status" | grep "Banned IP list:" | sed 's/.*Banned IP list:\s*//')

        echo "║   Currently banned: ${currently:-0}"
        echo "║   Total banned: ${total:-0}"
        [ -n "$banned_ips" ] && [ "$banned_ips" != " " ] && echo "║   Banned IPs: $banned_ips"
    done

    echo "╚══════════════════════════════════════════════════╝"
}

# Local status
print_status

# Remote hosts
for host in "${REMOTE_HOSTS[@]}"; do
    echo ""
    print_status "$host"
done
