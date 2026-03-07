#!/bin/bash
set -euo pipefail

# Install Mozilla SOPS and age encryption tool

echo "🔐 Installing SOPS Secrets Manager dependencies..."

SOPS_VERSION="3.9.4"
AGE_VERSION="1.2.1"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Normalize architecture
case "$ARCH" in
  x86_64|amd64) ARCH_SOPS="amd64"; ARCH_AGE="amd64" ;;
  aarch64|arm64) ARCH_SOPS="arm64"; ARCH_AGE="arm64" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Install directory
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
USE_SUDO=""
if [ ! -w "$INSTALL_DIR" ]; then
  USE_SUDO="sudo"
fi

install_sops() {
  if command -v sops &>/dev/null; then
    CURRENT=$(sops --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
    echo "ℹ️  SOPS already installed (v${CURRENT})"
    return 0
  fi

  echo "📥 Installing SOPS v${SOPS_VERSION}..."

  local SOPS_URL="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.${OS}.${ARCH_SOPS}"

  TMP=$(mktemp)
  curl -fsSL "$SOPS_URL" -o "$TMP"
  chmod +x "$TMP"
  $USE_SUDO mv "$TMP" "${INSTALL_DIR}/sops"

  echo "✅ SOPS v${SOPS_VERSION} installed to ${INSTALL_DIR}/sops"
}

install_age() {
  if command -v age &>/dev/null; then
    CURRENT=$(age --version 2>/dev/null || echo "unknown")
    echo "ℹ️  age already installed (${CURRENT})"
    return 0
  fi

  echo "📥 Installing age v${AGE_VERSION}..."

  local AGE_URL="https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-${OS}-${ARCH_AGE}.tar.gz"

  TMP_DIR=$(mktemp -d)
  curl -fsSL "$AGE_URL" | tar xz -C "$TMP_DIR"
  $USE_SUDO mv "$TMP_DIR/age/age" "${INSTALL_DIR}/age"
  $USE_SUDO mv "$TMP_DIR/age/age-keygen" "${INSTALL_DIR}/age-keygen"
  rm -rf "$TMP_DIR"

  echo "✅ age v${AGE_VERSION} installed to ${INSTALL_DIR}/"
}

install_sops
install_age

echo ""
echo "🎉 Installation complete!"
echo "   sops: $(sops --version 2>/dev/null || echo 'installed')"
echo "   age:  $(age --version 2>/dev/null || echo 'installed')"
echo ""
echo "Next: Run 'bash scripts/setup-keys.sh' to generate your encryption key."
