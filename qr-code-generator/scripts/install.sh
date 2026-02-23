#!/bin/bash
# Install qrencode on common platforms
set -e

echo "🔍 Checking for qrencode..."

if command -v qrencode &>/dev/null; then
  echo "✅ qrencode already installed: $(qrencode --version 2>&1 | head -1)"
  exit 0
fi

echo "📦 Installing qrencode..."

if [ -f /etc/debian_version ] || command -v apt-get &>/dev/null; then
  sudo apt-get update -qq && sudo apt-get install -y qrencode
elif [ -f /etc/redhat-release ] || command -v dnf &>/dev/null; then
  sudo dnf install -y qrencode
elif [ -f /etc/alpine-release ] || command -v apk &>/dev/null; then
  sudo apk add libqrencode-tools
elif command -v brew &>/dev/null; then
  brew install qrencode
elif command -v pacman &>/dev/null; then
  sudo pacman -S --noconfirm qrencode
else
  echo "❌ Could not detect package manager. Install qrencode manually:"
  echo "   https://fukuchi.org/works/qrencode/"
  exit 1
fi

echo "✅ qrencode installed: $(qrencode --version 2>&1 | head -1)"
