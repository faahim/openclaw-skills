#!/bin/bash
# Install inotify-tools for folder watching
set -e

echo "🔍 Detecting OS..."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  if command -v apt-get &>/dev/null; then
    echo "📦 Installing inotify-tools via apt..."
    sudo apt-get update -qq && sudo apt-get install -y -qq inotify-tools
  elif command -v yum &>/dev/null; then
    echo "📦 Installing inotify-tools via yum..."
    sudo yum install -y inotify-tools
  elif command -v dnf &>/dev/null; then
    echo "📦 Installing inotify-tools via dnf..."
    sudo dnf install -y inotify-tools
  elif command -v pacman &>/dev/null; then
    echo "📦 Installing inotify-tools via pacman..."
    sudo pacman -S --noconfirm inotify-tools
  elif command -v apk &>/dev/null; then
    echo "📦 Installing inotify-tools via apk..."
    sudo apk add inotify-tools
  else
    echo "❌ Unsupported package manager. Install inotify-tools manually."
    exit 1
  fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
  if command -v brew &>/dev/null; then
    echo "📦 Installing fswatch via Homebrew (macOS alternative)..."
    brew install fswatch
  else
    echo "❌ Install Homebrew first: https://brew.sh"
    exit 1
  fi
else
  echo "❌ Unsupported OS: $OSTYPE"
  exit 1
fi

# Verify installation
if command -v inotifywait &>/dev/null; then
  echo "✅ inotify-tools installed successfully ($(inotifywait --help 2>&1 | head -1))"
elif command -v fswatch &>/dev/null; then
  echo "✅ fswatch installed successfully (macOS mode)"
else
  echo "❌ Installation failed"
  exit 1
fi
