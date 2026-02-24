#!/bin/bash
# Check SSL certificate status for all Traefik-managed domains

set -euo pipefail

TRAEFIK_DIR="/opt/traefik"
ACME_FILE="${TRAEFIK_DIR}/acme/acme.json"
WARN_DAYS=30

while [[ $# -gt 0 ]]; do
  case $1 in
    --dir) TRAEFIK_DIR="$2"; ACME_FILE="${TRAEFIK_DIR}/acme/acme.json"; shift 2 ;;
    --warn-days) WARN_DAYS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

echo "=== SSL Certificate Status ==="
echo ""

if [[ ! -f "$ACME_FILE" ]]; then
  echo "❌ ACME file not found: $ACME_FILE"
  exit 1
fi

DOMAINS=$(jq -r '.letsencrypt.Certificates[]? | .domain.main' "$ACME_FILE" 2>/dev/null)

if [[ -z "$DOMAINS" ]]; then
  echo "No certificates found."
  exit 0
fi

NOW=$(date +%s)
ISSUES=0

while IFS= read -r domain; do
  # Check cert via openssl
  EXPIRY=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  
  if [[ -n "$EXPIRY" ]]; then
    EXPIRY_TS=$(date -d "$EXPIRY" +%s 2>/dev/null || date -jf "%b %d %T %Y %Z" "$EXPIRY" +%s 2>/dev/null || echo 0)
    DAYS_LEFT=$(( (EXPIRY_TS - NOW) / 86400 ))
    
    if [[ $DAYS_LEFT -lt 0 ]]; then
      echo "❌ ${domain} — EXPIRED (${DAYS_LEFT} days ago)"
      ISSUES=$((ISSUES + 1))
    elif [[ $DAYS_LEFT -lt $WARN_DAYS ]]; then
      echo "⚠️  ${domain} — expires in ${DAYS_LEFT} days (${EXPIRY})"
      ISSUES=$((ISSUES + 1))
    else
      echo "✅ ${domain} — valid for ${DAYS_LEFT} days (${EXPIRY})"
    fi
  else
    echo "⚠️  ${domain} — could not check (DNS or connectivity issue)"
    ISSUES=$((ISSUES + 1))
  fi
done <<< "$DOMAINS"

echo ""
if [[ $ISSUES -eq 0 ]]; then
  echo "All certificates healthy ✅"
else
  echo "⚠️  ${ISSUES} certificate(s) need attention"
fi
