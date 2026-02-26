#!/bin/bash
# ClamAV Antivirus — Install & Configure
set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📦 Installing ClamAV..."

# Detect package manager
if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq clamav clamav-daemon clamav-freshclam
elif command -v dnf &>/dev/null; then
    sudo dnf install -y -q clamav clamav-update clamd
elif command -v yum &>/dev/null; then
    sudo yum install -y -q clamav clamav-update clamd
elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm clamav
elif command -v apk &>/dev/null; then
    sudo apk add clamav clamav-daemon freshclam
else
    echo "❌ Unsupported package manager. Install ClamAV manually."
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ ClamAV installed"

# Create quarantine directory
QUARANTINE_DIR="${CLAMAV_QUARANTINE_DIR:-/var/clamav/quarantine}"
sudo mkdir -p "$QUARANTINE_DIR"
sudo chmod 700 "$QUARANTINE_DIR"

# Create log directory
LOG_DIR="$(dirname "${CLAMAV_SCAN_LOG:-/var/log/clamav/scan.log}")"
sudo mkdir -p "$LOG_DIR"

# Stop freshclam service temporarily to run manual update
sudo systemctl stop clamav-freshclam 2>/dev/null || true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📥 Downloading virus definitions (this may take 2-5 minutes)..."
sudo freshclam || echo "⚠️  freshclam failed — definitions may still be downloading. Retry in a few minutes."

# Start services
sudo systemctl enable clamav-freshclam 2>/dev/null || true
sudo systemctl start clamav-freshclam 2>/dev/null || true
sudo systemctl enable clamav-daemon 2>/dev/null || true
sudo systemctl start clamav-daemon 2>/dev/null || true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ ClamAV setup complete"
echo "  Quarantine: $QUARANTINE_DIR"
echo "  Logs: ${CLAMAV_SCAN_LOG:-/var/log/clamav/scan.log}"
echo "  Auto-update: enabled (freshclam daemon)"

# Verify
clamscan --version
echo ""
echo "Run your first scan: bash scripts/scan.sh --path /home"
