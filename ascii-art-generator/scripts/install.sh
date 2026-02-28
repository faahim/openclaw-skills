#!/bin/bash
# ASCII Art Generator — Dependency Installer
set -e

echo "🎨 Installing ASCII Art Generator dependencies..."

# Detect package manager
if command -v apt-get &>/dev/null; then
    PKG="apt-get"
    SUDO="sudo"
    UPDATE="$SUDO apt-get update -qq"
    INSTALL="$SUDO apt-get install -y -qq"
elif command -v brew &>/dev/null; then
    PKG="brew"
    SUDO=""
    UPDATE="brew update"
    INSTALL="brew install"
elif command -v dnf &>/dev/null; then
    PKG="dnf"
    SUDO="sudo"
    UPDATE=""
    INSTALL="$SUDO dnf install -y -q"
elif command -v pacman &>/dev/null; then
    PKG="pacman"
    SUDO="sudo"
    UPDATE="$SUDO pacman -Sy --noconfirm"
    INSTALL="$SUDO pacman -S --noconfirm"
elif command -v apk &>/dev/null; then
    PKG="apk"
    SUDO="sudo"
    UPDATE="$SUDO apk update"
    INSTALL="$SUDO apk add"
else
    echo "❌ No supported package manager found (apt, brew, dnf, pacman, apk)"
    exit 1
fi

echo "📦 Using package manager: $PKG"

# Update package index
if [ -n "$UPDATE" ]; then
    echo "📥 Updating package index..."
    $UPDATE 2>/dev/null || true
fi

# Install packages
MISSING=()

if ! command -v figlet &>/dev/null; then
    MISSING+=(figlet)
fi

if ! command -v toilet &>/dev/null; then
    # toilet package name varies
    case $PKG in
        brew) MISSING+=(toilet) ;;
        *) MISSING+=(toilet) ;;
    esac
fi

if ! command -v jp2a &>/dev/null; then
    MISSING+=(jp2a)
fi

if ! command -v convert &>/dev/null; then
    case $PKG in
        apt-get) MISSING+=(imagemagick) ;;
        brew) MISSING+=(imagemagick) ;;
        dnf) MISSING+=(ImageMagick) ;;
        pacman) MISSING+=(imagemagick) ;;
        apk) MISSING+=(imagemagick) ;;
    esac
fi

if ! command -v curl &>/dev/null; then
    MISSING+=(curl)
fi

if [ ${#MISSING[@]} -eq 0 ]; then
    echo "✅ All dependencies already installed!"
else
    echo "📦 Installing: ${MISSING[*]}"
    $INSTALL "${MISSING[@]}"
fi

# Verify installation
echo ""
echo "🔍 Verification:"
for cmd in figlet toilet jp2a convert curl; do
    if command -v "$cmd" &>/dev/null; then
        echo "  ✅ $cmd — $(command -v "$cmd")"
    else
        echo "  ❌ $cmd — NOT FOUND"
    fi
done

# Show available figlet fonts
FONT_COUNT=$(figlet -I 2 2>/dev/null | xargs -I{} find {} -name '*.flf' 2>/dev/null | wc -l)
echo ""
echo "🔤 Available figlet fonts: $FONT_COUNT"
echo "🎨 ASCII Art Generator ready!"
