#!/bin/bash
# Install smartmontools and dependencies
set -euo pipefail

echo "📦 Installing SMART Disk Monitor dependencies..."

# Detect OS
if command -v apt-get &>/dev/null; then
  sudo apt-get update -qq
  sudo apt-get install -y smartmontools jq bc
elif command -v yum &>/dev/null; then
  sudo yum install -y smartmontools jq bc
elif command -v dnf &>/dev/null; then
  sudo dnf install -y smartmontools jq bc
elif command -v pacman &>/dev/null; then
  sudo pacman -S --noconfirm smartmontools jq bc
elif command -v brew &>/dev/null; then
  brew install smartmontools jq
else
  echo "❌ Unknown package manager. Install manually: smartmontools jq bc"
  exit 1
fi

# Enable SMART on all detected disks
echo "🔧 Enabling SMART on detected disks..."
for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
  if [[ -b "$disk" ]]; then
    sudo smartctl -s on "$disk" 2>/dev/null && echo "  ✅ Enabled on $disk" || echo "  ⚠️  Could not enable on $disk"
  fi
done

echo ""
echo "✅ Installation complete. Run: sudo bash scripts/run.sh --all"
