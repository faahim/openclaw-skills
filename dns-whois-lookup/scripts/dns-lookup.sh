#!/bin/bash
# DNS Lookup Tool — Query DNS records for any domain
set -euo pipefail

# Defaults
DNS_SERVER="${DNS_SERVER:-}"
DNS_TIMEOUT="${DNS_TIMEOUT:-5}"
OUTPUT_JSON=false
RECORD_TYPE="ALL"
REVERSE_MODE=false
COMPARE_MODE=false
NS1=""
NS2=""

usage() {
  cat <<EOF
Usage: dns-lookup.sh [OPTIONS] <domain>

Options:
  --type TYPE     Record type: A, AAAA, MX, TXT, CNAME, NS, SOA, CAA (default: ALL)
  --all           Show all record types (same as default)
  --json          Output as JSON
  --reverse IP    Reverse DNS lookup (PTR record)
  --compare       Compare DNS across two nameservers
  --ns1 IP        First nameserver for compare mode
  --ns2 IP        Second nameserver for compare mode
  --server IP     Use specific DNS server
  --timeout SEC   Query timeout (default: 5)
  -h, --help      Show this help

Examples:
  dns-lookup.sh example.com
  dns-lookup.sh --type MX gmail.com
  dns-lookup.sh --json example.com
  dns-lookup.sh --reverse 93.184.216.34
  dns-lookup.sh --compare example.com --ns1 8.8.8.8 --ns2 1.1.1.1
EOF
  exit 0
}

# Parse arguments
DOMAIN=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --type) RECORD_TYPE="${2^^}"; shift 2 ;;
    --all) RECORD_TYPE="ALL"; shift ;;
    --json) OUTPUT_JSON=true; shift ;;
    --reverse) REVERSE_MODE=true; DOMAIN="$2"; shift 2 ;;
    --compare) COMPARE_MODE=true; shift ;;
    --ns1) NS1="$2"; shift 2 ;;
    --ns2) NS2="$2"; shift 2 ;;
    --server) DNS_SERVER="$2"; shift 2 ;;
    --timeout) DNS_TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) DOMAIN="$1"; shift ;;
  esac
done

if [[ -z "$DOMAIN" ]]; then
  echo "Error: No domain specified" >&2
  usage
fi

# Build dig command with optional server
dig_cmd() {
  local server_arg=""
  if [[ -n "${1:-}" ]]; then
    server_arg="@${1}"
  elif [[ -n "$DNS_SERVER" ]]; then
    server_arg="@${DNS_SERVER}"
  fi
  dig +short +time="$DNS_TIMEOUT" +tries=2 $server_arg "${@:2}" 2>/dev/null || echo ""
}

# Query a specific record type
query_record() {
  local domain="$1"
  local type="$2"
  local server="${3:-}"
  dig_cmd "$server" "$domain" "$type"
}

# Reverse DNS
if $REVERSE_MODE; then
  PTR=$(dig_cmd "" "-x" "$DOMAIN")
  if $OUTPUT_JSON; then
    echo "{\"ip\":\"$DOMAIN\",\"ptr\":\"${PTR:-null}\"}"
  else
    echo "── Reverse DNS: $DOMAIN ──"
    if [[ -n "$PTR" ]]; then
      echo "PTR: $DOMAIN → $PTR"
    else
      echo "No PTR record found"
    fi
  fi
  exit 0
fi

# Compare mode
if $COMPARE_MODE; then
  if [[ -z "$NS1" || -z "$NS2" ]]; then
    echo "Error: --compare requires --ns1 and --ns2" >&2
    exit 1
  fi
  echo "── DNS Compare: $DOMAIN ──"
  echo ""
  printf "%-8s %-35s %-35s\n" "Type" "NS1 ($NS1)" "NS2 ($NS2)"
  printf "%-8s %-35s %-35s\n" "────" "───────────────────" "───────────────────"
  for type in A AAAA MX TXT CNAME NS; do
    r1=$(query_record "$DOMAIN" "$type" "$NS1" | tr '\n' ',' | sed 's/,$//')
    r2=$(query_record "$DOMAIN" "$type" "$NS2" | tr '\n' ',' | sed 's/,$//')
    [[ -z "$r1" ]] && r1="(none)"
    [[ -z "$r2" ]] && r2="(none)"
    match=""
    [[ "$r1" == "$r2" ]] && match="" || match=" ⚠️"
    printf "%-8s %-35s %-35s%s\n" "$type" "${r1:0:34}" "${r2:0:34}" "$match"
  done
  exit 0
fi

# Determine record types to query
if [[ "$RECORD_TYPE" == "ALL" ]]; then
  TYPES=(A AAAA MX TXT CNAME NS SOA CAA)
else
  TYPES=("$RECORD_TYPE")
fi

# Collect results
declare -A RESULTS
for type in "${TYPES[@]}"; do
  RESULTS[$type]=$(query_record "$DOMAIN" "$type")
done

# JSON output
if $OUTPUT_JSON; then
  json="{"
  json+="\"domain\":\"$DOMAIN\""
  for type in "${TYPES[@]}"; do
    values="${RESULTS[$type]}"
    json+=",\"$(echo "$type" | tr '[:upper:]' '[:lower:]')\":"
    if [[ -z "$values" ]]; then
      json+="[]"
    else
      json+="["
      first=true
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        $first || json+=","
        first=false
        # Escape quotes in value
        line="${line//\\/\\\\}"
        line="${line//\"/\\\"}"
        json+="\"$line\""
      done <<< "$values"
      json+="]"
    fi
  done
  json+="}"
  if command -v jq &>/dev/null; then
    echo "$json" | jq .
  else
    echo "$json"
  fi
  exit 0
fi

# Pretty output
echo "╔══════════════════════════════════════════╗"
printf "║  DNS Report: %-27s ║\n" "$DOMAIN"
echo "╚══════════════════════════════════════════╝"
echo ""

for type in "${TYPES[@]}"; do
  values="${RESULTS[$type]}"
  echo "── $type Records ──"
  if [[ -z "$values" ]]; then
    echo "(none)"
  else
    echo "$values"
  fi
  echo ""
done

# Show TTL for A record
TTL=$(dig +noall +answer +time="$DNS_TIMEOUT" ${DNS_SERVER:+@$DNS_SERVER} "$DOMAIN" A 2>/dev/null | awk '{print $2}' | head -1)
if [[ -n "$TTL" ]]; then
  echo "── TTL ──"
  echo "A record TTL: ${TTL}s"
  if [[ "$TTL" -lt 300 ]]; then
    echo "⚠️ Very low TTL — likely in migration or using dynamic DNS"
  elif [[ "$TTL" -gt 86400 ]]; then
    echo "ℹ️ High TTL (>24h) — DNS changes will propagate slowly"
  fi
fi
