#!/bin/bash
# Web Screenshot — Install Dependencies
set -e

echo "📸 Web Screenshot — Installing dependencies..."

# Check Node.js
if ! command -v node &>/dev/null; then
  echo "❌ Node.js not found. Install Node.js 16+ first."
  echo "   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
  echo "   sudo apt-get install -y nodejs"
  exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 16 ]; then
  echo "❌ Node.js $NODE_VERSION found, but 16+ is required."
  exit 1
fi

echo "✅ Node.js $(node -v) found"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Install Playwright in skill directory
cd "$SKILL_DIR"

if [ ! -d "node_modules/playwright" ]; then
  echo "📦 Installing Playwright..."
  npm init -y --silent 2>/dev/null || true
  npm install --save playwright 2>&1 | tail -5
else
  echo "✅ Playwright already installed"
fi

# Install Chromium browser
echo "🌐 Installing Chromium browser (this may take a minute)..."
npx playwright install chromium 2>&1 | tail -3

# Install system dependencies (Linux only)
if [ "$(uname)" = "Linux" ]; then
  echo "📚 Installing system dependencies..."
  npx playwright install-deps chromium 2>&1 | tail -3 || echo "⚠️  Some system deps may need sudo. Run: sudo npx playwright install-deps chromium"
fi

echo ""
echo "✅ Web Screenshot installed successfully!"
echo "   Test: bash scripts/screenshot.sh --url https://example.com --output test.png"
