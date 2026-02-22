#!/bin/bash
# Install dependencies for Port Scanner & Security Auditor
set -euo pipefail

echo "🔧 Installing Port Scanner dependencies..."

# Detect OS
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  OS=$ID
elif [[ "$(uname)" == "Darwin" ]]; then
  OS="macos"
else
  OS="unknown"
fi

install_pkg() {
  case "$OS" in
    ubuntu|debian|pop)
      sudo apt-get update -qq && sudo apt-get install -y "$@"
      ;;
    centos|rhel|fedora|rocky|alma)
      sudo yum install -y "$@" || sudo dnf install -y "$@"
      ;;
    arch|manjaro)
      sudo pacman -S --noconfirm "$@"
      ;;
    macos)
      brew install "$@"
      ;;
    *)
      echo "❌ Unsupported OS: $OS. Install manually: $*"
      exit 1
      ;;
  esac
}

# Check and install nmap
if command -v nmap &>/dev/null; then
  echo "  ✅ nmap $(nmap --version 2>&1 | head -1 | grep -oP '\d+\.\d+')"
else
  echo "  📦 Installing nmap..."
  install_pkg nmap
fi

# Check and install jq
if command -v jq &>/dev/null; then
  echo "  ✅ jq $(jq --version 2>&1)"
else
  echo "  📦 Installing jq..."
  install_pkg jq
fi

# Make scripts executable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$SCRIPT_DIR/scan.sh" "$SCRIPT_DIR/diff.sh" 2>/dev/null || true

echo ""
echo "✅ Port Scanner ready!"
echo "   Run: bash scripts/scan.sh --target <host> --mode quick"
