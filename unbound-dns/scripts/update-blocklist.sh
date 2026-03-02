#!/bin/bash
# Download and apply ad/tracker blocklist for Unbound
set -euo pipefail

CONF_DIR="/etc/unbound"
[[ "$(uname)" == "Darwin" ]] && CONF_DIR="$(brew --prefix)/etc/unbound"

BLOCKLIST_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
BLOCKLIST_FILE="$CONF_DIR/blocklist.conf"
TMP_FILE=$(mktemp)

echo "📥 Downloading StevenBlack unified hosts blocklist..."
curl -sS "$BLOCKLIST_URL" -o "$TMP_FILE"

echo "🔄 Converting to Unbound format..."
# Parse hosts file: extract blocked domains (0.0.0.0 entries), convert to unbound local-zone
grep "^0\.0\.0\.0 " "$TMP_FILE" \
    | awk '{print $2}' \
    | grep -v "^0\.0\.0\.0$" \
    | sort -u \
    | while read -r domain; do
        echo "local-zone: \"$domain\" always_nxdomain"
    done > "${BLOCKLIST_FILE}.tmp"

DOMAIN_COUNT=$(wc -l < "${BLOCKLIST_FILE}.tmp")
mv "${BLOCKLIST_FILE}.tmp" "$BLOCKLIST_FILE"
rm -f "$TMP_FILE"

echo "🔄 Reloading Unbound..."
if command -v unbound-control &>/dev/null; then
    sudo unbound-control reload 2>/dev/null || sudo systemctl restart unbound
else
    sudo systemctl restart unbound 2>/dev/null || sudo brew services restart unbound 2>/dev/null || true
fi

echo ""
echo "✅ Blocklist updated: $DOMAIN_COUNT domains blocked"
echo "   File: $BLOCKLIST_FILE"
echo "   Source: StevenBlack/hosts (unified)"
echo "   Updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
