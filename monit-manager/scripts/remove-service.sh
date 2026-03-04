#!/bin/bash
# Remove a service monitor from Monit
set -e

NAME=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "Usage: $0 --name <service-name>"
  exit 1
fi

CONF_FILE="/etc/monit/conf.d/${NAME}.conf"

if [ ! -f "$CONF_FILE" ]; then
  echo "❌ No monitor found for '$NAME' at $CONF_FILE"
  echo "Available monitors:"
  ls /etc/monit/conf.d/ 2>/dev/null | sed 's/.conf$//' || echo "  (none)"
  exit 1
fi

sudo monit unmonitor "$NAME" 2>/dev/null || true
sudo rm -f "$CONF_FILE"
sudo monit reload 2>/dev/null

echo "✅ Removed monitor '$NAME'"
