#!/bin/bash
# Uninstall Unbound and restore original DNS
set -euo pipefail

echo "🗑️  Uninstalling Unbound DNS..."

# Unlock resolv.conf
if command -v chattr &>/dev/null; then
    chattr -i /etc/resolv.conf 2>/dev/null || true
fi

# Restore resolv.conf backup
LATEST_BACKUP=$(ls -t /etc/resolv.conf.bak.* 2>/dev/null | head -1)
if [[ -n "$LATEST_BACKUP" ]]; then
    cp "$LATEST_BACKUP" /etc/resolv.conf
    echo "✅ Restored DNS from backup: $LATEST_BACKUP"
else
    # Fallback: use Cloudflare
    cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
    echo "✅ Restored DNS to Cloudflare/Google defaults"
fi

# Re-enable systemd-resolved if it was disabled
if command -v systemctl &>/dev/null && systemctl list-unit-files | grep -q systemd-resolved; then
    echo "🔄 Re-enabling systemd-resolved..."
    systemctl enable --now systemd-resolved 2>/dev/null || true
fi

# Stop Unbound
if command -v systemctl &>/dev/null; then
    systemctl disable --now unbound 2>/dev/null || true
elif command -v brew &>/dev/null; then
    brew services stop unbound 2>/dev/null || true
fi

echo ""
echo "✅ Unbound stopped and DNS restored"
echo "   Unbound package NOT removed (run 'sudo apt remove unbound' manually if desired)"
