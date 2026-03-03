#!/bin/bash
# Cockpit Web Console — Installer
# Detects distro and installs Cockpit with optional full module set

set -euo pipefail

FULL_INSTALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --full) FULL_INSTALL=true; shift ;;
    --help|-h)
      echo "Usage: install.sh [--full]"
      echo "  --full    Install all available Cockpit modules"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Detect distro
detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  elif command -v lsb_release &>/dev/null; then
    lsb_release -si | tr '[:upper:]' '[:lower:]'
  else
    echo "unknown"
  fi
}

DISTRO=$(detect_distro)
echo "🔍 Detected distro: $DISTRO"

BASE_PKGS=""
FULL_PKGS=""

case "$DISTRO" in
  ubuntu|debian|pop|linuxmint)
    BASE_PKGS="cockpit"
    FULL_PKGS="cockpit-machines cockpit-podman cockpit-storaged cockpit-networkmanager cockpit-packagekit cockpit-pcp"
    echo "📦 Installing via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y $BASE_PKGS
    if $FULL_INSTALL; then
      sudo apt-get install -y $FULL_PKGS 2>/dev/null || echo "⚠️ Some optional modules unavailable (non-critical)"
    fi
    ;;
  fedora|rhel|centos|rocky|alma|ol)
    BASE_PKGS="cockpit"
    FULL_PKGS="cockpit-machines cockpit-podman cockpit-storaged cockpit-networkmanager cockpit-packagekit cockpit-pcp cockpit-session-recording"
    echo "📦 Installing via dnf..."
    sudo dnf install -y $BASE_PKGS
    if $FULL_INSTALL; then
      sudo dnf install -y $FULL_PKGS 2>/dev/null || echo "⚠️ Some optional modules unavailable (non-critical)"
    fi
    ;;
  arch|manjaro|endeavouros)
    BASE_PKGS="cockpit"
    FULL_PKGS="cockpit-machines cockpit-podman cockpit-storaged cockpit-networkmanager cockpit-pcp"
    echo "📦 Installing via pacman..."
    sudo pacman -S --noconfirm $BASE_PKGS
    if $FULL_INSTALL; then
      sudo pacman -S --noconfirm $FULL_PKGS 2>/dev/null || echo "⚠️ Some optional modules unavailable"
    fi
    ;;
  opensuse*|suse|sles)
    BASE_PKGS="cockpit cockpit-ws cockpit-system"
    FULL_PKGS="cockpit-machines cockpit-podman cockpit-storaged cockpit-networkmanager cockpit-packagekit"
    echo "📦 Installing via zypper..."
    sudo zypper install -y $BASE_PKGS
    if $FULL_INSTALL; then
      sudo zypper install -y $FULL_PKGS 2>/dev/null || echo "⚠️ Some optional modules unavailable"
    fi
    ;;
  *)
    echo "❌ Unsupported distro: $DISTRO"
    echo "   Supported: Ubuntu, Debian, Fedora, RHEL, CentOS, Rocky, Alma, Arch, openSUSE"
    echo "   Try manual install: https://cockpit-project.org/running.html"
    exit 1
    ;;
esac

# Enable and start
echo "🚀 Enabling Cockpit..."
sudo systemctl enable --now cockpit.socket

# Open firewall if available
if command -v ufw &>/dev/null; then
  sudo ufw allow 9090/tcp 2>/dev/null && echo "🔓 Opened port 9090 in UFW" || true
elif command -v firewall-cmd &>/dev/null; then
  sudo firewall-cmd --add-service=cockpit --permanent 2>/dev/null && \
    sudo firewall-cmd --reload && echo "🔓 Opened cockpit in firewalld" || true
fi

# Get IP
IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo ""
echo "═══════════════════════════════════════"
echo "✅ Cockpit installed successfully!"
echo "═══════════════════════════════════════"
echo "🌐 Dashboard: https://${IP}:9090"
echo "🔑 Login with your Linux user credentials"
echo ""
echo "Run 'bash scripts/status.sh' to check status"
echo "Run 'bash scripts/modules.sh list' to see modules"
