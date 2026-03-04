#!/bin/bash
# Install iperf3 and dependencies
set -euo pipefail

echo "🌐 iperf Network Test — Installer"
echo "==================================="

install_iperf3() {
  if command -v iperf3 &>/dev/null; then
    echo "✅ iperf3 already installed: $(iperf3 --version 2>&1 | head -1)"
    return 0
  fi

  echo "📦 Installing iperf3..."

  if [ -f /etc/debian_version ]; then
    sudo apt-get update -qq && sudo apt-get install -y -qq iperf3 jq bc
  elif [ -f /etc/redhat-release ]; then
    sudo dnf install -y iperf3 jq bc 2>/dev/null || sudo yum install -y iperf3 jq bc
  elif [ -f /etc/arch-release ]; then
    sudo pacman -S --noconfirm iperf3 jq bc
  elif command -v brew &>/dev/null; then
    brew install iperf3 jq
  else
    echo "❌ Unsupported package manager. Install iperf3 manually:"
    echo "   https://iperf.fr/iperf-download.php"
    exit 1
  fi

  echo "✅ iperf3 installed: $(iperf3 --version 2>&1 | head -1)"
}

install_iperf3

mkdir -p reports

echo ""
echo "🎉 Installation complete!"
echo "   Quick test: bash scripts/quicktest.sh"
echo "   Custom test: bash scripts/test.sh --server <host>"
