#!/bin/bash
# ACME.sh SSL Manager — Deploy Certificate

set -euo pipefail

ACME="$HOME/.acme.sh/acme.sh"
[[ -f "$ACME" ]] || { echo "❌ acme.sh not installed."; exit 1; }

DOMAIN=""
SERVER=""
CERT_PATH=""
KEY_PATH=""
FULLCHAIN_PATH=""
RELOAD_CMD=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --domain|-d) DOMAIN="$2"; shift 2 ;;
    --server) SERVER="$2"; shift 2 ;;
    --cert-path) CERT_PATH="$2"; shift 2 ;;
    --key-path) KEY_PATH="$2"; shift 2 ;;
    --fullchain-path) FULLCHAIN_PATH="$2"; shift 2 ;;
    --reload) RELOAD_CMD="$2"; shift 2 ;;
    --help) echo "Usage: bash deploy.sh --domain example.com [--server nginx|apache] [--cert-path /path] [--key-path /path] [--reload 'cmd']"; exit 0 ;;
    *) shift ;;
  esac
done

[[ -z "$DOMAIN" ]] && { echo "❌ --domain is required"; exit 1; }

# Preset server configs
case "${SERVER:-custom}" in
  nginx)
    CERT_PATH="${CERT_PATH:-/etc/nginx/ssl/${DOMAIN}.pem}"
    KEY_PATH="${KEY_PATH:-/etc/nginx/ssl/${DOMAIN}.key}"
    FULLCHAIN_PATH="${FULLCHAIN_PATH:-/etc/nginx/ssl/${DOMAIN}-fullchain.pem}"
    RELOAD_CMD="${RELOAD_CMD:-systemctl reload nginx}"
    mkdir -p /etc/nginx/ssl
    ;;
  apache)
    CERT_PATH="${CERT_PATH:-/etc/apache2/ssl/${DOMAIN}.pem}"
    KEY_PATH="${KEY_PATH:-/etc/apache2/ssl/${DOMAIN}.key}"
    FULLCHAIN_PATH="${FULLCHAIN_PATH:-/etc/apache2/ssl/${DOMAIN}-fullchain.pem}"
    RELOAD_CMD="${RELOAD_CMD:-systemctl reload apache2}"
    mkdir -p /etc/apache2/ssl
    ;;
  caddy)
    echo "ℹ️  Caddy handles SSL automatically. No deployment needed."
    exit 0
    ;;
  custom)
    [[ -z "$CERT_PATH" ]] && { echo "❌ --cert-path required for custom deploy"; exit 1; }
    [[ -z "$KEY_PATH" ]] && { echo "❌ --key-path required for custom deploy"; exit 1; }
    ;;
esac

echo "🚀 Deploying certificate for $DOMAIN..."

CMD=("$ACME" --install-cert -d "$DOMAIN")
CMD+=(--cert-file "$CERT_PATH")
CMD+=(--key-file "$KEY_PATH")
[[ -n "$FULLCHAIN_PATH" ]] && CMD+=(--fullchain-file "$FULLCHAIN_PATH")
[[ -n "$RELOAD_CMD" ]] && CMD+=(--reloadcmd "$RELOAD_CMD")

if "${CMD[@]}"; then
  echo ""
  echo "✅ Certificate deployed!"
  echo "   Cert:      $CERT_PATH"
  echo "   Key:       $KEY_PATH"
  [[ -n "$FULLCHAIN_PATH" ]] && echo "   Fullchain: $FULLCHAIN_PATH"
  [[ -n "$RELOAD_CMD" ]] && echo "   Reload:    $RELOAD_CMD"
  echo ""
  echo "   Auto-deploy on renewal is configured."
else
  echo "❌ Deployment failed."
  exit 1
fi
