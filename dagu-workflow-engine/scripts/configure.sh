#!/bin/bash
# Dagu Configuration Helper
# Usage: bash configure.sh [options]

set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/dagu}"
CONFIG_FILE="$CONFIG_DIR/admin.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config not found: $CONFIG_FILE"
  echo "   Run: bash scripts/install.sh first"
  exit 1
fi

usage() {
  cat << 'EOF'
Dagu Configuration Helper

Usage: bash configure.sh [options]

Options:
  --port <port>           Set dashboard port (default: 8080)
  --host <host>           Set bind address (default: 127.0.0.1)
  --auth                  Enable basic authentication
  --user <username>       Set auth username
  --pass <password>       Set auth password
  --no-auth               Disable authentication
  --dags-dir <path>       Set DAGs directory
  --show                  Show current configuration

Examples:
  bash configure.sh --port 9090
  bash configure.sh --auth --user admin --pass s3cur3
  bash configure.sh --host 0.0.0.0
  bash configure.sh --show
EOF
}

show_config() {
  echo "📋 Current Dagu Configuration:"
  echo "   File: $CONFIG_FILE"
  echo ""
  cat "$CONFIG_FILE"
}

# Parse args
PORT=""
HOST=""
AUTH=""
USER=""
PASS=""
DAGS=""
SHOW=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --port)     PORT="$2"; shift 2 ;;
    --host)     HOST="$2"; shift 2 ;;
    --auth)     AUTH="true"; shift ;;
    --no-auth)  AUTH="false"; shift ;;
    --user)     USER="$2"; shift 2 ;;
    --pass)     PASS="$2"; shift 2 ;;
    --dags-dir) DAGS="$2"; shift 2 ;;
    --show)     SHOW="true"; shift ;;
    --help)     usage; exit 0 ;;
    *)          echo "Unknown: $1"; usage; exit 1 ;;
  esac
done

if [ -n "$SHOW" ]; then
  show_config
  exit 0
fi

if [ -z "$PORT$HOST$AUTH$DAGS" ]; then
  usage
  exit 0
fi

# Apply changes using sed (simple YAML manipulation)
if [ -n "$PORT" ]; then
  sed -i "s/^port:.*/port: $PORT/" "$CONFIG_FILE"
  echo "✅ Port set to $PORT"
fi

if [ -n "$HOST" ]; then
  sed -i "s/^host:.*/host: $HOST/" "$CONFIG_FILE"
  echo "✅ Host set to $HOST"
fi

if [ "$AUTH" = "true" ]; then
  USER="${USER:-admin}"
  PASS="${PASS:-$(openssl rand -base64 16)}"
  
  # Enable auth lines (uncomment if commented)
  sed -i 's/^#\s*isBasicAuth:.*/isBasicAuth: true/' "$CONFIG_FILE"
  sed -i "s/^#\s*basicAuthUsername:.*/basicAuthUsername: $USER/" "$CONFIG_FILE"
  sed -i "s/^#\s*basicAuthPassword:.*/basicAuthPassword: $PASS/" "$CONFIG_FILE"
  
  # Also handle already-uncommented lines
  sed -i "s/^isBasicAuth:.*/isBasicAuth: true/" "$CONFIG_FILE"
  sed -i "s/^basicAuthUsername:.*/basicAuthUsername: $USER/" "$CONFIG_FILE"
  sed -i "s/^basicAuthPassword:.*/basicAuthPassword: $PASS/" "$CONFIG_FILE"
  
  # Add if not present
  if ! grep -q "isBasicAuth" "$CONFIG_FILE"; then
    echo "" >> "$CONFIG_FILE"
    echo "isBasicAuth: true" >> "$CONFIG_FILE"
    echo "basicAuthUsername: $USER" >> "$CONFIG_FILE"
    echo "basicAuthPassword: $PASS" >> "$CONFIG_FILE"
  fi
  
  echo "✅ Authentication enabled"
  echo "   Username: $USER"
  echo "   Password: $PASS"
fi

if [ "$AUTH" = "false" ]; then
  sed -i 's/^isBasicAuth:.*/# isBasicAuth: false/' "$CONFIG_FILE"
  echo "✅ Authentication disabled"
fi

if [ -n "$DAGS" ]; then
  mkdir -p "$DAGS"
  sed -i "s|^dagsDir:.*|dagsDir: $DAGS|" "$CONFIG_FILE"
  echo "✅ DAGs directory set to $DAGS"
fi

echo ""
echo "⚠️  Restart Dagu for changes to take effect:"
echo "   bash scripts/manage.sh restart"
