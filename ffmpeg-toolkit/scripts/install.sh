#!/bin/bash
# FFmpeg Toolkit — Installer
set -e

echo "🎬 FFmpeg Toolkit — Installing dependencies..."

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
elif [ "$(uname)" = "Darwin" ]; then
  OS="macos"
else
  OS="unknown"
fi

install_ffmpeg() {
  case "$OS" in
    ubuntu|debian|pop|linuxmint)
      echo "📦 Installing ffmpeg via apt..."
      sudo apt-get update -qq
      sudo apt-get install -y ffmpeg
      ;;
    fedora)
      echo "📦 Installing ffmpeg via dnf..."
      sudo dnf install -y ffmpeg
      ;;
    arch|manjaro)
      echo "📦 Installing ffmpeg via pacman..."
      sudo pacman -S --noconfirm ffmpeg
      ;;
    alpine)
      echo "📦 Installing ffmpeg via apk..."
      sudo apk add ffmpeg
      ;;
    macos)
      if command -v brew &>/dev/null; then
        echo "📦 Installing ffmpeg via Homebrew..."
        brew install ffmpeg
      else
        echo "❌ Homebrew not found. Install from https://brew.sh first."
        exit 1
      fi
      ;;
    *)
      echo "❌ Unsupported OS: $OS"
      echo "Install ffmpeg manually: https://ffmpeg.org/download.html"
      exit 1
      ;;
  esac
}

# Check if already installed
if command -v ffmpeg &>/dev/null && command -v ffprobe &>/dev/null; then
  echo "✅ ffmpeg already installed: $(ffmpeg -version | head -1)"
  echo "✅ ffprobe already installed: $(ffprobe -version | head -1)"
else
  install_ffmpeg
fi

# Verify
if command -v ffmpeg &>/dev/null; then
  echo ""
  echo "✅ Installation complete!"
  echo "   ffmpeg: $(ffmpeg -version 2>&1 | head -1)"
  echo "   ffprobe: $(ffprobe -version 2>&1 | head -1)"
  
  # Check hardware acceleration
  echo ""
  echo "🔧 Available hardware accelerators:"
  ffmpeg -hwaccels 2>/dev/null | tail -n +2 | sed 's/^/   /'
else
  echo "❌ Installation failed. Please install ffmpeg manually."
  exit 1
fi
