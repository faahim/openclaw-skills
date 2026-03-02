#!/bin/bash
# Manage Unbound cache
set -euo pipefail

ACTION=""
DOMAIN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --stats) ACTION="stats"; shift ;;
        --dump) ACTION="dump"; shift ;;
        --flush) ACTION="flush"; DOMAIN="${2:-}"; shift; [[ -n "$DOMAIN" ]] && shift ;;
        *) shift ;;
    esac
done

case "$ACTION" in
    stats)
        echo "📊 Cache Statistics"
        echo "==================="
        sudo unbound-control stats_noreset 2>/dev/null | grep -E "^(msg\.cache|rrset\.cache|total\.num)" | while IFS='=' read -r key val; do
            printf "  %-35s %s\n" "$key" "$val"
        done
        ;;
    dump)
        echo "📋 Cache Dump (recent entries)"
        echo "=============================="
        sudo unbound-control dump_cache 2>/dev/null | head -100
        ;;
    flush)
        if [[ -n "$DOMAIN" ]]; then
            echo "🗑️  Flushing cache for: $DOMAIN"
            sudo unbound-control flush "$DOMAIN" 2>/dev/null
            sudo unbound-control flush_type "$DOMAIN" A 2>/dev/null
            sudo unbound-control flush_type "$DOMAIN" AAAA 2>/dev/null
            echo "✅ Flushed: $DOMAIN"
        else
            echo "🗑️  Flushing entire cache..."
            sudo unbound-control reload 2>/dev/null
            echo "✅ Cache flushed (config reloaded)"
        fi
        ;;
    *)
        echo "Usage: bash cache.sh [--stats|--dump|--flush [domain]]"
        exit 1
        ;;
esac
