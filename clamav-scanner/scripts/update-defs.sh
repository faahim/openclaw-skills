#!/bin/bash
# ClamAV — Update virus definitions
set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📥 Updating virus definitions..."

# Stop freshclam daemon temporarily
sudo systemctl stop clamav-freshclam 2>/dev/null || true

# Run freshclam
if sudo freshclam 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Virus definitions updated"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  Update failed — retrying..."
    sleep 5
    sudo freshclam 2>&1 || echo "❌ Update failed. Check network connection."
fi

# Restart freshclam daemon
sudo systemctl start clamav-freshclam 2>/dev/null || true

# Show current signature count
if command -v sigtool &>/dev/null; then
    SIG_COUNT=$(sigtool --info /var/lib/clamav/main.c?d 2>/dev/null | grep "Signatures:" | head -1 | awk '{print $2}' || echo "unknown")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📊 Total signatures: $SIG_COUNT"
fi
