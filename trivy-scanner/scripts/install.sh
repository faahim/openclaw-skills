#!/bin/bash
# Install Trivy — auto-detects OS and architecture
set -euo pipefail

INSTALL_DIR="${TRIVY_INSTALL_DIR:-$HOME/.local/bin}"
TRIVY_VERSION="${TRIVY_VERSION:-latest}"

echo "🔧 Installing Trivy..."

# Detect OS
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
  linux)  OS="Linux" ;;
  darwin) OS="macOS" ;;
  *)      echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)  ARCH="64bit" ;;
  aarch64|arm64) ARCH="ARM64" ;;
  armv7l)  ARCH="ARM" ;;
  *)       echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Check if already installed
if command -v trivy &>/dev/null; then
  CURRENT=$(trivy --version 2>/dev/null | head -1 | awk '{print $2}')
  echo "ℹ️  Trivy $CURRENT already installed"
  
  if [ "$TRIVY_VERSION" = "latest" ]; then
    echo "   Checking for updates..."
  else
    echo "   Requested version: $TRIVY_VERSION"
  fi
fi

# Get latest version if needed
if [ "$TRIVY_VERSION" = "latest" ]; then
  TRIVY_VERSION=$(curl -s "https://api.github.com/repos/aquasecurity/trivy/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
  if [ -z "$TRIVY_VERSION" ] || [ "$TRIVY_VERSION" = "null" ]; then
    echo "❌ Failed to fetch latest version. Set TRIVY_VERSION manually."
    exit 1
  fi
fi

echo "📦 Version: $TRIVY_VERSION"
echo "🖥️  Platform: $OS $ARCH"

# Download
TARBALL="trivy_${TRIVY_VERSION}_${OS}-${ARCH}.tar.gz"
URL="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TARBALL}"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "⬇️  Downloading from $URL..."
curl -fsSL "$URL" -o "$TMPDIR/$TARBALL"

# Extract
echo "📂 Extracting..."
tar -xzf "$TMPDIR/$TARBALL" -C "$TMPDIR"

# Install
mkdir -p "$INSTALL_DIR"
mv "$TMPDIR/trivy" "$INSTALL_DIR/trivy"
chmod +x "$INSTALL_DIR/trivy"

# Verify
if "$INSTALL_DIR/trivy" --version &>/dev/null; then
  VERSION=$("$INSTALL_DIR/trivy" --version 2>/dev/null | head -1)
  echo ""
  echo "✅ Trivy installed successfully!"
  echo "   $VERSION"
  echo "   Location: $INSTALL_DIR/trivy"
  
  # Check PATH
  if ! echo "$PATH" | tr ':' '\n' | grep -q "^${INSTALL_DIR}$"; then
    echo ""
    echo "⚠️  $INSTALL_DIR is not in your PATH. Add it:"
    echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
  fi
else
  echo "❌ Installation failed"
  exit 1
fi

# Pre-download vulnerability database
echo ""
echo "📥 Downloading vulnerability database (first-time setup)..."
"$INSTALL_DIR/trivy" image --download-db-only 2>/dev/null && \
  echo "✅ Database ready" || \
  echo "⚠️  DB download failed — will retry on first scan"
