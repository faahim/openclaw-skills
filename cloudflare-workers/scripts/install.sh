#!/bin/bash
# Install Cloudflare Wrangler CLI
set -e

echo "🔧 Installing Cloudflare Wrangler CLI..."

# Check Node.js
if ! command -v node &>/dev/null; then
    echo "❌ Node.js is required. Install it first:"
    echo "   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
    echo "   sudo apt-get install -y nodejs"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js 18+ required. Current: $(node -v)"
    exit 1
fi

# Install wrangler
if command -v wrangler &>/dev/null; then
    CURRENT=$(wrangler --version 2>/dev/null | head -1)
    echo "ℹ️  Wrangler already installed: $CURRENT"
    echo "   Updating to latest..."
fi

npm install -g wrangler@latest

# Verify
if command -v wrangler &>/dev/null; then
    echo "✅ Wrangler installed: $(wrangler --version 2>/dev/null | head -1)"
    echo ""
    echo "Next steps:"
    echo "  1. Run 'wrangler login' to authenticate (opens browser)"
    echo "  2. Or set CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID env vars"
    echo "  3. Run 'bash scripts/run.sh create my-worker' to create your first worker"
else
    echo "❌ Installation failed. Try: sudo npm install -g wrangler@latest"
    exit 1
fi
