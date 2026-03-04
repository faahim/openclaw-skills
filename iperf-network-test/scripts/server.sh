#!/bin/bash
# Manage iperf3 server
set -euo pipefail

PORT="${IPERF_PORT:-5201}"
ACTION="${1:-help}"
shift 2>/dev/null || true

while [[ $# -gt 0 ]]; do
  case $1 in
    --port|-p) PORT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

case "$ACTION" in
  start)
    echo "🚀 Starting iperf3 server on port ${PORT}..."
    if pgrep -f "iperf3 -s" &>/dev/null; then
      echo "⚠️  iperf3 server already running (PID: $(pgrep -f 'iperf3 -s' | head -1))"
      exit 0
    fi
    iperf3 -s -p "$PORT" -D
    echo "✅ Server running on port ${PORT} (daemon mode)"
    echo "   Test from another host: iperf3 -c $(hostname -I 2>/dev/null | awk '{print $1}' || echo '<this-ip>') -p ${PORT}"
    ;;

  stop)
    echo "🛑 Stopping iperf3 server..."
    if pkill -f "iperf3 -s" 2>/dev/null; then
      echo "✅ Server stopped"
    else
      echo "ℹ️  No iperf3 server running"
    fi
    ;;

  status)
    if pgrep -f "iperf3 -s" &>/dev/null; then
      PID=$(pgrep -f "iperf3 -s" | head -1)
      echo "✅ iperf3 server running (PID: ${PID}, port: ${PORT})"
    else
      echo "❌ iperf3 server not running"
    fi
    ;;

  install-service)
    echo "📦 Installing iperf3 as systemd service..."
    sudo tee /etc/systemd/system/iperf3.service > /dev/null <<EOF
[Unit]
Description=iperf3 Network Testing Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/iperf3 -s -p ${PORT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now iperf3
    echo "✅ iperf3 service installed and started"
    echo "   Status: sudo systemctl status iperf3"
    ;;

  remove-service)
    echo "🗑️  Removing iperf3 systemd service..."
    sudo systemctl stop iperf3 2>/dev/null || true
    sudo systemctl disable iperf3 2>/dev/null || true
    sudo rm -f /etc/systemd/system/iperf3.service
    sudo systemctl daemon-reload
    echo "✅ Service removed"
    ;;

  *)
    echo "Usage: bash scripts/server.sh <action> [options]"
    echo ""
    echo "Actions:"
    echo "  start             Start iperf3 server (daemon)"
    echo "  stop              Stop iperf3 server"
    echo "  status            Check if server is running"
    echo "  install-service   Install as systemd service"
    echo "  remove-service    Remove systemd service"
    echo ""
    echo "Options:"
    echo "  --port, -p    Port to listen on (default: 5201)"
    ;;
esac
