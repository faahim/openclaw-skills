#!/bin/bash
# Install Latency Monitor as a systemd service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOSTS=""
INTERVAL=60
EXTRA_ARGS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --hosts) HOSTS="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        *) EXTRA_ARGS="$EXTRA_ARGS $1"; shift ;;
    esac
done

if [[ -z "$HOSTS" ]]; then
    echo "Usage: sudo $(basename "$0") --hosts HOST1,HOST2 [--interval SECS] [other latency-monitor args]"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "Error: Must run as root (sudo)"
    exit 1
fi

# Create service file
cat > /etc/systemd/system/latency-monitor.service <<EOF
[Unit]
Description=Latency Monitor
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash ${SCRIPT_DIR}/latency-monitor.sh --hosts "${HOSTS}" --interval ${INTERVAL} --log /var/log/latency-monitor.csv${EXTRA_ARGS}
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable latency-monitor
systemctl start latency-monitor

echo "✅ Latency Monitor installed as systemd service"
echo "   Monitoring: $HOSTS"
echo "   Interval: ${INTERVAL}s"
echo "   Log: /var/log/latency-monitor.csv"
echo ""
echo "Commands:"
echo "  sudo systemctl status latency-monitor"
echo "  sudo systemctl stop latency-monitor"
echo "  sudo journalctl -u latency-monitor -f"
