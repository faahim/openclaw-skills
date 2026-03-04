#!/bin/bash
# Install monolith web page archiver
set -e

echo "🔧 Installing monolith web page archiver..."

# Check if already installed
if command -v monolith &>/dev/null; then
  echo "✅ monolith already installed: $(monolith --version 2>&1 || echo 'unknown version')"
  exit 0
fi

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

install_via_cargo() {
  if command -v cargo &>/dev/null; then
    echo "📦 Installing via cargo..."
    cargo install monolith
    return 0
  fi
  return 1
}

install_via_brew() {
  if command -v brew &>/dev/null; then
    echo "📦 Installing via Homebrew..."
    brew install monolith
    return 0
  fi
  return 1
}

install_via_binary() {
  echo "📦 Downloading pre-built binary..."
  local RELEASE_URL="https://api.github.com/repos/Y2Z/monolith/releases/latest"
  local DOWNLOAD_URL=""

  case "$OS-$ARCH" in
    Linux-x86_64)
      DOWNLOAD_URL=$(curl -s "$RELEASE_URL" | grep -o 'https://[^"]*linux-x86_64[^"]*' | head -1)
      ;;
    Linux-aarch64|Linux-arm64)
      DOWNLOAD_URL=$(curl -s "$RELEASE_URL" | grep -o 'https://[^"]*linux-aarch64[^"]*\|https://[^"]*linux-arm64[^"]*' | head -1)
      ;;
    Darwin-x86_64)
      DOWNLOAD_URL=$(curl -s "$RELEASE_URL" | grep -o 'https://[^"]*darwin-x86_64[^"]*\|https://[^"]*apple-darwin[^"]*x86_64[^"]*' | head -1)
      ;;
    Darwin-arm64)
      DOWNLOAD_URL=$(curl -s "$RELEASE_URL" | grep -o 'https://[^"]*darwin-aarch64[^"]*\|https://[^"]*apple-darwin[^"]*arm64[^"]*\|https://[^"]*darwin-arm64[^"]*' | head -1)
      ;;
  esac

  if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ No pre-built binary found for $OS-$ARCH"
    return 1
  fi

  local TMP_DIR=$(mktemp -d)
  local FILENAME=$(basename "$DOWNLOAD_URL")

  curl -sL "$DOWNLOAD_URL" -o "$TMP_DIR/$FILENAME"

  # Handle different archive formats
  case "$FILENAME" in
    *.tar.gz|*.tgz)
      tar -xzf "$TMP_DIR/$FILENAME" -C "$TMP_DIR"
      ;;
    *.zip)
      unzip -q "$TMP_DIR/$FILENAME" -d "$TMP_DIR"
      ;;
    *)
      # Might be a raw binary
      chmod +x "$TMP_DIR/$FILENAME"
      mv "$TMP_DIR/$FILENAME" "$TMP_DIR/monolith"
      ;;
  esac

  # Find the binary
  local BIN=$(find "$TMP_DIR" -name "monolith" -type f | head -1)
  if [ -z "$BIN" ]; then
    echo "❌ Could not find monolith binary in download"
    rm -rf "$TMP_DIR"
    return 1
  fi

  chmod +x "$BIN"

  # Install to user-local bin
  local INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
  mv "$BIN" "$INSTALL_DIR/monolith"
  rm -rf "$TMP_DIR"

  # Add to PATH if needed
  if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
    export PATH="$INSTALL_DIR:$PATH"
    echo "ℹ️  Added $INSTALL_DIR to PATH (reload shell or source ~/.bashrc)"
  fi

  return 0
}

# Try install methods in order
if install_via_brew 2>/dev/null; then
  echo "✅ monolith installed via Homebrew"
elif install_via_binary 2>/dev/null; then
  echo "✅ monolith installed via binary download"
elif install_via_cargo 2>/dev/null; then
  echo "✅ monolith installed via cargo"
else
  echo "❌ Failed to install monolith. Please install manually:"
  echo "   https://github.com/Y2Z/monolith#installation"
  exit 1
fi

# Verify
if command -v monolith &>/dev/null; then
  echo "🎉 monolith ready: $(monolith --version 2>&1 || echo 'installed')"
else
  echo "⚠️  monolith installed but not in PATH. Try: source ~/.bashrc"
fi
