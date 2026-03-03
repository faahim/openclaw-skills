#!/bin/bash
# Cockpit Web Console — Status Checker

set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

# Check if cockpit is installed
if ! command -v cockpit-bridge &>/dev/null && ! systemctl list-unit-files cockpit.socket &>/dev/null; then
  echo "❌ Cockpit is not installed. Run: bash scripts/install.sh"
  exit 1
fi

# Service status
STATUS=$(systemctl is-active cockpit.socket 2>/dev/null || echo "inactive")
ENABLED=$(systemctl is-enabled cockpit.socket 2>/dev/null || echo "disabled")

# Port
PORT=$(grep -oP 'ListenStream=\K\d+' /etc/systemd/system/cockpit.socket.d/listen.conf 2>/dev/null || echo "9090")

# IP
IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

# SSL info
CERT_FILE=$(find /etc/cockpit/ws-certs.d/ -name "*.cert" -o -name "*.crt" 2>/dev/null | head -1)
SSL_INFO="Self-signed (default)"
if [ -n "$CERT_FILE" ]; then
  EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | sed 's/notAfter=//' || echo "unknown")
  SSL_INFO="✅ Valid (expires $EXPIRY)"
fi

# Uptime
UPTIME=$(systemctl show cockpit.socket --property=ActiveEnterTimestamp --value 2>/dev/null || echo "unknown")

echo "Cockpit Web Console Status"
echo "══════════════════════════"

if [ "$STATUS" = "active" ]; then
  echo "Service:    ✅ Active (listening)"
else
  echo "Service:    ❌ $STATUS"
fi

echo "Enabled:    $ENABLED"
echo "Port:       $PORT"
echo "Dashboard:  https://${IP}:${PORT}"
echo "SSL:        $SSL_INFO"
echo "Started:    $UPTIME"

if $FULL; then
  echo ""
  echo "Installed Modules:"
  
  # List installed cockpit packages
  if command -v dpkg &>/dev/null; then
    dpkg -l 'cockpit*' 2>/dev/null | grep '^ii' | awk '{printf "  ✅ %s (%s)\n", $2, $3}'
  elif command -v rpm &>/dev/null; then
    rpm -qa 'cockpit*' 2>/dev/null | sort | while read pkg; do
      echo "  ✅ $pkg"
    done
  elif command -v pacman &>/dev/null; then
    pacman -Qs cockpit 2>/dev/null | grep 'local/' | awk -F/ '{print "  ✅ " $2}'
  fi

  echo ""
  echo "Active Sessions:"
  loginctl list-sessions --no-legend 2>/dev/null | head -5 | while read session uid user seat tty; do
    echo "  👤 $user (session $session)"
  done || echo "  No active sessions"

  echo ""
  echo "Resource Usage:"
  # Check cockpit-ws process
  COCKPIT_PID=$(pgrep cockpit-ws 2>/dev/null || echo "")
  if [ -n "$COCKPIT_PID" ]; then
    ps -p "$COCKPIT_PID" -o pid=,pcpu=,pmem=,rss= 2>/dev/null | while read pid cpu mem rss; do
      echo "  CPU:    ${cpu}%"
      echo "  Memory: $((rss / 1024)) MB"
    done
  else
    echo "  cockpit-ws not currently running (starts on demand)"
  fi
fi
