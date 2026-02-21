#!/bin/bash
# PDF Tools — Dependency Installer
set -e

echo "🔧 Installing PDF Tools dependencies..."

install_pkg() {
  if command -v "$1" &>/dev/null; then
    echo "  ✅ $1 already installed"
    return 0
  fi

  echo "  📦 Installing $2..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y "$2" 2>/dev/null
  elif command -v brew &>/dev/null; then
    brew install "$3" 2>/dev/null
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y "$2" 2>/dev/null
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm "$2" 2>/dev/null
  else
    echo "  ❌ Cannot auto-install $2. Please install manually."
    return 1
  fi
}

install_pkg pdfunite poppler-utils poppler
install_pkg gs ghostscript ghostscript
install_pkg qpdf qpdf qpdf

echo ""
echo "✅ All dependencies installed!"
echo "   Run: bash scripts/pdf-tools.sh --help"
