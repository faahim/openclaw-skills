#!/bin/bash
# Access Log Analytics — Parse nginx/apache access logs for traffic stats
# Usage: bash access-stats.sh <access.log> [--format json|detailed]

set -euo pipefail

LOG_FILE="${1:-}"
FORMAT="${2:-detailed}"

if [[ -z "$LOG_FILE" || ! -f "$LOG_FILE" ]]; then
  echo "Usage: bash access-stats.sh <access.log> [--format json|detailed]"
  exit 1
fi

BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TOTAL=$(wc -l < "$LOG_FILE")
UNIQUE_IPS=$(awk '{print $1}' "$LOG_FILE" | sort -u | wc -l)

echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          ACCESS LOG ANALYTICS                ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════════╣${NC}"
printf  "${BOLD}║${NC} File: %-39s${BOLD}║${NC}\n" "$LOG_FILE"
printf  "${BOLD}║${NC} Total requests: %-29s${BOLD}║${NC}\n" "$TOTAL"
printf  "${BOLD}║${NC} Unique IPs: %-33s${BOLD}║${NC}\n" "$UNIQUE_IPS"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"

# Status code breakdown
echo ""
echo -e "${BOLD}STATUS CODES${NC}"
echo "────────────────────────────────────────"
awk '{print $9}' "$LOG_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -10 | \
  while read -r count code; do
    [[ -z "$count" ]] && continue
    pct=$(awk "BEGIN {printf \"%.1f\", ($count/$TOTAL)*100}")
    color=$GREEN
    [[ "$code" =~ ^4 ]] && color=$YELLOW
    [[ "$code" =~ ^5 ]] && color=$RED
    printf "  ${color}%s${NC}  %s requests (%s%%)\n" "$code" "$count" "$pct"
  done

# Top paths
echo ""
echo -e "${BOLD}TOP PATHS${NC}"
echo "────────────────────────────────────────"
awk '{print $7}' "$LOG_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -10 | \
  while read -r count path; do
    [[ -z "$count" ]] && continue
    printf "  ${CYAN}%-6s${NC} %s\n" "$count" "$(echo "$path" | head -c 60)"
  done

# Top IPs
echo ""
echo -e "${BOLD}TOP IPs${NC}"
echo "────────────────────────────────────────"
awk '{print $1}' "$LOG_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -10 | \
  while read -r count ip; do
    [[ -z "$count" ]] && continue
    printf "  ${CYAN}%-6s${NC} %s\n" "$count" "$ip"
  done

# Hourly traffic
echo ""
echo -e "${BOLD}HOURLY TRAFFIC${NC}"
echo "────────────────────────────────────────"
awk -F'[' '{print $2}' "$LOG_FILE" 2>/dev/null | \
  grep -oP '\d{2}(?=:\d{2}:\d{2})' | sort | uniq -c | \
  awk '{printf "  %s:00  %-5s ", $2, $1; for(i=0;i<$1/('$TOTAL'/24/2) && i<40;i++) printf "█"; printf "\n"}' | \
  head -24

# Response time stats (if available — field after last ")
echo ""
echo -e "${BOLD}HTTP METHODS${NC}"
echo "────────────────────────────────────────"
awk -F'"' '{print $2}' "$LOG_FILE" 2>/dev/null | awk '{print $1}' | \
  sort | uniq -c | sort -rn | head -5 | \
  while read -r count method; do
    [[ -z "$count" ]] && continue
    printf "  ${CYAN}%-8s${NC} %s requests\n" "$method" "$count"
  done
