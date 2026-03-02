#!/bin/bash
# Set Unbound as system DNS resolver
set -euo pipefail

echo "🔧 Setting Unbound as system DNS..."

# Backup current resolv.conf
if [[ -f /etc/resolv.conf ]]; then
    cp /etc/resolv.conf /etc/resolv.conf.bak.$(date +%s)
    echo "📋 Backed up /etc/resolv.conf"
fi

# Disable systemd-resolved if present
if systemctl is-active systemd-resolved &>/dev/null; then
    echo "⏹️  Stopping systemd-resolved..."
    systemctl disable --now systemd-resolved
    rm -f /etc/resolv.conf  # Remove symlink
fi

# Write new resolv.conf
cat > /etc/resolv.conf <<EOF
# Managed by unbound-dns skill
nameserver 127.0.0.1
options edns0 trust-ad
EOF

# Prevent overwriting by DHCP/NetworkManager
if command -v chattr &>/dev/null; then
    chattr +i /etc/resolv.conf 2>/dev/null || true
    echo "🔒 Locked /etc/resolv.conf (chattr +i)"
fi

echo ""
echo "✅ System DNS set to 127.0.0.1 (Unbound)"
echo "   Test: dig example.com"
echo ""
echo "To revert: sudo bash scripts/uninstall.sh"
