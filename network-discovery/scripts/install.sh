#!/bin/bash
# Network Discovery — Install dependencies
set -euo pipefail

echo "🔧 Installing Network Discovery dependencies..."

if [[ "$(uname)" == "Darwin" ]]; then
  # macOS
  if ! command -v brew &>/dev/null; then
    echo "❌ Homebrew required. Install from https://brew.sh"
    exit 1
  fi
  brew install arp-scan nmap jq
elif command -v apt-get &>/dev/null; then
  # Debian/Ubuntu
  sudo apt-get update -qq
  sudo apt-get install -y arp-scan nmap jq
elif command -v dnf &>/dev/null; then
  # Fedora/RHEL
  sudo dnf install -y arp-scan nmap jq
elif command -v pacman &>/dev/null; then
  # Arch
  sudo pacman -S --noconfirm arp-scan nmap jq
elif command -v apk &>/dev/null; then
  # Alpine
  sudo apk add arp-scan nmap jq
else
  echo "❌ Unsupported package manager. Install manually: arp-scan, nmap, jq"
  exit 1
fi

# Create data directory
mkdir -p "$HOME/.network-discovery/scans"
echo '[]' > "$HOME/.network-discovery/known-devices.json" 2>/dev/null || true

echo ""
echo "✅ Installation complete!"
echo "   Run: sudo bash scripts/scan.sh"
