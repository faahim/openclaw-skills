#!/bin/bash
# Postfix SMTP Relay — Diagnostics

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "🔍 Postfix SMTP Relay Diagnostics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RELAY=$(postconf -h relayhost 2>/dev/null | tr -d '[]' | cut -d: -f1)
PORT=$(postconf -h relayhost 2>/dev/null | grep -oP ':\K\d+' || echo "587")

if [[ -z "$RELAY" ]]; then
    echo -e "${RED}❌${NC} No relay host configured"
    exit 1
fi

echo "Relay: $RELAY:$PORT"
echo ""

# 1. DNS resolution
echo -n "DNS resolution... "
if host "$RELAY" &>/dev/null; then
    IP=$(host "$RELAY" | head -1 | awk '{print $NF}')
    echo -e "${GREEN}✅${NC} $IP"
else
    echo -e "${RED}❌${NC} Failed to resolve $RELAY"
fi

# 2. Port reachability
echo -n "Port $PORT reachable... "
if timeout 5 bash -c "echo >/dev/tcp/$RELAY/$PORT" 2>/dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC} Cannot connect (firewall or ISP blocking?)"
fi

# 3. TLS handshake
echo -n "TLS handshake... "
if echo "" | timeout 10 openssl s_client -connect "$RELAY:$PORT" -starttls smtp 2>/dev/null | grep -q "Verify return code: 0"; then
    echo -e "${GREEN}✅${NC} verified"
else
    echo -e "${YELLOW}⚠️${NC} could not verify (may still work)"
fi

# 4. SASL credentials
echo -n "SASL credentials... "
if [[ -f /etc/postfix/sasl_passwd.db ]]; then
    echo -e "${GREEN}✅${NC} password database exists"
else
    echo -e "${RED}❌${NC} missing /etc/postfix/sasl_passwd.db (run configure.sh)"
fi

# 5. Postfix service
echo -n "Postfix service... "
if systemctl is-active --quiet postfix 2>/dev/null; then
    echo -e "${GREEN}✅${NC} running"
else
    echo -e "${RED}❌${NC} not running"
fi

if [[ "$FULL" == true ]]; then
    echo ""
    echo "📋 Extended Diagnostics"
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    
    # Reverse DNS
    MY_IP=$(curl -s -4 ifconfig.me 2>/dev/null || echo "unknown")
    echo -n "Your public IP: $MY_IP ... "
    if [[ "$MY_IP" != "unknown" ]]; then
        RDNS=$(host "$MY_IP" 2>/dev/null | awk '{print $NF}' || echo "none")
        echo "rDNS: $RDNS"
    else
        echo "could not determine"
    fi
    
    # Hostname
    echo "Hostname: $(hostname -f 2>/dev/null || hostname)"
    
    # Recent errors
    echo ""
    echo "📋 Recent mail log (last 10 lines):"
    sudo tail -10 /var/log/mail.log 2>/dev/null || sudo journalctl -u postfix --no-pager -n 10 2>/dev/null || echo "(no logs available)"
fi
