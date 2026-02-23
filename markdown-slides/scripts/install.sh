#!/bin/bash
# Install Marp CLI for Markdown-to-Slides conversion
set -e

echo "🎯 Installing Marp CLI..."

# Check Node.js
if ! command -v node &>/dev/null; then
  echo "❌ Node.js is required. Install it first:"
  echo "   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
  echo "   sudo apt-get install -y nodejs"
  exit 1
fi

NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 16 ]; then
  echo "❌ Node.js 16+ required. Current: $(node -v)"
  exit 1
fi

# Install Marp CLI globally
echo "📦 Installing @marp-team/marp-cli..."
npm install -g @marp-team/marp-cli 2>/dev/null || {
  echo "⚠️ Global install failed (no sudo?). Installing locally..."
  npm install @marp-team/marp-cli
  echo "ℹ️ Use 'npx @marp-team/marp-cli' instead of 'marp'"
}

# Check for Chromium (needed for PDF/PPTX)
if ! command -v chromium-browser &>/dev/null && ! command -v chromium &>/dev/null && ! command -v google-chrome &>/dev/null; then
  echo ""
  echo "⚠️ No Chrome/Chromium found. PDF/PPTX export needs it."
  echo "   Install with: sudo apt-get install -y chromium-browser"
  echo "   Or Marp will try to download Chromium on first PDF export."
fi

echo ""
echo "✅ Marp CLI installed!"
echo ""
echo "Quick test:"
echo "  marp --version"
echo "  # or: npx @marp-team/marp-cli --version"
echo ""
echo "Create slides:"
echo "  marp slides.md --html     # HTML output"
echo "  marp slides.md --pdf      # PDF output"
echo "  marp slides.md --pptx     # PowerPoint output"
