#!/bin/bash
# Install Tesseract OCR and dependencies
set -e

LANG_EXTRA=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --lang) LANG_EXTRA="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "[OCR Install] Detecting OS..."

install_apt() {
  sudo apt-get update -qq
  sudo apt-get install -y -qq tesseract-ocr imagemagick poppler-utils
  if [[ -n "$LANG_EXTRA" ]]; then
    sudo apt-get install -y -qq "tesseract-ocr-${LANG_EXTRA}"
  fi
}

install_brew() {
  brew install tesseract imagemagick poppler
  if [[ -n "$LANG_EXTRA" ]]; then
    echo "[OCR Install] For additional languages on macOS, use: brew install tesseract-lang"
  fi
}

install_dnf() {
  sudo dnf install -y tesseract ImageMagick poppler-utils
  if [[ -n "$LANG_EXTRA" ]]; then
    sudo dnf install -y "tesseract-langpack-${LANG_EXTRA}"
  fi
}

install_pacman() {
  sudo pacman -S --noconfirm tesseract imagemagick poppler
  if [[ -n "$LANG_EXTRA" ]]; then
    sudo pacman -S --noconfirm "tesseract-data-${LANG_EXTRA}"
  fi
}

if command -v apt-get &>/dev/null; then
  install_apt
elif command -v brew &>/dev/null; then
  install_brew
elif command -v dnf &>/dev/null; then
  install_dnf
elif command -v pacman &>/dev/null; then
  install_pacman
else
  echo "[OCR Install] ❌ Unsupported package manager. Install manually:"
  echo "  - tesseract-ocr (5.0+)"
  echo "  - imagemagick"
  echo "  - poppler-utils"
  exit 1
fi

# Verify installation
echo ""
echo "[OCR Install] Verifying..."
tesseract --version 2>&1 | head -1
convert --version 2>&1 | head -1
pdftoppm -v 2>&1 | head -1 || true

echo ""
echo "[OCR Install] ✅ All dependencies installed."
echo "[OCR Install] Available languages:"
tesseract --list-langs 2>&1 | tail -n +2
