#!/bin/bash
# Audio Splitter — Dependency Installer
set -e

echo "[audio-splitter] Checking dependencies..."

MISSING=()

# Check ffmpeg
if ! command -v ffmpeg &>/dev/null; then
  MISSING+=("ffmpeg")
fi

# Check sox
if ! command -v sox &>/dev/null; then
  MISSING+=("sox")
fi

# Check bc
if ! command -v bc &>/dev/null; then
  MISSING+=("bc")
fi

if [ ${#MISSING[@]} -eq 0 ]; then
  echo "[audio-splitter] ✅ All dependencies installed!"
  ffmpeg -version | head -1
  sox --version 2>/dev/null | head -1 || true
  exit 0
fi

echo "[audio-splitter] Missing: ${MISSING[*]}"

# Detect package manager
if command -v apt-get &>/dev/null; then
  echo "[audio-splitter] Installing via apt..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq "${MISSING[@]}"
elif command -v dnf &>/dev/null; then
  echo "[audio-splitter] Installing via dnf..."
  sudo dnf install -y "${MISSING[@]}"
elif command -v pacman &>/dev/null; then
  echo "[audio-splitter] Installing via pacman..."
  sudo pacman -Sy --noconfirm "${MISSING[@]}"
elif command -v brew &>/dev/null; then
  echo "[audio-splitter] Installing via brew..."
  brew install "${MISSING[@]}"
elif command -v apk &>/dev/null; then
  echo "[audio-splitter] Installing via apk..."
  sudo apk add "${MISSING[@]}"
else
  echo "[audio-splitter] ❌ No supported package manager found."
  echo "Please install manually: ${MISSING[*]}"
  exit 1
fi

echo "[audio-splitter] ✅ Dependencies installed!"
ffmpeg -version | head -1
sox --version 2>/dev/null | head -1 || true
