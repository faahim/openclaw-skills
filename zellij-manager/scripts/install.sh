#!/bin/bash
# Zellij Installer — auto-detects platform, installs latest release
set -euo pipefail

INSTALL_DIR="${ZELLIJ_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${ZELLIJ_VERSION:-latest}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[zellij-installer]${NC} $1"; }
warn() { echo -e "${YELLOW}[zellij-installer]${NC} $1"; }
err() { echo -e "${RED}[zellij-installer]${NC} $1" >&2; }

# Detect platform
detect_platform() {
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"

    case "$os" in
        linux) os="unknown-linux-musl" ;;
        darwin) os="apple-darwin" ;;
        *) err "Unsupported OS: $os"; exit 1 ;;
    esac

    case "$arch" in
        x86_64|amd64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) err "Unsupported architecture: $arch"; exit 1 ;;
    esac

    echo "${arch}-${os}"
}

# Get latest version tag from GitHub
get_latest_version() {
    curl -sL "https://api.github.com/repos/zellij-org/zellij/releases/latest" \
        | grep '"tag_name"' | head -1 | sed 's/.*"v\([^"]*\)".*/\1/'
}

# Handle --update flag
if [[ "${1:-}" == "--update" ]]; then
    if command -v zellij &>/dev/null; then
        CURRENT=$(zellij --version 2>/dev/null | awk '{print $2}')
        log "Current version: $CURRENT"
    fi
    VERSION="latest"
fi

# Resolve version
if [[ "$VERSION" == "latest" ]]; then
    log "Fetching latest version..."
    VERSION=$(get_latest_version)
fi
log "Installing Zellij v${VERSION}"

# Detect platform
PLATFORM=$(detect_platform)
log "Detected platform: $PLATFORM"

# Download
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

DOWNLOAD_URL="https://github.com/zellij-org/zellij/releases/download/v${VERSION}/zellij-${PLATFORM}.tar.gz"
log "Downloading from: $DOWNLOAD_URL"

curl -sL "$DOWNLOAD_URL" -o "$TMPDIR/zellij.tar.gz"

# Extract
cd "$TMPDIR"
tar xzf zellij.tar.gz

# Install
mkdir -p "$INSTALL_DIR"
mv zellij "$INSTALL_DIR/zellij"
chmod +x "$INSTALL_DIR/zellij"

log "Installed to: $INSTALL_DIR/zellij"

# Verify
if "$INSTALL_DIR/zellij" --version &>/dev/null; then
    log "✅ Zellij $("$INSTALL_DIR/zellij" --version) installed successfully!"
else
    err "Installation failed — binary not executable"
    exit 1
fi

# PATH check
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    warn "⚠️  $INSTALL_DIR is not in your PATH"
    warn "Add this to your shell profile:"
    warn "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi

# Create default config directory
mkdir -p "$HOME/.config/zellij/layouts"
log "Config directory: ~/.config/zellij/"
log "Layouts directory: ~/.config/zellij/layouts/"

# Generate default config if none exists
if [[ ! -f "$HOME/.config/zellij/config.kdl" ]]; then
    "$INSTALL_DIR/zellij" setup --dump-config > "$HOME/.config/zellij/config.kdl" 2>/dev/null || true
    log "Generated default config at ~/.config/zellij/config.kdl"
fi

log "🎉 Done! Run 'zellij' to start."
