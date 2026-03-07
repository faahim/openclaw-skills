#!/bin/bash
# Stripe CLI Health Check — verify installation, auth, and connectivity
set -e

echo "🔍 Stripe CLI Health Check"
echo "=========================="
echo ""

# 1. Check installation
echo -n "1. CLI installed: "
if command -v stripe &>/dev/null; then
  VERSION=$(stripe version 2>/dev/null || stripe --version 2>/dev/null || echo "unknown")
  echo "✅ ($VERSION)"
else
  echo "❌ Not found"
  echo "   Fix: bash scripts/install.sh"
  exit 1
fi

# 2. Check authentication
echo -n "2. Authenticated: "
if stripe config --list 2>/dev/null | grep -q "test_mode_api_key\|live_mode_api_key"; then
  echo "✅"
elif [[ -n "$STRIPE_API_KEY" ]]; then
  echo "✅ (via env var)"
else
  echo "❌ Not logged in"
  echo "   Fix: stripe login"
fi

# 3. Check API connectivity
echo -n "3. API reachable: "
if stripe charges list --limit 1 &>/dev/null 2>&1; then
  echo "✅"
else
  echo "⚠️  Cannot reach API (may need auth)"
fi

# 4. Check for running listeners
echo -n "4. Active listeners: "
LISTENERS=$(pgrep -c -f "stripe listen" 2>/dev/null || echo "0")
if [[ "$LISTENERS" -gt 0 ]]; then
  echo "✅ ($LISTENERS running)"
else
  echo "ℹ️  None active"
fi

# 5. Check config
echo -n "5. Config file: "
CONFIG="$HOME/.config/stripe/config.toml"
if [[ -f "$CONFIG" ]]; then
  echo "✅ ($CONFIG)"
else
  echo "ℹ️  Not found (will be created on login)"
fi

echo ""
echo "Done."
