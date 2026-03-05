#!/bin/bash
# Install Smallstep step-cli and step-ca
set -euo pipefail

echo "🔐 Installing Smallstep step-cli and step-ca..."

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l)  ARCH="armv7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get latest versions
STEP_CLI_VERSION=$(curl -s https://api.github.com/repos/smallstep/cli/releases/latest | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/')
STEP_CA_VERSION=$(curl -s https://api.github.com/repos/smallstep/certificates/releases/latest | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/')

if [ -z "$STEP_CLI_VERSION" ] || [ -z "$STEP_CA_VERSION" ]; then
  echo "❌ Failed to fetch latest versions. Check internet connection."
  exit 1
fi

echo "📦 step-cli version: $STEP_CLI_VERSION"
echo "📦 step-ca version: $STEP_CA_VERSION"

install_linux() {
  local tmpdir=$(mktemp -d)
  
  # Check for existing package manager installs
  if command -v step &>/dev/null && command -v step-ca &>/dev/null; then
    echo "✅ step-cli and step-ca already installed"
    step version
    step-ca version
    return 0
  fi

  # Try package manager first
  if command -v apt-get &>/dev/null; then
    echo "📥 Installing via apt..."
    wget -qO- https://packages.smallstep.com/keys/smallstep.asc | sudo gpg --dearmor -o /usr/share/keyrings/smallstep-archive-keyring.gpg 2>/dev/null || true
    echo "deb [signed-by=/usr/share/keyrings/smallstep-archive-keyring.gpg] https://packages.smallstep.com/deb stable main" | sudo tee /etc/apt/sources.list.d/smallstep.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq step-cli step-ca
  else
    # Direct binary download
    echo "📥 Downloading binaries..."
    
    # step-cli
    curl -sSfL "https://github.com/smallstep/cli/releases/download/v${STEP_CLI_VERSION}/step_linux_${STEP_CLI_VERSION}_${ARCH}.tar.gz" -o "$tmpdir/step-cli.tar.gz"
    tar xzf "$tmpdir/step-cli.tar.gz" -C "$tmpdir"
    sudo mv "$tmpdir/step_${STEP_CLI_VERSION}/bin/step" /usr/local/bin/step
    
    # step-ca
    curl -sSfL "https://github.com/smallstep/certificates/releases/download/v${STEP_CA_VERSION}/step-ca_linux_${STEP_CA_VERSION}_${ARCH}.tar.gz" -o "$tmpdir/step-ca.tar.gz"
    tar xzf "$tmpdir/step-ca.tar.gz" -C "$tmpdir"
    sudo mv "$tmpdir/step-ca_${STEP_CA_VERSION}/bin/step-ca" /usr/local/bin/step-ca
  fi
  
  rm -rf "$tmpdir"
}

install_macos() {
  if command -v brew &>/dev/null; then
    echo "📥 Installing via Homebrew..."
    brew install step smallstep/smallstep/step-ca
  else
    echo "❌ Homebrew not found. Install from: https://brew.sh"
    echo "   Then run: brew install step smallstep/smallstep/step-ca"
    exit 1
  fi
}

case "$OS" in
  linux)  install_linux ;;
  darwin) install_macos ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Verify installation
echo ""
echo "✅ Installation complete!"
echo ""
step version 2>/dev/null || echo "⚠️  step-cli not in PATH"
step-ca version 2>/dev/null || echo "⚠️  step-ca not in PATH"
echo ""
echo "Next: Run 'bash scripts/setup-ca.sh' to initialize your CA"
