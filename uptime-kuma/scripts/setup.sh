#!/bin/bash
# Uptime Kuma initial setup — create admin account
set -euo pipefail

KUMA_URL="${KUMA_URL:-http://localhost:3001}"
USERNAME=""
PASSWORD=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --username) USERNAME="$2"; shift 2 ;;
    --password) PASSWORD="$2"; shift 2 ;;
    --url) KUMA_URL="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Usage: $0 --username <user> --password <pass> [--url <kuma-url>]"
  exit 1
fi

echo "⏳ Waiting for Uptime Kuma to be ready..."
for i in $(seq 1 30); do
  if curl -s -o /dev/null -w "%{http_code}" "${KUMA_URL}/api/info" | grep -q "200"; then
    break
  fi
  sleep 2
done

# Check if setup is needed
NEED_SETUP=$(curl -s "${KUMA_URL}/api/info" | jq -r '.needSetup // false')

if [ "$NEED_SETUP" = "true" ]; then
  echo "🔧 Creating admin account..."
  RESULT=$(curl -s "${KUMA_URL}/api/setup" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}")
  
  if echo "$RESULT" | jq -e '.token' &>/dev/null; then
    echo "✅ Admin account created!"
    echo ""
    echo "Save these credentials:"
    echo "  export KUMA_URL=\"${KUMA_URL}\""
    echo "  export KUMA_USERNAME=\"${USERNAME}\""
    echo "  export KUMA_PASSWORD=\"${PASSWORD}\""
  else
    echo "❌ Setup failed: $(echo "$RESULT" | jq -r '.msg // "Unknown error"')"
    exit 1
  fi
else
  echo "ℹ️  Setup already completed. Admin account already exists."
  echo "   Use existing credentials to log in."
fi
