#!/bin/bash
# ShellCheck Installer — auto-detects OS/arch and installs ShellCheck
set -euo pipefail

SHELLCHECK_VERSION="${SHELLCHECK_VERSION:-0.10.0}"

echo "🔧 ShellCheck Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━"

# Check if already installed
if command -v shellcheck &>/dev/null; then
    CURRENT=$(shellcheck --version 2>/dev/null | grep "^version:" | awk '{print $2}')
    echo "✅ ShellCheck already installed (version: ${CURRENT:-unknown})"
    echo "   Path: $(command -v shellcheck)"
    read -rp "Reinstall/upgrade to v${SHELLCHECK_VERSION}? [y/N] " REPLY
    [[ "$REPLY" =~ ^[Yy]$ ]] || { echo "Keeping current version."; exit 0; }
fi

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux)
        case "$ARCH" in
            x86_64)  PLATFORM="linux.x86_64" ;;
            aarch64|arm64) PLATFORM="linux.aarch64" ;;
            armv6*|armv7*) PLATFORM="linux.armv6hf" ;;
            *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
        esac
        ;;
    Darwin)
        PLATFORM="darwin.x86_64"  # Universal binary works on ARM too
        ;;
    *)
        echo "❌ Unsupported OS: $OS"
        echo "Try: apt install shellcheck / brew install shellcheck / snap install shellcheck"
        exit 1
        ;;
esac

# Try package manager first (faster, gets updates)
install_via_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "📦 Installing via apt..."
        sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck
        return $?
    elif command -v brew &>/dev/null; then
        echo "📦 Installing via brew..."
        brew install shellcheck
        return $?
    elif command -v dnf &>/dev/null; then
        echo "📦 Installing via dnf..."
        sudo dnf install -y ShellCheck
        return $?
    elif command -v pacman &>/dev/null; then
        echo "📦 Installing via pacman..."
        sudo pacman -S --noconfirm shellcheck
        return $?
    elif command -v apk &>/dev/null; then
        echo "📦 Installing via apk..."
        sudo apk add shellcheck
        return $?
    elif command -v snap &>/dev/null; then
        echo "📦 Installing via snap..."
        sudo snap install shellcheck
        return $?
    fi
    return 1
}

# Try package manager first
if install_via_package_manager 2>/dev/null; then
    echo ""
    echo "✅ ShellCheck installed successfully!"
    shellcheck --version
    exit 0
fi

# Fallback: download binary
echo "📥 Downloading ShellCheck v${SHELLCHECK_VERSION} for ${PLATFORM}..."
DOWNLOAD_URL="https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.${PLATFORM}.tar.xz"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

if command -v curl &>/dev/null; then
    curl -fsSL "$DOWNLOAD_URL" -o "$TMPDIR/shellcheck.tar.xz"
elif command -v wget &>/dev/null; then
    wget -q "$DOWNLOAD_URL" -O "$TMPDIR/shellcheck.tar.xz"
else
    echo "❌ Neither curl nor wget found. Install one and retry."
    exit 1
fi

echo "📦 Extracting..."
tar -xJf "$TMPDIR/shellcheck.tar.xz" -C "$TMPDIR"

# Install binary
INSTALL_DIR="/usr/local/bin"
if [[ -w "$INSTALL_DIR" ]]; then
    cp "$TMPDIR/shellcheck-v${SHELLCHECK_VERSION}/shellcheck" "$INSTALL_DIR/"
else
    echo "🔑 Need sudo to install to $INSTALL_DIR"
    sudo cp "$TMPDIR/shellcheck-v${SHELLCHECK_VERSION}/shellcheck" "$INSTALL_DIR/"
fi
chmod +x "$INSTALL_DIR/shellcheck"

echo ""
echo "✅ ShellCheck v${SHELLCHECK_VERSION} installed successfully!"
echo "   Path: $INSTALL_DIR/shellcheck"
shellcheck --version
