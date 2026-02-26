#!/bin/bash
# Install system benchmark dependencies
set -e

echo "🔧 Installing system benchmark tools..."

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  elif [ "$(uname)" = "Darwin" ]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

OS=$(detect_os)

case "$OS" in
  ubuntu|debian|pop|linuxmint)
    echo "Detected: Debian/Ubuntu"
    sudo apt-get update -qq
    sudo apt-get install -y -qq sysbench fio iperf3 jq
    ;;
  fedora)
    echo "Detected: Fedora"
    sudo dnf install -y sysbench fio iperf3 jq
    ;;
  centos|rhel|rocky|alma)
    echo "Detected: RHEL/CentOS"
    sudo yum install -y epel-release
    sudo yum install -y sysbench fio iperf3 jq
    ;;
  arch|manjaro)
    echo "Detected: Arch Linux"
    sudo pacman -S --noconfirm sysbench fio iperf3 jq
    ;;
  alpine)
    echo "Detected: Alpine"
    sudo apk add --no-cache sysbench fio iperf3 jq
    ;;
  macos)
    echo "Detected: macOS"
    if ! command -v brew &>/dev/null; then
      echo "❌ Homebrew required. Install: https://brew.sh"
      exit 1
    fi
    brew install sysbench fio iperf3 jq
    ;;
  *)
    echo "⚠️  Unknown OS. Install manually: sysbench fio iperf3 jq"
    exit 1
    ;;
esac

echo ""
echo "✅ All tools installed:"
echo "  sysbench $(sysbench --version 2>/dev/null || echo 'not found')"
echo "  fio $(fio --version 2>/dev/null || echo 'not found')"
echo "  iperf3 $(iperf3 --version 2>/dev/null | head -1 || echo 'not found')"
echo "  jq $(jq --version 2>/dev/null || echo 'not found')"
