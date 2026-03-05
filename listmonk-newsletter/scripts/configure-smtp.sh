#!/bin/bash
set -euo pipefail

# Configure SMTP for Listmonk via API

INSTALL_DIR="${LISTMONK_DIR:-$HOME/listmonk}"
source "$INSTALL_DIR/.env" 2>/dev/null || true

PORT="${LISTMONK_PORT:-9000}"
ADMIN_USER="${LISTMONK_ADMIN_USER:-admin}"
ADMIN_PASS="${LISTMONK_ADMIN_PASSWORD:-admin}"
BASE_URL="http://localhost:${PORT}"

# Parse args
SMTP_HOST="" SMTP_PORT="587" SMTP_USER="" SMTP_PASSWORD="" SMTP_FROM="" SMTP_TLS="starttls"

while [[ $# -gt 0 ]]; do
    case $1 in
        --host) SMTP_HOST="$2"; shift 2 ;;
        --port) SMTP_PORT="$2"; shift 2 ;;
        --user) SMTP_USER="$2"; shift 2 ;;
        --password) SMTP_PASSWORD="$2"; shift 2 ;;
        --from) SMTP_FROM="$2"; shift 2 ;;
        --tls) SMTP_TLS="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ -z "$SMTP_HOST" ] || [ -z "$SMTP_USER" ] || [ -z "$SMTP_PASSWORD" ]; then
    echo "Usage: bash configure-smtp.sh --host <smtp-host> --port 587 --user <email> --password <pass> [--from <from-addr>] [--tls starttls|tls|none]"
    exit 1
fi

[ -z "$SMTP_FROM" ] && SMTP_FROM="$SMTP_USER"

echo "📧 Configuring SMTP for Listmonk..."
echo "   Host: $SMTP_HOST:$SMTP_PORT"
echo "   User: $SMTP_USER"
echo "   From: $SMTP_FROM"
echo "   TLS:  $SMTP_TLS"

# Get current settings
SETTINGS=$(curl -sf -u "${ADMIN_USER}:${ADMIN_PASS}" "${BASE_URL}/api/settings" | jq '.data')

if [ -z "$SETTINGS" ] || [ "$SETTINGS" = "null" ]; then
    echo "❌ Could not fetch Listmonk settings. Is the server running?"
    exit 1
fi

# Update SMTP settings
UPDATED=$(echo "$SETTINGS" | jq --arg host "$SMTP_HOST" --argjson port "$SMTP_PORT" \
    --arg user "$SMTP_USER" --arg pass "$SMTP_PASSWORD" --arg from "$SMTP_FROM" \
    --arg tls "$SMTP_TLS" '
    .smtp[0].host = $host |
    .smtp[0].port = $port |
    .smtp[0].auth_protocol = "login" |
    .smtp[0].username = $user |
    .smtp[0].password = $pass |
    .smtp[0].email_headers = [] |
    .smtp[0].tls_type = $tls |
    .smtp[0].tls_skip_verify = false |
    .smtp[0].enabled = true |
    .["app.from_email"] = $from
')

RESULT=$(curl -sf -u "${ADMIN_USER}:${ADMIN_PASS}" -X PUT "${BASE_URL}/api/settings" \
    -H "Content-Type: application/json" \
    -d "$UPDATED")

if echo "$RESULT" | jq -e '.data' &>/dev/null; then
    echo "✅ SMTP configured successfully!"
    echo ""
    echo "Test it: Go to ${BASE_URL} → Campaigns → Create → Send test email"
else
    echo "❌ Failed to update SMTP settings"
    echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
    exit 1
fi
