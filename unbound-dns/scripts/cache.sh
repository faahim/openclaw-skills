#!/bin/bash
# Manage Unbound DNS cache
set -euo pipefail

ACTION="${1:---help}"

case "$ACTION" in
    flush)
        DOMAIN="${2:-}"
        if [ -n "$DOMAIN" ]; then
            sudo unbound-control flush "$DOMAIN"
            sudo unbound-control flush_type "$DOMAIN" A
            sudo unbound-control flush_type "$DOMAIN" AAAA
            echo "[✓] Flushed cache for: $DOMAIN"
        else
            sudo unbound-control reload
            echo "[✓] Flushed entire cache"
        fi
        ;;
    dump)
        echo "=== Cache Dump ==="
        sudo unbound-control dump_cache | head -100
        echo "..."
        TOTAL=$(sudo unbound-control dump_cache | wc -l)
        echo "(Showing first 100 of $TOTAL entries)"
        ;;
    *)
        echo "Usage: bash cache.sh [flush|dump]"
        echo ""
        echo "  flush              Flush entire cache"
        echo "  flush <domain>     Flush specific domain"
        echo "  dump               Dump cache contents"
        ;;
esac
