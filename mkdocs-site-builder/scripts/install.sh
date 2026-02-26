#!/bin/bash
# MkDocs Site Builder — Install Dependencies
set -e

echo "📦 Installing MkDocs + Material theme..."

# Check Python3
if ! command -v python3 &>/dev/null; then
  echo "❌ Python 3 is required. Install it first:"
  echo "   Ubuntu/Debian: sudo apt-get install python3 python3-pip"
  echo "   Mac: brew install python3"
  exit 1
fi

# Check pip
if ! command -v pip3 &>/dev/null && ! python3 -m pip --version &>/dev/null 2>&1; then
  echo "❌ pip is required. Install it:"
  echo "   Ubuntu/Debian: sudo apt-get install python3-pip"
  echo "   Mac: python3 -m ensurepip"
  exit 1
fi

PIP_CMD="pip3"
if ! command -v pip3 &>/dev/null; then
  PIP_CMD="python3 -m pip"
fi

# Install packages
$PIP_CMD install --user --upgrade \
  mkdocs \
  mkdocs-material \
  mkdocs-minify-plugin \
  mkdocs-redirects \
  pymdown-extensions

# Verify installation
if command -v mkdocs &>/dev/null || python3 -m mkdocs --version &>/dev/null 2>&1; then
  echo ""
  echo "✅ MkDocs installed successfully!"
  mkdocs --version 2>/dev/null || python3 -m mkdocs --version
  echo ""
  echo "Installed packages:"
  echo "  - mkdocs"
  echo "  - mkdocs-material (Material theme)"
  echo "  - mkdocs-minify-plugin (HTML minification)"
  echo "  - mkdocs-redirects (URL redirects)"
  echo "  - pymdown-extensions (enhanced markdown)"
else
  echo "⚠️  MkDocs installed but not on PATH. Add to PATH:"
  echo '  export PATH="$HOME/.local/bin:$PATH"'
fi
