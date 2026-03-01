#!/bin/bash
# Postfix SMTP Relay — Status Check

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "📧 Postfix SMTP Relay Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Service status
if systemctl is-active --quiet postfix 2>/dev/null; then
    PID=$(systemctl show postfix -p MainPID --value 2>/dev/null)
    echo -e "Service:    ${GREEN}✅ running${NC} (pid $PID)"
else
    echo -e "Service:    ${RED}❌ stopped${NC}"
fi

# Relay host
RELAY=$(postconf -h relayhost 2>/dev/null || echo "not configured")
echo "Relay host: $RELAY"

# SASL auth
if [[ -f /etc/postfix/sasl_passwd.db ]] || [[ -f /etc/postfix/sasl_passwd ]]; then
    echo -e "Auth:       ${GREEN}✅ SASL configured${NC}"
else
    echo -e "Auth:       ${RED}❌ not configured${NC}"
fi

# TLS
TLS_LEVEL=$(postconf -h smtp_tls_security_level 2>/dev/null || echo "none")
if [[ "$TLS_LEVEL" == "encrypt" ]] || [[ "$TLS_LEVEL" == "verify" ]]; then
    echo -e "TLS:        ${GREEN}✅ $TLS_LEVEL${NC}"
else
    echo -e "TLS:        ${YELLOW}⚠️ $TLS_LEVEL${NC}"
fi

# Mail queue
QUEUE_COUNT=$(mailq 2>/dev/null | tail -1 | grep -oP '\d+(?= Request)' || echo "0")
if [[ "$QUEUE_COUNT" == "0" ]] || [[ -z "$QUEUE_COUNT" ]]; then
    echo "Queue:      0 messages"
else
    echo -e "Queue:      ${YELLOW}$QUEUE_COUNT messages${NC}"
fi

# Last sent
LAST_SENT=$(sudo grep "status=sent" /var/log/mail.log 2>/dev/null | tail -1 || sudo journalctl -u postfix --no-pager -n 100 2>/dev/null | grep "status=sent" | tail -1 || echo "")
if [[ -n "$LAST_SENT" ]]; then
    LAST_TIME=$(echo "$LAST_SENT" | awk '{print $1, $2, $3}')
    LAST_TO=$(echo "$LAST_SENT" | grep -oP 'to=<\K[^>]+' || echo "unknown")
    echo "Last sent:  $LAST_TIME → $LAST_TO (delivered)"
else
    echo "Last sent:  no recent deliveries found"
fi

# Errors in last 24h
ERROR_COUNT=$(sudo grep -c "status=bounced\|status=deferred\|warning:\|error:" /var/log/mail.log 2>/dev/null || echo "0")
if [[ "$ERROR_COUNT" == "0" ]]; then
    echo "Errors:     0 in last 24h"
else
    echo -e "Errors:     ${YELLOW}$ERROR_COUNT in log${NC} (check: sudo tail -50 /var/log/mail.log)"
fi
