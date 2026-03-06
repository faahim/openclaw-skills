#!/bin/bash
set -euo pipefail

# Bitwarden CLI Installer
# Installs the official Bitwarden CLI via npm

echo "🔐 Bitwarden CLI Installer"
echo "=========================="
echo ""

# Check Node.js
if ! command -v node &>/dev/null; then
  echo "❌ Node.js is required but not installed."
  echo "   Install it: https://nodejs.org/ or via your package manager"
  echo "   Ubuntu/Debian: sudo apt install nodejs npm"
  echo "   macOS: brew install node"
  exit 1
fi

NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VER" -lt 16 ]; then
  echo "❌ Node.js 16+ required. Current: $(node -v)"
  exit 1
fi

echo "✅ Node.js $(node -v) detected"

# Check if already installed
if command -v bw &>/dev/null; then
  CURRENT=$(bw --version 2>/dev/null || echo "unknown")
  echo "ℹ️  Bitwarden CLI already installed (v$CURRENT)"
  read -p "   Reinstall/upgrade? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "👍 Keeping current installation"
    exit 0
  fi
fi

# Install via npm
echo ""
echo "📦 Installing @bitwarden/cli..."
npm install -g @bitwarden/cli

# Verify
if command -v bw &>/dev/null; then
  echo ""
  echo "✅ Bitwarden CLI installed successfully!"
  echo "   Version: $(bw --version)"
  echo ""
  echo "📋 Next steps:"
  echo "   1. Log in:     bw login"
  echo "   2. Unlock:     export BW_SESSION=\$(bw unlock --raw)"
  echo "   3. Search:     bw list items --search 'github'"
  echo ""
  echo "   For API key login (headless/CI):"
  echo "   export BW_CLIENTID='your-client-id'"
  echo "   export BW_CLIENTSECRET='your-client-secret'"
  echo "   bw login --apikey"
else
  echo "❌ Installation failed. Check npm output above."
  exit 1
fi

# Install jq if missing
if ! command -v jq &>/dev/null; then
  echo ""
  echo "⚠️  jq not found (used for JSON parsing)"
  echo "   Install: sudo apt install jq  OR  brew install jq"
fi
