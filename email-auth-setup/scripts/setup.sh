#!/bin/bash
# Email Auth Setup — Generate and verify DKIM, SPF, DMARC records
# Dependencies: openssl, dig (dnsutils/bind-utils)

set -euo pipefail

VERSION="1.0.0"
DKIM_BITS="${DKIM_BITS:-2048}"
DKIM_SELECTOR="${DKIM_SELECTOR:-default}"
DMARC_POLICY="${DMARC_POLICY:-quarantine}"
DMARC_RUA="${DMARC_RUA:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
Email Auth Setup v${VERSION}

Usage:
  $(basename "$0") --domain <domain> [--selector <sel>]    Full setup (DKIM + SPF + DMARC)
  $(basename "$0") --dkim --domain <domain> [options]      Generate DKIM keys only
  $(basename "$0") --spf --domain <domain> [options]       Generate SPF record only
  $(basename "$0") --dmarc --domain <domain> [options]     Generate DMARC record only
  $(basename "$0") --verify <domain> [--selector <sel>]    Verify existing email auth
  $(basename "$0") --audit <file>                          Audit multiple domains
  $(basename "$0") --spf-check <domain>                    Check SPF lookup count
  $(basename "$0") --spf-flatten <domain>                  Flatten SPF to IPs

Options:
  --domain <domain>       Target domain
  --selector <selector>   DKIM selector (default: $DKIM_SELECTOR)
  --bits <bits>           DKIM key size (default: $DKIM_BITS)
  --policy <policy>       DMARC policy: none|quarantine|reject (default: $DMARC_POLICY)
  --rua <email>           DMARC aggregate report email
  --ruf <email>           DMARC forensic report email
  --pct <0-100>           DMARC percentage (default: 100)
  --include <domain>      SPF include (repeatable)
  --ip4 <ip>              SPF IPv4 (repeatable)
  --ip6 <ip>              SPF IPv6 (repeatable)
  --split                 Split long DKIM records for DNS
  -h, --help              Show this help
EOF
}

check_deps() {
  local missing=()
  command -v openssl &>/dev/null || missing+=("openssl")
  command -v dig &>/dev/null || missing+=("dig (dnsutils/bind-utils)")
  
  if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${RED}Missing dependencies:${NC}"
    for dep in "${missing[@]}"; do
      echo "  - $dep"
    done
    exit 1
  fi
}

generate_dkim() {
  local domain="$1"
  local selector="$2"
  local bits="$3"
  local split="${4:-false}"
  local outdir="output/${domain}"
  
  mkdir -p "$outdir"
  
  # Generate private key
  openssl genrsa -out "${outdir}/${selector}.private" "$bits" 2>/dev/null
  
  # Extract public key (remove header/footer, join lines)
  local pubkey
  pubkey=$(openssl rsa -in "${outdir}/${selector}.private" -pubout 2>/dev/null | \
    grep -v "^-----" | tr -d '\n')
  
  # Save public key record
  echo "v=DKIM1; k=rsa; p=${pubkey}" > "${outdir}/${selector}.txt"
  
  echo -e "${GREEN}✅ DKIM Key Generated (${bits}-bit RSA)${NC}"
  echo "   Selector: ${selector}"
  echo "   Private key: ${outdir}/${selector}.private"
  echo "   Public key:  ${outdir}/${selector}.txt"
  echo ""
  echo -e "${BLUE}--- DKIM DNS Record ---${NC}"
  echo "Type: TXT"
  echo "Host: ${selector}._domainkey"
  
  if [ "$split" = "true" ] && [ ${#pubkey} -gt 200 ]; then
    # Split into 255-char chunks for DNS compatibility
    echo "Value:"
    local record="v=DKIM1; k=rsa; p=${pubkey}"
    local i=0
    while [ $i -lt ${#record} ]; do
      local chunk="${record:$i:255}"
      echo "  \"${chunk}\""
      i=$((i + 255))
    done
  else
    echo "Value: v=DKIM1; k=rsa; p=${pubkey}"
  fi
  echo ""
}

generate_spf() {
  local domain="$1"
  shift
  local includes=()
  local ip4s=()
  local ip6s=()
  
  while [ $# -gt 0 ]; do
    case "$1" in
      --include) includes+=("$2"); shift 2 ;;
      --ip4) ip4s+=("$2"); shift 2 ;;
      --ip6) ip6s+=("$2"); shift 2 ;;
      *) shift ;;
    esac
  done
  
  local spf="v=spf1"
  
  # Add mechanisms
  [ ${#includes[@]} -eq 0 ] && [ ${#ip4s[@]} -eq 0 ] && [ ${#ip6s[@]} -eq 0 ] && spf+=" mx a"
  
  for inc in "${includes[@]+"${includes[@]}"}"; do
    spf+=" include:${inc}"
  done
  for ip in "${ip4s[@]+"${ip4s[@]}"}"; do
    spf+=" ip4:${ip}"
  done
  for ip in "${ip6s[@]+"${ip6s[@]}"}"; do
    spf+=" ip6:${ip}"
  done
  
  spf+=" ~all"
  
  echo -e "${BLUE}--- SPF DNS Record ---${NC}"
  echo "Type: TXT"
  echo "Host: @"
  echo "Value: ${spf}"
  echo ""
}

generate_dmarc() {
  local domain="$1"
  local policy="${2:-$DMARC_POLICY}"
  local rua="${3:-${DMARC_RUA:-dmarc@${domain}}}"
  local ruf="${4:-}"
  local pct="${5:-100}"
  
  local dmarc="v=DMARC1; p=${policy}; rua=mailto:${rua}; pct=${pct}; adkim=r; aspf=r"
  [ -n "$ruf" ] && dmarc+="; ruf=mailto:${ruf}"
  
  echo -e "${BLUE}--- DMARC DNS Record ---${NC}"
  echo "Type: TXT"
  echo "Host: _dmarc"
  echo "Value: ${dmarc}"
  echo ""
}

verify_domain() {
  local domain="$1"
  local selector="${2:-$DKIM_SELECTOR}"
  
  echo -e "${BLUE}=== Email Auth Verification: ${domain} ===${NC}"
  echo ""
  
  # Check SPF
  local spf
  spf=$(dig +short TXT "$domain" 2>/dev/null | grep -i "v=spf1" | tr -d '"' || true)
  if [ -n "$spf" ]; then
    echo -e "SPF:   ${GREEN}✅ Found:${NC} ${spf}"
  else
    echo -e "SPF:   ${RED}❌ Not found${NC}"
  fi
  
  # Check DKIM
  local dkim
  dkim=$(dig +short TXT "${selector}._domainkey.${domain}" 2>/dev/null | tr -d '"' || true)
  if [ -n "$dkim" ] && echo "$dkim" | grep -qi "v=DKIM1"; then
    local keylen=""
    local pk
    pk=$(echo "$dkim" | grep -oP 'p=\K[A-Za-z0-9+/=]+' || true)
    if [ -n "$pk" ]; then
      local decoded_len
      decoded_len=$(echo "$pk" | base64 -d 2>/dev/null | wc -c || echo "?")
      keylen=" (${decoded_len} bytes)"
    fi
    echo -e "DKIM:  ${GREEN}✅ Found${NC} (selector: ${selector})${keylen}"
  else
    echo -e "DKIM:  ${RED}❌ Not found${NC} (selector: ${selector})"
    # Try common selectors
    for sel in google default selector1 selector2 mail dkim s1 s2 k1; do
      local alt
      alt=$(dig +short TXT "${sel}._domainkey.${domain}" 2>/dev/null | tr -d '"' || true)
      if [ -n "$alt" ] && echo "$alt" | grep -qi "v=DKIM1"; then
        echo -e "       ${YELLOW}⚠️  Found with selector '${sel}' instead${NC}"
        break
      fi
    done
  fi
  
  # Check DMARC
  local dmarc
  dmarc=$(dig +short TXT "_dmarc.${domain}" 2>/dev/null | tr -d '"' || true)
  if [ -n "$dmarc" ] && echo "$dmarc" | grep -qi "v=DMARC1"; then
    local policy
    policy=$(echo "$dmarc" | grep -oP 'p=\K[a-z]+' || echo "unknown")
    case "$policy" in
      reject)
        echo -e "DMARC: ${GREEN}✅ Found: p=${policy}${NC} (strictest)"
        ;;
      quarantine)
        echo -e "DMARC: ${GREEN}✅ Found: p=${policy}${NC}"
        ;;
      none)
        echo -e "DMARC: ${YELLOW}⚠️  Found: p=${policy}${NC} — consider upgrading to 'quarantine' or 'reject'"
        ;;
      *)
        echo -e "DMARC: ${YELLOW}⚠️  Found but policy unclear:${NC} ${dmarc}"
        ;;
    esac
  else
    echo -e "DMARC: ${RED}❌ Not found${NC}"
  fi
  
  # Check MX
  local mx
  mx=$(dig +short MX "$domain" 2>/dev/null | sort -n || true)
  if [ -n "$mx" ]; then
    echo -e "MX:    ${GREEN}✅ Found:${NC}"
    echo "$mx" | while read -r line; do
      echo "       ${line}"
    done
  else
    echo -e "MX:    ${RED}❌ Not found${NC}"
  fi
  
  echo ""
}

spf_check_lookups() {
  local domain="$1"
  local count=0
  local visited=()
  
  _count_lookups() {
    local d="$1"
    local spf
    spf=$(dig +short TXT "$d" 2>/dev/null | grep -i "v=spf1" | tr -d '"' || true)
    [ -z "$spf" ] && return
    
    # Count include: mechanisms
    local includes
    includes=$(echo "$spf" | grep -oP 'include:\K[^ ]+' || true)
    for inc in $includes; do
      count=$((count + 1))
      _count_lookups "$inc"
    done
    
    # Count redirect=
    local redirect
    redirect=$(echo "$spf" | grep -oP 'redirect=\K[^ ]+' || true)
    [ -n "$redirect" ] && { count=$((count + 1)); _count_lookups "$redirect"; }
    
    # Count a: and mx: mechanisms
    echo "$spf" | grep -qP '\ba\b|\ba:' && count=$((count + 1))
    echo "$spf" | grep -qP '\bmx\b|\bmx:' && count=$((count + 1))
  }
  
  _count_lookups "$domain"
  
  echo -e "${BLUE}SPF Lookup Count for ${domain}: ${count}${NC}"
  if [ "$count" -gt 10 ]; then
    echo -e "${RED}⚠️  Exceeds 10-lookup limit! Emails may fail SPF checks.${NC}"
    echo "   Solution: Flatten includes to IP addresses with --spf-flatten"
  elif [ "$count" -gt 7 ]; then
    echo -e "${YELLOW}⚠️  Getting close to 10-lookup limit (${count}/10)${NC}"
  else
    echo -e "${GREEN}✅ Within limit (${count}/10)${NC}"
  fi
}

spf_flatten() {
  local domain="$1"
  local spf
  spf=$(dig +short TXT "$domain" 2>/dev/null | grep -i "v=spf1" | tr -d '"' || true)
  
  if [ -z "$spf" ]; then
    echo -e "${RED}No SPF record found for ${domain}${NC}"
    return 1
  fi
  
  echo -e "${BLUE}Flattening SPF for ${domain}...${NC}"
  echo "Original: ${spf}"
  echo ""
  
  local ips=()
  
  # Resolve includes to IPs
  local includes
  includes=$(echo "$spf" | grep -oP 'include:\K[^ ]+' || true)
  for inc in $includes; do
    echo "Resolving ${inc}..."
    local inc_ips
    inc_ips=$(dig +short TXT "$inc" 2>/dev/null | tr -d '"' || true)
    
    # Extract ip4/ip6 from included records
    local v4s
    v4s=$(echo "$inc_ips" | grep -oP 'ip4:\K[^ ]+' || true)
    for ip in $v4s; do
      ips+=("ip4:${ip}")
    done
    local v6s
    v6s=$(echo "$inc_ips" | grep -oP 'ip6:\K[^ ]+' || true)
    for ip in $v6s; do
      ips+=("ip6:${ip}")
    done
  done
  
  # Build flattened record
  local flat="v=spf1"
  for ip in "${ips[@]+"${ips[@]}"}"; do
    flat+=" ${ip}"
  done
  
  # Keep direct ip4/ip6 from original
  local direct_ips
  direct_ips=$(echo "$spf" | grep -oP 'ip[46]:[^ ]+' || true)
  for ip in $direct_ips; do
    flat+=" ${ip}"
  done
  
  flat+=" ~all"
  
  echo ""
  echo -e "${GREEN}Flattened SPF:${NC}"
  echo "$flat"
  echo ""
  echo -e "${YELLOW}Note: Flattened records must be updated when provider IPs change.${NC}"
}

audit_domains() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo -e "${RED}File not found: ${file}${NC}"
    exit 1
  fi
  
  while IFS= read -r domain; do
    [ -z "$domain" ] && continue
    [[ "$domain" =~ ^# ]] && continue
    verify_domain "$domain"
    echo "---"
    echo ""
  done < "$file"
}

# --- Main ---

check_deps

MODE=""
DOMAIN=""
SELECTOR="$DKIM_SELECTOR"
BITS="$DKIM_BITS"
POLICY="$DMARC_POLICY"
RUA=""
RUF=""
PCT="100"
SPLIT="false"
SPF_ARGS=()
AUDIT_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --dkim) MODE="dkim"; shift ;;
    --spf) MODE="spf"; shift ;;
    --dmarc) MODE="dmarc"; shift ;;
    --verify) MODE="verify"; DOMAIN="${2:-}"; shift; [ -n "$DOMAIN" ] && shift ;;
    --audit) MODE="audit"; AUDIT_FILE="$2"; shift 2 ;;
    --spf-check) MODE="spf-check"; DOMAIN="$2"; shift 2 ;;
    --spf-flatten) MODE="spf-flatten"; DOMAIN="$2"; shift 2 ;;
    --selector) SELECTOR="$2"; shift 2 ;;
    --bits) BITS="$2"; shift 2 ;;
    --policy) POLICY="$2"; shift 2 ;;
    --rua) RUA="$2"; shift 2 ;;
    --ruf) RUF="$2"; shift 2 ;;
    --pct) PCT="$2"; shift 2 ;;
    --include) SPF_ARGS+=("--include" "$2"); shift 2 ;;
    --ip4) SPF_ARGS+=("--ip4" "$2"); shift 2 ;;
    --ip6) SPF_ARGS+=("--ip6" "$2"); shift 2 ;;
    --split) SPLIT="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      # If no mode set and arg looks like a domain, treat as full setup
      if [ -z "$MODE" ] && [ -z "$DOMAIN" ]; then
        DOMAIN="$1"
      fi
      shift
      ;;
  esac
done

case "$MODE" in
  dkim)
    [ -z "$DOMAIN" ] && { echo "Error: --domain required"; exit 1; }
    generate_dkim "$DOMAIN" "$SELECTOR" "$BITS" "$SPLIT"
    ;;
  spf)
    [ -z "$DOMAIN" ] && { echo "Error: --domain required"; exit 1; }
    generate_spf "$DOMAIN" "${SPF_ARGS[@]+"${SPF_ARGS[@]}"}"
    ;;
  dmarc)
    [ -z "$DOMAIN" ] && { echo "Error: --domain required"; exit 1; }
    generate_dmarc "$DOMAIN" "$POLICY" "$RUA" "$RUF" "$PCT"
    ;;
  verify)
    [ -z "$DOMAIN" ] && { echo "Error: domain required"; exit 1; }
    verify_domain "$DOMAIN" "$SELECTOR"
    ;;
  audit)
    [ -z "$AUDIT_FILE" ] && { echo "Error: file required"; exit 1; }
    audit_domains "$AUDIT_FILE"
    ;;
  spf-check)
    [ -z "$DOMAIN" ] && { echo "Error: domain required"; exit 1; }
    spf_check_lookups "$DOMAIN"
    ;;
  spf-flatten)
    [ -z "$DOMAIN" ] && { echo "Error: domain required"; exit 1; }
    spf_flatten "$DOMAIN"
    ;;
  "")
    # Full setup
    [ -z "$DOMAIN" ] && { usage; exit 1; }
    echo -e "${BLUE}=== Email Authentication Setup for ${DOMAIN} ===${NC}"
    echo ""
    generate_dkim "$DOMAIN" "$SELECTOR" "$BITS" "$SPLIT"
    generate_spf "$DOMAIN" "${SPF_ARGS[@]+"${SPF_ARGS[@]}"}"
    generate_dmarc "$DOMAIN" "$POLICY" "$RUA" "$RUF" "$PCT"
    echo -e "${GREEN}Add these DNS records, then run:${NC}"
    echo "  bash scripts/setup.sh --verify ${DOMAIN}"
    ;;
esac
