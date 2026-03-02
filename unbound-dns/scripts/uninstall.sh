#!/bin/bash
# Uninstall Unbound DNS resolver
set -euo pipefail

echo "=== Unbound DNS Resolver — Uninstall ==="
read -p "This will remove Unbound and restore default DNS. Continue? [y/N] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Stop service
echo "[*] Stopping Unbound..."
sudo systemctl stop unbound 2>/dev/null || true
sudo systemctl disable unbound 2>/dev/null || true

# Remove cron jobs
echo "[*] Removing cron jobs..."
crontab -l 2>/dev/null | grep -v "unbound-dns" | crontab - 2>/dev/null || true

# Remove config files
echo "[*] Removing config files..."
sudo rm -f /etc/unbound/blocklist.conf
sudo rm -f /etc/unbound/local-zones.conf

# Restore DNS
echo "[*] Restoring default DNS..."
if [ -f /etc/resolv.conf.backup.* ] 2>/dev/null; then
    LATEST=$(ls -t /etc/resolv.conf.backup.* 2>/dev/null | head -1)
    sudo cp "$LATEST" /etc/resolv.conf
    echo "[✓] Restored from backup"
else
    echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf > /dev/null
    echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf > /dev/null
    echo "[✓] Set DNS to Cloudflare + Google"
fi

# Optionally remove package
read -p "Remove Unbound package too? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v apt-get &>/dev/null; then
        sudo apt-get remove -y unbound unbound-host
    elif command -v dnf &>/dev/null; then
        sudo dnf remove -y unbound
    elif command -v pacman &>/dev/null; then
        sudo pacman -R --noconfirm unbound
    elif command -v brew &>/dev/null; then
        brew uninstall unbound
    fi
    echo "[✓] Unbound package removed"
fi

echo ""
echo "=== Uninstall Complete ==="
