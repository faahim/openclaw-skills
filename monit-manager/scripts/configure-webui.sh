#!/bin/bash
# Enable Monit web UI
set -e

PORT="2812"
USER="admin"
PASS="monit"
ALLOW="localhost"

while [[ $# -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift 2 ;;
    --user) USER="$2"; shift 2 ;;
    --password) PASS="$2"; shift 2 ;;
    --allow) ALLOW="$ALLOW $2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

MONITRC="/etc/monit/monitrc"

# Remove existing httpd config
sudo sed -i '/^set httpd/,/^$/d' "$MONITRC" 2>/dev/null || true

# Build allow lines
ALLOW_LINES=""
for addr in $ALLOW; do
  ALLOW_LINES="$ALLOW_LINES  allow $addr\n"
done

# Add httpd config
cat <<EOF | sudo tee -a "$MONITRC" >/dev/null

set httpd port $PORT
  allow $USER:$PASS
$(for addr in $ALLOW; do echo "  allow $addr"; done)
EOF

echo "✅ Web UI enabled at http://localhost:$PORT"
echo "   User: $USER"

if sudo monit -t 2>/dev/null; then
  sudo monit reload 2>/dev/null
  echo "🔄 Monit reloaded"
fi
