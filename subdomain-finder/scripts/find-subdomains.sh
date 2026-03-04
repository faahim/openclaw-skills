#!/bin/bash
# Subdomain Finder — Multi-technique subdomain enumeration
# Usage: bash find-subdomains.sh <domain> [options]

set -euo pipefail

# Defaults
DOMAIN=""
METHOD="all"  # ct, brute, all
WORDLIST=""
RESOLVE=false
CHECK_HTTP=false
OUTPUT=""
FORMAT="text"  # text, json
DIFF_FILE=""
ALERT=""
DNS_RESOLVER="${DNS_RESOLVER:-8.8.8.8}"
HTTP_TIMEOUT="${HTTP_TIMEOUT:-5}"
MAX_CONCURRENT="${MAX_CONCURRENT:-20}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_WORDLIST="$SCRIPT_DIR/wordlist-top500.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  echo "Usage: $0 <domain> [options]"
  echo ""
  echo "Options:"
  echo "  --method ct|brute|all    Enumeration method (default: all)"
  echo "  --full                   Same as --method all"
  echo "  --wordlist <file>        Custom wordlist for brute force"
  echo "  --resolve                Resolve IPs for found subdomains"
  echo "  --check-http             Check HTTP/HTTPS status codes"
  echo "  --output <file>          Save results to file"
  echo "  --format text|json       Output format (default: text)"
  echo "  --diff <file>            Compare against baseline, show new only"
  echo "  --alert telegram         Send alert on new subdomains (needs env vars)"
  echo "  -h, --help               Show this help"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) usage ;;
    --method) METHOD="$2"; shift 2 ;;
    --full) METHOD="all"; shift ;;
    --wordlist) WORDLIST="$2"; shift 2 ;;
    --resolve) RESOLVE=true; shift ;;
    --check-http) CHECK_HTTP=true; RESOLVE=true; shift ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --diff) DIFF_FILE="$2"; shift 2 ;;
    --alert) ALERT="$2"; shift 2 ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *) DOMAIN="$1"; shift ;;
  esac
done

if [[ -z "$DOMAIN" ]]; then
  echo "Error: Domain is required"
  usage
fi

# Use default wordlist if none specified
[[ -z "$WORDLIST" ]] && WORDLIST="$DEFAULT_WORDLIST"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

ALL_SUBS="$TMPDIR/all-subdomains.txt"
touch "$ALL_SUBS"

# ─── Certificate Transparency (crt.sh) ───────────────────────────
ct_scan() {
  echo -e "${CYAN}[CT]${NC} Querying crt.sh for ${DOMAIN}..."
  
  local response
  response=$(curl -s --max-time 30 "https://crt.sh/?q=%25.${DOMAIN}&output=json" 2>/dev/null || echo "[]")
  
  if [[ "$response" == "[]" || -z "$response" ]]; then
    echo -e "${YELLOW}[CT]${NC} No results from crt.sh (may be rate-limited)"
    return
  fi
  
  # Extract unique subdomain names
  echo "$response" | jq -r '.[].name_value' 2>/dev/null | \
    tr ',' '\n' | \
    sed 's/\*\.//g' | \
    grep -E "\.${DOMAIN//./\\.}$" | \
    sort -u >> "$ALL_SUBS"
  
  local count
  count=$(wc -l < "$ALL_SUBS" | tr -d ' ')
  echo -e "${GREEN}[CT]${NC} Found ${count} unique subdomains"
}

# ─── DNS Brute Force ─────────────────────────────────────────────
brute_scan() {
  if [[ ! -f "$WORDLIST" ]]; then
    echo -e "${RED}[BRUTE]${NC} Wordlist not found: $WORDLIST"
    return
  fi
  
  local total
  total=$(wc -l < "$WORDLIST" | tr -d ' ')
  echo -e "${CYAN}[BRUTE]${NC} Testing ${total} subdomain names against ${DOMAIN}..."
  
  local found=0
  
  # Use xargs for parallel DNS queries
  while IFS= read -r name; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    local fqdn="${name}.${DOMAIN}"
    if dig +short "$fqdn" @"$DNS_RESOLVER" 2>/dev/null | grep -qE '^[0-9]'; then
      echo "$fqdn" >> "$ALL_SUBS"
      ((found++))
    fi
  done < "$WORDLIST"
  
  echo -e "${GREEN}[BRUTE]${NC} Found ${found} resolving subdomains"
}

# ─── Resolve IPs ─────────────────────────────────────────────────
declare -A IP_MAP

resolve_ips() {
  echo -e "${CYAN}[RESOLVE]${NC} Resolving IPs..."
  while IFS= read -r sub; do
    local ip
    ip=$(dig +short "$sub" @"$DNS_RESOLVER" 2>/dev/null | head -1)
    IP_MAP["$sub"]="${ip:-N/A}"
  done < "$TMPDIR/unique-subs.txt"
}

# ─── Check HTTP Status ───────────────────────────────────────────
declare -A HTTP_MAP
declare -A HTTPS_MAP

check_http() {
  echo -e "${CYAN}[HTTP]${NC} Checking HTTP status..."
  while IFS= read -r sub; do
    local ip="${IP_MAP[$sub]:-N/A}"
    [[ "$ip" == "N/A" ]] && { HTTP_MAP["$sub"]="-"; HTTPS_MAP["$sub"]="-"; continue; }
    
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$HTTP_TIMEOUT" "http://${sub}" 2>/dev/null || echo "-")
    [[ "$http_code" == "000" ]] && http_code="-"
    HTTP_MAP["$sub"]="$http_code"
    
    local https_code
    https_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$HTTP_TIMEOUT" -k "https://${sub}" 2>/dev/null || echo "-")
    [[ "$https_code" == "000" ]] && https_code="-"
    HTTPS_MAP["$sub"]="$https_code"
  done < "$TMPDIR/unique-subs.txt"
}

# ─── Diff Against Baseline ───────────────────────────────────────
diff_baseline() {
  if [[ ! -f "$DIFF_FILE" ]]; then
    echo -e "${YELLOW}[DIFF]${NC} No baseline file found. Saving current results as baseline."
    cp "$TMPDIR/unique-subs.txt" "$DIFF_FILE"
    return
  fi
  
  local known
  known=$(wc -l < "$DIFF_FILE" | tr -d ' ')
  echo -e "${CYAN}[DIFF]${NC} Comparing against baseline (${known} known subdomains)..."
  
  local new_subs
  new_subs=$(comm -13 <(sort "$DIFF_FILE") <(sort "$TMPDIR/unique-subs.txt"))
  
  if [[ -z "$new_subs" ]]; then
    echo -e "${GREEN}[DIFF]${NC} No new subdomains detected."
  else
    local new_count
    new_count=$(echo "$new_subs" | wc -l | tr -d ' ')
    echo -e "${RED}[NEW]${NC} ${new_count} new subdomains detected:"
    echo "$new_subs" | while read -r sub; do
      local ip="${IP_MAP[$sub]:-unknown}"
      echo -e "  ${RED}+${NC} ${sub} (${ip})"
    done
    
    # Update baseline
    sort -u "$TMPDIR/unique-subs.txt" > "$DIFF_FILE"
    
    # Alert
    if [[ "$ALERT" == "telegram" ]]; then
      send_telegram_alert "$new_subs" "$new_count"
    fi
  fi
}

# ─── Telegram Alert ──────────────────────────────────────────────
send_telegram_alert() {
  local subs="$1"
  local count="$2"
  
  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    echo -e "${YELLOW}[ALERT]${NC} Telegram credentials not set. Skipping alert."
    return
  fi
  
  local msg="🔍 *Subdomain Alert: ${DOMAIN}*%0A${count} new subdomains found:%0A%0A"
  while IFS= read -r sub; do
    msg+="• \`${sub}\`%0A"
  done <<< "$subs"
  
  curl -s -o /dev/null "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT_ID}&text=${msg}&parse_mode=Markdown"
  echo -e "${GREEN}[ALERT]${NC} Telegram notification sent."
}

# ─── Output Results ──────────────────────────────────────────────
output_results() {
  local total
  total=$(wc -l < "$TMPDIR/unique-subs.txt" | tr -d ' ')
  
  echo ""
  echo -e "${GREEN}RESULTS:${NC} ${total} subdomains found for ${DOMAIN}"
  echo ""
  
  if [[ "$FORMAT" == "json" ]]; then
    output_json "$total"
  else
    output_text "$total"
  fi
}

output_text() {
  local total="$1"
  
  if $CHECK_HTTP; then
    printf "%-35s %-16s %-5s %-5s\n" "SUBDOMAIN" "IP" "HTTP" "HTTPS"
    printf '%.0s─' {1..65}; echo ""
    while IFS= read -r sub; do
      printf "%-35s %-16s %-5s %-5s\n" \
        "$sub" "${IP_MAP[$sub]:-N/A}" "${HTTP_MAP[$sub]:-N/A}" "${HTTPS_MAP[$sub]:-N/A}"
    done < "$TMPDIR/unique-subs.txt"
  elif $RESOLVE; then
    printf "%-35s %-16s\n" "SUBDOMAIN" "IP"
    printf '%.0s─' {1..52}; echo ""
    while IFS= read -r sub; do
      printf "%-35s %-16s\n" "$sub" "${IP_MAP[$sub]:-N/A}"
    done < "$TMPDIR/unique-subs.txt"
  else
    cat "$TMPDIR/unique-subs.txt"
  fi
  
  # Save to file
  if [[ -n "$OUTPUT" ]]; then
    if [[ "$OUTPUT" == *.json ]]; then
      output_json "$total" > "$OUTPUT"
    else
      cp "$TMPDIR/unique-subs.txt" "$OUTPUT"
    fi
    echo ""
    echo -e "Saved to ${OUTPUT}"
  fi
}

output_json() {
  local total="$1"
  
  echo "{"
  echo "  \"domain\": \"${DOMAIN}\","
  echo "  \"scanned_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"total\": ${total},"
  echo "  \"subdomains\": ["
  
  local first=true
  while IFS= read -r sub; do
    $first || echo ","
    first=false
    local ip="${IP_MAP[$sub]:-null}"
    local http="${HTTP_MAP[$sub]:-null}"
    local https="${HTTPS_MAP[$sub]:-null}"
    [[ "$ip" == "N/A" ]] && ip="null" || ip="\"$ip\""
    [[ "$http" == "-" || "$http" == "N/A" ]] && http="null"
    [[ "$https" == "-" || "$https" == "N/A" ]] && https="null"
    printf "    {\"name\": \"%s\", \"ip\": %s, \"http_status\": %s, \"https_status\": %s}" \
      "$sub" "$ip" "$http" "$https"
  done < "$TMPDIR/unique-subs.txt"
  
  echo ""
  echo "  ]"
  echo "}"
}

# ─── Main ─────────────────────────────────────────────────────────

echo -e "${CYAN}━━━ Subdomain Finder ━━━${NC}"
echo -e "Target: ${DOMAIN}"
echo -e "Method: ${METHOD}"
echo ""

# Run selected methods
case $METHOD in
  ct) ct_scan ;;
  brute) brute_scan ;;
  all|full)
    ct_scan
    brute_scan
    ;;
  *) echo "Unknown method: $METHOD"; exit 1 ;;
esac

# Deduplicate
sort -u "$ALL_SUBS" > "$TMPDIR/unique-subs.txt"
local_total=$(wc -l < "$TMPDIR/unique-subs.txt" | tr -d ' ')

if [[ "$local_total" -eq 0 ]]; then
  echo -e "${YELLOW}No subdomains found for ${DOMAIN}${NC}"
  exit 0
fi

echo -e "${CYAN}[MERGE]${NC} ${local_total} unique subdomains after dedup"

# Optional steps
$RESOLVE && resolve_ips
$CHECK_HTTP && check_http

# Diff
[[ -n "$DIFF_FILE" ]] && diff_baseline

# Output
output_results
