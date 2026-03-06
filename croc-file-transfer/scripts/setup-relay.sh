#!/bin/bash
set -euo pipefail

# Croc Relay Server — Systemd Service Setup
# Self-host a croc relay for private/fast transfers

RELAY_PORT="${CROC_RELAY_PORT:-9009}"
RELAY_PORTS="${CROC_RELAY_PORTS:-9010-9013}"
RELAY_PASS="${CROC_PASS:-}"

echo "🔄 Setting up croc relay server..."

# Check croc is installed
if ! command -v croc &>/dev/null; then
    echo "❌ croc not found. Run install.sh first."
    exit 1
fi

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "🔐 This script needs sudo to create a systemd service."
    echo "   Re-run with: sudo bash scripts/setup-relay.sh"
    exit 1
fi

# Create systemd service
SERVICE_FILE="/etc/systemd/system/croc-relay.service"

PASS_ENV=""
if [ -n "$RELAY_PASS" ]; then
    PASS_ENV="Environment=CROC_PASS=$RELAY_PASS"
fi

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Croc Relay Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$(which croc) relay --ports ${RELAY_PORT},${RELAY_PORTS}
Restart=always
RestartSec=5
$PASS_ENV

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF

# Open firewall ports if ufw is active
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    echo "🔓 Opening firewall ports..."
    ufw allow "$RELAY_PORT"/tcp
    # Parse port range
    START_PORT=$(echo "$RELAY_PORTS" | cut -d'-' -f1)
    END_PORT=$(echo "$RELAY_PORTS" | cut -d'-' -f2)
    ufw allow "$START_PORT:$END_PORT"/tcp
fi

# Enable and start
systemctl daemon-reload
systemctl enable croc-relay
systemctl start croc-relay

echo ""
echo "✅ Croc relay server is running!"
echo ""
echo "Status:  systemctl status croc-relay"
echo "Logs:    journalctl -u croc-relay -f"
echo "Stop:    systemctl stop croc-relay"
echo ""
echo "Usage on clients:"
echo "  croc --relay $(hostname -I | awk '{print $1}'):${RELAY_PORT} send file.txt"
echo "  croc --relay $(hostname -I | awk '{print $1}'):${RELAY_PORT} <code>"
if [ -n "$RELAY_PASS" ]; then
    echo ""
    echo "Relay password is set. Clients need: export CROC_PASS=\"$RELAY_PASS\""
fi
