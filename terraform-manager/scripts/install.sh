#!/bin/bash
# Terraform Installer — Downloads and installs Terraform binary
set -euo pipefail

VERSION=""
INSTALL_DIR="/usr/local/bin"

while [[ $# -gt 0 ]]; do
  case $1 in
    --version) VERSION="$2"; shift 2 ;;
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case $ARCH in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l) ARCH="arm" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get latest version if not specified
if [[ -z "$VERSION" ]]; then
  echo "🔍 Fetching latest Terraform version..."
  VERSION=$(curl -sL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')
  if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
    echo "❌ Could not determine latest version. Use --version to specify."
    exit 1
  fi
fi

echo "📦 Downloading Terraform v${VERSION} for ${OS}_${ARCH}..."

DOWNLOAD_URL="https://releases.hashicorp.com/terraform/${VERSION}/terraform_${VERSION}_${OS}_${ARCH}.zip"
CHECKSUM_URL="https://releases.hashicorp.com/terraform/${VERSION}/terraform_${VERSION}_SHA256SUMS"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Download binary
if ! curl -sL "$DOWNLOAD_URL" -o "$TMP_DIR/terraform.zip"; then
  echo "❌ Failed to download Terraform v${VERSION}"
  exit 1
fi

# Download checksums and verify
curl -sL "$CHECKSUM_URL" -o "$TMP_DIR/SHA256SUMS"
EXPECTED_SHA=$(grep "terraform_${VERSION}_${OS}_${ARCH}.zip" "$TMP_DIR/SHA256SUMS" | awk '{print $1}')
ACTUAL_SHA=$(sha256sum "$TMP_DIR/terraform.zip" | awk '{print $1}')

if [[ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]]; then
  echo "❌ Checksum verification failed!"
  echo "   Expected: $EXPECTED_SHA"
  echo "   Got:      $ACTUAL_SHA"
  exit 1
fi

echo "✅ Checksum verified"

# Extract and install
unzip -qo "$TMP_DIR/terraform.zip" -d "$TMP_DIR"

if [[ -w "$INSTALL_DIR" ]]; then
  mv "$TMP_DIR/terraform" "$INSTALL_DIR/terraform"
else
  sudo mv "$TMP_DIR/terraform" "$INSTALL_DIR/terraform"
fi

chmod +x "$INSTALL_DIR/terraform"

# Verify installation
INSTALLED_VERSION=$("$INSTALL_DIR/terraform" version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || "$INSTALL_DIR/terraform" --version | head -1 | awk '{print $2}')
echo "✅ Terraform v${INSTALLED_VERSION} installed to ${INSTALL_DIR}/terraform"
