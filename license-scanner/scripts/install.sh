#!/bin/bash
# License Scanner — Install Dependencies
set -e

echo "🔧 Installing License Scanner dependencies..."

# Check for Node.js
if command -v node &>/dev/null; then
  echo "✅ Node.js $(node --version) found"
  
  # Install license-checker globally
  if ! command -v license-checker &>/dev/null; then
    echo "📦 Installing license-checker..."
    npm install -g license-checker 2>/dev/null || {
      echo "⚠️  Global install failed, trying npx fallback..."
      echo "   Use: npx license-checker instead"
    }
  else
    echo "✅ license-checker already installed"
  fi
else
  echo "⚠️  Node.js not found — Node.js project scanning unavailable"
  echo "   Install: https://nodejs.org/"
fi

# Check for Python
if command -v python3 &>/dev/null; then
  echo "✅ Python $(python3 --version 2>&1 | cut -d' ' -f2) found"
  
  # Install pip-licenses
  if ! python3 -m pip show pip-licenses &>/dev/null 2>&1; then
    echo "📦 Installing pip-licenses..."
    python3 -m pip install pip-licenses --quiet 2>/dev/null || {
      echo "⚠️  pip-licenses install failed"
      echo "   Try: pip3 install pip-licenses"
    }
  else
    echo "✅ pip-licenses already installed"
  fi
else
  echo "⚠️  Python3 not found — Python project scanning unavailable"
fi

# Check for Cargo (Rust)
if command -v cargo &>/dev/null; then
  echo "✅ Cargo $(cargo --version | cut -d' ' -f2) found"
  
  if ! command -v cargo-license &>/dev/null; then
    echo "📦 Installing cargo-license..."
    cargo install cargo-license 2>/dev/null || {
      echo "⚠️  cargo-license install failed"
    }
  else
    echo "✅ cargo-license already installed"
  fi
else
  echo "ℹ️  Cargo not found — Rust project scanning unavailable (optional)"
fi

# Check for jq
if ! command -v jq &>/dev/null; then
  echo "📦 Installing jq..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y jq 2>/dev/null
  elif command -v brew &>/dev/null; then
    brew install jq 2>/dev/null
  elif command -v apk &>/dev/null; then
    apk add jq 2>/dev/null
  else
    echo "❌ Please install jq manually: https://stedolan.github.io/jq/"
    exit 1
  fi
else
  echo "✅ jq $(jq --version) found"
fi

echo ""
echo "✅ License Scanner installation complete!"
echo "   Run: bash scripts/scan.sh --dir /path/to/project"
