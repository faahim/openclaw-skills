#!/bin/bash
# Install Kopia backup tool — auto-detects OS and architecture
set -euo pipefail

KOPIA_VERSION="${KOPIA_VERSION:-0.18.2}"

echo "🔧 Installing Kopia v${KOPIA_VERSION}..."

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l)  ARCH="arm" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux)
    # Check if apt is available (Debian/Ubuntu)
    if command -v apt-get &>/dev/null; then
      echo "📦 Installing via APT repository..."
      curl -fsSL https://kopia.io/signing-key | sudo gpg --dearmor -o /usr/share/keyrings/kopia-keyring.gpg 2>/dev/null || true
      echo "deb [signed-by=/usr/share/keyrings/kopia-keyring.gpg] http://packages.kopia.io/apt/ stable main" | sudo tee /etc/apt/sources.list.d/kopia.list
      sudo apt-get update -qq
      sudo apt-get install -y -qq kopia
    else
      # Direct binary download
      echo "📦 Installing binary for linux/${ARCH}..."
      DOWNLOAD_URL="https://github.com/kopia/kopia/releases/download/v${KOPIA_VERSION}/kopia-${KOPIA_VERSION}-linux-${ARCH}.tar.gz"
      TMP_DIR=$(mktemp -d)
      curl -fsSL "$DOWNLOAD_URL" -o "${TMP_DIR}/kopia.tar.gz"
      tar -xzf "${TMP_DIR}/kopia.tar.gz" -C "${TMP_DIR}"
      sudo mv "${TMP_DIR}/kopia-${KOPIA_VERSION}-linux-${ARCH}/kopia" /usr/local/bin/kopia
      sudo chmod +x /usr/local/bin/kopia
      rm -rf "$TMP_DIR"
    fi
    ;;
  darwin)
    if command -v brew &>/dev/null; then
      echo "📦 Installing via Homebrew..."
      brew install kopia
    else
      echo "📦 Installing binary for macOS/${ARCH}..."
      DOWNLOAD_URL="https://github.com/kopia/kopia/releases/download/v${KOPIA_VERSION}/kopia-${KOPIA_VERSION}-macOS-${ARCH}.tar.gz"
      TMP_DIR=$(mktemp -d)
      curl -fsSL "$DOWNLOAD_URL" -o "${TMP_DIR}/kopia.tar.gz"
      tar -xzf "${TMP_DIR}/kopia.tar.gz" -C "${TMP_DIR}"
      sudo mv "${TMP_DIR}/kopia-${KOPIA_VERSION}-macOS-${ARCH}/kopia" /usr/local/bin/kopia
      sudo chmod +x /usr/local/bin/kopia
      rm -rf "$TMP_DIR"
    fi
    ;;
  *)
    echo "❌ Unsupported OS: $OS"
    exit 1
    ;;
esac

# Verify installation
if command -v kopia &>/dev/null; then
  INSTALLED_VERSION=$(kopia --version 2>/dev/null | head -1)
  echo "✅ Kopia installed: $INSTALLED_VERSION"
  echo ""
  echo "Next steps:"
  echo "  1. Create a repository:  kopia repository create filesystem --path /backup/repo"
  echo "  2. Take a snapshot:      kopia snapshot create /home/\$(whoami)"
  echo "  3. List snapshots:       kopia snapshot list"
else
  echo "❌ Installation failed. Please check errors above."
  exit 1
fi
