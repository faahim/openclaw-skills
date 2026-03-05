#!/bin/bash
# NetBird VPN Setup Script
# Installs NetBird and connects to mesh network

set -euo pipefail

SETUP_KEY="${NETBIRD_SETUP_KEY:-}"
MANAGEMENT_URL="${NETBIRD_MANAGEMENT_URL:-https://api.netbird.io}"
ENABLE_DNS=false
ENABLE_ROSENPASS=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --setup-key KEY       Setup key for headless authentication
  --management-url URL  Management server URL (default: https://api.netbird.io)
  --enable-dns          Enable NetBird DNS resolution
  --enable-rosenpass    Enable post-quantum key exchange
  -h, --help            Show this help

Examples:
  # Interactive setup (opens browser)
  $(basename "$0")

  # Headless setup with key
  $(basename "$0") --setup-key "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

  # Self-hosted management server
  $(basename "$0") --management-url "https://vpn.example.com" --setup-key "KEY"
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --setup-key) SETUP_KEY="$2"; shift 2 ;;
    --management-url) MANAGEMENT_URL="$2"; shift 2 ;;
    --enable-dns) ENABLE_DNS=true; shift ;;
    --enable-rosenpass) ENABLE_ROSENPASS=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

# Detect OS
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  elif [[ "$(uname)" == "Darwin" ]]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

# Install NetBird
install_netbird() {
  if command -v netbird &>/dev/null; then
    log "✅ NetBird already installed: $(netbird version)"
    return 0
  fi

  local os
  os=$(detect_os)
  log "🔧 Installing NetBird on $os..."

  case "$os" in
    ubuntu|debian|pop|linuxmint)
      curl -fsSL https://pkgs.netbird.io/debian/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/netbird-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/netbird-archive-keyring.gpg] https://pkgs.netbird.io/debian stable main" | sudo tee /etc/apt/sources.list.d/netbird.list
      sudo apt-get update
      sudo apt-get install -y netbird
      ;;
    fedora|centos|rhel|rocky|alma)
      sudo dnf config-manager --add-repo https://pkgs.netbird.io/yum/repos/netbird-stable.repo
      sudo dnf install -y netbird
      ;;
    macos)
      brew install netbird
      ;;
    *)
      log "⚠️  Unknown OS. Using generic install script..."
      curl -fsSL https://pkgs.netbird.io/install.sh | sudo sh
      ;;
  esac

  if command -v netbird &>/dev/null; then
    log "✅ NetBird installed: $(netbird version)"
  else
    log "❌ Installation failed"
    exit 1
  fi
}

# Connect to mesh
connect() {
  log "🔗 Connecting to NetBird mesh..."

  local args=()
  args+=(--management-url "$MANAGEMENT_URL")

  if [[ -n "$SETUP_KEY" ]]; then
    args+=(--setup-key "$SETUP_KEY")
  fi

  if $ENABLE_DNS; then
    args+=(--enable-dns)
  fi

  if $ENABLE_ROSENPASS; then
    args+=(--enable-rosenpass)
  fi

  sudo netbird up "${args[@]}"

  # Wait for connection
  sleep 3

  # Show status
  log "📊 Connection status:"
  sudo netbird status
}

# Enable systemd service
enable_service() {
  if command -v systemctl &>/dev/null; then
    log "🔄 Enabling NetBird systemd service..."
    sudo systemctl enable netbird
    sudo systemctl start netbird
    log "✅ Service enabled and started"
  fi
}

# Main
main() {
  log "🚀 NetBird VPN Setup"
  log "   Management: $MANAGEMENT_URL"
  [[ -n "$SETUP_KEY" ]] && log "   Setup key: ${SETUP_KEY:0:8}..."

  install_netbird
  enable_service
  connect

  log ""
  log "✅ NetBird VPN is connected!"
  log "   Run 'sudo netbird status' to see peers"
  log "   Run 'sudo netbird status --detail' for full details"
}

main
