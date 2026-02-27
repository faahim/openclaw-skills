#!/bin/bash
# TLS Inspector — Deep SSL/TLS security scanner
# Requires: openssl, curl, bash 4+
set -uo pipefail

VERSION="1.0.0"
TIMEOUT=10
OUTPUT_FORMAT="text"
VERBOSE=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
TLS Inspector v${VERSION} — SSL/TLS Security Scanner

Usage: bash tls-inspect.sh [OPTIONS] <domain> [domain2 ...]

Options:
  --timeout <sec>    Connection timeout (default: 10)
  --json             Output as JSON
  --verbose          Show detailed cipher/protocol info
  --batch <file>     Read domains from file (one per line)
  --help             Show this help

Examples:
  bash tls-inspect.sh example.com
  bash tls-inspect.sh --verbose google.com github.com
  bash tls-inspect.sh --json --batch domains.txt
EOF
  exit 0
}

# Parse args
DOMAINS=()
BATCH_FILE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --json) OUTPUT_FORMAT="json"; shift ;;
    --verbose) VERBOSE=1; shift ;;
    --batch) BATCH_FILE="$2"; shift 2 ;;
    --help|-h) usage ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *) DOMAINS+=("$1"); shift ;;
  esac
done

if [[ -n "$BATCH_FILE" ]]; then
  while IFS= read -r line; do
    line=$(echo "$line" | tr -d '[:space:]')
    [[ -n "$line" && ! "$line" =~ ^# ]] && DOMAINS+=("$line")
  done < "$BATCH_FILE"
fi

if [[ ${#DOMAINS[@]} -eq 0 ]]; then
  echo "Error: No domains specified. Use --help for usage."
  exit 1
fi

# Check dependencies
for cmd in openssl curl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: $cmd is required but not installed."; exit 1; }
done

# ── Protocol Check ──
check_protocol() {
  local domain=$1 proto=$2 port=${3:-443}
  echo | timeout "$TIMEOUT" openssl s_client -connect "${domain}:${port}" -"${proto}" 2>/dev/null | grep -q "BEGIN CERTIFICATE"
  return $?
}

# ── Certificate Info ──
get_cert_info() {
  local domain=$1 port=${2:-443}
  local cert_text
  cert_text=$(echo | timeout "$TIMEOUT" openssl s_client -connect "${domain}:${port}" -servername "$domain"  2>/dev/null)
  
  local cert_pem
  cert_pem=$(echo "$cert_text" | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p')
  
  if [[ -z "$cert_pem" ]]; then
    echo "CONNECT_FAILED"
    return 1
  fi
  
  local subject issuer not_before not_after serial san
  subject=$(echo "$cert_pem" | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//')
  issuer=$(echo "$cert_pem" | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=//')
  not_before=$(echo "$cert_pem" | openssl x509 -noout -startdate 2>/dev/null | sed 's/notBefore=//')
  not_after=$(echo "$cert_pem" | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//')
  serial=$(echo "$cert_pem" | openssl x509 -noout -serial 2>/dev/null | sed 's/serial=//')
  san=$(echo "$cert_pem" | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -v "Subject Alternative Name" | tr -d ' ')
  
  # Days until expiry
  local expiry_epoch now_epoch days_left
  expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$not_after" +%s 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
  
  # Key size
  local key_size
  key_size=$(echo "$cert_pem" | openssl x509 -noout -text 2>/dev/null | grep "Public-Key:" | grep -oP '\d+')
  
  # Signature algorithm
  local sig_alg
  sig_alg=$(echo "$cert_pem" | openssl x509 -noout -text 2>/dev/null | grep "Signature Algorithm:" | head -1 | awk '{print $3}')
  
  # Chain depth
  local chain_depth
  chain_depth=$(echo "$cert_text" | grep -c "^ [0-9]" 2>/dev/null || echo "0")
  
  echo "SUBJECT=${subject}"
  echo "ISSUER=${issuer}"
  echo "NOT_BEFORE=${not_before}"
  echo "NOT_AFTER=${not_after}"
  echo "DAYS_LEFT=${days_left}"
  echo "SERIAL=${serial}"
  echo "SAN=${san}"
  echo "KEY_SIZE=${key_size}"
  echo "SIG_ALG=${sig_alg}"
  echo "CHAIN_DEPTH=${chain_depth}"
}

# ── HSTS Check ──
check_hsts() {
  local domain=$1
  local hsts_header
  hsts_header=$(curl -sI --max-time "$TIMEOUT" "https://${domain}/" 2>/dev/null | grep -i "strict-transport-security" | head -1)
  if [[ -n "$hsts_header" ]]; then
    local max_age
    max_age=$(echo "$hsts_header" | grep -oP 'max-age=\K\d+' || echo "0")
    local include_sub="no"
    echo "$hsts_header" | grep -qi "includeSubDomains" && include_sub="yes"
    local preload="no"
    echo "$hsts_header" | grep -qi "preload" && preload="yes"
    echo "ENABLED max-age=${max_age} includeSubDomains=${include_sub} preload=${preload}"
  else
    echo "DISABLED"
  fi
}

# ── Supported Ciphers (top 5) ──
get_ciphers() {
  local domain=$1 port=${2:-443}
  echo | timeout "$TIMEOUT" openssl s_client -connect "${domain}:${port}" -servername "$domain"  2>/dev/null | grep "Cipher    :" | awk '{print $NF}'
}

# ── HTTP→HTTPS Redirect ──
check_redirect() {
  local domain=$1
  local status
  status=$(curl -sI --max-time "$TIMEOUT" -o /dev/null -w "%{http_code}" "http://${domain}/" 2>/dev/null)
  local location
  location=$(curl -sI --max-time "$TIMEOUT" "http://${domain}/" 2>/dev/null | grep -i "^location:" | head -1 | tr -d '\r')
  if [[ "$status" =~ ^3[0-9]{2}$ ]] && echo "$location" | grep -qi "https://"; then
    echo "YES (${status})"
  else
    echo "NO (HTTP ${status})"
  fi
}

# ── OCSP Stapling ──
check_ocsp() {
  local domain=$1 port=${2:-443}
  local ocsp_result
  ocsp_result=$(echo | timeout "$TIMEOUT" openssl s_client -connect "${domain}:${port}" -servername "$domain" -status  2>/dev/null | grep "OCSP Response Status")
  if [[ -n "$ocsp_result" ]] && echo "$ocsp_result" | grep -q "successful"; then
    echo "YES"
  else
    echo "NO"
  fi
}

# ── Grade Calculation ──
calculate_grade() {
  local score=100
  local protocol_tls13=$1 protocol_tls12=$2 protocol_tls11=$3 protocol_tls10=$4 protocol_ssl3=$5
  local days_left=$6 key_size=$7 hsts=$8 redirect=$9 ocsp=${10} sig_alg=${11}
  local deductions=""
  
  # Protocol penalties
  [[ "$protocol_ssl3" == "yes" ]] && score=$((score - 40)) && deductions="${deductions}SSLv3 enabled (-40); "
  [[ "$protocol_tls10" == "yes" ]] && score=$((score - 15)) && deductions="${deductions}TLSv1.0 enabled (-15); "
  [[ "$protocol_tls11" == "yes" ]] && score=$((score - 10)) && deductions="${deductions}TLSv1.1 enabled (-10); "
  [[ "$protocol_tls13" == "no" && "$protocol_tls12" == "yes" ]] && score=$((score - 5)) && deductions="${deductions}No TLS 1.3 (-5); "
  [[ "$protocol_tls13" == "no" && "$protocol_tls12" == "no" ]] && score=$((score - 30)) && deductions="${deductions}No TLS 1.2/1.3 (-30); "
  
  # Cert penalties
  [[ "$days_left" -lt 0 ]] && score=0 && deductions="${deductions}EXPIRED (-100); "
  [[ "$days_left" -ge 0 && "$days_left" -lt 7 ]] && score=$((score - 30)) && deductions="${deductions}Expires <7 days (-30); "
  [[ "$days_left" -ge 7 && "$days_left" -lt 30 ]] && score=$((score - 15)) && deductions="${deductions}Expires <30 days (-15); "
  
  # Key size (EC 256+ is fine, RSA needs 2048+)
  if [[ -n "$key_size" ]]; then
    if [[ "$key_size" -le 384 ]]; then
      : # EC key (256/384 bit) — strong
    elif [[ "$key_size" -lt 2048 ]]; then
      score=$((score - 20)) && deductions="${deductions}Weak RSA key <2048 (-20); "
    fi
  fi
  
  # Signature
  [[ "$sig_alg" == *"sha1"* ]] && score=$((score - 20)) && deductions="${deductions}SHA-1 signature (-20); "
  
  # HSTS
  [[ "$hsts" == "DISABLED" ]] && score=$((score - 10)) && deductions="${deductions}No HSTS (-10); "
  
  # Redirect
  [[ "$redirect" == "NO"* ]] && score=$((score - 5)) && deductions="${deductions}No HTTP→HTTPS redirect (-5); "
  
  # OCSP
  [[ "$ocsp" == "NO" ]] && score=$((score - 5)) && deductions="${deductions}No OCSP stapling (-5); "
  
  [[ $score -lt 0 ]] && score=0
  
  local grade
  if [[ $score -ge 95 ]]; then grade="A+"
  elif [[ $score -ge 90 ]]; then grade="A"
  elif [[ $score -ge 80 ]]; then grade="B"
  elif [[ $score -ge 70 ]]; then grade="C"
  elif [[ $score -ge 60 ]]; then grade="D"
  else grade="F"
  fi
  
  echo "${grade}|${score}|${deductions:-None}"
}

# ── JSON output helper ──
json_escape() {
  echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr -d '\n'
}

# ── Main scan ──
scan_domain() {
  local domain=$1
  local port=443
  
  # Strip protocol prefix if present
  domain=$(echo "$domain" | sed 's|^https\?://||; s|/.*||; s|:.*||')
  
  if [[ "$OUTPUT_FORMAT" == "text" ]]; then
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  TLS Inspector — ${domain}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
  fi
  
  # Certificate info
  local cert_info
  cert_info=$(get_cert_info "$domain" "$port")
  
  if [[ "$cert_info" == "CONNECT_FAILED" ]]; then
    if [[ "$OUTPUT_FORMAT" == "text" ]]; then
      echo -e "  ${RED}✗ Connection failed — could not retrieve certificate${NC}"
    else
      echo "{\"domain\":\"${domain}\",\"error\":\"Connection failed\"}"
    fi
    return 1
  fi
  
  # Parse cert fields
  local subject issuer not_after days_left key_size sig_alg san
  subject=$(echo "$cert_info" | grep "^SUBJECT=" | sed 's/^SUBJECT=//')
  issuer=$(echo "$cert_info" | grep "^ISSUER=" | sed 's/^ISSUER=//')
  not_after=$(echo "$cert_info" | grep "^NOT_AFTER=" | sed 's/^NOT_AFTER=//')
  days_left=$(echo "$cert_info" | grep "^DAYS_LEFT=" | sed 's/^DAYS_LEFT=//')
  key_size=$(echo "$cert_info" | grep "^KEY_SIZE=" | sed 's/^KEY_SIZE=//')
  sig_alg=$(echo "$cert_info" | grep "^SIG_ALG=" | sed 's/^SIG_ALG=//')
  san=$(echo "$cert_info" | grep "^SAN=" | sed 's/^SAN=//')
  
  # Protocol checks
  local tls13="no" tls12="no" tls11="no" tls10="no" ssl3="no"
  check_protocol "$domain" "tls1_3" "$port" 2>/dev/null && tls13="yes"
  check_protocol "$domain" "tls1_2" "$port" 2>/dev/null && tls12="yes"
  check_protocol "$domain" "tls1_1" "$port" 2>/dev/null && tls11="yes"
  check_protocol "$domain" "tls1" "$port" 2>/dev/null && tls10="yes"
  check_protocol "$domain" "ssl3" "$port" 2>/dev/null && ssl3="yes"
  
  # Cipher
  local cipher
  cipher=$(get_ciphers "$domain" "$port")
  
  # HSTS
  local hsts
  hsts=$(check_hsts "$domain")
  
  # Redirect
  local redirect
  redirect=$(check_redirect "$domain")
  
  # OCSP
  local ocsp
  ocsp=$(check_ocsp "$domain" "$port")
  
  # Grade
  local grade_result grade score deductions
  grade_result=$(calculate_grade "$tls13" "$tls12" "$tls11" "$tls10" "$ssl3" "$days_left" "$key_size" "$hsts" "$redirect" "$ocsp" "$sig_alg")
  grade=$(echo "$grade_result" | cut -d'|' -f1)
  score=$(echo "$grade_result" | cut -d'|' -f2)
  deductions=$(echo "$grade_result" | cut -d'|' -f3)
  
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    cat <<ENDJSON
{
  "domain": "${domain}",
  "grade": "${grade}",
  "score": ${score},
  "certificate": {
    "subject": "$(json_escape "$subject")",
    "issuer": "$(json_escape "$issuer")",
    "expires": "${not_after}",
    "days_left": ${days_left},
    "key_size": ${key_size:-0},
    "signature": "${sig_alg}",
    "san": "$(json_escape "$san")"
  },
  "protocols": {
    "tls_1_3": $( [[ "$tls13" == "yes" ]] && echo true || echo false ),
    "tls_1_2": $( [[ "$tls12" == "yes" ]] && echo true || echo false ),
    "tls_1_1": $( [[ "$tls11" == "yes" ]] && echo true || echo false ),
    "tls_1_0": $( [[ "$tls10" == "yes" ]] && echo true || echo false ),
    "ssl_3": $( [[ "$ssl3" == "yes" ]] && echo true || echo false )
  },
  "cipher": "${cipher}",
  "hsts": "$(json_escape "$hsts")",
  "http_redirect": "$(json_escape "$redirect")",
  "ocsp_stapling": "${ocsp}",
  "deductions": "$(json_escape "$deductions")"
}
ENDJSON
    return
  fi
  
  # Text output
  local grade_color="$GREEN"
  [[ "$grade" == "B" ]] && grade_color="$YELLOW"
  [[ "$grade" =~ ^[CDF] ]] && grade_color="$RED"
  
  echo -e "  ${grade_color}Grade: ${grade} (${score}/100)${NC}"
  echo ""
  
  # Certificate
  echo -e "  ${GREEN}📜 Certificate${NC}"
  echo "     Subject:    ${subject}"
  echo "     Issuer:     ${issuer}"
  echo "     Expires:    ${not_after} (${days_left} days left)"
  [[ -n "$key_size" ]] && echo "     Key Size:   ${key_size} bit"
  echo "     Signature:  ${sig_alg}"
  [[ $VERBOSE -eq 1 && -n "$san" ]] && echo "     SANs:       ${san}"
  echo ""
  
  # Protocols
  echo -e "  ${GREEN}🔐 Protocols${NC}"
  local proto_icon
  for proto_pair in "TLS 1.3:${tls13}" "TLS 1.2:${tls12}" "TLS 1.1:${tls11}" "TLS 1.0:${tls10}" "SSLv3:${ssl3}"; do
    local pname=${proto_pair%%:*} pval=${proto_pair##*:}
    if [[ "$pval" == "yes" ]]; then
      if [[ "$pname" == "TLS 1.3" || "$pname" == "TLS 1.2" ]]; then
        echo -e "     ${GREEN}✓${NC} ${pname}"
      else
        echo -e "     ${RED}⚠${NC} ${pname} (deprecated)"
      fi
    else
      if [[ "$pname" == "TLS 1.3" || "$pname" == "TLS 1.2" ]]; then
        echo -e "     ${YELLOW}✗${NC} ${pname} (not supported)"
      else
        echo -e "     ${GREEN}✓${NC} ${pname} (disabled)"
      fi
    fi
  done
  echo ""
  
  # Cipher
  [[ -n "$cipher" ]] && echo -e "  ${GREEN}🔑 Cipher${NC}" && echo "     Negotiated: ${cipher}" && echo ""
  
  # Security headers
  echo -e "  ${GREEN}🛡️  Security${NC}"
  if [[ "$hsts" == "DISABLED" ]]; then
    echo -e "     ${RED}✗${NC} HSTS: Disabled"
  else
    echo -e "     ${GREEN}✓${NC} HSTS: ${hsts#ENABLED }"
  fi
  
  if [[ "$redirect" == "YES"* ]]; then
    echo -e "     ${GREEN}✓${NC} HTTP→HTTPS redirect: ${redirect}"
  else
    echo -e "     ${RED}✗${NC} HTTP→HTTPS redirect: ${redirect}"
  fi
  
  if [[ "$ocsp" == "YES" ]]; then
    echo -e "     ${GREEN}✓${NC} OCSP Stapling: Yes"
  else
    echo -e "     ${YELLOW}✗${NC} OCSP Stapling: No"
  fi
  echo ""
  
  # Deductions
  if [[ "$deductions" != "None" ]]; then
    echo -e "  ${YELLOW}📋 Deductions${NC}"
    IFS=';' read -ra DED_ARRAY <<< "$deductions"
    for ded in "${DED_ARRAY[@]}"; do
      ded=$(echo "$ded" | xargs)
      [[ -n "$ded" ]] && echo "     • ${ded}"
    done
    echo ""
  fi
}

# ── Run ──
if [[ "$OUTPUT_FORMAT" == "json" && ${#DOMAINS[@]} -gt 1 ]]; then
  echo "["
  for i in "${!DOMAINS[@]}"; do
    scan_domain "${DOMAINS[$i]}"
    [[ $i -lt $((${#DOMAINS[@]} - 1)) ]] && echo ","
  done
  echo "]"
else
  for domain in "${DOMAINS[@]}"; do
    scan_domain "$domain"
  done
fi
