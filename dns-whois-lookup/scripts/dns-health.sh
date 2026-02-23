#!/bin/bash
# DNS Health Check — Diagnose common DNS misconfigurations
set -euo pipefail

DNS_TIMEOUT="${DNS_TIMEOUT:-5}"
DNS_SERVER="${DNS_SERVER:-}"
EMAIL_MODE=false
OUTPUT_JSON=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --email) EMAIL_MODE=true; shift ;;
    --json) OUTPUT_JSON=true; shift ;;
    --server) DNS_SERVER="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: dns-health.sh [--email] [--json] [--server IP] <domain>"
      exit 0
      ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) DOMAIN="$1"; shift ;;
  esac
done

DOMAIN="${DOMAIN:-}"
if [[ -z "$DOMAIN" ]]; then
  echo "Error: No domain specified" >&2
  exit 1
fi

DIG_OPTS="+short +time=$DNS_TIMEOUT +tries=2"
[[ -n "$DNS_SERVER" ]] && DIG_OPTS="$DIG_OPTS @$DNS_SERVER"

query() {
  dig $DIG_OPTS "$@" 2>/dev/null
}

PASSED=0
TOTAL=0
WARNINGS=()
RECOMMENDATIONS=()

check() {
  local label="$1"
  local value="$2"
  local warn_msg="${3:-}"
  local rec_msg="${4:-}"
  
  TOTAL=$((TOTAL + 1))
  if [[ -n "$value" ]]; then
    PASSED=$((PASSED + 1))
    echo "[✅] $label"
  else
    echo "[⚠️] $label"
    [[ -n "$warn_msg" ]] && WARNINGS+=("$warn_msg")
    [[ -n "$rec_msg" ]] && RECOMMENDATIONS+=("$rec_msg")
  fi
}

echo "── DNS Health: $DOMAIN ──"
echo ""

# A record
A_RECORDS=$(query "$DOMAIN" A)
check "A record exists" "$A_RECORDS" \
  "No A record — domain won't resolve" \
  "Add an A record pointing to your server IP"

# AAAA record (IPv6)
AAAA_RECORDS=$(query "$DOMAIN" AAAA)
check "AAAA record exists (IPv6 ready)" "$AAAA_RECORDS" \
  "No AAAA record — no IPv6 support" \
  "Add AAAA record for IPv6 support"

# NS records
NS_RECORDS=$(query "$DOMAIN" NS)
NS_COUNT=$(echo "$NS_RECORDS" | grep -c . 2>/dev/null || echo 0)
NS_OK=""; [[ $NS_COUNT -ge 2 ]] && NS_OK="yes"
check "NS records present ($NS_COUNT nameservers)" "$NS_OK" \
  "Fewer than 2 nameservers — poor redundancy" \
  "Use at least 2 nameservers for redundancy"

# MX records
MX_RECORDS=$(query "$DOMAIN" MX)
check "MX records present (email capable)" "$MX_RECORDS" \
  "No MX records — email delivery will fail" \
  "Add MX records if email is needed for this domain"

# SPF (TXT)
TXT_RECORDS=$(query "$DOMAIN" TXT)
SPF=$(echo "$TXT_RECORDS" | grep -i "v=spf1" || true)
check "SPF record found" "$SPF" \
  "No SPF record — email spoofing risk" \
  "Add TXT record: \"v=spf1 include:_spf.google.com ~all\" (adjust for your mail provider)"

# DMARC
DMARC=$(query "_dmarc.$DOMAIN" TXT)
check "DMARC record found" "$DMARC" \
  "No DMARC record — email authentication incomplete" \
  "Add TXT record for _dmarc.$DOMAIN: \"v=DMARC1; p=reject; rua=mailto:dmarc@$DOMAIN\""

# CAA
CAA_RECORDS=$(query "$DOMAIN" CAA)
check "CAA record exists (certificate control)" "$CAA_RECORDS" \
  "No CAA record — any CA can issue certs for your domain" \
  "Add CAA record: 0 issue \"letsencrypt.org\" (adjust for your CA)"

# SOA
SOA=$(query "$DOMAIN" SOA)
check "SOA record valid" "$SOA" \
  "No SOA record — DNS zone may be misconfigured" \
  "Check DNS zone configuration with your provider"

# TTL check
TTL=$(dig +noall +answer +time="$DNS_TIMEOUT" ${DNS_SERVER:+@$DNS_SERVER} "$DOMAIN" A 2>/dev/null | awk '{print $2}' | head -1)
if [[ -n "$TTL" ]]; then
  TOTAL=$((TOTAL + 1))
  if [[ "$TTL" -ge 300 && "$TTL" -le 86400 ]]; then
    PASSED=$((PASSED + 1))
    echo "[✅] TTL reasonable (${TTL}s)"
  elif [[ "$TTL" -lt 300 ]]; then
    echo "[⚠️] TTL very low (${TTL}s) — high query volume"
    RECOMMENDATIONS+=("Consider increasing TTL to 3600 for stable records")
  else
    echo "[⚠️] TTL very high (${TTL}s) — slow propagation on changes"
    RECOMMENDATIONS+=("Consider lowering TTL to 3600 before making DNS changes")
  fi
fi

# Email-specific checks
if $EMAIL_MODE; then
  echo ""
  echo "── Email Deliverability ──"
  echo ""
  
  # Check common DKIM selectors
  for selector in google default selector1 selector2 dkim k1; do
    DKIM=$(query "${selector}._domainkey.$DOMAIN" TXT 2>/dev/null)
    if [[ -n "$DKIM" ]]; then
      echo "[✅] DKIM found: ${selector}._domainkey.$DOMAIN"
      break
    fi
  done
  [[ -z "${DKIM:-}" ]] && echo "[⚠️] No DKIM records found for common selectors"
  
  # Check DMARC policy strength
  if [[ -n "$DMARC" ]]; then
    if echo "$DMARC" | grep -q "p=reject"; then
      echo "[✅] DMARC policy: reject (strongest)"
    elif echo "$DMARC" | grep -q "p=quarantine"; then
      echo "[ℹ️] DMARC policy: quarantine (good)"
    elif echo "$DMARC" | grep -q "p=none"; then
      echo "[⚠️] DMARC policy: none (monitoring only — not enforcing)"
    fi
  fi
  
  # Check MX connectivity
  if [[ -n "$MX_RECORDS" ]]; then
    MX_HOST=$(echo "$MX_RECORDS" | head -1 | awk '{print $NF}' | sed 's/\.$//')
    MX_IP=$(query "$MX_HOST" A)
    if [[ -n "$MX_IP" ]]; then
      echo "[✅] MX host resolves: $MX_HOST → $MX_IP"
    else
      echo "[⚠️] MX host doesn't resolve: $MX_HOST"
    fi
  fi
fi

echo ""
echo "Score: $PASSED/$TOTAL checks passed"

if [[ ${#RECOMMENDATIONS[@]} -gt 0 ]]; then
  echo ""
  echo "Recommendations:"
  for rec in "${RECOMMENDATIONS[@]}"; do
    echo "  • $rec"
  done
fi
