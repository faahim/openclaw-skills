#!/bin/bash
# ImageMagick Toolkit — Installer
set -e

echo "🖼️  ImageMagick Toolkit — Installing dependencies..."

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
elif [ "$(uname)" = "Darwin" ]; then
  OS="macos"
else
  OS="unknown"
fi

install_linux() {
  echo "[install] Detected: $PRETTY_NAME"
  
  case "$OS" in
    ubuntu|debian|pop|linuxmint)
      sudo apt-get update -qq
      sudo apt-get install -y imagemagick ghostscript webp libheif-dev
      ;;
    fedora|rhel|centos|rocky|alma)
      sudo dnf install -y ImageMagick ghostscript libwebp-tools libheif
      ;;
    arch|manjaro)
      sudo pacman -Sy --noconfirm imagemagick ghostscript libwebp libheif
      ;;
    alpine)
      sudo apk add imagemagick ghostscript libwebp libheif
      ;;
    *)
      echo "[install] ⚠️  Unknown distro: $OS. Try: sudo apt install imagemagick"
      exit 1
      ;;
  esac
}

install_macos() {
  echo "[install] Detected: macOS"
  if ! command -v brew &>/dev/null; then
    echo "[install] ❌ Homebrew required. Install: https://brew.sh"
    exit 1
  fi
  brew install imagemagick ghostscript webp libheif
}

case "$OS" in
  macos) install_macos ;;
  unknown) echo "[install] ❌ Unknown OS"; exit 1 ;;
  *) install_linux ;;
esac

# Enable PDF support in ImageMagick policy
for policy in /etc/ImageMagick-{6,7}/policy.xml; do
  if [ -f "$policy" ]; then
    echo "[install] Enabling PDF support in $policy"
    sudo sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/g' "$policy" 2>/dev/null || true
  fi
done

# Verify installation
echo ""
echo "[install] Verifying..."
if command -v convert &>/dev/null; then
  VERSION=$(convert --version | head -1)
  echo "[install] ✅ $VERSION"
else
  if command -v magick &>/dev/null; then
    VERSION=$(magick --version | head -1)
    echo "[install] ✅ $VERSION (ImageMagick 7)"
  else
    echo "[install] ❌ ImageMagick not found after install"
    exit 1
  fi
fi

# Check format support
echo "[install] Format support:"
FORMATS=$(convert -list format 2>/dev/null || magick -list format 2>/dev/null)
for fmt in JPEG PNG WebP AVIF TIFF GIF PDF SVG; do
  if echo "$FORMATS" | grep -qi "$fmt"; then
    echo "  ✅ $fmt"
  else
    echo "  ⚠️  $fmt (not available)"
  fi
done

echo ""
echo "[install] ✅ ImageMagick Toolkit ready!"
echo "[install] Run: bash scripts/run.sh --help"
