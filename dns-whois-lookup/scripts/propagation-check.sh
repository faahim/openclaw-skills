#!/bin/bash
# DNS Propagation Check — Verify DNS changes across global nameservers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DNS_TIMEOUT="${DNS_TIMEOUT:-5}"
OUTPUT_JSON=false

# Default propagation servers
DEFAULT_SERVERS=(
  "8.8.8.8:Google"
  "1.1.1.1:Cloudflare"
  "9.9.9.9:Quad9"
  "208.67.222.222:OpenDNS"
  "8.26.56.26:Comodo"
  "4.2.2.1:Level3"
  "64.6.64.6:Verisign"
  "94.140.14.14:AdGuard"
)

while [[ $# -gt 0 ]]; do
  case $1 in
    --json) OUTPUT_JSON=true; shift ;;
    --timeout) DNS_TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: propagation-check.sh [--json] <domain> [record-type]"
      echo "Default record type: A"
      exit 0
      ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) 
      if [[ -z "${DOMAIN:-}" ]]; then
        DOMAIN="$1"
      else
        RTYPE="$1"
      fi
      shift
      ;;
  esac
done

DOMAIN="${DOMAIN:-}"
RTYPE="${RTYPE:-A}"

if [[ -z "$DOMAIN" ]]; then
  echo "Error: No domain specified" >&2
  exit 1
fi

# Load custom servers if file exists
SERVERS=()
if [[ -f "$SCRIPT_DIR/propagation-servers.txt" ]]; then
  while IFS=' ' read -r ip name; do
    [[ -z "$ip" || "$ip" == "#"* ]] && continue
    SERVERS+=("$ip:$name")
  done < "$SCRIPT_DIR/propagation-servers.txt"
fi
[[ ${#SERVERS[@]} -eq 0 ]] && SERVERS=("${DEFAULT_SERVERS[@]}")

# Query each server
CONSISTENT=0
TOTAL=0
FIRST_RESULT=""
RESULTS=()

for entry in "${SERVERS[@]}"; do
  IFS=':' read -r ip name <<< "$entry"
  result=$(dig +short +time="$DNS_TIMEOUT" +tries=1 "@$ip" "$DOMAIN" "$RTYPE" 2>/dev/null | sort | tr '\n' ',' | sed 's/,$//')
  [[ -z "$result" ]] && result="TIMEOUT"
  
  TOTAL=$((TOTAL + 1))
  
  if [[ -z "$FIRST_RESULT" ]]; then
    FIRST_RESULT="$result"
  fi
  
  if [[ "$result" == "$FIRST_RESULT" ]]; then
    CONSISTENT=$((CONSISTENT + 1))
    status="✅"
  else
    status="⚠️"
  fi
  
  RESULTS+=("$ip|$name|$result|$status")
done

if $OUTPUT_JSON; then
  echo "{"
  echo "  \"domain\": \"$DOMAIN\","
  echo "  \"type\": \"$RTYPE\","
  echo "  \"consistent\": $CONSISTENT,"
  echo "  \"total\": $TOTAL,"
  echo "  \"propagated\": $([ $CONSISTENT -eq $TOTAL ] && echo true || echo false),"
  echo "  \"servers\": ["
  first=true
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r ip name result status <<< "$r"
    $first || echo ","
    first=false
    printf '    {"ip":"%s","name":"%s","result":"%s","match":%s}' "$ip" "$name" "$result" "$([ "$status" == "✅" ] && echo true || echo false)"
  done
  echo ""
  echo "  ]"
  echo "}"
else
  echo "── Propagation Check: $DOMAIN ($RTYPE) ──"
  echo ""
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r ip name result status <<< "$r"
    printf "%-10s (%-15s): %-35s %s\n" "$name" "$ip" "$result" "$status"
  done
  echo ""
  if [[ $CONSISTENT -eq $TOTAL ]]; then
    echo "Result: $CONSISTENT/$TOTAL consistent ✅ — Fully propagated"
  else
    echo "Result: $CONSISTENT/$TOTAL consistent ⚠️ — Still propagating"
  fi
fi
