#!/bin/bash
# Install Unbound DNS resolver — auto-detects OS
set -euo pipefail

echo "=== Unbound DNS Resolver — Installation ==="

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    elif command -v brew &>/dev/null; then
        OS="macos"
    else
        echo "❌ Unsupported OS. Install Unbound manually."
        exit 1
    fi
    echo "[i] Detected OS: $OS"
}

install_unbound() {
    case "$OS" in
        ubuntu|debian|pop|linuxmint)
            echo "[*] Installing via apt..."
            sudo apt-get update -qq
            sudo apt-get install -y -qq unbound unbound-host dns-root-data
            ;;
        fedora|rhel|centos|rocky|alma)
            echo "[*] Installing via dnf/yum..."
            if command -v dnf &>/dev/null; then
                sudo dnf install -y unbound
            else
                sudo yum install -y unbound
            fi
            ;;
        arch|manjaro|endeavouros)
            echo "[*] Installing via pacman..."
            sudo pacman -S --noconfirm unbound expat
            ;;
        alpine)
            echo "[*] Installing via apk..."
            sudo apk add unbound
            ;;
        macos)
            echo "[*] Installing via Homebrew..."
            brew install unbound
            ;;
        *)
            echo "❌ Unsupported OS: $OS"
            echo "   Install Unbound manually: https://nlnetlabs.nl/projects/unbound/download/"
            exit 1
            ;;
    esac
}

verify_install() {
    if command -v unbound &>/dev/null; then
        local version
        version=$(unbound -V 2>&1 | head -1)
        echo "[✓] Unbound installed: $version"
    else
        echo "❌ Installation failed — unbound not found in PATH"
        exit 1
    fi

    if command -v unbound-checkconf &>/dev/null; then
        echo "[✓] unbound-checkconf available"
    fi

    if command -v unbound-control &>/dev/null; then
        echo "[✓] unbound-control available"
    fi
}

# Disable systemd-resolved if it's hogging port 53
handle_resolved() {
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        echo ""
        echo "[!] systemd-resolved is running on port 53."
        echo "    Unbound needs port 53. Options:"
        echo "    1) Run: sudo systemctl disable --now systemd-resolved"
        echo "    2) Or configure Unbound on a different port (--port 5353)"
        echo ""
        read -p "    Disable systemd-resolved now? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo systemctl disable --now systemd-resolved
            # Fix resolv.conf
            if [ -L /etc/resolv.conf ]; then
                sudo rm /etc/resolv.conf
            fi
            echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null
            echo "[✓] systemd-resolved disabled, resolv.conf updated"
        else
            echo "[i] Skipped. You may need to configure a different port."
        fi
    fi
}

# Fetch root hints
fetch_root_hints() {
    local hints_file="/etc/unbound/root.hints"
    if [ "$OS" = "macos" ]; then
        hints_file="$(brew --prefix)/etc/unbound/root.hints"
    fi

    echo "[*] Fetching root hints from internic.net..."
    sudo curl -sS -o "$hints_file" https://www.internic.net/domain/named.cache
    echo "[✓] Root hints saved to $hints_file"
}

# Setup unbound-control
setup_control() {
    if command -v unbound-control-setup &>/dev/null; then
        echo "[*] Setting up unbound-control (for stats/management)..."
        sudo unbound-control-setup -d /etc/unbound 2>/dev/null || true
        echo "[✓] unbound-control configured"
    fi
}

main() {
    detect_os
    install_unbound
    verify_install
    handle_resolved
    fetch_root_hints
    setup_control
    echo ""
    echo "=== Installation Complete ==="
    echo "Next: Run 'bash scripts/configure.sh' to set up your resolver."
}

main "$@"
