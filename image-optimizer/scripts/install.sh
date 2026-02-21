#!/bin/bash
# Image Optimizer — Dependency Installer
set -e

echo "🖼️  Image Optimizer — Installing dependencies..."
echo ""

OS="$(uname -s)"
MISSING=()

# Check each dependency
for cmd in convert cwebp avifenc; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING+=("$cmd")
  else
    echo "✅ $cmd found: $(command -v "$cmd")"
  fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
  echo ""
  echo "✅ All dependencies installed!"
  exit 0
fi

echo ""
echo "Missing: ${MISSING[*]}"
echo ""

if [ "$OS" = "Linux" ]; then
  if command -v apt-get &>/dev/null; then
    PKGS=""
    for cmd in "${MISSING[@]}"; do
      case "$cmd" in
        convert) PKGS="$PKGS imagemagick" ;;
        cwebp)   PKGS="$PKGS webp" ;;
        avifenc) PKGS="$PKGS libavif-bin" ;;
      esac
    done
    echo "Installing: sudo apt-get install -y $PKGS"
    sudo apt-get update -qq && sudo apt-get install -y $PKGS
  elif command -v dnf &>/dev/null; then
    PKGS=""
    for cmd in "${MISSING[@]}"; do
      case "$cmd" in
        convert) PKGS="$PKGS ImageMagick" ;;
        cwebp)   PKGS="$PKGS libwebp-tools" ;;
        avifenc) PKGS="$PKGS libavif-tools" ;;
      esac
    done
    echo "Installing: sudo dnf install -y $PKGS"
    sudo dnf install -y $PKGS
  elif command -v pacman &>/dev/null; then
    PKGS=""
    for cmd in "${MISSING[@]}"; do
      case "$cmd" in
        convert) PKGS="$PKGS imagemagick" ;;
        cwebp)   PKGS="$PKGS libwebp" ;;
        avifenc) PKGS="$PKGS libavif" ;;
      esac
    done
    echo "Installing: sudo pacman -S --noconfirm $PKGS"
    sudo pacman -S --noconfirm $PKGS
  else
    echo "❌ Unknown package manager. Install manually:"
    echo "   ImageMagick: https://imagemagick.org/script/download.php"
    echo "   WebP tools:  https://developers.google.com/speed/webp/download"
    echo "   AVIF tools:  https://github.com/AOMediaCodec/libavif"
    exit 1
  fi
elif [ "$OS" = "Darwin" ]; then
  if ! command -v brew &>/dev/null; then
    echo "❌ Homebrew not found. Install: https://brew.sh"
    exit 1
  fi
  PKGS=""
  for cmd in "${MISSING[@]}"; do
    case "$cmd" in
      convert) PKGS="$PKGS imagemagick" ;;
      cwebp)   PKGS="$PKGS webp" ;;
      avifenc) PKGS="$PKGS libavif" ;;
    esac
  done
  echo "Installing: brew install $PKGS"
  brew install $PKGS
else
  echo "❌ Unsupported OS: $OS"
  exit 1
fi

echo ""
echo "✅ All dependencies installed!"
