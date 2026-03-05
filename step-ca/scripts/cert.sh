#!/bin/bash
# Issue, renew, inspect, and revoke certificates
set -euo pipefail

STEPPATH="${STEPPATH:-$HOME/.step}"
CERT_DIR="${STEPPATH}/certs/issued"
CLIENT_DIR="${STEPPATH}/certs/clients"

mkdir -p "$CERT_DIR" "$CLIENT_DIR"

ACTION="${1:-help}"
shift || true

cmd_issue() {
  local domain="${1:?Usage: cert.sh issue <domain> [--san <san>] [--not-after <duration>] [--kty <type>] [--size <bits>]}"
  shift || true

  local extra_args=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --san) extra_args+=(--san "$2"); shift 2 ;;
      --not-after) extra_args+=(--not-after "$2"); shift 2 ;;
      --kty) extra_args+=(--kty "$2"); shift 2 ;;
      --size) extra_args+=(--size "$2"); shift 2 ;;
      *) shift ;;
    esac
  done

  local cert_file="$CERT_DIR/${domain}.crt"
  local key_file="$CERT_DIR/${domain}.key"

  echo "🔐 Issuing certificate for $domain..."

  step ca certificate "$domain" "$cert_file" "$key_file" "${extra_args[@]}" 2>&1

  if [ -f "$cert_file" ]; then
    local expiry=$(step certificate inspect "$cert_file" --format json 2>/dev/null | jq -r '.validity.end' 2>/dev/null || echo "unknown")
    echo ""
    echo "✅ Certificate issued:"
    echo "   cert:    $cert_file"
    echo "   key:     $key_file"
    echo "   expires: $expiry"
  else
    echo "❌ Failed to issue certificate"
    exit 1
  fi
}

cmd_issue_client() {
  local name="${1:?Usage: cert.sh issue-client <name>}"

  local cert_file="$CLIENT_DIR/${name}.crt"
  local key_file="$CLIENT_DIR/${name}.key"

  echo "🔐 Issuing client certificate for $name..."

  step ca certificate "$name" "$cert_file" "$key_file" 2>&1

  if [ -f "$cert_file" ]; then
    echo ""
    echo "✅ Client certificate issued:"
    echo "   cert: $cert_file"
    echo "   key:  $key_file"
  fi
}

cmd_renew() {
  local domain="${1:?Usage: cert.sh renew <domain>}"

  local cert_file="$CERT_DIR/${domain}.crt"
  local key_file="$CERT_DIR/${domain}.key"

  if [ ! -f "$cert_file" ]; then
    echo "❌ No certificate found for $domain at $cert_file"
    exit 1
  fi

  echo "🔄 Renewing certificate for $domain..."
  step ca renew "$cert_file" "$key_file" --force 2>&1

  # Set up cron for auto-renewal
  local cron_cmd="*/12 * * * * step ca renew --force $cert_file $key_file >> $STEPPATH/renew.log 2>&1"
  
  # Check if cron entry already exists
  if crontab -l 2>/dev/null | grep -qF "$cert_file"; then
    echo "✅ Renewed (cron already configured)"
  else
    (crontab -l 2>/dev/null; echo "$cron_cmd") | crontab -
    echo "✅ Renewed + cron job added (every 12 hours)"
  fi
}

cmd_inspect() {
  local cert_file="${1:?Usage: cert.sh inspect <cert-file>}"

  if [ ! -f "$cert_file" ]; then
    echo "❌ File not found: $cert_file"
    exit 1
  fi

  step certificate inspect "$cert_file" --short 2>&1
}

cmd_verify() {
  local cert_file="${1:?Usage: cert.sh verify <cert-file>}"

  if [ ! -f "$cert_file" ]; then
    echo "❌ File not found: $cert_file"
    exit 1
  fi

  local root_cert="$STEPPATH/certs/root_ca.crt"
  if step certificate verify "$cert_file" --roots "$root_cert" 2>&1; then
    echo "✅ Valid — signed by this CA"
  else
    echo "❌ Invalid or expired"
    exit 1
  fi
}

cmd_revoke() {
  local cert_file="${1:?Usage: cert.sh revoke <cert-file>}"

  if [ ! -f "$cert_file" ]; then
    echo "❌ File not found: $cert_file"
    exit 1
  fi

  echo "⚠️  Revoking certificate: $cert_file"
  step ca revoke --cert "$cert_file" --key "${cert_file%.crt}.key" 2>&1
  echo "✅ Certificate revoked"
}

cmd_list() {
  echo "📋 Issued certificates:"
  echo ""
  for cert in "$CERT_DIR"/*.crt; do
    [ -f "$cert" ] || continue
    local name=$(basename "$cert" .crt)
    local expiry=$(step certificate inspect "$cert" --format json 2>/dev/null | jq -r '.validity.end' 2>/dev/null || echo "unknown")
    local remaining=""
    
    if step certificate verify "$cert" --roots "$STEPPATH/certs/root_ca.crt" >/dev/null 2>&1; then
      remaining="✅"
    else
      remaining="❌ EXPIRED"
    fi
    
    printf "  %s %-30s expires: %s\n" "$remaining" "$name" "$expiry"
  done

  if ls "$CLIENT_DIR"/*.crt >/dev/null 2>&1; then
    echo ""
    echo "📋 Client certificates:"
    for cert in "$CLIENT_DIR"/*.crt; do
      local name=$(basename "$cert" .crt)
      local expiry=$(step certificate inspect "$cert" --format json 2>/dev/null | jq -r '.validity.end' 2>/dev/null || echo "unknown")
      printf "  %-30s expires: %s\n" "$name" "$expiry"
    done
  fi
}

case "$ACTION" in
  issue)        cmd_issue "$@" ;;
  issue-client) cmd_issue_client "$@" ;;
  renew)        cmd_renew "$@" ;;
  inspect)      cmd_inspect "$@" ;;
  verify)       cmd_verify "$@" ;;
  revoke)       cmd_revoke "$@" ;;
  list)         cmd_list ;;
  *)
    echo "Usage: bash scripts/cert.sh {issue|issue-client|renew|inspect|verify|revoke|list}"
    echo ""
    echo "  issue <domain> [--san <san>] [--not-after <dur>]  Issue a server certificate"
    echo "  issue-client <name>                                Issue a client certificate (mTLS)"
    echo "  renew <domain>                                     Renew + set up auto-renewal cron"
    echo "  inspect <cert-file>                                Show certificate details"
    echo "  verify <cert-file>                                 Verify cert against CA root"
    echo "  revoke <cert-file>                                 Revoke a certificate"
    echo "  list                                               List all issued certificates"
    exit 1
    ;;
esac
