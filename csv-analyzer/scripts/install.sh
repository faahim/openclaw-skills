#!/bin/bash
# Install Miller (mlr) — the Swiss Army knife for structured data
set -e

echo "=== CSV Analyzer — Installing Miller ==="

# Check if already installed
if command -v mlr &>/dev/null; then
  echo "✅ Miller already installed: $(mlr --version 2>&1 | head -1)"
  exit 0
fi

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64)  ARCH_NAME="amd64" ;;
  aarch64) ARCH_NAME="arm64" ;;
  arm64)   ARCH_NAME="arm64" ;;
  *)       ARCH_NAME="$ARCH" ;;
esac

install_success=false

# Method 1: Package manager
if [[ "$OS" == "linux" ]]; then
  if command -v apt-get &>/dev/null; then
    echo "📦 Installing via apt..."
    sudo apt-get update -qq && sudo apt-get install -y -qq miller 2>/dev/null && install_success=true
  elif command -v dnf &>/dev/null; then
    echo "📦 Installing via dnf..."
    sudo dnf install -y miller 2>/dev/null && install_success=true
  elif command -v pacman &>/dev/null; then
    echo "📦 Installing via pacman..."
    sudo pacman -S --noconfirm miller 2>/dev/null && install_success=true
  elif command -v apk &>/dev/null; then
    echo "📦 Installing via apk..."
    sudo apk add miller 2>/dev/null && install_success=true
  fi
elif [[ "$OS" == "darwin" ]]; then
  if command -v brew &>/dev/null; then
    echo "📦 Installing via Homebrew..."
    brew install miller 2>/dev/null && install_success=true
  fi
fi

# Method 2: Direct binary download
if [[ "$install_success" == "false" ]]; then
  echo "📦 Installing from GitHub release..."
  MLR_VERSION=$(curl -s https://api.github.com/repos/johnkerl/miller/releases/latest | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
  
  if [[ -z "$MLR_VERSION" ]]; then
    MLR_VERSION="v6.13.0"
  fi

  DOWNLOAD_URL="https://github.com/johnkerl/miller/releases/download/${MLR_VERSION}/miller-${MLR_VERSION#v}-${OS}-${ARCH_NAME}.tar.gz"
  
  TMPDIR=$(mktemp -d)
  echo "Downloading $DOWNLOAD_URL..."
  
  if curl -fsSL "$DOWNLOAD_URL" -o "$TMPDIR/miller.tar.gz"; then
    tar -xzf "$TMPDIR/miller.tar.gz" -C "$TMPDIR" 2>/dev/null
    MLR_BIN=$(find "$TMPDIR" -name "mlr" -type f 2>/dev/null | head -1)
    
    if [[ -n "$MLR_BIN" ]]; then
      chmod +x "$MLR_BIN"
      if [[ -w /usr/local/bin ]]; then
        mv "$MLR_BIN" /usr/local/bin/mlr
      else
        sudo mv "$MLR_BIN" /usr/local/bin/mlr
      fi
      install_success=true
    fi
  fi
  
  rm -rf "$TMPDIR"
fi

# Method 3: Linuxbrew
if [[ "$install_success" == "false" ]] && command -v brew &>/dev/null; then
  echo "📦 Trying Linuxbrew..."
  brew install miller 2>/dev/null && install_success=true
fi

# Verify
if command -v mlr &>/dev/null; then
  echo "✅ Miller installed successfully: $(mlr --version 2>&1 | head -1)"
else
  echo "❌ Installation failed. Please install manually:"
  echo "   https://miller.readthedocs.io/en/latest/installing-miller/"
  exit 1
fi
