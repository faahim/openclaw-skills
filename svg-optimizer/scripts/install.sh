#!/bin/bash
# SVG Optimizer — Install Dependencies
set -e

echo "🔧 Installing SVG Optimizer dependencies..."

# Check for Node.js
if ! command -v node &>/dev/null; then
  echo "❌ Node.js is required. Install it first:"
  echo "   curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
  echo "   sudo apt-get install -y nodejs"
  exit 1
fi

NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VER" -lt 16 ]; then
  echo "❌ Node.js 16+ required (found v$(node -v))"
  exit 1
fi

# Install svgo
if command -v svgo &>/dev/null; then
  echo "✅ svgo already installed ($(svgo --version))"
else
  echo "📦 Installing svgo..."
  npm install -g svgo
  echo "✅ svgo installed ($(svgo --version))"
fi

# Install chokidar for watch mode (optional)
if ! npm list -g chokidar-cli &>/dev/null 2>&1; then
  echo "📦 Installing chokidar-cli (for watch mode)..."
  npm install -g chokidar-cli 2>/dev/null || echo "⚠️  chokidar-cli optional — watch mode unavailable"
fi

echo ""
echo "✅ SVG Optimizer ready!"
echo "   Run: bash scripts/run.sh --input <file-or-dir> --output <destination>"
