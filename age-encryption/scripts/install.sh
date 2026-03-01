#!/bin/bash
# Install age encryption tool
set -e

echo "🔐 Installing age encryption tool..."

# Detect OS and install
if command -v age &>/dev/null; then
  VERSION=$(age --version 2>/dev/null || echo "unknown")
  echo "✅ age is already installed (version: $VERSION)"
  exit 0
fi

install_age() {
  # Try package managers first
  if command -v apt-get &>/dev/null; then
    echo "📦 Installing via apt..."
    sudo apt-get update -qq && sudo apt-get install -y -qq age
  elif command -v brew &>/dev/null; then
    echo "📦 Installing via Homebrew..."
    brew install age
  elif command -v pacman &>/dev/null; then
    echo "📦 Installing via pacman..."
    sudo pacman -S --noconfirm age
  elif command -v dnf &>/dev/null; then
    echo "📦 Installing via dnf..."
    sudo dnf install -y age
  elif command -v apk &>/dev/null; then
    echo "📦 Installing via apk..."
    sudo apk add age
  else
    # Fallback: download binary from GitHub
    echo "📦 Installing from GitHub release..."
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$ARCH" in
      x86_64|amd64) ARCH="amd64" ;;
      aarch64|arm64) ARCH="arm64" ;;
      armv7l) ARCH="arm" ;;
      *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    LATEST=$(curl -sL "https://api.github.com/repos/FiloSottile/age/releases/latest" | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4)
    [ -z "$LATEST" ] && LATEST="v1.2.0"
    
    URL="https://github.com/FiloSottile/age/releases/download/${LATEST}/age-${LATEST}-${OS}-${ARCH}.tar.gz"
    
    TMPDIR=$(mktemp -d)
    curl -sL "$URL" -o "$TMPDIR/age.tar.gz"
    tar xzf "$TMPDIR/age.tar.gz" -C "$TMPDIR"
    
    sudo install -m 755 "$TMPDIR/age/age" /usr/local/bin/age
    sudo install -m 755 "$TMPDIR/age/age-keygen" /usr/local/bin/age-keygen
    
    rm -rf "$TMPDIR"
  fi
}

install_age

# Verify installation
if command -v age &>/dev/null; then
  VERSION=$(age --version 2>/dev/null || echo "installed")
  echo ""
  echo "✅ age installed successfully!"
  echo "   Version: $VERSION"
  echo "   Binary:  $(which age)"
  echo ""
  echo "🔑 Generate a key pair:"
  echo "   age-keygen -o ~/.age/key.txt"
  echo ""
  echo "🔒 Encrypt a file:"
  echo "   age -p -o secret.age secret.txt"
  echo ""
  echo "🔓 Decrypt a file:"
  echo "   age -d -i ~/.age/key.txt secret.age > secret.txt"
else
  echo "❌ Installation failed. Please install age manually:"
  echo "   https://github.com/FiloSottile/age#installation"
  exit 1
fi
