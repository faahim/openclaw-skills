#!/bin/bash
# Postfix SMTP Relay — Queue Management

set -euo pipefail

ACTION="${1:-status}"

case "$ACTION" in
    status|"")
        echo "📬 Mail Queue"
        echo "━━━━━━━━━━━━━"
        mailq 2>/dev/null || echo "Queue is empty"
        ;;
    --flush|flush)
        echo "Flushing mail queue..."
        sudo postqueue -f 2>/dev/null
        echo "✅ Queue flushed"
        ;;
    --delete-all|purge)
        echo "Deleting all queued messages..."
        sudo postsuper -d ALL 2>/dev/null
        echo "✅ Queue purged"
        ;;
    *)
        echo "Usage: $0 [status|--flush|--delete-all]"
        exit 1
        ;;
esac
