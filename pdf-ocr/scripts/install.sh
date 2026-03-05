#!/bin/bash
# PDF OCR — Install dependencies
set -e

echo "[PDF-OCR] Installing dependencies..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
fi

case "$OS" in
    ubuntu|debian|pop|linuxmint)
        echo "[PDF-OCR] Detected Debian/Ubuntu"
        sudo apt-get update -qq
        sudo apt-get install -y -qq tesseract-ocr ghostscript python3-pip poppler-utils unpaper
        pip install --user --quiet ocrmypdf
        ;;
    fedora|rhel|centos|rocky|alma)
        echo "[PDF-OCR] Detected RHEL/Fedora"
        sudo dnf install -y tesseract ghostscript python3-pip poppler-utils unpaper
        pip install --user --quiet ocrmypdf
        ;;
    arch|manjaro)
        echo "[PDF-OCR] Detected Arch"
        sudo pacman -S --noconfirm tesseract ghostscript python-pip poppler unpaper
        pip install --user --quiet ocrmypdf
        ;;
    darwin)
        echo "[PDF-OCR] Detected macOS"
        brew install tesseract ghostscript poppler unpaper
        pip3 install ocrmypdf
        ;;
    *)
        echo "[PDF-OCR] Unknown OS: $OS"
        echo "[PDF-OCR] Please install manually: tesseract-ocr, ghostscript, python3-pip"
        echo "[PDF-OCR] Then run: pip install ocrmypdf"
        exit 1
        ;;
esac

# Verify installation
echo ""
echo "[PDF-OCR] Verifying installation..."

if command -v ocrmypdf &>/dev/null; then
    echo "[PDF-OCR] ✅ ocrmypdf $(ocrmypdf --version 2>&1 | head -1)"
else
    echo "[PDF-OCR] ❌ ocrmypdf not found in PATH"
    echo "[PDF-OCR] Try: export PATH=\$PATH:\$HOME/.local/bin"
    exit 1
fi

if command -v tesseract &>/dev/null; then
    echo "[PDF-OCR] ✅ tesseract $(tesseract --version 2>&1 | head -1)"
else
    echo "[PDF-OCR] ❌ tesseract not found"
    exit 1
fi

if command -v gs &>/dev/null; then
    echo "[PDF-OCR] ✅ ghostscript $(gs --version 2>&1)"
else
    echo "[PDF-OCR] ❌ ghostscript not found"
    exit 1
fi

echo ""
echo "[PDF-OCR] Available languages:"
tesseract --list-langs 2>&1 | tail -n +2
echo ""
echo "[PDF-OCR] ✅ Installation complete!"
echo "[PDF-OCR] Install more languages: sudo apt-get install tesseract-ocr-<lang>"
