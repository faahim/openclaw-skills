#!/bin/bash
# Install yt-dlp and ffmpeg dependencies
set -euo pipefail

echo "🔧 Installing YouTube Downloader dependencies..."

# Detect OS
if [[ "$(uname)" == "Darwin" ]]; then
  PKG_MGR="brew"
elif command -v apt-get &>/dev/null; then
  PKG_MGR="apt"
elif command -v dnf &>/dev/null; then
  PKG_MGR="dnf"
elif command -v pacman &>/dev/null; then
  PKG_MGR="pacman"
else
  PKG_MGR="unknown"
fi

# Install ffmpeg
if ! command -v ffmpeg &>/dev/null; then
  echo "📦 Installing ffmpeg..."
  case $PKG_MGR in
    brew) brew install ffmpeg ;;
    apt) sudo apt-get update && sudo apt-get install -y ffmpeg ;;
    dnf) sudo dnf install -y ffmpeg ;;
    pacman) sudo pacman -S --noconfirm ffmpeg ;;
    *) echo "❌ Cannot auto-install ffmpeg. Install manually."; exit 1 ;;
  esac
else
  echo "✅ ffmpeg already installed: $(ffmpeg -version 2>&1 | head -1)"
fi

# Install yt-dlp
if ! command -v yt-dlp &>/dev/null; then
  echo "📦 Installing yt-dlp..."
  if command -v pipx &>/dev/null; then
    pipx install yt-dlp
  elif command -v pip3 &>/dev/null; then
    pip3 install --user yt-dlp
  else
    echo "📦 Installing via direct download..."
    sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
    sudo chmod a+rx /usr/local/bin/yt-dlp
  fi
else
  echo "✅ yt-dlp already installed: $(yt-dlp --version)"
fi

# Optional: atomicparsley for M4A thumbnails
if ! command -v AtomicParsley &>/dev/null; then
  echo "ℹ️  Optional: AtomicParsley (for M4A thumbnail embedding)"
  echo "   Install: sudo apt-get install atomicparsley  OR  brew install atomicparsley"
fi

echo ""
echo "✅ All dependencies installed!"
echo "   yt-dlp: $(yt-dlp --version 2>/dev/null || echo 'check PATH')"
echo "   ffmpeg: $(ffmpeg -version 2>&1 | head -1)"
echo ""
echo "Run: bash scripts/download.sh --url 'https://youtube.com/watch?v=...' --audio-only"
