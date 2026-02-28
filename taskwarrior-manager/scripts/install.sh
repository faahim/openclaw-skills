#!/bin/bash
# Install Taskwarrior on any major Linux/macOS platform
set -e

echo "🔧 Installing Taskwarrior..."

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

OS=$(detect_os)

case "$OS" in
  ubuntu|debian|pop|linuxmint|raspbian)
    echo "Detected Debian/Ubuntu-based system"
    sudo apt-get update -qq
    sudo apt-get install -y taskwarrior jq
    ;;
  fedora)
    echo "Detected Fedora"
    sudo dnf install -y task jq
    ;;
  centos|rhel|rocky|almalinux)
    echo "Detected RHEL-based system"
    sudo yum install -y epel-release
    sudo yum install -y task jq
    ;;
  arch|manjaro|endeavouros)
    echo "Detected Arch-based system"
    sudo pacman -Sy --noconfirm task jq
    ;;
  opensuse*|sles)
    echo "Detected openSUSE"
    sudo zypper install -y taskwarrior jq
    ;;
  alpine)
    echo "Detected Alpine"
    sudo apk add task jq
    ;;
  macos)
    echo "Detected macOS"
    if command -v brew &>/dev/null; then
      brew install task jq
    else
      echo "❌ Homebrew not found. Install it first: https://brew.sh"
      exit 1
    fi
    ;;
  *)
    echo "❌ Unsupported OS: $OS"
    echo "Install manually: https://taskwarrior.org/download/"
    exit 1
    ;;
esac

# Verify installation
if command -v task &>/dev/null; then
  VERSION=$(task --version 2>/dev/null || echo "unknown")
  echo ""
  echo "✅ Taskwarrior installed successfully (v$VERSION)"
  echo ""

  # Set up sensible defaults if fresh install
  if [[ ! -f "$HOME/.taskrc" ]]; then
    echo "📝 Setting up default configuration..."
    # Create taskrc with sensible defaults
    task rc.confirmation=off config default.priority M 2>/dev/null || true
    task rc.confirmation=off config dateformat Y-M-D 2>/dev/null || true
    task rc.confirmation=off config weekstart monday 2>/dev/null || true
    task rc.confirmation=off config urgency.due.coefficient 12.0 2>/dev/null || true
    task rc.confirmation=off config urgency.priority.coefficient 6.0 2>/dev/null || true
    task rc.confirmation=off config urgency.active.coefficient 4.0 2>/dev/null || true
    echo "✅ Default configuration applied"
  fi

  echo ""
  echo "🚀 Quick start:"
  echo "  task add 'My first task' project:inbox priority:M due:tomorrow"
  echo "  task list"
  echo "  task next"
else
  echo "❌ Installation failed. Check errors above."
  exit 1
fi
