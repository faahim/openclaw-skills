#!/bin/bash
# Install DuckDB CLI — auto-detects OS and architecture
set -e

INSTALL_DIR="${DUCKDB_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${DUCKDB_VERSION:-latest}"

echo "🦆 Installing DuckDB CLI..."

# Detect OS
OS="$(uname -s)"
case "$OS" in
  Linux)  PLATFORM="linux" ;;
  Darwin) PLATFORM="osx" ;;
  *)      echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)  ARCH_SUFFIX="amd64" ;;
  aarch64|arm64) ARCH_SUFFIX="arm64" ;;
  *)             echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get latest version if not specified
if [ "$VERSION" = "latest" ]; then
  VERSION=$(curl -sL "https://api.github.com/repos/duckdb/duckdb/releases/latest" | grep '"tag_name"' | head -1 | sed 's/.*"v\([^"]*\)".*/\1/')
  if [ -z "$VERSION" ]; then
    echo "❌ Could not determine latest version. Set DUCKDB_VERSION manually."
    exit 1
  fi
fi

echo "  Platform: $PLATFORM-$ARCH_SUFFIX"
echo "  Version:  v$VERSION"
echo "  Install:  $INSTALL_DIR/duckdb"

# Check if already installed with same version
if command -v duckdb &>/dev/null; then
  CURRENT=$(duckdb -c "SELECT version()" 2>/dev/null | grep -oP 'v[\d.]+' | head -1 || true)
  if [ "$CURRENT" = "v$VERSION" ]; then
    echo "✅ DuckDB v$VERSION already installed."
    duckdb -c "SELECT version()" 2>/dev/null
    exit 0
  fi
  echo "  Upgrading from $CURRENT to v$VERSION..."
fi

# Download
DOWNLOAD_URL="https://github.com/duckdb/duckdb/releases/download/v${VERSION}/duckdb_cli-${PLATFORM}-${ARCH_SUFFIX}.zip"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "  Downloading from GitHub..."
curl -sL "$DOWNLOAD_URL" -o "$TMPDIR/duckdb.zip"

# Extract
cd "$TMPDIR"
unzip -q duckdb.zip

# Install
mkdir -p "$INSTALL_DIR"
mv duckdb "$INSTALL_DIR/duckdb"
chmod +x "$INSTALL_DIR/duckdb"

# Verify
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo ""
  echo "⚠️  Add to PATH: export PATH=\"$INSTALL_DIR:\$PATH\""
  echo "   (Add this to ~/.bashrc or ~/.zshrc for persistence)"
fi

echo ""
echo "✅ DuckDB v$VERSION installed successfully!"
"$INSTALL_DIR/duckdb" -c "SELECT '🦆 DuckDB ' || version() || ' ready!' as status"
