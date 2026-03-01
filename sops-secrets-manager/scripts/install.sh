#!/bin/bash
# Install SOPS and age for secrets management
set -euo pipefail

SOPS_VERSION="${SOPS_VERSION:-3.9.4}"
AGE_VERSION="${AGE_VERSION:-1.2.1}"
FORCE="${1:-}"

echo "🔐 SOPS Secrets Manager — Installer"
echo "======================================"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l) ARCH="arm" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) OS_LABEL="linux" ;;
  darwin) OS_LABEL="darwin" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Install directory
INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"

# Add to PATH if not already
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  export PATH="$INSTALL_DIR:$PATH"
  echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "${HOME}/.bashrc" 2>/dev/null || true
  echo "📋 Added $INSTALL_DIR to PATH (restart shell or source ~/.bashrc)"
fi

# Install age
install_age() {
  if command -v age &>/dev/null && [[ "$FORCE" != "--force" ]]; then
    echo "✅ age already installed: $(age --version 2>/dev/null || echo 'unknown version')"
    return
  fi

  echo "📦 Installing age v${AGE_VERSION}..."
  local TMPDIR=$(mktemp -d)
  local AGE_URL="https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-${OS_LABEL}-${ARCH}.tar.gz"

  if curl -fsSL "$AGE_URL" -o "$TMPDIR/age.tar.gz"; then
    tar -xzf "$TMPDIR/age.tar.gz" -C "$TMPDIR"
    cp "$TMPDIR/age/age" "$INSTALL_DIR/age"
    cp "$TMPDIR/age/age-keygen" "$INSTALL_DIR/age-keygen"
    chmod +x "$INSTALL_DIR/age" "$INSTALL_DIR/age-keygen"
    echo "✅ age v${AGE_VERSION} installed to $INSTALL_DIR"
  else
    echo "❌ Failed to download age. Check your internet connection."
    rm -rf "$TMPDIR"
    return 1
  fi
  rm -rf "$TMPDIR"
}

# Install sops
install_sops() {
  if command -v sops &>/dev/null && [[ "$FORCE" != "--force" ]]; then
    echo "✅ sops already installed: $(sops --version 2>/dev/null || echo 'unknown version')"
    return
  fi

  echo "📦 Installing sops v${SOPS_VERSION}..."
  local SOPS_URL="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.${OS_LABEL}.${ARCH}"

  if curl -fsSL "$SOPS_URL" -o "$INSTALL_DIR/sops"; then
    chmod +x "$INSTALL_DIR/sops"
    echo "✅ sops v${SOPS_VERSION} installed to $INSTALL_DIR"
  else
    echo "❌ Failed to download sops. Check your internet connection."
    return 1
  fi
}

install_age
install_sops

echo ""
echo "✅ Installation complete!"
echo "   sops: $(sops --version 2>&1 | head -1 || echo 'installed')"
echo "   age:  $(age --version 2>&1 | head -1 || echo 'installed')"
echo ""
echo "Next steps:"
echo "  1. Generate a key:  bash scripts/setup-keys.sh"
echo "  2. Init repo:       bash scripts/init-repo.sh --key <your-public-key>"
echo "  3. Encrypt a file:  bash scripts/run.sh encrypt secrets.yaml"
