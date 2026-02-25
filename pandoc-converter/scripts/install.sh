#!/bin/bash
# Pandoc Document Converter — Installer
# Detects OS and installs pandoc + optional PDF support

set -e

echo "🔍 Detecting operating system..."

install_pandoc_debian() {
  echo "📦 Installing Pandoc on Debian/Ubuntu..."
  sudo apt-get update -qq
  sudo apt-get install -y pandoc

  echo ""
  read -p "Install PDF support (LaTeX)? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📦 Installing LaTeX (this may take a few minutes)..."
    sudo apt-get install -y texlive-latex-recommended texlive-fonts-recommended texlive-latex-extra texlive-xetex
  else
    echo "📦 Installing lightweight PDF engine (wkhtmltopdf)..."
    sudo apt-get install -y wkhtmltopdf
  fi
}

install_pandoc_fedora() {
  echo "📦 Installing Pandoc on Fedora/RHEL..."
  sudo dnf install -y pandoc
  read -p "Install PDF support (LaTeX)? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo dnf install -y texlive-scheme-basic texlive-xetex
  else
    sudo dnf install -y wkhtmltopdf
  fi
}

install_pandoc_arch() {
  echo "📦 Installing Pandoc on Arch..."
  sudo pacman -S --noconfirm pandoc
  read -p "Install PDF support (LaTeX)? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo pacman -S --noconfirm texlive-core texlive-latexextra
  fi
}

install_pandoc_macos() {
  echo "📦 Installing Pandoc on macOS..."
  if command -v brew &>/dev/null; then
    brew install pandoc
    read -p "Install PDF support (BasicTeX)? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      brew install --cask basictex
    fi
  else
    echo "❌ Homebrew not found. Install from: https://pandoc.org/installing.html"
    exit 1
  fi
}

install_pandoc_generic() {
  echo "📦 Installing Pandoc via GitHub release..."
  PANDOC_VERSION=$(curl -s https://api.github.com/repos/jgm/pandoc/releases/latest | grep -oP '"tag_name": "\K[^"]+')
  ARCH=$(uname -m)

  if [[ "$ARCH" == "x86_64" ]]; then
    DEB_ARCH="amd64"
  elif [[ "$ARCH" == "aarch64" ]]; then
    DEB_ARCH="arm64"
  else
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
  fi

  URL="https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-1-${DEB_ARCH}.deb"
  echo "⬇️  Downloading Pandoc ${PANDOC_VERSION}..."
  curl -sL "$URL" -o /tmp/pandoc.deb
  sudo dpkg -i /tmp/pandoc.deb
  rm /tmp/pandoc.deb
}

# Detect OS
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  case "$ID" in
    ubuntu|debian|linuxmint|pop) install_pandoc_debian ;;
    fedora|rhel|centos|rocky|alma) install_pandoc_fedora ;;
    arch|manjaro) install_pandoc_arch ;;
    *) install_pandoc_generic ;;
  esac
elif [[ "$(uname)" == "Darwin" ]]; then
  install_pandoc_macos
else
  install_pandoc_generic
fi

# Verify
echo ""
echo "✅ Installation complete!"
pandoc --version | head -1
echo ""

# Check PDF engine
if command -v xelatex &>/dev/null; then
  echo "📄 PDF engine: xelatex (full LaTeX)"
elif command -v pdflatex &>/dev/null; then
  echo "📄 PDF engine: pdflatex (basic LaTeX)"
elif command -v wkhtmltopdf &>/dev/null; then
  echo "📄 PDF engine: wkhtmltopdf (lightweight)"
elif command -v weasyprint &>/dev/null; then
  echo "📄 PDF engine: weasyprint (CSS-based)"
else
  echo "⚠️  No PDF engine found. Install texlive or wkhtmltopdf for PDF output."
fi
