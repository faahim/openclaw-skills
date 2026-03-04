#!/bin/bash
# Monitor a file for changes (checksum, size, permissions)
set -e

FILE_PATH=""
CHECKSUM="sha256"
ON_CHANGE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --path) FILE_PATH="$2"; shift 2 ;;
    --checksum) CHECKSUM="$2"; shift 2 ;;
    --on-change) ON_CHANGE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$FILE_PATH" ]; then
  echo "❌ --path is required"
  echo "Usage: $0 --path /etc/nginx/nginx.conf [--checksum sha256] [--on-change 'systemctl reload nginx']"
  exit 1
fi

NAME=$(basename "$FILE_PATH" | tr '.' '_')
CONF_FILE="/etc/monit/conf.d/file-${NAME}.conf"

CONFIG="check file ${NAME} with path ${FILE_PATH}
  if changed checksum then alert
  if changed permission then alert
  if changed uid then alert
  if changed gid then alert"

if [ -n "$ON_CHANGE" ]; then
  CONFIG="$CONFIG
  if changed checksum then exec \"$ON_CHANGE\""
fi

echo "$CONFIG" | sudo tee "$CONF_FILE" >/dev/null
echo "✅ File monitor for '$FILE_PATH' created at $CONF_FILE"

if sudo monit -t 2>/dev/null; then
  sudo monit reload 2>/dev/null
  echo "🔄 Monit reloaded"
else
  echo "❌ Config validation failed"
  exit 1
fi
