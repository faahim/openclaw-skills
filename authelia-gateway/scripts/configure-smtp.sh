#!/bin/bash
set -euo pipefail

# Configure SMTP for Authelia notifications

CONFIG="authelia-data/configuration.yml"
SMTP_HOST=""
SMTP_PORT="587"
SMTP_USERNAME=""
SMTP_FROM=""

usage() {
  cat <<EOF
Usage: bash scripts/configure-smtp.sh --host <host> --username <user> --from <sender>

Options:
  --host <host>       SMTP server hostname
  --port <port>       SMTP port (default: 587)
  --username <user>   SMTP username
  --from <sender>     Sender address (e.g., "Authelia <auth@example.com>")
  --config <path>     Config file path (default: authelia-data/configuration.yml)
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --host) SMTP_HOST="$2"; shift 2 ;;
    --port) SMTP_PORT="$2"; shift 2 ;;
    --username) SMTP_USERNAME="$2"; shift 2 ;;
    --from) SMTP_FROM="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    *) echo "Unknown: $1"; usage ;;
  esac
done

if [[ -z "$SMTP_HOST" || -z "$SMTP_USERNAME" || -z "$SMTP_FROM" ]]; then
  echo "Error: --host, --username, and --from are required"
  usage
fi

echo -n "Enter SMTP password/app password: "
read -s SMTP_PASSWORD
echo

# Save password to secrets
echo "$SMTP_PASSWORD" > authelia-data/secrets/smtp_password

# Update config: comment out filesystem notifier, add SMTP
# This is a simplified approach — for production, edit the YAML properly
echo ""
echo "📧 SMTP Configuration:"
echo "   Host: $SMTP_HOST:$SMTP_PORT"
echo "   Username: $SMTP_USERNAME"
echo "   From: $SMTP_FROM"
echo ""
echo "Add this to your configuration.yml under 'notifier:':"
echo ""
cat <<YAML
notifier:
  smtp:
    host: $SMTP_HOST
    port: $SMTP_PORT
    username: $SMTP_USERNAME
    sender: "$SMTP_FROM"
    password: $SMTP_PASSWORD
    disable_require_tls: false
    disable_starttls: false
YAML
echo ""
echo "⚠️  Remove or comment out the 'filesystem:' section under notifier."
echo "Then restart: cd authelia-data && docker compose restart authelia"
