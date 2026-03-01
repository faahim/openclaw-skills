#!/bin/bash
# Install dependencies for Subtitle Generator
set -euo pipefail

PREFIX="[subtitle-gen-install]"

echo "$PREFIX Installing Subtitle Generator dependencies..."

# ffmpeg
if command -v ffmpeg &>/dev/null; then
  echo "$PREFIX ✅ ffmpeg already installed ($(ffmpeg -version 2>&1 | head -1))"
else
  echo "$PREFIX Installing ffmpeg..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y ffmpeg
  elif command -v brew &>/dev/null; then
    brew install ffmpeg
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y ffmpeg
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm ffmpeg
  else
    echo "$PREFIX ❌ Cannot auto-install ffmpeg. Please install manually."
    exit 1
  fi
fi

# Python 3
if command -v python3 &>/dev/null; then
  echo "$PREFIX ✅ Python3 already installed ($(python3 --version))"
else
  echo "$PREFIX ❌ Python3 not found. Please install Python 3.8+."
  exit 1
fi

# pip
if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
  echo "$PREFIX ✅ pip available"
else
  echo "$PREFIX Installing pip..."
  sudo apt-get install -y python3-pip 2>/dev/null || python3 -m ensurepip
fi

# Whisper
if command -v whisper &>/dev/null; then
  echo "$PREFIX ✅ Whisper already installed"
else
  echo "$PREFIX Installing OpenAI Whisper..."
  pip install -U openai-whisper 2>/dev/null || pip3 install -U openai-whisper
fi

echo ""
echo "$PREFIX ✅ All dependencies installed!"
echo "$PREFIX Run: bash scripts/generate.sh --input <video.mp4>"
