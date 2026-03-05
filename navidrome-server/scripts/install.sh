#!/bin/bash
# Navidrome Installer
# Installs Navidrome music server as a systemd service

set -euo pipefail

VERSION=""
INSTALL_DIR="/opt/navidrome"
DATA_DIR="/var/lib/navidrome"
MUSIC_DIR="${HOME}/Music"
PORT=4533

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[navidrome]${NC} $1"; }
warn() { echo -e "${YELLOW}[navidrome]${NC} $1"; }
err() { echo -e "${RED}[navidrome]${NC} $1" >&2; }

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --version) VERSION="$2"; shift 2 ;;
    --music-folder) MUSIC_DIR="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: install.sh [--version X.Y.Z] [--music-folder /path] [--port 4533]"
      exit 0
      ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l)  ARCH="armv7" ;;
  armv6l)  ARCH="armv6" ;;
  *) err "Unsupported architecture: $ARCH"; exit 1 ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [[ "$OS" != "linux" && "$OS" != "darwin" ]]; then
  err "Unsupported OS: $OS (only Linux and macOS supported)"
  exit 1
fi

# Get latest version if not specified
if [[ -z "$VERSION" ]]; then
  log "Fetching latest version..."
  VERSION=$(curl -s "https://api.github.com/repos/navidrome/navidrome/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
  if [[ -z "$VERSION" ]]; then
    err "Could not determine latest version. Specify with --version"
    exit 1
  fi
fi

log "Installing Navidrome v${VERSION} (${OS}/${ARCH})"

# Check if already installed
if [[ -f "${INSTALL_DIR}/navidrome" ]]; then
  CURRENT=$("${INSTALL_DIR}/navidrome" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
  warn "Navidrome ${CURRENT} already installed at ${INSTALL_DIR}"
  read -rp "Overwrite? [y/N] " confirm
  [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0
fi

# Check for root/sudo
SUDO=""
if [[ $EUID -ne 0 ]]; then
  if command -v sudo &>/dev/null; then
    SUDO="sudo"
  else
    warn "Not running as root and sudo not available. Installing to user directories."
    INSTALL_DIR="${HOME}/.local/share/navidrome/bin"
    DATA_DIR="${HOME}/.local/share/navidrome/data"
  fi
fi

# Create directories
log "Creating directories..."
$SUDO mkdir -p "$INSTALL_DIR" "$DATA_DIR"

# Create navidrome user (if root)
if [[ $EUID -eq 0 ]] || [[ -n "$SUDO" ]]; then
  if ! id navidrome &>/dev/null; then
    log "Creating navidrome user..."
    $SUDO useradd -r -s /bin/false -d "$DATA_DIR" navidrome 2>/dev/null || true
  fi
fi

# Download
DOWNLOAD_URL="https://github.com/navidrome/navidrome/releases/download/v${VERSION}/navidrome_${VERSION}_${OS}_${ARCH}.tar.gz"
TMPFILE=$(mktemp)
log "Downloading from ${DOWNLOAD_URL}..."
curl -fSL "$DOWNLOAD_URL" -o "$TMPFILE" || {
  err "Download failed. Check version and architecture."
  rm -f "$TMPFILE"
  exit 1
}

# Extract
log "Extracting to ${INSTALL_DIR}..."
$SUDO tar -xzf "$TMPFILE" -C "$INSTALL_DIR" navidrome
rm -f "$TMPFILE"
$SUDO chmod +x "${INSTALL_DIR}/navidrome"

# Create config
if [[ ! -f "${DATA_DIR}/navidrome.toml" ]]; then
  log "Creating default config..."
  $SUDO tee "${DATA_DIR}/navidrome.toml" > /dev/null <<EOF
# Navidrome Configuration
MusicFolder = "${MUSIC_DIR}"
DataFolder = "${DATA_DIR}"
Address = "0.0.0.0"
Port = ${PORT}
ScanSchedule = "@every 5m"
AutoImportPlaylists = true
EnableTranscodingConfig = true
UIWelcomeMessage = ""
SessionTimeout = "24h"
LogLevel = "info"
EOF
fi

# Create music directory if it doesn't exist
mkdir -p "$MUSIC_DIR" 2>/dev/null || true

# Set permissions
if [[ $EUID -eq 0 ]] || [[ -n "$SUDO" ]]; then
  $SUDO chown -R navidrome:navidrome "$DATA_DIR" "$INSTALL_DIR"
  $SUDO chmod 750 "$DATA_DIR"
fi

# Create systemd service
if [[ -d /etc/systemd/system ]] && ([[ $EUID -eq 0 ]] || [[ -n "$SUDO" ]]); then
  log "Creating systemd service..."
  $SUDO tee /etc/systemd/system/navidrome.service > /dev/null <<EOF
[Unit]
Description=Navidrome Music Server
After=network.target

[Service]
User=navidrome
Group=navidrome
Type=simple
ExecStart=${INSTALL_DIR}/navidrome --configfile ${DATA_DIR}/navidrome.toml
WorkingDirectory=${DATA_DIR}
TimeoutStopSec=20
KillMode=process
Restart=on-failure
RestartSec=5

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${DATA_DIR}
ReadOnlyPaths=${MUSIC_DIR}

[Install]
WantedBy=multi-user.target
EOF

  $SUDO systemctl daemon-reload
  $SUDO systemctl enable navidrome
  $SUDO systemctl start navidrome

  # Wait for startup
  sleep 2

  if systemctl is-active --quiet navidrome; then
    log "✅ Navidrome v${VERSION} installed and running!"
    echo ""
    echo "   🎵 Web UI:      http://localhost:${PORT}"
    echo "   📂 Music folder: ${MUSIC_DIR}"
    echo "   💾 Data folder:  ${DATA_DIR}"
    echo "   📝 Config:       ${DATA_DIR}/navidrome.toml"
    echo ""
    echo "   Open the web UI to create your admin account."
  else
    err "Service failed to start. Check: sudo journalctl -u navidrome -n 20"
    exit 1
  fi
else
  log "✅ Navidrome v${VERSION} installed (no systemd — start manually)"
  echo ""
  echo "   Start: ${INSTALL_DIR}/navidrome --configfile ${DATA_DIR}/navidrome.toml"
  echo "   Web UI: http://localhost:${PORT}"
fi
