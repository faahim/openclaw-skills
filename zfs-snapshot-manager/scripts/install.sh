#!/usr/bin/env bash
set -euo pipefail

if ! command -v zfs >/dev/null 2>&1; then
  echo "❌ zfs command not found. Install ZFS first:"
  echo "   Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y zfsutils-linux"
  exit 1
fi

mkdir -p "${HOME}/.config/zfs-snapshot-manager"
if [ ! -f "${HOME}/.config/zfs-snapshot-manager/config.env" ]; then
  cat > "${HOME}/.config/zfs-snapshot-manager/config.env" <<'CFG'
# Required: one or more ZFS datasets (space-separated)
DATASETS="tank/data"

# Snapshot retention policy
KEEP_HOURLY=24
KEEP_DAILY=7
KEEP_WEEKLY=4

# Prefix for snapshot names
SNAPSHOT_PREFIX="oclaw"
CFG
  echo "✅ Created ~/.config/zfs-snapshot-manager/config.env"
else
  echo "ℹ️ Config already exists at ~/.config/zfs-snapshot-manager/config.env"
fi

echo "✅ zfs-snapshot-manager install complete"
