#!/bin/bash
set -e

if command -v age &>/dev/null; then
  echo "✅ age is already installed: $(age --version)"
  exit 0
fi

echo "📦 Installing age..."

if command -v apt-get &>/dev/null; then
  sudo apt-get update -qq && sudo apt-get install -y -qq age
elif command -v brew &>/dev/null; then
  brew install age
elif command -v pacman &>/dev/null; then
  sudo pacman -S --noconfirm age
elif command -v dnf &>/dev/null; then
  sudo dnf install -y age
else
  AGE_VERSION="1.2.1"
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
  esac
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  cd /tmp
  curl -sLO "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-${OS}-${ARCH}.tar.gz"
  tar xzf "age-v${AGE_VERSION}-${OS}-${ARCH}.tar.gz"
  sudo mv age/age age/age-keygen /usr/local/bin/
  rm -rf age "age-v${AGE_VERSION}-${OS}-${ARCH}.tar.gz"
fi

echo "✅ age installed: $(age --version)"
