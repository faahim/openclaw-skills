#!/bin/bash
# Install inotify-tools for file watching
set -e

echo "🔧 Installing inotify-tools..."

if command -v inotifywait &>/dev/null; then
  echo "✅ inotify-tools already installed ($(inotifywait --help 2>&1 | head -1))"
  exit 0
fi

# Detect package manager
if command -v apt-get &>/dev/null; then
  sudo apt-get update -qq && sudo apt-get install -y -qq inotify-tools
elif command -v yum &>/dev/null; then
  sudo yum install -y inotify-tools
elif command -v dnf &>/dev/null; then
  sudo dnf install -y inotify-tools
elif command -v pacman &>/dev/null; then
  sudo pacman -S --noconfirm inotify-tools
elif command -v apk &>/dev/null; then
  sudo apk add inotify-tools
elif command -v brew &>/dev/null; then
  echo "❌ inotify-tools is Linux-only. macOS uses fswatch instead."
  echo "   Install: brew install fswatch"
  exit 1
else
  echo "❌ Could not detect package manager. Install inotify-tools manually."
  exit 1
fi

if command -v inotifywait &>/dev/null; then
  echo "✅ inotify-tools installed successfully"
else
  echo "❌ Installation failed"
  exit 1
fi
