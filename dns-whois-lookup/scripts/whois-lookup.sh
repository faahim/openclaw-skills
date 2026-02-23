#!/bin/bash
# WHOIS Lookup — Extract key registration data for a domain
set -euo pipefail

WHOIS_SERVER="${WHOIS_SERVER:-}"
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --json) OUTPUT_JSON=true; shift ;;
    --server) WHOIS_SERVER="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: whois-lookup.sh [--json] [--server HOST] <domain>"
      exit 0
      ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) DOMAIN="$1"; shift ;;
  esac
done

if [[ -z "${DOMAIN:-}" ]]; then
  echo "Error: No domain specified" >&2
  exit 1
fi

# Run whois
if [[ -n "$WHOIS_SERVER" ]]; then
  RAW=$(whois -h "$WHOIS_SERVER" "$DOMAIN" 2>/dev/null)
else
  RAW=$(whois "$DOMAIN" 2>/dev/null)
fi

if [[ -z "$RAW" ]]; then
  echo "Error: WHOIS query failed for $DOMAIN" >&2
  exit 1
fi

# Extract fields (handles various WHOIS formats)
extract() {
  local pattern="$1"
  echo "$RAW" | grep -iE "$pattern" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

REGISTRAR=$(extract "^(Registrar|registrar):")
CREATED=$(extract "^(Creation Date|Created|created|Registration Date):")
EXPIRES=$(extract "^(Registry Expiry Date|Expiration Date|Expiry Date|expires|paid-till):")
UPDATED=$(extract "^(Updated Date|Last Updated|updated|last-modified):")
STATUS=$(extract "^(Domain Status|Status|status):" | head -1)
NAMESERVERS=$(echo "$RAW" | grep -iE "^(Name Server|nserver|nameserver):" | sed 's/^[^:]*:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' | sort -u | tr '\n' ', ' | sed 's/,$//')
REGISTRANT=$(extract "^(Registrant Organization|Registrant Name|org|registrant):")
DNSSEC=$(extract "^(DNSSEC|dnssec):")

if $OUTPUT_JSON; then
  cat <<EOF | jq .
{
  "domain": "$DOMAIN",
  "registrar": "${REGISTRAR:-unknown}",
  "created": "${CREATED:-unknown}",
  "expires": "${EXPIRES:-unknown}",
  "updated": "${UPDATED:-unknown}",
  "status": "${STATUS:-unknown}",
  "nameservers": "${NAMESERVERS:-unknown}",
  "registrant": "${REGISTRANT:-redacted}",
  "dnssec": "${DNSSEC:-unknown}"
}
EOF
else
  echo "── WHOIS: $DOMAIN ──"
  echo ""
  printf "%-14s %s\n" "Registrar:" "${REGISTRAR:-unknown}"
  printf "%-14s %s\n" "Created:" "${CREATED:-unknown}"
  printf "%-14s %s\n" "Expires:" "${EXPIRES:-unknown}"
  printf "%-14s %s\n" "Updated:" "${UPDATED:-unknown}"
  printf "%-14s %s\n" "Status:" "${STATUS:-unknown}"
  printf "%-14s %s\n" "Nameservers:" "${NAMESERVERS:-unknown}"
  printf "%-14s %s\n" "Registrant:" "${REGISTRANT:-redacted}"
  printf "%-14s %s\n" "DNSSEC:" "${DNSSEC:-unknown}"

  # Expiry warning
  if [[ -n "$EXPIRES" && "$EXPIRES" != "unknown" ]]; then
    EXPIRY_EPOCH=$(date -d "$EXPIRES" +%s 2>/dev/null || echo "")
    if [[ -n "$EXPIRY_EPOCH" ]]; then
      NOW_EPOCH=$(date +%s)
      DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
      echo ""
      if [[ $DAYS_LEFT -lt 0 ]]; then
        echo "🚨 EXPIRED $((DAYS_LEFT * -1)) days ago!"
      elif [[ $DAYS_LEFT -lt 30 ]]; then
        echo "⚠️ Expires in $DAYS_LEFT days — RENEW SOON"
      elif [[ $DAYS_LEFT -lt 90 ]]; then
        echo "ℹ️ Expires in $DAYS_LEFT days"
      else
        echo "✅ Expires in $DAYS_LEFT days"
      fi
    fi
  fi
fi
