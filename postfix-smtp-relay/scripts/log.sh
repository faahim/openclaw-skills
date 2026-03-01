#!/bin/bash
# Postfix SMTP Relay — Log Viewer

set -euo pipefail

LINES="${2:-20}"
[[ "$1" == "--last" ]] && LINES="$2"

echo "📋 Mail Log (last $LINES entries)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sudo tail -"$LINES" /var/log/mail.log 2>/dev/null || \
    sudo journalctl -u postfix --no-pager -n "$LINES" 2>/dev/null || \
    echo "No mail logs found"
