#!/bin/bash
# CrowdSec Bouncer Setup
# Usage: bash setup-bouncer.sh <type>
# Types: firewall, nginx, cloudflare

set -euo pipefail

BOUNCER_TYPE="${1:-}"

if [ -z "$BOUNCER_TYPE" ]; then
    echo "Usage: bash setup-bouncer.sh <firewall|nginx|cloudflare>"
    exit 1
fi

setup_firewall_bouncer() {
    echo "🔥 Setting up Firewall Bouncer (iptables/nftables)..."
    
    # Install
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y crowdsec-firewall-bouncer-iptables
    elif command -v yum &>/dev/null; then
        sudo yum install -y crowdsec-firewall-bouncer
    else
        echo "❌ Unsupported package manager"
        exit 1
    fi
    
    # Enable and start
    sudo systemctl enable crowdsec-firewall-bouncer
    sudo systemctl start crowdsec-firewall-bouncer
    
    echo "✅ Firewall bouncer active — malicious IPs will be blocked via iptables/nftables"
}

setup_nginx_bouncer() {
    echo "🌐 Setting up Nginx Bouncer..."
    
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y crowdsec-nginx-bouncer
    elif command -v yum &>/dev/null; then
        sudo yum install -y crowdsec-nginx-bouncer
    else
        echo "❌ Unsupported package manager"
        exit 1
    fi
    
    sudo systemctl enable crowdsec-nginx-bouncer
    sudo systemctl start crowdsec-nginx-bouncer
    
    echo "✅ Nginx bouncer active — banned IPs get 403 Forbidden"
    echo ""
    echo "⚠️  Restart Nginx to apply: sudo systemctl restart nginx"
}

setup_cloudflare_bouncer() {
    echo "☁️  Setting up Cloudflare Bouncer..."
    
    if [ -z "${CF_API_TOKEN:-}" ] || [ -z "${CF_ACCOUNT_ID:-}" ]; then
        echo "❌ Required environment variables:"
        echo "   export CF_API_TOKEN=\"<your-cloudflare-api-token>\""
        echo "   export CF_ACCOUNT_ID=\"<your-cloudflare-account-id>\""
        exit 1
    fi
    
    # Install bouncer
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y crowdsec-cloudflare-bouncer
    elif command -v yum &>/dev/null; then
        sudo yum install -y crowdsec-cloudflare-bouncer
    else
        # Manual install
        echo "Installing via GitHub release..."
        LATEST=$(curl -s https://api.github.com/repos/crowdsecurity/cs-cloudflare-bouncer/releases/latest | jq -r '.tag_name')
        ARCH=$(uname -m)
        case "$ARCH" in
            x86_64) ARCH="amd64" ;;
            aarch64) ARCH="arm64" ;;
        esac
        curl -sL "https://github.com/crowdsecurity/cs-cloudflare-bouncer/releases/download/${LATEST}/crowdsec-cloudflare-bouncer-linux-${ARCH}.tgz" | sudo tar xzf - -C /usr/local/bin/
    fi
    
    # Configure
    sudo cat > /etc/crowdsec/bouncers/crowdsec-cloudflare-bouncer.yaml <<EOF
crowdsec_lapi_url: http://127.0.0.1:8080/
crowdsec_lapi_key: $(sudo cscli bouncers add cloudflare-bouncer -o raw 2>/dev/null || echo "GENERATE_KEY")
cloudflare_config:
  accounts:
    - id: ${CF_ACCOUNT_ID}
      token: ${CF_API_TOKEN}
      zones:
        - actions:
            - ban
          zone_id: auto
EOF
    
    sudo systemctl enable crowdsec-cloudflare-bouncer
    sudo systemctl start crowdsec-cloudflare-bouncer
    
    echo "✅ Cloudflare bouncer active — bans propagate to Cloudflare edge"
}

case "$BOUNCER_TYPE" in
    firewall|fw|iptables)
        setup_firewall_bouncer
        ;;
    nginx|web)
        setup_nginx_bouncer
        ;;
    cloudflare|cf)
        setup_cloudflare_bouncer
        ;;
    *)
        echo "❌ Unknown bouncer type: $BOUNCER_TYPE"
        echo "Available: firewall, nginx, cloudflare"
        exit 1
        ;;
esac

echo ""
echo "Verify with: cscli bouncers list"
