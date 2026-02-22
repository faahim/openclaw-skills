#!/bin/bash
# Install pre-commit framework
set -e

echo "🔧 Installing pre-commit framework..."

# Check Python
if ! command -v python3 &>/dev/null; then
  echo "❌ Python 3 is required. Install it first:"
  echo "   Ubuntu/Debian: sudo apt install python3 python3-pip"
  echo "   Mac: brew install python3"
  exit 1
fi

# Check git
if ! command -v git &>/dev/null; then
  echo "❌ Git is required."
  exit 1
fi

# Install pre-commit
if command -v pipx &>/dev/null; then
  echo "Installing via pipx..."
  pipx install pre-commit 2>/dev/null || pipx upgrade pre-commit
elif command -v pip3 &>/dev/null; then
  echo "Installing via pip3..."
  pip3 install --user pre-commit
elif command -v pip &>/dev/null; then
  echo "Installing via pip..."
  pip install --user pre-commit
else
  echo "❌ pip not found. Install pip first:"
  echo "   Ubuntu/Debian: sudo apt install python3-pip"
  echo "   Mac: brew install python3"
  exit 1
fi

# Verify
if command -v pre-commit &>/dev/null; then
  echo "✅ pre-commit $(pre-commit --version) installed successfully"
else
  # Try adding user bin to PATH
  export PATH="$HOME/.local/bin:$PATH"
  if command -v pre-commit &>/dev/null; then
    echo "✅ pre-commit $(pre-commit --version) installed successfully"
    echo "⚠️  Add to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\""
  else
    echo "❌ Installation succeeded but 'pre-commit' not found in PATH"
    echo "   Try: export PATH=\"\$HOME/.local/bin:\$PATH\""
    exit 1
  fi
fi
