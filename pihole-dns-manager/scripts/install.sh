#!/bin/bash
# Pi-hole DNS Manager — Installer
# Installs Pi-hole with sensible defaults or interactive mode

set -euo pipefail

INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --interactive) INTERACTIVE=true; shift ;;
    -h|--help) echo "Usage: $0 [--interactive]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check root
if [[ $EUID -ne 0 ]]; then
  echo "❌ This script must be run as root (use sudo)"
  exit 1
fi

# Check if already installed
if command -v pihole &>/dev/null; then
  echo "✅ Pi-hole is already installed"
  pihole version
  echo ""
  echo "To update: pihole -up"
  echo "To reconfigure: pihole -r"
  exit 0
fi

echo "🛡️ Installing Pi-hole..."
echo ""

# Check for conflicting services
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
  echo "⚠️  systemd-resolved is running on port 53. Disabling it..."
  systemctl stop systemd-resolved
  systemctl disable systemd-resolved
  # Fix resolv.conf
  rm -f /etc/resolv.conf
  echo "nameserver 8.8.8.8" > /etc/resolv.conf
  echo "nameserver 1.1.1.1" >> /etc/resolv.conf
  echo "✅ systemd-resolved disabled"
fi

# Check port 53
if ss -tulnp | grep -q ':53 ' 2>/dev/null; then
  echo "❌ Port 53 is in use. Free it before installing Pi-hole."
  ss -tulnp | grep ':53 '
  exit 1
fi

if [[ "$INTERACTIVE" == "true" ]]; then
  # Interactive install
  curl -sSL https://install.pi-hole.net | bash
else
  # Automated install with sensible defaults
  # Detect primary interface
  INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
  IP=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

  mkdir -p /etc/pihole

  cat > /etc/pihole/setupVars.conf <<EOF
PIHOLE_INTERFACE=${INTERFACE}
PIHOLE_DNS_1=1.1.1.1
PIHOLE_DNS_2=8.8.8.8
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=true
CACHE_SIZE=10000
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSMASQ_LISTENING=local
WEBPASSWORD=$(openssl rand -hex 32)
BLOCKING_ENABLED=true
EOF

  # Run unattended install
  curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ Pi-hole installed successfully!"
  echo ""
  echo "📍 Web interface: http://${IP}/admin"
  echo "🔑 Set password:  pihole -a -p <password>"
  echo "📡 DNS server:    ${IP}"
  echo ""
  echo "Point your router/device DNS to ${IP}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
