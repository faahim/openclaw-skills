#!/bin/bash
# HAProxy Manager — Install Script
# Detects OS and installs HAProxy 2.x+

set -euo pipefail

echo "🔧 HAProxy Manager — Installer"
echo "================================"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "❌ Cannot detect OS. Install HAProxy manually."
    exit 1
fi

echo "📦 Detected: $OS $VERSION"

install_haproxy() {
    case "$OS" in
        ubuntu|debian)
            # Add HAProxy PPA for latest version
            if ! command -v haproxy &>/dev/null; then
                sudo apt-get update -qq
                sudo apt-get install -y -qq software-properties-common
                sudo add-apt-repository -y ppa:vbernat/haproxy-2.8 2>/dev/null || true
                sudo apt-get update -qq
                sudo apt-get install -y -qq haproxy jq socat curl openssl
            fi
            ;;
        centos|rhel|fedora|rocky|alma)
            if ! command -v haproxy &>/dev/null; then
                sudo yum install -y epel-release 2>/dev/null || true
                sudo yum install -y haproxy jq socat curl openssl
            fi
            ;;
        alpine)
            if ! command -v haproxy &>/dev/null; then
                sudo apk add --no-cache haproxy jq socat curl openssl
            fi
            ;;
        arch|manjaro)
            if ! command -v haproxy &>/dev/null; then
                sudo pacman -Sy --noconfirm haproxy jq socat curl openssl
            fi
            ;;
        *)
            echo "❌ Unsupported OS: $OS"
            echo "   Install haproxy manually: https://www.haproxy.org/#down"
            exit 1
            ;;
    esac
}

setup_dirs() {
    mkdir -p "$HOME/.haproxy-manager/backups"
    
    # Initialize state file if not exists
    if [ ! -f "$HOME/.haproxy-manager/state.json" ]; then
        cat > "$HOME/.haproxy-manager/state.json" <<'EOF'
{
  "version": "1.0",
  "created_at": "",
  "backends": [],
  "frontends": [],
  "stats": {
    "enabled": false,
    "port": 9090,
    "user": "admin",
    "pass": "admin"
  },
  "global": {
    "maxconn": 4096,
    "log": "/dev/log local0",
    "chroot": "/var/lib/haproxy",
    "user": "haproxy",
    "group": "haproxy"
  }
}
EOF
        # Set created_at
        local ts
        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        local tmp
        tmp=$(jq --arg ts "$ts" '.created_at = $ts' "$HOME/.haproxy-manager/state.json")
        echo "$tmp" > "$HOME/.haproxy-manager/state.json"
    fi
}

verify_install() {
    if command -v haproxy &>/dev/null; then
        local ver
        ver=$(haproxy -v 2>&1 | head -1)
        echo ""
        echo "✅ HAProxy installed: $ver"
        echo "📁 State file: $HOME/.haproxy-manager/state.json"
        echo "📁 Backups: $HOME/.haproxy-manager/backups/"
        echo ""
        echo "Next steps:"
        echo "  1. Add a backend: bash scripts/manage.sh add-backend --name myapp --servers 'host:port' --port 80"
        echo "  2. Apply config:  bash scripts/manage.sh apply"
        echo "  3. Start HAProxy: sudo systemctl start haproxy"
    else
        echo "❌ HAProxy installation failed"
        exit 1
    fi
}

install_haproxy
setup_dirs
verify_install
