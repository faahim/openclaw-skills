#!/bin/bash
# Email Deliverability Checker
# Checks SPF, DKIM, DMARC, MX records, and DNSBL blacklists
set -euo pipefail

# Defaults
DNS_TIMEOUT="${DNS_TIMEOUT:-5}"
DNS_SERVER="${DNS_SERVER:-}"
DKIM_SELECTORS="${DKIM_SELECTORS:-default,google,selector1,selector2,k1,s1,s2,dkim}"
OUTPUT_JSON=false
FULL_CHECK=false
NO_BLACKLIST=false
CUSTOM_SELECTORS=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# DNSBL lists
BLACKLISTS=(
  zen.spamhaus.org
  bl.spamcop.net
  b.barracudacentral.org
  dnsbl.sorbs.net
  spam.dnsbl.sorbs.net
  dul.dnsbl.sorbs.net
  smtp.dnsbl.sorbs.net
  cbl.abuseat.org
  dnsbl-1.uceprotect.net
  dnsbl-2.uceprotect.net
  dnsbl-3.uceprotect.net
  db.wpbl.info
  access.redhawk.org
  blacklist.woody.ch
  bogons.cymru.com
  combined.abuse.ch
  duinv.aupads.org
  psbl.surriel.com
  dyna.spamrats.com
  noptr.spamrats.com
  spam.spamrats.com
  drone.abuse.ch
  httpbl.abuse.ch
  korea.services.net
  short.rbl.jp
  virus.rbl.jp
  spamrbl.imp.ch
  wormrbl.imp.ch
  rbl.interserver.net
  ubl.unsubscore.com
  all.s5h.net
)

usage() {
  echo "Usage: $0 [OPTIONS] <domain>"
  echo ""
  echo "Options:"
  echo "  --full              Run full audit including blacklist checks"
  echo "  --json              Output results as JSON"
  echo "  --dkim-selector S   Comma-separated DKIM selectors to check"
  echo "  --no-blacklist      Skip blacklist checks even with --full"
  echo "  --timeout N         DNS query timeout in seconds (default: 5)"
  echo "  --dns-server IP     Use specific DNS server"
  echo "  -h, --help          Show this help"
  exit 0
}

# Parse args
DOMAIN=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --full) FULL_CHECK=true; shift ;;
    --json) OUTPUT_JSON=true; shift ;;
    --dkim-selector) CUSTOM_SELECTORS="$2"; shift 2 ;;
    --no-blacklist) NO_BLACKLIST=true; shift ;;
    --timeout) DNS_TIMEOUT="$2"; shift 2 ;;
    --dns-server) DNS_SERVER="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *) DOMAIN="$1"; shift ;;
  esac
done

if [[ -z "$DOMAIN" ]]; then
  echo "Error: No domain specified"
  usage
fi

if [[ -n "$CUSTOM_SELECTORS" ]]; then
  DKIM_SELECTORS="$CUSTOM_SELECTORS"
fi

# Build dig options
DIG_OPTS="+short +time=${DNS_TIMEOUT} +tries=2"
if [[ -n "$DNS_SERVER" ]]; then
  DIG_OPTS="$DIG_OPTS @${DNS_SERVER}"
fi

# Results
SCORE=0
RECS=()
MX_STATUS="fail"
MX_RECORDS=()
SPF_STATUS="fail"
SPF_RECORD=""
DKIM_STATUS="fail"
DKIM_SELECTOR_FOUND=""
DKIM_RECORD=""
DMARC_STATUS="fail"
DMARC_RECORD=""
BL_CHECKED=0
BL_LISTED=0
BL_LISTINGS=()

# --- CHECK MX ---
check_mx() {
  local mx_raw
  mx_raw=$(dig $DIG_OPTS MX "$DOMAIN" 2>/dev/null || true)
  if [[ -n "$mx_raw" ]]; then
    MX_STATUS="pass"
    SCORE=$((SCORE + 25))
    while IFS= read -r line; do
      MX_RECORDS+=("$line")
    done <<< "$mx_raw"
  else
    RECS+=("Add MX records pointing to your mail server")
  fi
}

# --- CHECK SPF ---
check_spf() {
  local txt_records
  txt_records=$(dig $DIG_OPTS TXT "$DOMAIN" 2>/dev/null || true)
  SPF_RECORD=$(echo "$txt_records" | grep -i 'v=spf1' | head -1 | tr -d '"' || true)
  if [[ -n "$SPF_RECORD" ]]; then
    SPF_STATUS="pass"
    SCORE=$((SCORE + 25))
    # Check for weak policy
    if echo "$SPF_RECORD" | grep -q '+all'; then
      RECS+=("SPF uses +all (allows anyone to send) — change to ~all or -all")
      SCORE=$((SCORE - 10))
    elif echo "$SPF_RECORD" | grep -q '?all'; then
      RECS+=("SPF uses ?all (neutral) — consider ~all or -all for better protection")
      SCORE=$((SCORE - 5))
    fi
  else
    RECS+=("Add SPF record: v=spf1 include:<your-provider> ~all")
  fi
}

# --- CHECK DKIM ---
check_dkim() {
  IFS=',' read -ra selectors <<< "$DKIM_SELECTORS"
  for sel in "${selectors[@]}"; do
    sel=$(echo "$sel" | tr -d ' ')
    local dkim_raw
    dkim_raw=$(dig $DIG_OPTS TXT "${sel}._domainkey.${DOMAIN}" 2>/dev/null || true)
    local dkim_val
    dkim_val=$(echo "$dkim_raw" | grep -i 'v=DKIM1' | head -1 | tr -d '"' || true)
    if [[ -n "$dkim_val" ]]; then
      DKIM_STATUS="pass"
      DKIM_SELECTOR_FOUND="$sel"
      DKIM_RECORD="$dkim_val"
      SCORE=$((SCORE + 25))
      return
    fi
  done
  RECS+=("Add DKIM record (checked selectors: ${DKIM_SELECTORS}). Use --dkim-selector to specify your provider's selector")
}

# --- CHECK DMARC ---
check_dmarc() {
  local dmarc_raw
  dmarc_raw=$(dig $DIG_OPTS TXT "_dmarc.${DOMAIN}" 2>/dev/null || true)
  DMARC_RECORD=$(echo "$dmarc_raw" | grep -i 'v=DMARC1' | head -1 | tr -d '"' || true)
  if [[ -n "$DMARC_RECORD" ]]; then
    DMARC_STATUS="pass"
    SCORE=$((SCORE + 25))
    # Check policy strength
    if echo "$DMARC_RECORD" | grep -qi 'p=none'; then
      RECS+=("DMARC policy is 'none' (monitoring only) — consider 'quarantine' or 'reject' for enforcement")
      SCORE=$((SCORE - 5))
    fi
  else
    RECS+=("Add DMARC record: v=DMARC1; p=quarantine; rua=mailto:dmarc@${DOMAIN}")
  fi
}

# --- CHECK BLACKLISTS ---
check_blacklists() {
  # Get A record for domain's MX
  local ip=""
  if [[ ${#MX_RECORDS[@]} -gt 0 ]]; then
    local mx_host
    mx_host=$(echo "${MX_RECORDS[0]}" | awk '{print $2}' | sed 's/\.$//')
    ip=$(dig $DIG_OPTS A "$mx_host" 2>/dev/null | head -1 || true)
  fi
  # Fallback to domain A record
  if [[ -z "$ip" ]]; then
    ip=$(dig $DIG_OPTS A "$DOMAIN" 2>/dev/null | head -1 || true)
  fi
  if [[ -z "$ip" || ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    RECS+=("Could not resolve IP for blacklist check")
    return
  fi

  # Reverse IP
  local reversed
  reversed=$(echo "$ip" | awk -F. '{print $4"."$3"."$2"."$1}')

  for bl in "${BLACKLISTS[@]}"; do
    BL_CHECKED=$((BL_CHECKED + 1))
    local result
    result=$(dig +short +time=3 +tries=1 "${reversed}.${bl}" A 2>/dev/null || true)
    if [[ -n "$result" && "$result" =~ ^127\. ]]; then
      BL_LISTED=$((BL_LISTED + 1))
      BL_LISTINGS+=("$bl")
      SCORE=$((SCORE - 5))
    fi
  done
}

# --- RUN CHECKS ---
check_mx
check_spf
check_dkim
check_dmarc

if [[ "$FULL_CHECK" == true && "$NO_BLACKLIST" != true ]]; then
  check_blacklists
fi

# Clamp score
[[ $SCORE -lt 0 ]] && SCORE=0
[[ $SCORE -gt 100 ]] && SCORE=100

# --- OUTPUT ---
if [[ "$OUTPUT_JSON" == true ]]; then
  # JSON output
  MX_JSON="[]"
  if [[ ${#MX_RECORDS[@]} -gt 0 ]]; then
    MX_JSON=$(printf '%s\n' "${MX_RECORDS[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
  fi
  RECS_JSON="[]"
  if [[ ${#RECS[@]} -gt 0 ]]; then
    RECS_JSON=$(printf '%s\n' "${RECS[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
  fi
  BL_JSON="[]"
  if [[ ${#BL_LISTINGS[@]} -gt 0 ]]; then
    BL_JSON=$(printf '%s\n' "${BL_LISTINGS[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")
  fi

  cat <<EOF
{
  "domain": "$DOMAIN",
  "score": $SCORE,
  "mx": {"status": "$MX_STATUS", "records": $MX_JSON},
  "spf": {"status": "$SPF_STATUS", "record": $(echo "$SPF_RECORD" | jq -R . 2>/dev/null || echo '""')},
  "dkim": {"status": "$DKIM_STATUS", "selector": $(echo "$DKIM_SELECTOR_FOUND" | jq -R . 2>/dev/null || echo '""'), "record": $(echo "$DKIM_RECORD" | jq -R . 2>/dev/null || echo '""')},
  "dmarc": {"status": "$DMARC_STATUS", "record": $(echo "$DMARC_RECORD" | jq -R . 2>/dev/null || echo '""')},
  "blacklists": {"checked": $BL_CHECKED, "listed": $BL_LISTED, "listings": $BL_JSON},
  "recommendations": $RECS_JSON
}
EOF
  exit 0
fi

# Pretty output
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Email Deliverability Report: ${CYAN}${DOMAIN}${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
echo ""

# MX
echo -e "${BOLD}📬 MX Records${NC}"
if [[ "$MX_STATUS" == "pass" ]]; then
  for r in "${MX_RECORDS[@]}"; do
    echo -e "  ${GREEN}✅${NC} $r"
  done
else
  echo -e "  ${RED}❌${NC} No MX records found"
fi
echo ""

# SPF
echo -e "${BOLD}🛡️  SPF Record${NC}"
if [[ "$SPF_STATUS" == "pass" ]]; then
  echo -e "  ${GREEN}✅${NC} $SPF_RECORD"
else
  echo -e "  ${RED}❌${NC} No SPF record found"
fi
echo ""

# DKIM
echo -e "${BOLD}🔑 DKIM Record${NC}"
if [[ "$DKIM_STATUS" == "pass" ]]; then
  echo -e "  ${GREEN}✅${NC} Found for selector '${DKIM_SELECTOR_FOUND}'"
  echo -e "  ${CYAN}   ${DKIM_RECORD:0:80}...${NC}"
else
  echo -e "  ${RED}❌${NC} No DKIM record found (checked: ${DKIM_SELECTORS})"
fi
echo ""

# DMARC
echo -e "${BOLD}📋 DMARC Record${NC}"
if [[ "$DMARC_STATUS" == "pass" ]]; then
  echo -e "  ${GREEN}✅${NC} $DMARC_RECORD"
else
  echo -e "  ${RED}❌${NC} No DMARC record found"
fi
echo ""

# Blacklists
if [[ "$FULL_CHECK" == true && "$NO_BLACKLIST" != true ]]; then
  echo -e "${BOLD}🚫 Blacklist Status${NC}"
  if [[ $BL_CHECKED -gt 0 ]]; then
    if [[ $BL_LISTED -eq 0 ]]; then
      echo -e "  ${GREEN}✅${NC} Clean — not listed on any of ${BL_CHECKED} blacklists"
    else
      echo -e "  ${RED}❌${NC} Listed on ${BL_LISTED}/${BL_CHECKED} blacklists:"
      for bl in "${BL_LISTINGS[@]}"; do
        echo -e "     ${RED}•${NC} $bl"
      done
    fi
  else
    echo -e "  ${YELLOW}⚠️${NC}  Could not check blacklists"
  fi
  echo ""
fi

# Score
echo -e "${BOLD}📊 Score: ${NC}"
if [[ $SCORE -ge 90 ]]; then
  echo -e "  ${GREEN}${BOLD}${SCORE}/100 — Excellent${NC}"
elif [[ $SCORE -ge 70 ]]; then
  echo -e "  ${YELLOW}${BOLD}${SCORE}/100 — Good (room for improvement)${NC}"
elif [[ $SCORE -ge 50 ]]; then
  echo -e "  ${YELLOW}${BOLD}${SCORE}/100 — Fair (action needed)${NC}"
else
  echo -e "  ${RED}${BOLD}${SCORE}/100 — Poor (urgent fixes needed)${NC}"
fi
echo ""

# Recommendations
if [[ ${#RECS[@]} -gt 0 ]]; then
  echo -e "${BOLD}⚠️  Recommendations:${NC}"
  i=1
  for rec in "${RECS[@]}"; do
    echo -e "  ${i}. ${rec}"
    i=$((i + 1))
  done
  echo ""
fi

echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
