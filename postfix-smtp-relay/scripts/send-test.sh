#!/bin/bash
# Send a test email through the configured Postfix relay

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

VERBOSE=false
RECIPIENT="${1:-}"

[[ "$1" == "--verbose" ]] && { VERBOSE=true; RECIPIENT="${2:-}"; }
[[ "$RECIPIENT" == "--verbose" ]] && { VERBOSE=true; RECIPIENT="${1:-}"; }
[[ -z "$RECIPIENT" ]] && { echo "Usage: $0 [--verbose] recipient@example.com"; exit 1; }

# Get relay info
RELAY=$(postconf -h relayhost 2>/dev/null || echo "unknown")
HOSTNAME=$(hostname -f 2>/dev/null || hostname)

echo "📧 Sending test email to $RECIPIENT..."

# Send
echo "This is a test email from Postfix SMTP Relay on $HOSTNAME.

Sent at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Relay: $RELAY
Hostname: $HOSTNAME

If you received this, your SMTP relay is working! 🎉" | mail -s "✅ Postfix Relay Test from $HOSTNAME" "$RECIPIENT"

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅${NC} Test email sent to $RECIPIENT via $RELAY"
    echo "   Check inbox (and spam folder) in 1-2 minutes."
else
    echo -e "${RED}❌${NC} Failed to send test email"
    echo "   Check: sudo tail -20 /var/log/mail.log"
    exit 1
fi

if [[ "$VERBOSE" == true ]]; then
    echo ""
    echo "📋 Recent mail log:"
    sudo tail -10 /var/log/mail.log 2>/dev/null || sudo journalctl -u postfix --no-pager -n 10 2>/dev/null || echo "(no logs available)"
fi
