#!/bin/bash
# Supabase CLI Installer
# Detects OS/arch and installs the appropriate binary

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[supabase-install]${NC} $1"; }
warn() { echo -e "${YELLOW}[supabase-install]${NC} $1"; }
err() { echo -e "${RED}[supabase-install]${NC} $1" >&2; }

# Check if already installed
if command -v supabase &>/dev/null; then
  CURRENT_VERSION=$(supabase --version 2>/dev/null | grep -oP '[\d.]+' || echo "unknown")
  log "Supabase CLI already installed (v${CURRENT_VERSION})"
  read -p "Reinstall/upgrade? [y/N] " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) err "Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux)
    log "Detected Linux ($ARCH)"
    ;;
  darwin)
    log "Detected macOS ($ARCH)"
    ;;
  *)
    err "Unsupported OS: $OS"
    exit 1
    ;;
esac

# Try npm first (most portable)
if command -v npm &>/dev/null; then
  log "Installing via npm..."
  npm install -g supabase
  log "✅ Installed: $(supabase --version)"
  exit 0
fi

# Try brew
if command -v brew &>/dev/null; then
  log "Installing via Homebrew..."
  brew install supabase/tap/supabase
  log "✅ Installed: $(supabase --version)"
  exit 0
fi

# Direct binary download
log "Installing from GitHub releases..."
LATEST_URL="https://github.com/supabase/cli/releases/latest/download/supabase_${OS}_${ARCH}.tar.gz"

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
TMP_DIR=$(mktemp -d)

curl -fsSL "$LATEST_URL" | tar xzf - -C "$TMP_DIR" supabase

if [ -w "$INSTALL_DIR" ]; then
  mv "$TMP_DIR/supabase" "$INSTALL_DIR/supabase"
else
  sudo mv "$TMP_DIR/supabase" "$INSTALL_DIR/supabase"
fi

chmod +x "$INSTALL_DIR/supabase"
rm -rf "$TMP_DIR"

log "✅ Installed: $(supabase --version)"
log "Binary location: $(which supabase)"

# Check Docker
if ! command -v docker &>/dev/null; then
  warn "⚠️  Docker not found. Required for 'supabase start' (local dev)."
  warn "   Install Docker: https://docs.docker.com/get-docker/"
elif ! docker info &>/dev/null 2>&1; then
  warn "⚠️  Docker installed but not running. Start it for local dev."
fi

log "Run 'supabase init' in your project to get started."
