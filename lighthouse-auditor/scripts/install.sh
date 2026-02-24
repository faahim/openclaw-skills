#!/bin/bash
# Install Lighthouse CLI and Chromium dependencies
set -e

echo "🔧 Installing Lighthouse Performance Auditor..."

# Check Node.js
if ! command -v node &>/dev/null; then
  echo "❌ Node.js is required but not installed."
  echo "   Install: https://nodejs.org/ or 'sudo apt install nodejs'"
  exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 16 ]; then
  echo "❌ Node.js 16+ required (found: $(node -v))"
  exit 1
fi

# Install Lighthouse globally
if ! command -v lighthouse &>/dev/null; then
  echo "📦 Installing lighthouse CLI..."
  npm install -g lighthouse
else
  echo "✅ lighthouse already installed: $(lighthouse --version)"
fi

# Check for Chrome/Chromium
CHROME_PATH="${CHROME_PATH:-}"
if [ -z "$CHROME_PATH" ]; then
  for candidate in chromium-browser chromium google-chrome google-chrome-stable; do
    if command -v "$candidate" &>/dev/null; then
      CHROME_PATH=$(which "$candidate")
      break
    fi
  done
fi

if [ -z "$CHROME_PATH" ]; then
  echo "📦 Installing Chromium..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq chromium-browser 2>/dev/null || \
    sudo apt-get install -y -qq chromium 2>/dev/null
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y chromium
  elif command -v brew &>/dev/null; then
    brew install --cask chromium
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm chromium
  else
    echo "❌ Could not install Chromium automatically."
    echo "   Please install Chromium/Chrome manually and set CHROME_PATH."
    exit 1
  fi
  CHROME_PATH=$(which chromium-browser 2>/dev/null || which chromium 2>/dev/null || which google-chrome 2>/dev/null)
fi

echo "✅ Chrome found at: $CHROME_PATH"

# Install jq if missing (optional, for JSON parsing)
if ! command -v jq &>/dev/null; then
  echo "📦 Installing jq (optional, for JSON output parsing)..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y -qq jq
  elif command -v brew &>/dev/null; then
    brew install jq
  fi
fi

echo ""
echo "═══════════════════════════════════════"
echo "  ✅ Lighthouse Auditor installed!"
echo "  Run: bash scripts/run.sh --url https://example.com"
echo "═══════════════════════════════════════"
