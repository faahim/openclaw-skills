#!/bin/bash
# Resume Builder — Dependency Installer
set -e

echo "📦 Installing Resume Builder dependencies..."

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get &>/dev/null; then
        echo "🐧 Detected Debian/Ubuntu"
        sudo apt-get update -qq
        sudo apt-get install -y -qq pandoc texlive-latex-base texlive-fonts-recommended \
            texlive-latex-extra texlive-xetex wkhtmltopdf python3-yaml 2>/dev/null
    elif command -v dnf &>/dev/null; then
        echo "🐧 Detected Fedora/RHEL"
        sudo dnf install -y pandoc texlive-scheme-basic texlive-collection-fontsrecommended \
            wkhtmltopdf python3-pyyaml 2>/dev/null
    elif command -v pacman &>/dev/null; then
        echo "🐧 Detected Arch Linux"
        sudo pacman -S --noconfirm pandoc texlive-core texlive-latexextra wkhtmltopdf python-yaml 2>/dev/null
    else
        echo "❌ Unsupported Linux distribution. Install manually:"
        echo "   pandoc, texlive, wkhtmltopdf, python3-yaml"
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 Detected macOS"
    if ! command -v brew &>/dev/null; then
        echo "❌ Homebrew not found. Install from https://brew.sh"
        exit 1
    fi
    brew install pandoc wkhtmltopdf python-yq 2>/dev/null || true
    brew install --cask mactex-no-gui 2>/dev/null || true
else
    echo "❌ Unsupported OS: $OSTYPE"
    exit 1
fi

# Verify
echo ""
echo "🔍 Checking installations..."
MISSING=()

command -v pandoc &>/dev/null && echo "  ✅ pandoc $(pandoc --version | head -1 | awk '{print $2}')" || MISSING+=("pandoc")
command -v pdflatex &>/dev/null && echo "  ✅ pdflatex" || command -v xelatex &>/dev/null && echo "  ✅ xelatex" || MISSING+=("texlive")
command -v wkhtmltopdf &>/dev/null && echo "  ✅ wkhtmltopdf" || echo "  ⚠️  wkhtmltopdf (optional, HTML-to-PDF fallback)"
command -v python3 &>/dev/null && echo "  ✅ python3" || MISSING+=("python3")

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    echo "❌ Missing: ${MISSING[*]}"
    exit 1
fi

echo ""
echo "✅ All dependencies installed. Run: bash scripts/build.sh resume.yaml"
