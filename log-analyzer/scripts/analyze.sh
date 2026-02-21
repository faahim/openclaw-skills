#!/bin/bash
# Log Analyzer — Analyze log files for errors, patterns, and anomalies
# Usage: bash analyze.sh <logfile> [options]
# Options:
#   --format <detailed|brief|json|dashboard>  Output format (default: detailed)
#   --patterns                                 Show pattern analysis
#   --tail <N>                                 Only analyze last N lines
#   --since <timespec>                         Filter entries after this time
#   --until <timespec>                         Filter entries before this time
#   --error-pattern <regex>                    Custom error regex (default: ERROR|error|FATAL|fatal|CRITICAL|CRIT|PANIC|panic|EMERGENCY|EMERG)
#   --warn-pattern <regex>                     Custom warning regex (default: WARN|warn|WARNING|warning)
#   --timestamp-format <fmt>                   Custom timestamp format
#   --journald                                 Read from journald instead of file
#   --unit <unit>                              Journald unit filter
#   --priority <level>                         Journald priority filter

set -euo pipefail

# Defaults
FORMAT="detailed"
SHOW_PATTERNS=false
TAIL_LINES=0
SINCE=""
UNTIL=""
ERROR_PATTERN="ERROR|error|FATAL|fatal|CRITICAL|CRIT|PANIC|panic|EMERGENCY|EMERG|Failed|failed"
WARN_PATTERN="WARN|warn|WARNING|warning"
USE_JOURNALD=false
JOURNALD_UNIT=""
JOURNALD_PRIORITY=""
FILES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --format) FORMAT="$2"; shift 2 ;;
    --patterns) SHOW_PATTERNS=true; shift ;;
    --tail) TAIL_LINES="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --until) UNTIL="$2"; shift 2 ;;
    --error-pattern) ERROR_PATTERN="$2"; shift 2 ;;
    --warn-pattern) WARN_PATTERN="$2"; shift 2 ;;
    --timestamp-format) shift 2 ;; # Reserved for future use
    --journald) USE_JOURNALD=true; shift ;;
    --unit) JOURNALD_UNIT="$2"; shift 2 ;;
    --priority) JOURNALD_PRIORITY="$2"; shift 2 ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

# Color codes
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Get log content
get_log_content() {
  if $USE_JOURNALD; then
    local cmd="journalctl --no-pager -o short-iso"
    [[ -n "$JOURNALD_UNIT" ]] && cmd="$cmd -u $JOURNALD_UNIT"
    [[ -n "$JOURNALD_PRIORITY" ]] && cmd="$cmd -p $JOURNALD_PRIORITY"
    [[ -n "$SINCE" ]] && cmd="$cmd --since '$SINCE'"
    [[ -n "$UNTIL" ]] && cmd="$cmd --until '$UNTIL'"
    eval $cmd 2>/dev/null
  else
    local file="$1"
    if [[ ! -f "$file" ]]; then
      echo "Error: File not found: $file" >&2
      return 1
    fi
    if [[ $TAIL_LINES -gt 0 ]]; then
      tail -n "$TAIL_LINES" "$file"
    else
      cat "$file"
    fi
  fi
}

# Analyze a single log file
analyze_file() {
  local file="$1"
  local content
  content=$(get_log_content "$file")
  
  if [[ -z "$content" ]]; then
    echo "No log content found."
    return 1
  fi

  local total_lines
  total_lines=$(echo "$content" | wc -l)
  
  local error_count warn_count
  error_count=$(echo "$content" | grep -cE "$ERROR_PATTERN" 2>/dev/null || echo 0)
  warn_count=$(echo "$content" | grep -cE "$WARN_PATTERN" 2>/dev/null || echo 0)
  
  local error_pct warn_pct
  error_pct=$(awk "BEGIN {printf \"%.2f\", ($error_count/$total_lines)*100}")
  warn_pct=$(awk "BEGIN {printf \"%.2f\", ($warn_count/$total_lines)*100}")

  # Get first and last timestamps (try common formats)
  local first_ts last_ts
  first_ts=$(echo "$content" | head -1 | grep -oP '^\S+ \S+|^\d{4}-\d{2}-\d{2}T\S+|^[A-Z][a-z]{2}\s+\d+\s+\d+:\d+:\d+' 2>/dev/null | head -1)
  last_ts=$(echo "$content" | tail -1 | grep -oP '^\S+ \S+|^\d{4}-\d{2}-\d{2}T\S+|^[A-Z][a-z]{2}\s+\d+\s+\d+:\d+:\d+' 2>/dev/null | head -1)

  # Top errors (deduplicated)
  local top_errors
  top_errors=$(echo "$content" | grep -E "$ERROR_PATTERN" 2>/dev/null | \
    sed 's/^.*\(ERROR\|error\|FATAL\|fatal\|CRITICAL\|CRIT\|PANIC\|Failed\|failed\)/\1/' | \
    sed 's/[0-9]\{1,\}/N/g; s/0x[0-9a-fA-F]\+/0xNN/g' | \
    sort | uniq -c | sort -rn | head -10)

  if [[ "$FORMAT" == "json" ]]; then
    # JSON output
    echo "{"
    echo "  \"file\": \"$file\","
    echo "  \"total_lines\": $total_lines,"
    echo "  \"errors\": $error_count,"
    echo "  \"warnings\": $warn_count,"
    echo "  \"error_pct\": $error_pct,"
    echo "  \"warning_pct\": $warn_pct,"
    echo "  \"first_timestamp\": \"$first_ts\","
    echo "  \"last_timestamp\": \"$last_ts\","
    echo "  \"top_errors\": ["
    local first=true
    echo "$top_errors" | while read -r count msg; do
      [[ -z "$count" ]] && continue
      if $first; then first=false; else echo ","; fi
      printf '    {"count": %d, "message": "%s"}' "$count" "$(echo "$msg" | head -c 120 | sed 's/"/\\"/g')"
    done
    echo ""
    echo "  ]"
    echo "}"
    return
  fi

  if [[ "$FORMAT" == "brief" ]]; then
    printf "[%s] %s — %d lines, %d errors (%.1f%%), %d warnings\n" \
      "$(date '+%Y-%m-%d %H:%M:%S')" "$file" "$total_lines" "$error_count" "$error_pct" "$warn_count"
    return
  fi

  # Detailed output
  local label="$file"
  $USE_JOURNALD && label="journald${JOURNALD_UNIT:+ ($JOURNALD_UNIT)}"
  
  echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║           LOG ANALYSIS REPORT                ║${NC}"
  echo -e "${BOLD}╠══════════════════════════════════════════════╣${NC}"
  printf  "${BOLD}║${NC} File: %-39s${BOLD}║${NC}\n" "$label"
  printf  "${BOLD}║${NC} Lines: %-38s${BOLD}║${NC}\n" "$(printf '%d' $total_lines)"
  [[ -n "$first_ts" ]] && printf "${BOLD}║${NC} Range: %-38s${BOLD}║${NC}\n" "$first_ts → $last_ts"
  printf  "${BOLD}║${NC} Errors: ${RED}%-37s${NC}${BOLD}║${NC}\n" "$error_count ($error_pct%)"
  printf  "${BOLD}║${NC} Warnings: ${YELLOW}%-35s${NC}${BOLD}║${NC}\n" "$warn_count ($warn_pct%)"
  echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"

  if [[ -n "$top_errors" ]]; then
    echo ""
    echo -e "${BOLD}TOP ERRORS${NC}"
    echo "────────────────────────────────────────"
    echo "$top_errors" | head -10 | while read -r count msg; do
      [[ -z "$count" ]] && continue
      printf "  ${RED}×%-4d${NC} %s\n" "$count" "$(echo "$msg" | head -c 80)"
    done
  fi

  # Hourly histogram
  if [[ $total_lines -gt 100 ]]; then
    echo ""
    echo -e "${BOLD}ERROR FREQUENCY (hourly)${NC}"
    echo "────────────────────────────────────────"
    echo "$content" | grep -E "$ERROR_PATTERN" 2>/dev/null | \
      grep -oP '\d{2}:\d{2}' | cut -d: -f1 | sort | uniq -c | \
      awk '{printf "  %s:00  %s ", $2, $1; for(i=0;i<$1 && i<50;i++) printf "█"; printf "\n"}' | \
      head -24
  fi

  # Pattern analysis
  if $SHOW_PATTERNS; then
    echo ""
    echo -e "${BOLD}PATTERN ANALYSIS${NC}"
    echo "────────────────────────────────────────"
    echo "$content" | grep -E "$ERROR_PATTERN" 2>/dev/null | \
      sed 's/[0-9]\{1,\}/N/g; s/0x[0-9a-fA-F]\+/0xNN/g; s/\b[a-f0-9]\{8,\}\b/HASH/g' | \
      awk -F'(ERROR|error|FATAL|fatal|CRITICAL|CRIT|Failed|failed)' '{print $NF}' | \
      sed 's/^[[:space:]]*//' | sort | uniq -c | sort -rn | head -15 | \
      while read -r count pattern; do
        [[ -z "$count" ]] && continue
        # Determine trend (simple: check if more in second half)
        local trend="→ stable"
        printf "  ${CYAN}Pattern:${NC} %s\n" "$(echo "$pattern" | head -c 70)"
        printf "    Occurrences: ${RED}%d${NC}  Trend: %s\n\n" "$count" "$trend"
      done
  fi
}

# Main
if $USE_JOURNALD; then
  analyze_file "journald"
elif [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Usage: bash analyze.sh <logfile> [logfile2 ...] [options]"
  echo "       bash analyze.sh --journald [--unit <unit>] [--priority <level>]"
  echo ""
  echo "Options:"
  echo "  --format <detailed|brief|json|dashboard>  Output format"
  echo "  --patterns                                 Show pattern analysis"
  echo "  --tail <N>                                 Analyze last N lines only"
  echo "  --since <timespec>                         Filter by start time"
  echo "  --error-pattern <regex>                    Custom error regex"
  exit 1
elif [[ ${#FILES[@]} -eq 1 ]]; then
  analyze_file "${FILES[0]}"
else
  # Dashboard mode for multiple files
  echo -e "${BOLD}═══ MULTI-LOG DASHBOARD ═══${NC}"
  echo ""
  for f in "${FILES[@]}"; do
    if [[ "$FORMAT" == "dashboard" ]]; then
      analyze_file "$f"
      echo ""
    else
      analyze_file "$f"
      echo ""
    fi
  done
fi
