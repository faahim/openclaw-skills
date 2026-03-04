#!/bin/bash
# Install Graphviz and dependencies
set -e

echo "🔍 Checking for Graphviz..."

if command -v dot &>/dev/null; then
  VERSION=$(dot -V 2>&1 | head -1)
  echo "✅ Graphviz already installed: $VERSION"
  exit 0
fi

echo "📦 Installing Graphviz..."

# Detect OS and install
if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    ubuntu|debian|pop|linuxmint)
      sudo apt-get update -qq
      sudo apt-get install -y -qq graphviz
      ;;
    fedora)
      sudo dnf install -y graphviz
      ;;
    centos|rhel|rocky|alma)
      sudo yum install -y graphviz
      ;;
    arch|manjaro)
      sudo pacman -S --noconfirm graphviz
      ;;
    alpine)
      sudo apk add graphviz
      ;;
    opensuse*|sles)
      sudo zypper install -y graphviz
      ;;
    *)
      echo "❌ Unsupported distro: $ID"
      echo "Install manually: https://graphviz.org/download/"
      exit 1
      ;;
  esac
elif [[ "$OSTYPE" == "darwin"* ]]; then
  if command -v brew &>/dev/null; then
    brew install graphviz
  else
    echo "❌ Homebrew not found. Install it first: https://brew.sh"
    exit 1
  fi
else
  echo "❌ Unsupported OS: $OSTYPE"
  echo "Install manually: https://graphviz.org/download/"
  exit 1
fi

# Verify
if command -v dot &>/dev/null; then
  VERSION=$(dot -V 2>&1 | head -1)
  echo "✅ Graphviz installed: $VERSION"
  echo "Available engines: dot, neato, fdp, sfdp, circo, twopi"
else
  echo "❌ Installation failed"
  exit 1
fi
