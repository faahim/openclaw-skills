#!/bin/bash
# CrowdSec Installation Script
# Supports: Debian/Ubuntu, RHEL/CentOS/Fedora, Alpine

set -euo pipefail

echo "🛡️  CrowdSec Security — Installation"
echo "======================================"

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
    else
        echo "❌ Unsupported OS"
        exit 1
    fi
}

install_debian() {
    echo "📦 Installing CrowdSec on Debian/Ubuntu..."
    
    # Add CrowdSec repository
    curl -s https://install.crowdsec.net | sudo bash
    
    # Install CrowdSec
    sudo apt-get update
    sudo apt-get install -y crowdsec
    
    echo "✅ CrowdSec installed"
}

install_rhel() {
    echo "📦 Installing CrowdSec on RHEL/CentOS/Fedora..."
    
    curl -s https://install.crowdsec.net | sudo bash
    sudo yum install -y crowdsec
    
    echo "✅ CrowdSec installed"
}

install_alpine() {
    echo "📦 Installing CrowdSec on Alpine..."
    
    sudo apk add --no-cache crowdsec
    
    echo "✅ CrowdSec installed"
}

install_generic() {
    echo "📦 Installing CrowdSec via install script..."
    
    curl -s https://install.crowdsec.net | sudo bash
    
    # Try apt first, then yum
    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y crowdsec
    elif command -v yum &>/dev/null; then
        sudo yum install -y crowdsec
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y crowdsec
    else
        echo "❌ No supported package manager found"
        exit 1
    fi
    
    echo "✅ CrowdSec installed"
}

# Post-install setup
post_install() {
    echo ""
    echo "🔧 Post-installation setup..."
    
    # Enable and start service
    sudo systemctl enable crowdsec
    sudo systemctl start crowdsec
    
    # Install common collections
    echo "📚 Installing essential collections..."
    sudo cscli collections install crowdsecurity/linux 2>/dev/null || true
    sudo cscli collections install crowdsecurity/sshd 2>/dev/null || true
    
    # Auto-detect and configure nginx if present
    if [ -d /var/log/nginx ]; then
        echo "🌐 Nginx detected — installing nginx collection..."
        sudo cscli collections install crowdsecurity/nginx 2>/dev/null || true
        
        # Add nginx logs to acquisition if not already there
        if ! grep -q "nginx" /etc/crowdsec/acquis.yaml 2>/dev/null; then
            cat <<EOF | sudo tee -a /etc/crowdsec/acquis.yaml
---
filenames:
  - /var/log/nginx/access.log
  - /var/log/nginx/error.log
labels:
  type: nginx
EOF
        fi
    fi
    
    # Auto-detect Apache
    if [ -d /var/log/apache2 ] || [ -d /var/log/httpd ]; then
        echo "🌐 Apache detected — installing apache2 collection..."
        sudo cscli collections install crowdsecurity/apache2 2>/dev/null || true
    fi
    
    # Register with Central API
    echo "🌍 Registering with CrowdSec Central API..."
    sudo cscli capi register 2>/dev/null || echo "⚠️  Already registered or registration failed (non-critical)"
    
    # Reload to apply changes
    sudo systemctl reload crowdsec
    
    echo ""
    echo "======================================"
    echo "✅ CrowdSec is installed and running!"
    echo ""
    echo "Next steps:"
    echo "  1. Install a bouncer:  bash scripts/setup-bouncer.sh firewall"
    echo "  2. Check status:       bash scripts/status.sh"
    echo "  3. View metrics:       cscli metrics"
    echo "======================================"
}

# Main
detect_os
echo "Detected OS: $OS"

case "$OS" in
    ubuntu|debian|pop|linuxmint)
        install_debian
        ;;
    centos|rhel|fedora|rocky|alma)
        install_rhel
        ;;
    alpine)
        install_alpine
        ;;
    *)
        echo "⚠️  Unknown OS '$OS' — trying generic install..."
        install_generic
        ;;
esac

post_install
