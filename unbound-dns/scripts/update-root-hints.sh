#!/bin/bash
# Update root hints file for DNSSEC
set -euo pipefail

CONF_DIR="/etc/unbound"
[[ "$(uname)" == "Darwin" ]] && CONF_DIR="$(brew --prefix)/etc/unbound"

echo "🌐 Updating root hints..."
curl -sS -o "$CONF_DIR/root.hints" https://www.internic.net/domain/named.root
echo "✅ Root hints updated: $CONF_DIR/root.hints"

echo "🔐 Updating trust anchor..."
unbound-anchor -a "$CONF_DIR/root.key" 2>/dev/null || true
echo "✅ Trust anchor updated"

echo "🔄 Reloading Unbound..."
unbound-control reload 2>/dev/null || systemctl restart unbound 2>/dev/null || true
echo "✅ Done"
