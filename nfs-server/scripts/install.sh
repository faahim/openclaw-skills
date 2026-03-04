#!/bin/bash
# NFS Server — Install & Configure
set -euo pipefail

echo "🔧 NFS Server Installer"
echo "═══════════════════════"

# Detect package manager
if command -v apt-get &>/dev/null; then
    PKG_MGR="apt"
    NFS_PKG="nfs-kernel-server"
    NFS_SVC="nfs-server"
elif command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
    NFS_PKG="nfs-utils"
    NFS_SVC="nfs-server"
elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
    NFS_PKG="nfs-utils"
    NFS_SVC="nfs-server"
elif command -v pacman &>/dev/null; then
    PKG_MGR="pacman"
    NFS_PKG="nfs-utils"
    NFS_SVC="nfs-server"
else
    echo "❌ Unsupported package manager. Install NFS manually."
    exit 1
fi

echo "📦 Installing $NFS_PKG via $PKG_MGR..."

case "$PKG_MGR" in
    apt)
        sudo apt-get update -qq
        sudo apt-get install -y -qq "$NFS_PKG" >/dev/null 2>&1
        ;;
    dnf|yum)
        sudo "$PKG_MGR" install -y -q "$NFS_PKG" >/dev/null 2>&1
        ;;
    pacman)
        sudo pacman -S --noconfirm --quiet "$NFS_PKG" >/dev/null 2>&1
        ;;
esac

echo "✅ $NFS_PKG installed"

# Enable and start NFS server
echo "🚀 Enabling NFS server..."
sudo systemctl enable "$NFS_SVC" --now 2>/dev/null || true

# Verify service
if systemctl is-active --quiet "$NFS_SVC"; then
    echo "✅ NFS server is running"
else
    echo "⚠️  NFS server failed to start. Check: journalctl -u $NFS_SVC"
    exit 1
fi

# Configure firewall
echo "🔥 Configuring firewall..."
if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
    sudo ufw allow 2049/tcp comment "NFS" >/dev/null 2>&1
    sudo ufw allow 111/tcp comment "NFS portmapper" >/dev/null 2>&1
    echo "✅ UFW rules added (ports 2049, 111)"
elif command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --permanent --add-service=nfs >/dev/null 2>&1
    sudo firewall-cmd --permanent --add-service=rpc-bind >/dev/null 2>&1
    sudo firewall-cmd --permanent --add-service=mountd >/dev/null 2>&1
    sudo firewall-cmd --reload >/dev/null 2>&1
    echo "✅ Firewalld rules added (nfs, rpc-bind, mountd)"
else
    echo "ℹ️  No active firewall detected. Ensure ports 2049/tcp and 111/tcp are open."
fi

# Backup existing exports if any
if [ -f /etc/exports ] && [ -s /etc/exports ]; then
    BACKUP="/etc/exports.backup.$(date +%Y-%m-%d)"
    sudo cp /etc/exports "$BACKUP"
    echo "📋 Backed up existing exports to $BACKUP"
fi

echo ""
echo "═══════════════════════"
echo "✅ NFS Server ready!"
echo ""
echo "Next steps:"
echo "  bash scripts/nfs-manage.sh add --path /srv/shared --clients '192.168.1.0/24' --options 'rw,sync,no_subtree_check'"
