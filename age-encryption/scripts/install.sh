#!/bin/bash
# Install age encryption tool
set -e

echo "🔐 Installing age encryption tool..."

# Detect OS and install
if command -v age &>/dev/null; then
    echo "✅ age is already installed: $(age --version 2>/dev/null || echo 'version unknown')"
    exit 0
fi

install_age() {
    # Try package managers first
    if command -v apt-get &>/dev/null; then
        echo "Installing via apt..."
        sudo apt-get update -qq && sudo apt-get install -y -qq age
    elif command -v brew &>/dev/null; then
        echo "Installing via Homebrew..."
        brew install age
    elif command -v pacman &>/dev/null; then
        echo "Installing via pacman..."
        sudo pacman -S --noconfirm age
    elif command -v dnf &>/dev/null; then
        echo "Installing via dnf..."
        sudo dnf install -y age
    elif command -v apk &>/dev/null; then
        echo "Installing via apk..."
        sudo apk add age
    else
        # Fallback: download binary
        echo "No package manager found. Downloading binary..."
        install_binary
    fi
}

install_binary() {
    local ARCH=$(uname -m)
    local OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    case "$ARCH" in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l|armhf) ARCH="armv6" ;;
        *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    local VERSION="v1.2.1"
    local URL="https://dl.filippo.io/age/${VERSION}?for=${OS}/${ARCH}"

    echo "Downloading age ${VERSION} for ${OS}/${ARCH}..."
    local TMPDIR=$(mktemp -d)
    curl -fsSL "$URL" -o "${TMPDIR}/age.tar.gz"
    tar -xzf "${TMPDIR}/age.tar.gz" -C "${TMPDIR}"

    # Install to /usr/local/bin or ~/bin
    if [ -w /usr/local/bin ]; then
        cp "${TMPDIR}"/age/age "${TMPDIR}"/age/age-keygen /usr/local/bin/
    else
        mkdir -p ~/bin
        cp "${TMPDIR}"/age/age "${TMPDIR}"/age/age-keygen ~/bin/
        echo "Installed to ~/bin — make sure it's in your PATH"
    fi

    rm -rf "${TMPDIR}"
}

install_age

# Verify
if command -v age &>/dev/null; then
    echo "✅ age installed successfully"
    age --version 2>/dev/null || true
else
    echo "❌ Installation may have failed. Check your PATH."
    exit 1
fi

# Create default key directory
mkdir -p ~/.age
chmod 700 ~/.age
echo "📁 Key directory created: ~/.age/"
