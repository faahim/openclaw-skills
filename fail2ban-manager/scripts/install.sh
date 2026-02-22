#!/bin/bash
# Fail2ban Installer — Detects OS and installs fail2ban
set -e

echo "🔧 Installing Fail2ban..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Cannot detect OS. Install fail2ban manually."
    exit 1
fi

case "$OS" in
    ubuntu|debian|pop|linuxmint)
        echo "📦 Detected: $PRETTY_NAME (apt)"
        sudo apt-get update -qq
        sudo apt-get install -y -qq fail2ban
        ;;
    centos|rhel|rocky|alma|fedora)
        echo "📦 Detected: $PRETTY_NAME (dnf/yum)"
        if command -v dnf &>/dev/null; then
            sudo dnf install -y -q epel-release 2>/dev/null || true
            sudo dnf install -y -q fail2ban
        else
            sudo yum install -y -q epel-release 2>/dev/null || true
            sudo yum install -y -q fail2ban
        fi
        ;;
    arch|manjaro)
        echo "📦 Detected: $PRETTY_NAME (pacman)"
        sudo pacman -S --noconfirm fail2ban
        ;;
    opensuse*|sles)
        echo "📦 Detected: $PRETTY_NAME (zypper)"
        sudo zypper install -y fail2ban
        ;;
    *)
        echo "❌ Unsupported OS: $OS"
        echo "   Install fail2ban manually: https://github.com/fail2ban/fail2ban"
        exit 1
        ;;
esac

# Enable and start
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Create local config if it doesn't exist
if [ ! -f /etc/fail2ban/jail.local ]; then
    sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    echo "📄 Created /etc/fail2ban/jail.local"
fi

# Verify
if sudo fail2ban-client status &>/dev/null; then
    echo ""
    echo "✅ Fail2ban installed and running!"
    echo "   Version: $(fail2ban-client --version 2>&1 | head -1)"
    echo "   Config:  /etc/fail2ban/jail.local"
    echo "   Logs:    /var/log/fail2ban.log"
    sudo fail2ban-client status
else
    echo "❌ Fail2ban installed but not running. Check: sudo systemctl status fail2ban"
    exit 1
fi
