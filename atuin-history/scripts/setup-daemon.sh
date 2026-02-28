#!/bin/bash
# Set up Atuin daemon as a systemd user service
set -e

if ! command -v atuin &>/dev/null; then
    echo "❌ Atuin not found. Run install.sh first."
    exit 1
fi

SERVICEDIR="$HOME/.config/systemd/user"
mkdir -p "$SERVICEDIR"

cat > "$SERVICEDIR/atuin-daemon.service" << EOF
[Unit]
Description=Atuin History Daemon

[Service]
Type=simple
ExecStart=$(which atuin) daemon
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now atuin-daemon

echo "✅ Atuin daemon started as user service"
echo "   Status: systemctl --user status atuin-daemon"
echo "   Logs:   journalctl --user -u atuin-daemon -f"
