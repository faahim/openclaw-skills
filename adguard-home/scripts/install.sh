#!/bin/bash
# AdGuard Home Installer
# Installs AdGuard Home binary or via Docker

set -euo pipefail

INSTALL_DIR="${ADGUARD_INSTALL_DIR:-/opt/AdGuardHome}"
METHOD="${1:-binary}"  # binary or docker

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err() { log "ERROR: $*" >&2; exit 1; }

check_root() {
  if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (sudo)"
  fi
}

install_binary() {
  check_root
  log "Installing AdGuard Home (binary)..."

  # Detect architecture
  ARCH=$(uname -m)
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l)  ARCH="armv7" ;;
    armv6l)  ARCH="armv6" ;;
    *)       err "Unsupported architecture: $ARCH" ;;
  esac

  # Get latest release URL
  RELEASE_URL="https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest"
  DOWNLOAD_URL=$(curl -sL "$RELEASE_URL" | grep "browser_download_url" | grep "${OS}_${ARCH}" | grep -v ".sig" | head -1 | cut -d '"' -f 4)

  if [[ -z "$DOWNLOAD_URL" ]]; then
    err "Could not find download URL for ${OS}_${ARCH}"
  fi

  log "Downloading from: $DOWNLOAD_URL"
  TMP_DIR=$(mktemp -d)
  curl -sL "$DOWNLOAD_URL" -o "$TMP_DIR/adguardhome.tar.gz"

  log "Extracting..."
  tar -xzf "$TMP_DIR/adguardhome.tar.gz" -C "$TMP_DIR"

  # Install
  mkdir -p "$INSTALL_DIR"
  cp "$TMP_DIR/AdGuardHome/AdGuardHome" "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/AdGuardHome"

  # Install as service
  "$INSTALL_DIR/AdGuardHome" -s install

  rm -rf "$TMP_DIR"

  log "✅ AdGuard Home installed at $INSTALL_DIR"
  log "   Web UI: http://$(hostname -I | awk '{print $1}'):3000"
  log "   DNS:    port 53"
  log "   Run initial setup at the web UI URL above"
}

install_docker() {
  if ! command -v docker &>/dev/null; then
    err "Docker is not installed. Install Docker first or use 'binary' method."
  fi

  log "Installing AdGuard Home (Docker)..."

  docker pull adguard/adguardhome:latest

  mkdir -p "${INSTALL_DIR}/work" "${INSTALL_DIR}/conf"

  docker run -d \
    --name adguardhome \
    --restart=always \
    -v "${INSTALL_DIR}/work:/opt/adguardhome/work" \
    -v "${INSTALL_DIR}/conf:/opt/adguardhome/conf" \
    -p 53:53/tcp -p 53:53/udp \
    -p 3000:3000/tcp \
    -p 443:443/tcp -p 443:443/udp \
    -p 80:80/tcp \
    adguard/adguardhome:latest

  log "✅ AdGuard Home running in Docker"
  log "   Web UI: http://$(hostname -I | awk '{print $1}'):3000"
  log "   Container: adguardhome"
}

case "$METHOD" in
  binary) install_binary ;;
  docker) install_docker ;;
  *)      err "Usage: $0 [binary|docker]" ;;
esac
