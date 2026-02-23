#!/bin/bash
# Process Manager — Install PM2 globally and configure startup
set -e

echo "🔧 Installing PM2 Process Manager..."

# Check Node.js
if ! command -v node &>/dev/null; then
  echo "❌ Node.js is required. Install it first:"
  echo "   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
  echo "   sudo apt-get install -y nodejs"
  exit 1
fi

NODE_VERSION=$(node -v)
echo "✅ Node.js found: $NODE_VERSION"

# Install PM2 globally
if command -v pm2 &>/dev/null; then
  echo "✅ PM2 already installed: $(pm2 -v)"
else
  echo "📦 Installing PM2..."
  npm install -g pm2
  echo "✅ PM2 installed: $(pm2 -v)"
fi

# Setup startup script
echo ""
echo "🚀 Setting up startup persistence..."
echo "   Run the following command (PM2 will tell you the exact sudo command):"
echo ""
pm2 startup 2>&1 || true

echo ""
echo "✅ PM2 installation complete!"
echo ""
echo "Quick start:"
echo "  pm2 start 'node server.js' --name my-app"
echo "  pm2 status"
echo "  pm2 save    # persist across reboots"
