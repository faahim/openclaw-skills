#!/bin/bash
# Bun Runtime Installer & Updater
# Installs or updates Bun to ~/.bun

set -euo pipefail

VERSION=""
UPDATE=false

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --version VERSION   Install specific version (e.g., 1.2.0)"
  echo "  --update            Update to latest version"
  echo "  -h, --help          Show this help"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --version) VERSION="$2"; shift 2 ;;
    --update) UPDATE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"

# Check if Bun is already installed
if command -v bun &>/dev/null; then
  CURRENT=$(bun --version 2>/dev/null || echo "unknown")
  echo "📦 Bun $CURRENT currently installed"
  if [[ "$UPDATE" == false && -z "$VERSION" ]]; then
    echo "ℹ️  Use --update to update or --version X.Y.Z to install specific version"
    exit 0
  fi
fi

# Check prerequisites
for cmd in curl unzip; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Required: $cmd"
    echo "   Install with: sudo apt-get install $cmd"
    exit 1
  fi
done

# Detect architecture
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$ARCH" in
  x86_64|amd64) ARCH="x64" ;;
  aarch64|arm64) ARCH="aarch64" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux|darwin) ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

echo "🔧 Platform: $OS-$ARCH"

# Build download URL
if [[ -n "$VERSION" ]]; then
  echo "📥 Installing Bun v$VERSION..."
  URL="https://github.com/oven-sh/bun/releases/download/bun-v${VERSION}/bun-${OS}-${ARCH}.zip"
else
  echo "📥 Installing latest Bun..."
  URL="https://github.com/oven-sh/bun/releases/latest/download/bun-${OS}-${ARCH}.zip"
fi

# Download and install
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "⬇️  Downloading from $URL"
curl -fsSL "$URL" -o "$TMPDIR/bun.zip" || {
  echo "❌ Download failed. Check version number or network."
  exit 1
}

echo "📂 Extracting..."
unzip -q -o "$TMPDIR/bun.zip" -d "$TMPDIR"

# Find the bun binary
BUN_BIN=$(find "$TMPDIR" -name "bun" -type f | head -1)
if [[ -z "$BUN_BIN" ]]; then
  echo "❌ Could not find bun binary in archive"
  exit 1
fi

# Install
mkdir -p "$BUN_INSTALL/bin"
cp "$BUN_BIN" "$BUN_INSTALL/bin/bun"
chmod +x "$BUN_INSTALL/bin/bun"

# Create bunx symlink
ln -sf "$BUN_INSTALL/bin/bun" "$BUN_INSTALL/bin/bunx"

# Verify
NEW_VERSION=$("$BUN_INSTALL/bin/bun" --version 2>/dev/null || echo "unknown")
echo "✅ Bun $NEW_VERSION installed to $BUN_INSTALL/bin/bun"

# Check PATH
if ! echo "$PATH" | grep -q "$BUN_INSTALL/bin"; then
  echo ""
  echo "⚠️  Add Bun to your PATH:"
  echo "   echo 'export BUN_INSTALL=\"$BUN_INSTALL\"' >> ~/.bashrc"
  echo "   echo 'export PATH=\"\$BUN_INSTALL/bin:\$PATH\"' >> ~/.bashrc"
  echo "   source ~/.bashrc"
  
  # Auto-add if .bashrc exists
  if [[ -f "$HOME/.bashrc" ]]; then
    if ! grep -q "BUN_INSTALL" "$HOME/.bashrc"; then
      echo "" >> "$HOME/.bashrc"
      echo "# Bun" >> "$HOME/.bashrc"
      echo "export BUN_INSTALL=\"$BUN_INSTALL\"" >> "$HOME/.bashrc"
      echo "export PATH=\"\$BUN_INSTALL/bin:\$PATH\"" >> "$HOME/.bashrc"
      echo "✅ Added to ~/.bashrc automatically. Run: source ~/.bashrc"
    fi
  fi
fi

echo ""
echo "🚀 Get started:"
echo "   bun init my-project    # Create new project"
echo "   bun run index.ts       # Run TypeScript directly"
echo "   bun add express        # Install packages"
echo "   bunx create-next-app   # Run packages without installing"
