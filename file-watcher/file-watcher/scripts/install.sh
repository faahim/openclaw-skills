#!/bin/bash
# File Watcher — Dependency Installer
set -e

echo "📂 File Watcher — Installing dependencies..."

# Detect package manager and install inotify-tools
if command -v apt-get &>/dev/null; then
  sudo apt-get update -qq && sudo apt-get install -y inotify-tools
elif command -v yum &>/dev/null; then
  sudo yum install -y inotify-tools
elif command -v dnf &>/dev/null; then
  sudo dnf install -y inotify-tools
elif command -v pacman &>/dev/null; then
  sudo pacman -Sy --noconfirm inotify-tools
elif command -v apk &>/dev/null; then
  sudo apk add inotify-tools
elif command -v brew &>/dev/null; then
  echo "⚠️  macOS detected. inotify is Linux-only."
  echo "   Install fswatch instead: brew install fswatch"
  echo "   This skill will use fswatch as fallback on macOS."
  brew install fswatch
else
  echo "❌ Unknown package manager. Install inotify-tools manually."
  echo "   https://github.com/inotify-tools/inotify-tools"
  exit 1
fi

# Verify installation
if command -v inotifywait &>/dev/null; then
  echo "✅ inotifywait installed: $(inotifywait --help 2>&1 | head -1)"
elif command -v fswatch &>/dev/null; then
  echo "✅ fswatch installed (macOS fallback): $(fswatch --version 2>&1 | head -1)"
else
  echo "❌ Installation failed. Please install inotify-tools manually."
  exit 1
fi

# Increase inotify watch limit if needed
CURRENT_LIMIT=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "0")
if [ "$CURRENT_LIMIT" -lt 65536 ] 2>/dev/null; then
  echo ""
  echo "⚠️  Current inotify watch limit is $CURRENT_LIMIT (low for large projects)."
  echo "   Recommended: 524288"
  read -p "   Increase to 524288? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    echo "✅ Watch limit increased to 524288"
  fi
fi

echo ""
echo "✅ File Watcher ready! Run: bash scripts/watch.sh --help"
