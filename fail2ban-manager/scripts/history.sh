#!/bin/bash
# Fail2ban ban history and statistics
set -e

HOURS=24
TOP=0
BY_COUNTRY=false
EXPORT=""
SUMMARY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --hours) HOURS="$2"; shift 2 ;;
        --top) TOP="$2"; shift 2 ;;
        --by-country) BY_COUNTRY=true; shift ;;
        --export) EXPORT="$2"; shift 2 ;;
        --summary) SUMMARY=true; shift ;;
        *) shift ;;
    esac
done

LOG="/var/log/fail2ban.log"
CUTOFF=$(date -d "$HOURS hours ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-${HOURS}H '+%Y-%m-%d %H:%M:%S' 2>/dev/null)

if [ ! -f "$LOG" ]; then
    echo "❌ Fail2ban log not found at $LOG"
    exit 1
fi

# Extract bans from log
get_bans() {
    sudo grep -E "Ban " "$LOG" | while read line; do
        timestamp=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}')
        jail=$(echo "$line" | grep -oE '\[.*\]' | tr -d '[]')
        ip=$(echo "$line" | grep -oE 'Ban [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}')
        [ -n "$ip" ] && echo "$timestamp|$jail|$ip"
    done
}

if $SUMMARY; then
    total_bans=$(sudo grep -c "Ban " "$LOG" 2>/dev/null || echo 0)
    recent_bans=$(get_bans | while IFS='|' read ts jail ip; do
        [ -n "$CUTOFF" ] && [[ "$ts" > "$CUTOFF" ]] && echo "$ip"
    done | wc -l)
    unique_ips=$(get_bans | cut -d'|' -f3 | sort -u | wc -l)
    
    echo "📊 Fail2ban Summary (last ${HOURS}h)"
    echo "   Total bans (all time): $total_bans"
    echo "   Recent bans: $recent_bans"
    echo "   Unique IPs: $unique_ips"
    
    # Top jails
    echo "   Top jails:"
    get_bans | cut -d'|' -f2 | sort | uniq -c | sort -rn | head -5 | while read count jail; do
        echo "     $jail: $count bans"
    done
    exit 0
fi

if [ "$TOP" -gt 0 ]; then
    echo "🏆 Top $TOP Most Banned IPs (all time):"
    echo ""
    get_bans | cut -d'|' -f3 | sort | uniq -c | sort -rn | head -"$TOP" | while read count ip; do
        country=""
        if command -v geoiplookup &>/dev/null; then
            country=$(geoiplookup "$ip" 2>/dev/null | head -1 | cut -d: -f2 | xargs)
        fi
        printf "  %-5s %s %s\n" "${count}x" "$ip" "${country:+($country)}"
    done
    exit 0
fi

if $BY_COUNTRY; then
    if ! command -v geoiplookup &>/dev/null; then
        echo "❌ geoiplookup not installed. Install: sudo apt install geoip-bin"
        exit 1
    fi
    
    echo "🌍 Bans by Country:"
    echo ""
    get_bans | cut -d'|' -f3 | sort -u | while read ip; do
        geoiplookup "$ip" 2>/dev/null | head -1 | cut -d: -f2 | xargs
    done | sort | uniq -c | sort -rn | while read count country; do
        printf "  %-5s %s\n" "${count}x" "$country"
    done
    exit 0
fi

if [ -n "$EXPORT" ]; then
    echo "timestamp,jail,ip" > "$EXPORT"
    get_bans | tr '|' ',' >> "$EXPORT"
    count=$(wc -l < "$EXPORT")
    echo "✅ Exported $((count - 1)) bans to $EXPORT"
    exit 0
fi

# Default: show recent bans
echo "📋 Bans in last ${HOURS} hours:"
echo ""
get_bans | while IFS='|' read ts jail ip; do
    if [ -n "$CUTOFF" ]; then
        [[ "$ts" > "$CUTOFF" ]] && printf "  [%s] %-20s %s\n" "$ts" "[$jail]" "$ip"
    else
        printf "  [%s] %-20s %s\n" "$ts" "[$jail]" "$ip"
    fi
done
