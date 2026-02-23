#!/bin/bash
# Caddy Web Server — Installation Script
# Supports: Debian/Ubuntu, RHEL/Fedora/CentOS, Alpine, macOS, direct binary

set -euo pipefail

CADDY_VERSION="${CADDY_VERSION:-latest}"

echo "🔧 Caddy Web Server Installer"
echo "=============================="

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_FAMILY=$ID_LIKE
    elif [ "$(uname)" = "Darwin" ]; then
        OS="macos"
        OS_FAMILY="macos"
    else
        OS="unknown"
        OS_FAMILY="unknown"
    fi
    echo "Detected OS: $OS (family: ${OS_FAMILY:-none})"
}

# Check if Caddy is already installed
check_existing() {
    if command -v caddy &>/dev/null; then
        CURRENT=$(caddy version 2>/dev/null | head -1)
        echo "⚠️  Caddy already installed: $CURRENT"
        read -p "Reinstall/upgrade? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    fi
}

# Install on Debian/Ubuntu
install_debian() {
    echo "📦 Installing via apt (Debian/Ubuntu)..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl

    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null

    sudo apt-get update -qq
    sudo apt-get install -y -qq caddy
}

# Install on RHEL/Fedora/CentOS
install_rhel() {
    echo "📦 Installing via dnf/yum (RHEL/Fedora)..."
    sudo dnf install -y 'dnf-command(copr)' 2>/dev/null || true
    sudo dnf copr enable -y @caddy/caddy 2>/dev/null || true
    sudo dnf install -y caddy 2>/dev/null || sudo yum install -y caddy
}

# Install on Alpine
install_alpine() {
    echo "📦 Installing via apk (Alpine)..."
    sudo apk add --no-cache caddy
}

# Install on macOS
install_macos() {
    echo "📦 Installing via Homebrew (macOS)..."
    if ! command -v brew &>/dev/null; then
        echo "❌ Homebrew not found. Install from https://brew.sh"
        exit 1
    fi
    brew install caddy
}

# Install via direct binary download (fallback)
install_binary() {
    echo "📦 Installing via direct binary download..."
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    PLATFORM="linux"
    [ "$(uname)" = "Darwin" ] && PLATFORM="mac"

    DOWNLOAD_URL="https://caddyserver.com/api/download?os=${PLATFORM}&arch=${ARCH}"
    echo "Downloading from: $DOWNLOAD_URL"

    curl -fsSL "$DOWNLOAD_URL" -o /tmp/caddy
    chmod +x /tmp/caddy
    sudo mv /tmp/caddy /usr/local/bin/caddy

    # Create systemd service if on Linux
    if [ "$PLATFORM" = "linux" ] && command -v systemctl &>/dev/null; then
        setup_systemd
    fi
}

# Setup systemd service (for binary installs)
setup_systemd() {
    echo "⚙️  Setting up systemd service..."

    # Create caddy user if not exists
    sudo useradd --system --home /var/lib/caddy --shell /usr/sbin/nologin caddy 2>/dev/null || true

    # Create directories
    sudo mkdir -p /etc/caddy /var/lib/caddy /var/log/caddy
    sudo chown caddy:caddy /var/lib/caddy /var/log/caddy

    # Create default Caddyfile if not exists
    if [ ! -f /etc/caddy/Caddyfile ]; then
        echo -e "# Caddy default config\n# Add your sites below\n\n:80 {\n    respond \"Caddy is running!\" 200\n}" | sudo tee /etc/caddy/Caddyfile >/dev/null
    fi

    # Create systemd unit
    cat <<'EOF' | sudo tee /etc/systemd/system/caddy.service >/dev/null
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable caddy
}

# Post-install verification
verify() {
    echo ""
    echo "✅ Caddy installed successfully!"
    caddy version
    echo ""

    if command -v systemctl &>/dev/null; then
        echo "Starting Caddy service..."
        sudo systemctl start caddy
        sleep 1
        if systemctl is-active --quiet caddy; then
            echo "✅ Caddy service is running"
        else
            echo "⚠️  Caddy service failed to start. Check: sudo journalctl -u caddy"
        fi
    fi

    echo ""
    echo "📝 Caddyfile location: /etc/caddy/Caddyfile"
    echo "📖 Docs: https://caddyserver.com/docs/"
    echo ""
    echo "Next steps:"
    echo "  1. Edit /etc/caddy/Caddyfile"
    echo "  2. Run: bash scripts/manage.sh reload"
    echo "  Or use: bash scripts/manage.sh proxy --domain app.example.com --upstream localhost:3000"
}

# Main
detect_os
check_existing

case $OS in
    ubuntu|debian|linuxmint|pop) install_debian ;;
    fedora|rhel|centos|rocky|alma) install_rhel ;;
    alpine) install_alpine ;;
    macos) install_macos ;;
    *)
        # Check OS_FAMILY for fallback
        case "${OS_FAMILY:-}" in
            *debian*) install_debian ;;
            *rhel*|*fedora*) install_rhel ;;
            *) install_binary ;;
        esac
        ;;
esac

verify
