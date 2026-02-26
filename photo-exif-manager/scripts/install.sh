#!/bin/bash
# Install exiftool and dependencies for Photo EXIF Manager
set -e

echo "📷 Installing Photo EXIF Manager dependencies..."

# Detect OS and install exiftool
if command -v exiftool &>/dev/null; then
  echo "✅ exiftool already installed ($(exiftool -ver))"
else
  if [[ -f /etc/debian_version ]]; then
    echo "Installing exiftool via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y libimage-exiftool-perl jq bc
  elif [[ -f /etc/redhat-release ]]; then
    echo "Installing exiftool via yum..."
    sudo yum install -y perl-Image-ExifTool jq bc
  elif [[ -f /etc/arch-release ]]; then
    echo "Installing exiftool via pacman..."
    sudo pacman -S --noconfirm perl-image-exiftool jq bc
  elif command -v brew &>/dev/null; then
    echo "Installing exiftool via brew..."
    brew install exiftool jq
  else
    echo "❌ Unsupported OS. Install exiftool manually:"
    echo "   https://exiftool.org/install.html"
    exit 1
  fi
  echo "✅ exiftool installed ($(exiftool -ver))"
fi

# Check jq
if ! command -v jq &>/dev/null; then
  echo "⚠️  jq not found — CSV export may not work. Install: sudo apt-get install jq"
fi

echo ""
echo "✅ Photo EXIF Manager ready!"
echo "   Run: bash scripts/run.sh view <photo>"
