#!/usr/bin/env bash
# IP Geolocation & Reputation Checker
# Uses ip-api.com (free, no key) + AbuseIPDB (optional, free tier)
set -euo pipefail

VERSION="1.0.0"
DELAY="${IP_LOOKUP_DELAY:-1.5}"
OUTPUT_FORMAT="${IP_OUTPUT_FORMAT:-table}"
ABUSEIPDB_KEY="${ABUSEIPDB_API_KEY:-}"
ABUSE_MODE=false
BULK_MODE=false
SELF_MODE=false
JSON_MODE=false
RDNS_MODE=false
WHOIS_MODE=false
SCAN_MODE=false
SCAN_FILE=""
THRESHOLD=50
REPORT_FILE=""

usage() {
  cat <<EOF
IP Geolocation & Reputation Checker v${VERSION}

Usage: $(basename "$0") [OPTIONS] <IP|FILE>

Options:
  --abuse         Include AbuseIPDB reputation check (requires ABUSEIPDB_API_KEY)
  --bulk <file>   Bulk lookup from file (one IP per line, or - for stdin)
  --self          Look up your own public IP
  --json          Output raw JSON
  --rdns          Include reverse DNS lookup
  --whois         Include WHOIS summary
  --scan <file>   Extract IPs from log file and check abuse scores
  --threshold <N> Abuse score threshold for --scan (default: 50)
  --report <file> Write scan report to file
  -h, --help      Show this help

Environment:
  ABUSEIPDB_API_KEY   API key for abuse checks (free at abuseipdb.com)
  IP_LOOKUP_DELAY     Seconds between bulk requests (default: 1.5)
  IP_OUTPUT_FORMAT    Output format: table, json, tsv (default: table)
EOF
  exit 0
}

# Parse arguments
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --abuse) ABUSE_MODE=true; shift ;;
    --bulk) BULK_MODE=true; shift; [[ $# -gt 0 ]] && { POSITIONAL+=("$1"); shift; } ;;
    --self) SELF_MODE=true; shift ;;
    --json) JSON_MODE=true; OUTPUT_FORMAT="json"; shift ;;
    --rdns) RDNS_MODE=true; shift ;;
    --whois) WHOIS_MODE=true; shift ;;
    --scan) SCAN_MODE=true; shift; [[ $# -gt 0 ]] && { SCAN_FILE="$1"; shift; } ;;
    --threshold) shift; THRESHOLD="${1:-50}"; shift ;;
    --report) shift; REPORT_FILE="${1:-}"; shift ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

# Validate IP address format
is_valid_ip() {
  local ip="$1"
  [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  local IFS='.'
  read -ra octets <<< "$ip"
  for o in "${octets[@]}"; do
    (( o >= 0 && o <= 255 )) || return 1
  done
  return 0
}

# Check if IP is private/reserved
is_private_ip() {
  local ip="$1"
  local IFS='.'
  read -ra o <<< "$ip"
  # 10.0.0.0/8
  [[ ${o[0]} -eq 10 ]] && return 0
  # 172.16.0.0/12
  [[ ${o[0]} -eq 172 && ${o[1]} -ge 16 && ${o[1]} -le 31 ]] && return 0
  # 192.168.0.0/16
  [[ ${o[0]} -eq 192 && ${o[1]} -eq 168 ]] && return 0
  # 127.0.0.0/8
  [[ ${o[0]} -eq 127 ]] && return 0
  return 1
}

# Geolocation lookup via ip-api.com
geo_lookup() {
  local ip="$1"
  curl -sf "http://ip-api.com/json/${ip}?fields=status,message,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,mobile,proxy,hosting,query" 2>/dev/null
}

# AbuseIPDB check
abuse_check() {
  local ip="$1"
  [[ -z "$ABUSEIPDB_KEY" ]] && { echo '{"error":"No API key"}'; return; }
  curl -sf "https://api.abuseipdb.com/api/v2/check" \
    -H "Key: ${ABUSEIPDB_KEY}" \
    -H "Accept: application/json" \
    -G -d "ipAddress=${ip}&maxAgeInDays=90&verbose" 2>/dev/null
}

# Reverse DNS
rdns_lookup() {
  local ip="$1"
  if command -v host &>/dev/null; then
    host "$ip" 2>/dev/null | grep "domain name pointer" | awk '{print $NF}' | sed 's/\.$//'
  elif command -v dig &>/dev/null; then
    dig +short -x "$ip" 2>/dev/null | sed 's/\.$//'
  else
    echo "(host/dig not installed)"
  fi
}

# WHOIS summary
whois_lookup() {
  local ip="$1"
  if command -v whois &>/dev/null; then
    whois "$ip" 2>/dev/null | grep -iE "^(OrgName|NetName|CIDR|Organization|netname|descr):" | head -5
  else
    echo "(whois not installed)"
  fi
}

# Format table output for a single IP
format_table() {
  local geo="$1"
  local ip="$2"

  local status=$(echo "$geo" | jq -r '.status // "fail"')
  if [[ "$status" != "success" ]]; then
    local msg=$(echo "$geo" | jq -r '.message // "Unknown error"')
    echo "❌ Lookup failed for ${ip}: ${msg}"
    return 1
  fi

  local country=$(echo "$geo" | jq -r '.country // "N/A"')
  local countryCode=$(echo "$geo" | jq -r '.countryCode // "N/A"')
  local city=$(echo "$geo" | jq -r '.city // "N/A"')
  local region=$(echo "$geo" | jq -r '.regionName // "N/A"')
  local lat=$(echo "$geo" | jq -r '.lat // "N/A"')
  local lon=$(echo "$geo" | jq -r '.lon // "N/A"')
  local tz=$(echo "$geo" | jq -r '.timezone // "N/A"')
  local isp=$(echo "$geo" | jq -r '.isp // "N/A"')
  local org=$(echo "$geo" | jq -r '.org // "N/A"')
  local asn=$(echo "$geo" | jq -r '.as // "N/A"')
  local mobile=$(echo "$geo" | jq -r 'if .mobile then "Yes" else "No" end')
  local proxy=$(echo "$geo" | jq -r 'if .proxy then "Yes ⚠️" else "No" end')
  local hosting=$(echo "$geo" | jq -r 'if .hosting then "Yes" else "No" end')

  echo "╔══════════════════════════════════════════════════════╗"
  printf "║  %-50s  ║\n" "IP Geolocation Report: ${ip}"
  echo "╠══════════════════════════════════════════════════════╣"
  printf "║  %-12s %-39s ║\n" "Location:" "${city}, ${region}, ${countryCode}"
  printf "║  %-12s %-39s ║\n" "Country:" "${country}"
  printf "║  %-12s %-39s ║\n" "Coords:" "${lat}, ${lon}"
  printf "║  %-12s %-39s ║\n" "Timezone:" "${tz}"
  printf "║  %-12s %-39s ║\n" "ISP:" "${isp}"
  printf "║  %-12s %-39s ║\n" "Org:" "${org}"
  printf "║  %-12s %-39s ║\n" "AS:" "${asn}"
  printf "║  %-12s %-39s ║\n" "Mobile:" "${mobile}"
  printf "║  %-12s %-39s ║\n" "Proxy/VPN:" "${proxy}"
  printf "║  %-12s %-39s ║\n" "Hosting:" "${hosting}"

  # Reverse DNS
  if $RDNS_MODE; then
    local rdns=$(rdns_lookup "$ip")
    printf "║  %-12s %-39s ║\n" "Reverse DNS:" "${rdns:-N/A}"
  fi

  # WHOIS
  if $WHOIS_MODE; then
    echo "║──────────────────────────────────────────────────────║"
    printf "║  %-50s  ║\n" "WHOIS Info:"
    while IFS= read -r line; do
      printf "║    %-48s  ║\n" "$line"
    done <<< "$(whois_lookup "$ip")"
  fi

  # Abuse check
  if $ABUSE_MODE && [[ -n "$ABUSEIPDB_KEY" ]]; then
    local abuse=$(abuse_check "$ip")
    local score=$(echo "$abuse" | jq -r '.data.abuseConfidenceScore // "N/A"')
    local reports=$(echo "$abuse" | jq -r '.data.totalReports // "0"')
    local last=$(echo "$abuse" | jq -r '.data.lastReportedAt // "Never"')
    local cats=$(echo "$abuse" | jq -r '[.data.reports[]?.categories[]? // empty] | unique | join(", ")' 2>/dev/null || echo "N/A")

    local risk_label="LOW"
    if [[ "$score" =~ ^[0-9]+$ ]]; then
      (( score >= 75 )) && risk_label="HIGH ⚠️"
      (( score >= 25 && score < 75 )) && risk_label="MEDIUM"
    fi

    echo "║──────────────────────────────────────────────────────║"
    printf "║  %-12s %-39s ║\n" "Abuse Score:" "${score}/100 — ${risk_label}"
    printf "║  %-12s %-39s ║\n" "Reports:" "${reports} (last 90 days)"
    printf "║  %-12s %-39s ║\n" "Last Report:" "${last}"
    [[ -n "$cats" && "$cats" != "N/A" ]] && printf "║  %-12s %-39s ║\n" "Categories:" "${cats:0:39}"
  fi

  echo "╚══════════════════════════════════════════════════════╝"
}

# Format TSV line
format_tsv() {
  local geo="$1"
  local ip="$2"
  local abuse_score="-"

  if $ABUSE_MODE && [[ -n "$ABUSEIPDB_KEY" ]]; then
    local abuse=$(abuse_check "$ip")
    abuse_score=$(echo "$abuse" | jq -r '.data.abuseConfidenceScore // "-"')
  fi

  local country=$(echo "$geo" | jq -r '.countryCode // "N/A"')
  local city=$(echo "$geo" | jq -r '.city // "N/A"')
  local isp=$(echo "$geo" | jq -r '.isp // "N/A"')
  local proxy=$(echo "$geo" | jq -r 'if .proxy then "Yes" else "No" end')

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$ip" "$country" "$city" "$isp" "$proxy" "$abuse_score"
}

# Process single IP
process_ip() {
  local ip="$1"

  if is_private_ip "$ip"; then
    echo "⏭️  Skipping private IP: ${ip}"
    return 0
  fi

  if ! is_valid_ip "$ip"; then
    echo "❌ Invalid IP: ${ip}" >&2
    return 1
  fi

  local geo=$(geo_lookup "$ip")

  case "$OUTPUT_FORMAT" in
    json)
      if $ABUSE_MODE && [[ -n "$ABUSEIPDB_KEY" ]]; then
        local abuse=$(abuse_check "$ip")
        echo "$geo" | jq --argjson abuse "$abuse" '. + {abuse: $abuse.data}'
      else
        echo "$geo" | jq .
      fi
      ;;
    tsv)
      format_tsv "$geo" "$ip"
      ;;
    *)
      format_table "$geo" "$ip"
      ;;
  esac
}

# Get own public IP
get_self_ip() {
  curl -sf "https://api.ipify.org" 2>/dev/null || \
  curl -sf "https://ifconfig.me" 2>/dev/null || \
  curl -sf "https://icanhazip.com" 2>/dev/null
}

# ============ Main ============

if $SELF_MODE; then
  MY_IP=$(get_self_ip)
  if [[ -z "$MY_IP" ]]; then
    echo "❌ Could not determine public IP" >&2
    exit 1
  fi
  echo "🌐 Your public IP: ${MY_IP}"
  echo ""
  process_ip "$MY_IP"
  exit 0
fi

if $SCAN_MODE; then
  if [[ -z "$SCAN_FILE" || ! -f "$SCAN_FILE" ]]; then
    echo "❌ Scan file not found: ${SCAN_FILE}" >&2
    exit 1
  fi

  echo "🔍 Scanning ${SCAN_FILE} for IPs..."
  IPS=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$SCAN_FILE" | sort -u)
  TOTAL=$(echo "$IPS" | wc -l)
  echo "   Found ${TOTAL} unique IPs. Checking abuse scores (threshold: ${THRESHOLD})..."
  echo ""

  ABUSE_MODE=true
  if [[ -z "$ABUSEIPDB_KEY" ]]; then
    echo "⚠️  ABUSEIPDB_API_KEY not set — scan requires it for abuse checks" >&2
    exit 1
  fi

  FLAGGED=()
  printf "%-18s %-5s %-20s %-20s %s\n" "IP" "Score" "Country" "ISP" "Status"
  echo "─────────────────────────────────────────────────────────────────────────────"

  while IFS= read -r ip; do
    [[ -z "$ip" ]] && continue
    is_private_ip "$ip" && continue
    is_valid_ip "$ip" || continue

    local_geo=$(geo_lookup "$ip")
    local_abuse=$(abuse_check "$ip")
    score=$(echo "$local_abuse" | jq -r '.data.abuseConfidenceScore // 0')
    country=$(echo "$local_geo" | jq -r '.countryCode // "?"')
    isp=$(echo "$local_geo" | jq -r '.isp // "?"' | cut -c1-20)

    flag=""
    if [[ "$score" =~ ^[0-9]+$ ]] && (( score >= THRESHOLD )); then
      flag="⚠️  FLAGGED"
      FLAGGED+=("$ip (score: $score)")
    fi

    printf "%-18s %-5s %-20s %-20s %s\n" "$ip" "$score" "$country" "$isp" "$flag"
    sleep "$DELAY"
  done <<< "$IPS"

  echo ""
  echo "════════════════════════════════════════"
  echo "  Scan complete. ${#FLAGGED[@]} IPs above threshold (${THRESHOLD})"
  if [[ ${#FLAGGED[@]} -gt 0 ]]; then
    echo ""
    echo "  Flagged IPs:"
    for f in "${FLAGGED[@]}"; do
      echo "    🚨 $f"
    done
  fi
  echo "════════════════════════════════════════"

  if [[ -n "$REPORT_FILE" ]]; then
    {
      echo "IP Scan Report — $(date -u '+%Y-%m-%d %H:%M UTC')"
      echo "Source: ${SCAN_FILE}"
      echo "Threshold: ${THRESHOLD}"
      echo "Flagged: ${#FLAGGED[@]}"
      echo ""
      for f in "${FLAGGED[@]}"; do echo "$f"; done
    } > "$REPORT_FILE"
    echo "  Report saved to: ${REPORT_FILE}"
  fi

  exit 0
fi

if $BULK_MODE; then
  INPUT="${POSITIONAL[0]:--}"
  if [[ "$OUTPUT_FORMAT" == "tsv" ]]; then
    printf "IP\tCountry\tCity\tISP\tProxy\tAbuse_Score\n"
  fi

  if [[ "$INPUT" == "-" ]]; then
    while IFS= read -r ip; do
      [[ -z "$ip" || "$ip" =~ ^# ]] && continue
      ip=$(echo "$ip" | tr -d '[:space:]')
      process_ip "$ip"
      sleep "$DELAY"
    done
  else
    [[ ! -f "$INPUT" ]] && { echo "❌ File not found: ${INPUT}" >&2; exit 1; }
    while IFS= read -r ip; do
      [[ -z "$ip" || "$ip" =~ ^# ]] && continue
      ip=$(echo "$ip" | tr -d '[:space:]')
      process_ip "$ip"
      sleep "$DELAY"
    done < "$INPUT"
  fi
  exit 0
fi

# Single IP mode
if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
  echo "❌ No IP address provided. Use --help for usage." >&2
  exit 1
fi

process_ip "${POSITIONAL[0]}"
