#!/bin/bash
# Domain Health Checker — Full domain diagnostics in one command
# Checks: DNS, SSL, HTTP, WHOIS, Email Auth (SPF/DKIM/DMARC)

set -euo pipefail

VERSION="1.0.0"
DKIM_SELECTOR="${DKIM_SELECTOR:-default}"
HTTP_TIMEOUT="${HTTP_TIMEOUT:-10}"
EXPIRY_ALERT_DAYS=0
JSON_MODE=false
SSL_ONLY=false
EMAIL_ONLY=false
SKIP_WHOIS=false
DOMAINS=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✅${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠️${NC}  $1"; }
fail() { echo -e "  ${RED}❌${NC} $1"; }
header() { echo -e "\n${CYAN}── $1 ──${NC}"; }

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --json) JSON_MODE=true; shift ;;
    --ssl-only) SSL_ONLY=true; shift ;;
    --email-only) EMAIL_ONLY=true; shift ;;
    --skip-whois) SKIP_WHOIS=true; shift ;;
    --dkim-selector) DKIM_SELECTOR="$2"; shift 2 ;;
    --expiry-alert) EXPIRY_ALERT_DAYS="$2"; shift 2 ;;
    --timeout) HTTP_TIMEOUT="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [options] domain [domain2 ...]"
      echo ""
      echo "Options:"
      echo "  --json              Output as JSON"
      echo "  --ssl-only          Check SSL certificate only"
      echo "  --email-only        Check email auth (SPF/DKIM/DMARC) only"
      echo "  --skip-whois        Skip WHOIS lookup"
      echo "  --dkim-selector S   DKIM selector (default: 'default')"
      echo "  --expiry-alert N    Alert if SSL/WHOIS expires within N days"
      echo "  --timeout N         HTTP timeout in seconds (default: 10)"
      exit 0
      ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *) DOMAINS+=("$1"); shift ;;
  esac
done

if [[ ${#DOMAINS[@]} -eq 0 ]]; then
  echo "Usage: $0 [options] domain [domain2 ...]"
  exit 1
fi

# JSON accumulator
JSON_RESULTS=()

check_dns() {
  local domain=$1
  local score=0 total=0 results=""

  header "DNS"

  # A record
  total=$((total + 1))
  local a_records
  a_records=$(dig +short A "$domain" 2>/dev/null | head -5)
  if [[ -n "$a_records" ]]; then
    pass "A Record:       $(echo "$a_records" | tr '\n' ', ' | sed 's/,$//')"
    score=$((score + 1))
  else
    fail "A Record:       Not found"
  fi

  # AAAA record
  total=$((total + 1))
  local aaaa_records
  aaaa_records=$(dig +short AAAA "$domain" 2>/dev/null | head -3)
  if [[ -n "$aaaa_records" ]]; then
    pass "AAAA Record:    $(echo "$aaaa_records" | tr '\n' ', ' | sed 's/,$//')"
    score=$((score + 1))
  else
    warn "AAAA Record:    Not set (IPv6 recommended)"
  fi

  # NS records
  total=$((total + 1))
  local ns_records
  ns_records=$(dig +short NS "$domain" 2>/dev/null | head -5)
  if [[ -n "$ns_records" ]]; then
    pass "NS Records:     $(echo "$ns_records" | tr '\n' ', ' | sed 's/,$//')"
    score=$((score + 1))
  else
    fail "NS Records:     Not found"
  fi

  # MX records
  total=$((total + 1))
  local mx_records
  mx_records=$(dig +short MX "$domain" 2>/dev/null | head -5)
  if [[ -n "$mx_records" ]]; then
    pass "MX Records:     $(echo "$mx_records" | tr '\n' ', ' | sed 's/,$//')"
    score=$((score + 1))
  else
    warn "MX Records:     Not set"
  fi

  # CAA record
  total=$((total + 1))
  local caa_records
  caa_records=$(dig +short CAA "$domain" 2>/dev/null)
  if [[ -n "$caa_records" ]]; then
    pass "CAA Record:     $(echo "$caa_records" | head -1)"
    score=$((score + 1))
  else
    warn "CAA Record:     Not set (recommended for SSL control)"
  fi

  echo "$score/$total"
}

check_ssl() {
  local domain=$1
  local score=0 total=0

  header "SSL"

  # Get certificate
  local cert_info
  cert_info=$(echo | timeout 10 openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null)

  if [[ -z "$cert_info" ]] || echo "$cert_info" | grep -q "connect:errno"; then
    fail "Certificate:    Could not connect to $domain:443"
    echo "0/1"
    return
  fi

  # Validity
  total=$((total + 1))
  local verify
  verify=$(echo "$cert_info" | grep "Verify return code" | head -1)
  if echo "$verify" | grep -q "0 (ok)"; then
    pass "Certificate:    Valid"
    score=$((score + 1))
  else
    local reason
    reason=$(echo "$verify" | sed 's/.*Verify return code: [0-9]* (\(.*\))/\1/')
    fail "Certificate:    Invalid — $reason"
  fi

  # Issuer
  total=$((total + 1))
  local issuer
  issuer=$(echo "$cert_info" | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=//;s/.*O = //;s/,.*//')
  if [[ -n "$issuer" ]]; then
    pass "Issuer:         $issuer"
    score=$((score + 1))
  else
    warn "Issuer:         Unknown"
  fi

  # Expiry
  total=$((total + 1))
  local expiry_date
  expiry_date=$(echo "$cert_info" | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//')
  if [[ -n "$expiry_date" ]]; then
    local expiry_epoch
    expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null || echo 0)
    local now_epoch
    now_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

    if [[ $days_left -lt 0 ]]; then
      fail "Expires:        EXPIRED ($(date -d "$expiry_date" '+%Y-%m-%d' 2>/dev/null || echo "$expiry_date"))"
    elif [[ $days_left -lt 14 ]]; then
      fail "Expires:        $(date -d "$expiry_date" '+%Y-%m-%d' 2>/dev/null || echo "$expiry_date") (${days_left} days remaining — CRITICAL)"
    elif [[ $days_left -lt 30 ]]; then
      warn "Expires:        $(date -d "$expiry_date" '+%Y-%m-%d' 2>/dev/null || echo "$expiry_date") (${days_left} days remaining)"
    else
      pass "Expires:        $(date -d "$expiry_date" '+%Y-%m-%d' 2>/dev/null || echo "$expiry_date") (${days_left} days remaining)"
      score=$((score + 1))
    fi

    # Expiry alert mode
    if [[ $EXPIRY_ALERT_DAYS -gt 0 && $days_left -le $EXPIRY_ALERT_DAYS ]]; then
      echo ""
      fail "🚨 SSL EXPIRY ALERT: $domain expires in $days_left days!"
    fi
  fi

  # SANs
  total=$((total + 1))
  local sans
  sans=$(echo "$cert_info" | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -oP 'DNS:[^,]+' | sed 's/DNS://g' | tr '\n' ', ' | sed 's/,$//')
  if [[ -n "$sans" ]]; then
    pass "SANs:           $sans"
    score=$((score + 1))
  else
    warn "SANs:           None found"
  fi

  # HSTS
  total=$((total + 1))
  local hsts
  hsts=$(curl -sI --max-time "$HTTP_TIMEOUT" "https://$domain" 2>/dev/null | grep -i "strict-transport-security" | head -1)
  if [[ -n "$hsts" ]]; then
    pass "HSTS:           Enabled"
    score=$((score + 1))
  else
    warn "HSTS:           Not enabled"
  fi

  echo "$score/$total"
}

check_http() {
  local domain=$1
  local score=0 total=0

  header "HTTP"

  # HTTP status
  total=$((total + 1))
  local start_ms
  start_ms=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  local http_code
  http_code=$(curl -sI -o /dev/null -w "%{http_code}" --max-time "$HTTP_TIMEOUT" "https://$domain" 2>/dev/null || echo "000")
  local end_ms
  end_ms=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  local elapsed=$((end_ms - start_ms))

  if [[ "$http_code" =~ ^2 ]]; then
    pass "Status:         $http_code OK"
    score=$((score + 1))
  elif [[ "$http_code" =~ ^3 ]]; then
    pass "Status:         $http_code Redirect"
    score=$((score + 1))
  elif [[ "$http_code" == "000" ]]; then
    fail "Status:         Connection failed"
  else
    fail "Status:         $http_code"
  fi

  # Response time
  total=$((total + 1))
  if [[ $elapsed -lt 1000 ]]; then
    pass "Response Time:  ${elapsed}ms"
    score=$((score + 1))
  elif [[ $elapsed -lt 3000 ]]; then
    warn "Response Time:  ${elapsed}ms (slow)"
  else
    fail "Response Time:  ${elapsed}ms (very slow)"
  fi

  # HTTP → HTTPS redirect
  total=$((total + 1))
  local http_redirect
  http_redirect=$(curl -sI -o /dev/null -w "%{http_code}" --max-time "$HTTP_TIMEOUT" "http://$domain" 2>/dev/null || echo "000")
  if [[ "$http_redirect" =~ ^3 ]]; then
    local redirect_loc
    redirect_loc=$(curl -sI --max-time "$HTTP_TIMEOUT" "http://$domain" 2>/dev/null | grep -i "^location:" | head -1 | tr -d '\r')
    if echo "$redirect_loc" | grep -qi "https://"; then
      pass "HTTP→HTTPS:     Redirects (${http_redirect})"
      score=$((score + 1))
    else
      warn "HTTP→HTTPS:     Redirects but not to HTTPS"
    fi
  elif [[ "$http_redirect" =~ ^2 ]]; then
    warn "HTTP→HTTPS:     No redirect (HTTP serves content directly)"
  else
    warn "HTTP→HTTPS:     HTTP not responding"
  fi

  # www redirect
  total=$((total + 1))
  local www_code
  www_code=$(curl -sI -o /dev/null -w "%{http_code}" --max-time "$HTTP_TIMEOUT" "https://www.$domain" 2>/dev/null || echo "000")
  if [[ "$www_code" =~ ^[23] ]]; then
    pass "www Check:      www.$domain responds ($www_code)"
    score=$((score + 1))
  else
    warn "www Check:      www.$domain not responding"
  fi

  echo "$score/$total"
}

check_whois() {
  local domain=$1
  local score=0 total=0

  header "WHOIS"

  local whois_data
  whois_data=$(timeout 15 whois "$domain" 2>/dev/null || echo "")

  if [[ -z "$whois_data" ]]; then
    fail "WHOIS:          Lookup failed or timed out"
    echo "0/1"
    return
  fi

  # Registrar
  total=$((total + 1))
  local registrar
  registrar=$(echo "$whois_data" | grep -i "Registrar:" | head -1 | sed 's/.*Registrar:[[:space:]]*//')
  if [[ -n "$registrar" ]]; then
    pass "Registrar:      $registrar"
    score=$((score + 1))
  else
    warn "Registrar:      Not found in WHOIS"
  fi

  # Expiry
  total=$((total + 1))
  local expiry
  expiry=$(echo "$whois_data" | grep -iE "(Expir|Expiration|Registry Expiry)" | head -1 | grep -oP '\d{4}-\d{2}-\d{2}' | head -1)
  if [[ -n "$expiry" ]]; then
    local expiry_epoch
    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
    local now_epoch
    now_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

    if [[ $days_left -lt 30 ]]; then
      fail "Expires:        $expiry (${days_left} days — RENEW NOW)"
    elif [[ $days_left -lt 90 ]]; then
      warn "Expires:        $expiry (${days_left} days remaining)"
    else
      pass "Expires:        $expiry (${days_left} days remaining)"
      score=$((score + 1))
    fi

    if [[ $EXPIRY_ALERT_DAYS -gt 0 && $days_left -le $EXPIRY_ALERT_DAYS ]]; then
      echo ""
      fail "🚨 DOMAIN EXPIRY ALERT: $domain expires in $days_left days!"
    fi
  else
    warn "Expires:        Could not parse expiry date"
  fi

  # DNSSEC
  total=$((total + 1))
  local dnssec
  dnssec=$(echo "$whois_data" | grep -i "DNSSEC:" | head -1)
  if echo "$dnssec" | grep -qi "signed"; then
    pass "DNSSEC:         Signed"
    score=$((score + 1))
  else
    warn "DNSSEC:         Unsigned"
  fi

  echo "$score/$total"
}

check_email() {
  local domain=$1
  local score=0 total=0

  header "EMAIL AUTH"

  # SPF
  total=$((total + 1))
  local spf
  spf=$(dig +short TXT "$domain" 2>/dev/null | grep "v=spf1" | head -1 | tr -d '"')
  if [[ -n "$spf" ]]; then
    pass "SPF:            $spf"
    score=$((score + 1))
  else
    fail "SPF:            Not found"
  fi

  # DKIM
  total=$((total + 1))
  local dkim
  dkim=$(dig +short TXT "${DKIM_SELECTOR}._domainkey.$domain" 2>/dev/null | head -1 | tr -d '"')
  if [[ -n "$dkim" ]]; then
    pass "DKIM:           Found (selector: $DKIM_SELECTOR)"
    score=$((score + 1))
  else
    # Try common selectors
    local found=false
    for sel in google selector1 selector2 k1 default mail; do
      local try
      try=$(dig +short TXT "${sel}._domainkey.$domain" 2>/dev/null | head -1)
      if [[ -n "$try" ]]; then
        pass "DKIM:           Found (selector: $sel)"
        score=$((score + 1))
        found=true
        break
      fi
    done
    if [[ "$found" == "false" ]]; then
      warn "DKIM:           Not found (tried: default, google, selector1, selector2, k1, mail)"
    fi
  fi

  # DMARC
  total=$((total + 1))
  local dmarc
  dmarc=$(dig +short TXT "_dmarc.$domain" 2>/dev/null | head -1 | tr -d '"')
  if [[ -n "$dmarc" ]]; then
    if echo "$dmarc" | grep -q "p=reject\|p=quarantine"; then
      pass "DMARC:          $dmarc"
      score=$((score + 1))
    else
      warn "DMARC:          $dmarc (consider p=quarantine or p=reject)"
    fi
  else
    fail "DMARC:          Not found"
  fi

  echo "$score/$total"
}

check_domain() {
  local domain=$1
  local total_score=0 total_checks=0
  local passed=0 warnings=0 failures=0

  if [[ "$JSON_MODE" == "false" ]]; then
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
    printf "${BOLD}║%*s${NC}\n" -54 "          DOMAIN HEALTH CHECK: $domain"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
  fi

  # Run checks based on mode
  if [[ "$SSL_ONLY" == "true" ]]; then
    check_ssl "$domain"
  elif [[ "$EMAIL_ONLY" == "true" ]]; then
    check_email "$domain"
  else
    check_dns "$domain"
    check_ssl "$domain"
    check_http "$domain"
    if [[ "$SKIP_WHOIS" == "false" ]]; then
      check_whois "$domain"
    fi
    check_email "$domain"
  fi

  if [[ "$JSON_MODE" == "false" ]]; then
    echo ""
    echo -e "${CYAN}─────────────────────────────────────────────────────${NC}"
    echo -e "  Check complete for ${BOLD}$domain${NC}"
  fi
}

# Main
for domain in "${DOMAINS[@]}"; do
  # Strip protocol if provided
  domain=$(echo "$domain" | sed 's|https\?://||;s|/.*||')
  check_domain "$domain"
done
