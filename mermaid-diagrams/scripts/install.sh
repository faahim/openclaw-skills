#!/bin/bash
# Install mermaid-cli and dependencies
set -euo pipefail

echo "📦 Installing @mermaid-js/mermaid-cli..."

# Check Node.js
if ! command -v node &>/dev/null; then
    echo "❌ Node.js required. Install from https://nodejs.org"
    exit 1
fi

NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
if [[ "$NODE_VER" -lt 16 ]]; then
    echo "❌ Node.js 16+ required (found: $(node -v))"
    exit 1
fi

# Install mermaid-cli
npm install -g @mermaid-js/mermaid-cli

# Verify
if command -v mmdc &>/dev/null; then
    echo "✅ mermaid-cli installed: $(mmdc --version)"
else
    echo "⚠️  mmdc not in PATH. Try: npx mmdc --version"
fi

# Install fonts for better rendering (optional)
if command -v apt-get &>/dev/null; then
    echo "📦 Installing fonts for better diagram rendering..."
    sudo apt-get install -y fonts-noto-core fonts-liberation 2>/dev/null || true
fi

echo ""
echo "🎉 Ready! Test with:"
echo "  echo 'graph LR; A-->B; B-->C;' | mmdc -i - -o test.png"
