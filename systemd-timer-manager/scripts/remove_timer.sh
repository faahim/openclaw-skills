#!/usr/bin/env bash
set -euo pipefail
NAME="${1:-}"
[[ -n "$NAME" ]] || { echo "Usage: $0 <name>"; exit 1; }

sudo systemctl disable --now "${NAME}.timer" 2>/dev/null || true
sudo rm -f "/etc/systemd/system/${NAME}.timer" "/etc/systemd/system/${NAME}.service"
sudo systemctl daemon-reload
sudo systemctl reset-failed

echo "✅ Removed ${NAME}.timer and ${NAME}.service"
