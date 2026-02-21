#!/bin/bash
# Install Nginx + Certbot for reverse proxy setup
set -euo pipefail

echo "🔧 Nginx Reverse Proxy — Installer"
echo "===================================="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Cannot detect OS. Supported: Ubuntu, Debian, CentOS, Fedora, RHEL"
    exit 1
fi

install_debian() {
    echo "📦 Installing on Debian/Ubuntu..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq nginx certbot python3-certbot-nginx openssl curl
}

install_rhel() {
    echo "📦 Installing on RHEL/CentOS/Fedora..."
    sudo dnf install -y epel-release 2>/dev/null || true
    sudo dnf install -y nginx certbot python3-certbot-nginx openssl curl
}

case "$OS" in
    ubuntu|debian|pop|linuxmint)
        install_debian
        ;;
    centos|rhel|fedora|rocky|alma)
        install_rhel
        ;;
    *)
        echo "⚠️  Unsupported OS: $OS. Trying apt-get..."
        install_debian
        ;;
esac

# Create directory structure
sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/snippets /etc/nginx/backups

# Check if sites-enabled is included in main config
if ! grep -q "sites-enabled" /etc/nginx/nginx.conf; then
    echo "📝 Adding sites-enabled include to nginx.conf..."
    sudo sed -i '/http {/a\    include /etc/nginx/sites-enabled/*.conf;' /etc/nginx/nginx.conf
fi

# Create shared SSL params snippet
sudo tee /etc/nginx/snippets/ssl-params.conf > /dev/null <<'SSLEOF'
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
SSLEOF

# Create shared proxy params snippet
sudo tee /etc/nginx/snippets/proxy-params.conf > /dev/null <<'PROXYEOF'
proxy_http_version 1.1;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_connect_timeout 60s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;
proxy_buffering on;
proxy_buffer_size 4k;
proxy_buffers 8 4k;
PROXYEOF

# Enable and start nginx
sudo systemctl enable nginx
sudo systemctl start nginx || sudo systemctl restart nginx

# Test config
sudo nginx -t

echo ""
echo "✅ Nginx installed and running!"
echo "   Version: $(nginx -v 2>&1 | cut -d/ -f2)"
echo "   Certbot: $(certbot --version 2>&1 | awk '{print $2}')"
echo ""
echo "Next: bash scripts/proxy.sh add --domain example.com --upstream 127.0.0.1:3000 --ssl"
