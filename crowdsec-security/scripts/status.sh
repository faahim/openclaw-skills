#!/bin/bash
# CrowdSec Status Dashboard
set -euo pipefail

echo "🛡️  CrowdSec Status"
echo "======================================"

# Engine status
if systemctl is-active --quiet crowdsec 2>/dev/null; then
    VERSION=$(cscli version 2>/dev/null | head -1 || echo "unknown")
    echo "Engine: ✅ Running ($VERSION)"
else
    echo "Engine: ❌ Not running"
    echo "  Fix: sudo systemctl start crowdsec"
    exit 1
fi

echo ""

# Acquisitions
echo "📂 Log Sources:"
if [ -f /etc/crowdsec/acquis.yaml ]; then
    grep -E "^\s*-\s*/|type:" /etc/crowdsec/acquis.yaml | while read line; do
        echo "  $line"
    done
else
    echo "  ⚠️  No acquisitions configured"
fi

echo ""

# Bouncers
echo "🔒 Bouncers:"
cscli bouncers list 2>/dev/null | tail -n +4 | while read line; do
    if [ -n "$line" ]; then
        echo "  $line"
    fi
done
BOUNCER_COUNT=$(cscli bouncers list -o json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
if [ "$BOUNCER_COUNT" = "0" ]; then
    echo "  ⚠️  No bouncers installed — attacks detected but NOT blocked!"
    echo "  Fix: bash scripts/setup-bouncer.sh firewall"
fi

echo ""

# Collections & Scenarios
SCENARIO_COUNT=$(cscli scenarios list -o json 2>/dev/null | jq 'length' 2>/dev/null || echo "?")
COLLECTION_COUNT=$(cscli collections list -o json 2>/dev/null | jq 'length' 2>/dev/null || echo "?")
PARSER_COUNT=$(cscli parsers list -o json 2>/dev/null | jq 'length' 2>/dev/null || echo "?")
echo "📚 Installed: $COLLECTION_COUNT collections, $SCENARIO_COUNT scenarios, $PARSER_COUNT parsers"

echo ""

# CAPI status
echo "🌍 Community:"
if cscli capi status &>/dev/null; then
    echo "  Central API: ✅ Connected"
else
    echo "  Central API: ❌ Not registered"
    echo "  Fix: sudo cscli capi register"
fi

echo ""

# Recent activity (24h)
echo "📊 Last 24 Hours:"
ALERT_COUNT=$(cscli alerts list -o json --since 24h 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
DECISION_COUNT=$(cscli decisions list -o json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
echo "  Alerts: $ALERT_COUNT"
echo "  Active bans: $DECISION_COUNT"

# Top offenders
if [ "$DECISION_COUNT" != "0" ] && [ "$DECISION_COUNT" != "null" ]; then
    echo ""
    echo "🏴 Top Banned IPs:"
    cscli decisions list -o json 2>/dev/null | jq -r '.[0:5][] | "  \(.value) — \(.scenario // "manual") (\(.duration))"' 2>/dev/null || true
fi

echo ""
echo "======================================"
