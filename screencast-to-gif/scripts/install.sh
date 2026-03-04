#!/bin/bash
# Install dependencies for screencast-to-gif
set -euo pipefail

PREFIX="[screencast-to-gif]"

install_deps() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "$PREFIX Installing via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y ffmpeg gifsicle bc
  elif command -v brew >/dev/null 2>&1; then
    echo "$PREFIX Installing via Homebrew..."
    brew install ffmpeg gifsicle
  elif command -v pacman >/dev/null 2>&1; then
    echo "$PREFIX Installing via pacman..."
    sudo pacman -S --noconfirm ffmpeg gifsicle bc
  elif command -v apk >/dev/null 2>&1; then
    echo "$PREFIX Installing via apk..."
    sudo apk add ffmpeg gifsicle bc
  elif command -v dnf >/dev/null 2>&1; then
    echo "$PREFIX Installing via dnf..."
    sudo dnf install -y ffmpeg gifsicle bc
  else
    echo "$PREFIX ❌ Unsupported package manager. Install manually: ffmpeg gifsicle bc"
    exit 1
  fi
}

echo "$PREFIX Checking dependencies..."

missing=()
command -v ffmpeg >/dev/null 2>&1 || missing+=(ffmpeg)
command -v gifsicle >/dev/null 2>&1 || missing+=(gifsicle)

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "$PREFIX ✅ All dependencies already installed!"
  ffmpeg -version | head -1
  gifsicle --version | head -1
else
  echo "$PREFIX Missing: ${missing[*]}"
  install_deps
  echo "$PREFIX ✅ Dependencies installed!"
fi
