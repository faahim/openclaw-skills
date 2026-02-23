#!/bin/bash
# Install ntfy server
# Supports: Debian/Ubuntu, RHEL/CentOS/Fedora, Arch, macOS (client only)
set -e

echo "🔔 Installing ntfy push notification server..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_FAMILY=$ID_LIKE
elif [ "$(uname)" = "Darwin" ]; then
    OS="macos"
else
    echo "❌ Unsupported OS"
    exit 1
fi

install_debian() {
    echo "📦 Installing via apt (Debian/Ubuntu)..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://archive.heckel.io/apt/pubkey.txt | sudo gpg --dearmor -o /etc/apt/keyrings/archive.heckel.io.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/archive.heckel.io.gpg] https://archive.heckel.io/apt debian main" | sudo tee /etc/apt/sources.list.d/archive.heckel.io.list
    sudo apt update
    sudo apt install -y ntfy
}

install_rpm() {
    echo "📦 Installing via rpm (RHEL/Fedora)..."
    sudo rpm -ivh https://archive.heckel.io/rpm/ntfy.rpm 2>/dev/null || {
        # Fallback: download binary
        install_binary
    }
}

install_arch() {
    echo "📦 Installing via AUR (Arch)..."
    if command -v yay &>/dev/null; then
        yay -S ntfy
    elif command -v paru &>/dev/null; then
        paru -S ntfy
    else
        echo "No AUR helper found. Installing binary..."
        install_binary
    fi
}

install_binary() {
    echo "📦 Installing binary directly..."
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7*|armhf) ARCH="armv7" ;;
        *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    LATEST=$(curl -s https://api.github.com/repos/binwiederhier/ntfy/releases/latest | grep tag_name | cut -d '"' -f 4)
    URL="https://github.com/binwiederhier/ntfy/releases/download/${LATEST}/ntfy_${LATEST#v}_linux_${ARCH}.tar.gz"
    
    echo "⬇️  Downloading ntfy ${LATEST} for ${ARCH}..."
    curl -fsSL "$URL" -o /tmp/ntfy.tar.gz
    tar -xzf /tmp/ntfy.tar.gz -C /tmp
    sudo mv /tmp/ntfy_*/ntfy /usr/local/bin/ntfy
    sudo chmod +x /usr/local/bin/ntfy
    rm -rf /tmp/ntfy.tar.gz /tmp/ntfy_*
    
    # Create systemd service
    sudo mkdir -p /etc/ntfy
    sudo ntfy serve --help >/dev/null 2>&1 && echo "✅ Binary installed"
    
    # Create systemd unit if it doesn't exist
    if [ ! -f /etc/systemd/system/ntfy.service ]; then
        cat <<'UNIT' | sudo tee /etc/systemd/system/ntfy.service
[Unit]
Description=ntfy push notification server
After=network.target

[Service]
ExecStart=/usr/local/bin/ntfy serve
Restart=on-failure
User=ntfy
Group=ntfy

[Install]
WantedBy=multi-user.target
UNIT
        # Create ntfy user
        sudo useradd -r -s /usr/sbin/nologin ntfy 2>/dev/null || true
        sudo mkdir -p /var/cache/ntfy /var/lib/ntfy
        sudo chown ntfy:ntfy /var/cache/ntfy /var/lib/ntfy
        sudo systemctl daemon-reload
    fi
}

install_macos() {
    echo "📦 Installing via Homebrew (macOS — client only)..."
    if ! command -v brew &>/dev/null; then
        echo "❌ Homebrew required. Install: https://brew.sh"
        exit 1
    fi
    brew install ntfy
}

# Route to correct installer
case "$OS" in
    ubuntu|debian|pop|linuxmint) install_debian ;;
    fedora|centos|rhel|rocky|alma) install_rpm ;;
    arch|manjaro|endeavouros) install_arch ;;
    macos) install_macos ;;
    *)
        if echo "$OS_FAMILY" | grep -qi debian; then
            install_debian
        elif echo "$OS_FAMILY" | grep -qi rhel; then
            install_rpm
        else
            install_binary
        fi
        ;;
esac

# Copy default config if none exists
if [ ! -f /etc/ntfy/server.yml ] && [ "$OS" != "macos" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$SCRIPT_DIR/server.yml" ]; then
        sudo cp "$SCRIPT_DIR/server.yml" /etc/ntfy/server.yml
        echo "📝 Default config installed to /etc/ntfy/server.yml"
    fi
fi

# Verify
if command -v ntfy &>/dev/null; then
    echo ""
    echo "✅ ntfy installed successfully!"
    echo "   Version: $(ntfy --version 2>/dev/null || echo 'unknown')"
    echo ""
    echo "Next steps:"
    echo "  1. Edit config:  sudo nano /etc/ntfy/server.yml"
    echo "  2. Start server: sudo systemctl start ntfy"
    echo "  3. Enable boot:  sudo systemctl enable ntfy"
    echo "  4. Test:         curl -d 'Hello!' localhost:8080/test"
else
    echo "❌ Installation failed"
    exit 1
fi
