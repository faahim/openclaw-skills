#!/bin/bash
# Uninstall Netdata
set -e

echo "🗑️  Uninstalling Netdata..."

if [ "$(uname)" = "Darwin" ]; then
    brew services stop netdata 2>/dev/null || true
    brew uninstall netdata 2>/dev/null || true
    echo "✅ Netdata removed (macOS)"
    exit 0
fi

# Stop service
sudo systemctl stop netdata 2>/dev/null || sudo service netdata stop 2>/dev/null || true
sudo systemctl disable netdata 2>/dev/null || true

# Use official uninstaller if available
UNINSTALLER="/usr/libexec/netdata/netdata-uninstaller.sh"
[ ! -f "$UNINSTALLER" ] && UNINSTALLER="$(find / -name 'netdata-uninstaller.sh' 2>/dev/null | head -1)"

if [ -n "$UNINSTALLER" ] && [ -f "$UNINSTALLER" ]; then
    sudo "$UNINSTALLER" --yes --force 2>&1 | tail -5
else
    # Manual removal
    sudo rm -rf /etc/netdata /opt/netdata /var/lib/netdata /var/cache/netdata /var/log/netdata
    sudo rm -f /usr/sbin/netdata /usr/lib/systemd/system/netdata.service
    sudo userdel netdata 2>/dev/null || true
    sudo groupdel netdata 2>/dev/null || true
fi

echo "✅ Netdata uninstalled"
