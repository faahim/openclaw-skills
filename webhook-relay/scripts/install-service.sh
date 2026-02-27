#!/bin/bash
# Install Webhook Relay as a systemd service
set -e

RELAY_USER="${1:-$(whoami)}"
RELAY_PATH="$HOME/.config/webhook-relay"

if [ ! -f "$RELAY_PATH/relay.py" ]; then
    echo "Error: relay.py not found at $RELAY_PATH/relay.py"
    echo "Run the install steps from SKILL.md first."
    exit 1
fi

cat > /tmp/webhook-relay.service << EOF
[Unit]
Description=Webhook Relay — Route webhooks to multiple destinations
After=network.target

[Service]
Type=simple
User=$RELAY_USER
ExecStart=/usr/bin/python3 $RELAY_PATH/relay.py
Restart=on-failure
RestartSec=5
Environment=HOME=$HOME

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/webhook-relay.service /etc/systemd/system/webhook-relay.service
sudo systemctl daemon-reload
sudo systemctl enable webhook-relay
sudo systemctl start webhook-relay

echo "✅ Webhook Relay installed as systemd service"
echo "   Status: sudo systemctl status webhook-relay"
echo "   Logs:   journalctl -u webhook-relay -f"
