#!/bin/bash
# Kopia Backup Manager — Install Script
# Installs Kopia binary for Linux (amd64/arm64) or macOS

set -euo pipefail

KOPIA_VERSION="${KOPIA_VERSION:-0.17.0}"

echo "🔧 Installing Kopia v${KOPIA_VERSION}..."

# Detect OS and architecture
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64)  ARCH="x64" ;;
  aarch64) ARCH="arm64" ;;
  arm64)   ARCH="arm64" ;;
  *)
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

case "$OS" in
  linux)
    if command -v apt-get &>/dev/null; then
      echo "📦 Installing via APT repository..."
      curl -s https://kopia.io/signing-key | sudo gpg --dearmor -o /usr/share/keyrings/kopia-keyring.gpg 2>/dev/null || true
      echo "deb [signed-by=/usr/share/keyrings/kopia-keyring.gpg] http://packages.kopia.io/apt/ stable main" | sudo tee /etc/apt/sources.list.d/kopia.list >/dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq kopia
    elif command -v yum &>/dev/null || command -v dnf &>/dev/null; then
      echo "📦 Installing via RPM..."
      sudo rpm --import https://kopia.io/signing-key
      cat <<EOF | sudo tee /etc/yum.repos.d/kopia.repo >/dev/null
[kopia]
name=Kopia
baseurl=http://packages.kopia.io/rpm/stable/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://kopia.io/signing-key
EOF
      if command -v dnf &>/dev/null; then
        sudo dnf install -y kopia
      else
        sudo yum install -y kopia
      fi
    else
      echo "📦 Installing binary directly..."
      TARBALL="kopia-${KOPIA_VERSION}-${OS}-${ARCH}.tar.gz"
      URL="https://github.com/kopia/kopia/releases/download/v${KOPIA_VERSION}/${TARBALL}"
      TMP_DIR=$(mktemp -d)
      curl -sL "$URL" -o "${TMP_DIR}/${TARBALL}"
      tar -xzf "${TMP_DIR}/${TARBALL}" -C "${TMP_DIR}"
      sudo mv "${TMP_DIR}/kopia-${KOPIA_VERSION}-${OS}-${ARCH}/kopia" /usr/local/bin/kopia
      sudo chmod +x /usr/local/bin/kopia
      rm -rf "$TMP_DIR"
    fi
    ;;
  darwin)
    if command -v brew &>/dev/null; then
      echo "📦 Installing via Homebrew..."
      brew install kopia
    else
      echo "📦 Installing binary directly..."
      TARBALL="kopia-${KOPIA_VERSION}-macOS-${ARCH}.tar.gz"
      URL="https://github.com/kopia/kopia/releases/download/v${KOPIA_VERSION}/${TARBALL}"
      TMP_DIR=$(mktemp -d)
      curl -sL "$URL" -o "${TMP_DIR}/${TARBALL}"
      tar -xzf "${TMP_DIR}/${TARBALL}" -C "${TMP_DIR}"
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
  echo "✅ Kopia installed successfully: $(kopia --version 2>&1 | head -1)"
else
  echo "❌ Installation failed. Please install manually: https://kopia.io/docs/installation/"
  exit 1
fi

echo ""
echo "📝 Next steps:"
echo "  1. Create a repository:  kopia repository create filesystem --path /backup/kopia"
echo "  2. Take a snapshot:      kopia snapshot create /home"
echo "  3. List snapshots:       kopia snapshot list"
