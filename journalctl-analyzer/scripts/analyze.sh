#!/bin/bash
# Journalctl Analyzer — Parse systemd logs for errors, security events, and service health
# Usage: bash analyze.sh [--mode services|security|resources|quick|full|watch] [--since "TIME"] [--format text|json]

set -euo pipefail

# Defaults
MODE="full"
SINCE="24 hours ago"
UNTIL=""
FORMAT="text"
OUTPUT=""
UNIT=""
BOOT=""
MAX_LINES="${JOURNAL_MAX_LINES:-50000}"
MIN_PRIORITY="${JOURNAL_MIN_PRIORITY:-err}"
ALERT_CMD=""
IGNORE_FILE="${HOME}/.config/journalctl-analyzer/ignore.txt"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --mode) MODE="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --until) UNTIL="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --unit) UNIT="$2"; shift 2 ;;
    --boot) BOOT="--boot"; shift ;;
    --max-lines) MAX_LINES="$2"; shift 2 ;;
    --alert-cmd) ALERT_CMD="$2"; shift 2 ;;
    --alert) ALERT_CMD="$2"; shift 2 ;;
    --quick) MODE="quick"; shift ;;
    -h|--help) echo "Usage: analyze.sh [--mode services|security|resources|quick|full|watch] [--since TIME] [--format text|json] [--output FILE]"; exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# Build journalctl command
build_journal_cmd() {
  local cmd="journalctl --no-pager -q"
  [[ -n "$BOOT" ]] && cmd+=" $BOOT"
  [[ -z "$BOOT" ]] && cmd+=" --since '$SINCE'"
  [[ -n "$UNTIL" ]] && cmd+=" --until '$UNTIL'"
  [[ -n "$UNIT" ]] && {
    IFS=',' read -ra UNITS <<< "$UNIT"
    for u in "${UNITS[@]}"; do
      cmd+=" -u $u"
    done
  }
  echo "$cmd"
}

# Apply ignore patterns
filter_ignored() {
  if [[ -f "$IGNORE_FILE" ]]; then
    grep -vEf <(grep -v '^#' "$IGNORE_FILE" | grep -v '^$') 2>/dev/null || cat
  else
    cat
  fi
}

# ── Service Health ──
analyze_services() {
  local journal_cmd
  journal_cmd=$(build_journal_cmd)

  echo -e "${BOLD}=== Service Health Report ===${NC}"
  echo ""

  # Failed services
  echo -e "${RED}FAILED SERVICES:${NC}"
  eval "$journal_cmd" -p err..emerg -o json 2>/dev/null | head -n "$MAX_LINES" | filter_ignored | \
    jq -r 'select(._SYSTEMD_UNIT != null) | ._SYSTEMD_UNIT' 2>/dev/null | \
    sort | uniq -c | sort -rn | head -20 | while read -r count unit; do
      last_ts=$(eval "$journal_cmd -u '$unit' -p err..emerg -n 1 -o json" 2>/dev/null | jq -r '.__REALTIME_TIMESTAMP' 2>/dev/null | head -1)
      if [[ -n "$last_ts" && "$last_ts" != "null" ]]; then
        last_date=$(date -d @"${last_ts:0:10}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
      else
        last_date="unknown"
      fi
      printf "  %-35s — %d errors (last: %s)\n" "$unit" "$count" "$last_date"
    done
  echo ""

  # Services that restarted frequently
  echo -e "${YELLOW}RESTARTED SERVICES (>2 restarts):${NC}"
  eval "$journal_cmd" -o json 2>/dev/null | head -n "$MAX_LINES" | \
    jq -r 'select(.MESSAGE != null) | select(.MESSAGE | test("Started |Stopped ")) | ._SYSTEMD_UNIT // "unknown"' 2>/dev/null | \
    sort | uniq -c | sort -rn | awk '$1 > 2 {printf "  %-35s — %d start/stop events\n", $2, $1}' | head -15
  echo ""

  # High-frequency error messages
  echo -e "${CYAN}HIGH-FREQUENCY ERRORS (top 10):${NC}"
  eval "$journal_cmd" -p err..emerg 2>/dev/null | head -n "$MAX_LINES" | filter_ignored | \
    sed 's/[0-9]\{1,\}/*/g' | sort | uniq -c | sort -rn | head -10 | \
    while read -r count msg; do
      printf "  %6d × %s\n" "$count" "$(echo "$msg" | cut -c1-100)"
    done
  echo ""
}

# ── Security Audit ──
analyze_security() {
  local journal_cmd
  journal_cmd=$(build_journal_cmd)

  echo -e "${BOLD}=== Security Audit ===${NC}"
  echo ""

  # SSH brute force
  echo -e "${RED}SSH FAILED LOGINS:${NC}"
  eval "$journal_cmd -u sshd" 2>/dev/null | head -n "$MAX_LINES" | \
    grep -i "failed password\|invalid user\|authentication failure" | filter_ignored | \
    grep -oP 'from \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
    sort | uniq -c | sort -rn | head -10 | while read -r count ip; do
      printf "  %-20s — %d failed attempts\n" "$ip" "$count"
    done
  echo ""

  # Sudo events
  echo -e "${YELLOW}SUDO EVENTS:${NC}"
  eval "$journal_cmd" 2>/dev/null | head -n "$MAX_LINES" | \
    grep -i "sudo\[" | filter_ignored | \
    grep -oP 'COMMAND=\K.*' | sort | uniq -c | sort -rn | head -10 | \
    while read -r count cmd; do
      # Flag suspicious commands
      if echo "$cmd" | grep -qiE 'rm -rf|chmod 777|passwd|shadow|visudo'; then
        printf "  %4d × %s ${RED}⚠️  SUSPICIOUS${NC}\n" "$count" "$(echo "$cmd" | cut -c1-80)"
      else
        printf "  %4d × %s ${GREEN}✅${NC}\n" "$count" "$(echo "$cmd" | cut -c1-80)"
      fi
    done
  echo ""

  # Auth failures
  echo -e "${CYAN}PAM AUTH FAILURES:${NC}"
  eval "$journal_cmd" 2>/dev/null | head -n "$MAX_LINES" | \
    grep -i "pam.*authentication failure\|pam.*auth.*fail" | filter_ignored | \
    grep -oP 'user=\K\S+' | sort | uniq -c | sort -rn | head -10 | \
    while read -r count user; do
      printf "  user '%s' — %d failures\n" "$user" "$count"
    done
  echo ""
}

# ── Resource Analysis ──
analyze_resources() {
  local journal_cmd
  journal_cmd=$(build_journal_cmd)

  echo -e "${BOLD}=== Resource Analysis ===${NC}"
  echo ""

  # OOM kills
  echo -e "${RED}OOM KILLS:${NC}"
  oom_count=0
  eval "$journal_cmd -k" 2>/dev/null | head -n "$MAX_LINES" | \
    grep -i "out of memory\|oom-kill\|killed process" | filter_ignored | \
    tail -20 | while read -r line; do
      echo "  $line"
      oom_count=$((oom_count + 1))
    done
  [[ $oom_count -eq 0 ]] && echo "  None detected ✅"
  echo ""

  # Disk pressure
  echo -e "${YELLOW}DISK PRESSURE:${NC}"
  disk_issues=$(eval "$journal_cmd" 2>/dev/null | head -n "$MAX_LINES" | \
    grep -ci "no space left on device\|disk full\|filesystem.*full" || echo "0")
  if [[ "$disk_issues" -gt 0 ]]; then
    echo "  \"No space left on device\" — ${disk_issues} occurrences"
  else
    echo "  None detected ✅"
  fi
  echo ""

  # Kernel errors
  echo -e "${CYAN}KERNEL ERRORS:${NC}"
  eval "$journal_cmd -k -p err..emerg" 2>/dev/null | head -n "$MAX_LINES" | filter_ignored | \
    sed 's/[0-9]\{1,\}/*/g' | sort | uniq -c | sort -rn | head -10 | \
    while read -r count msg; do
      printf "  %4d × %s\n" "$count" "$(echo "$msg" | cut -c1-100)"
    done
  echo ""
}

# ── Quick Check ──
quick_check() {
  local journal_cmd
  journal_cmd=$(build_journal_cmd)

  echo -e "${BOLD}=== Quick Health Check (since: $SINCE) ===${NC}"
  echo ""

  # Count by priority
  for prio in emerg alert crit err warning; do
    count=$(eval "$journal_cmd -p $prio" 2>/dev/null | wc -l)
    case $prio in
      emerg|alert|crit) color=$RED ;;
      err) color=$YELLOW ;;
      *) color=$CYAN ;;
    esac
    printf "  ${color}%-10s${NC} %d entries\n" "$prio:" "$count"
  done
  echo ""

  # Failed systemd units right now
  echo -e "${RED}Currently failed units:${NC}"
  systemctl --failed --no-legend 2>/dev/null | while read -r line; do
    echo "  ❌ $line"
  done || echo "  All units OK ✅"
  echo ""

  # Recent critical
  echo -e "${YELLOW}Last 5 critical/error entries:${NC}"
  eval "$journal_cmd -p err..emerg -n 5" 2>/dev/null | while read -r line; do
    echo "  $line"
  done
  echo ""
}

# ── Watch Mode ──
watch_mode() {
  echo -e "${BOLD}=== Live Log Watch (Ctrl+C to stop) ===${NC}"
  echo "Watching for: errors, OOM, auth failures, service crashes"
  echo ""

  local cmd="journalctl -f -p err..emerg --no-pager -q"
  [[ -n "$UNIT" ]] && {
    IFS=',' read -ra UNITS <<< "$UNIT"
    for u in "${UNITS[@]}"; do
      cmd+=" -u $u"
    done
  }

  eval "$cmd" | while read -r line; do
    filtered=$(echo "$line" | filter_ignored)
    [[ -z "$filtered" ]] && continue

    echo -e "${RED}[!]${NC} $line"

    if [[ -n "$ALERT_CMD" ]]; then
      MESSAGE="$line" eval "$ALERT_CMD" 2>/dev/null &
    fi
  done
}

# ── JSON Output ──
output_json() {
  local journal_cmd
  journal_cmd=$(build_journal_cmd)

  local tmpdir
  tmpdir=$(mktemp -d)

  # Collect data
  failed_services=$(eval "$journal_cmd -p err..emerg -o json" 2>/dev/null | head -n "$MAX_LINES" | \
    jq -r 'select(._SYSTEMD_UNIT != null) | ._SYSTEMD_UNIT' 2>/dev/null | \
    sort | uniq -c | sort -rn | head -20 | awk '{print "{\"unit\":\""$2"\",\"errors\":"$1"}"}' | \
    jq -s '.' 2>/dev/null || echo "[]")

  oom_kills=$(eval "$journal_cmd -k" 2>/dev/null | head -n "$MAX_LINES" | \
    grep -ci "out of memory\|oom-kill\|killed process" 2>/dev/null || true)
  oom_kills=${oom_kills:-0}
  oom_kills=$(echo "$oom_kills" | tr -d '[:space:]')

  ssh_failures=$(eval "$journal_cmd -u sshd" 2>/dev/null | head -n "$MAX_LINES" | \
    grep -ci "failed password\|invalid user" 2>/dev/null || true)
  ssh_failures=${ssh_failures:-0}
  ssh_failures=$(echo "$ssh_failures" | tr -d '[:space:]')

  total_errors=$(eval "$journal_cmd -p err..emerg" 2>/dev/null | wc -l | tr -d '[:space:]')
  total_warnings=$(eval "$journal_cmd -p warning" 2>/dev/null | wc -l | tr -d '[:space:]')

  currently_failed=$(systemctl --failed --no-legend 2>/dev/null | awk '{print $1}' | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null || echo "[]")

  jq -n \
    --arg gen "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg since "$SINCE" \
    --arg until "${UNTIL:-now}" \
    --argjson errors "$total_errors" \
    --argjson warnings "$total_warnings" \
    --argjson ooms "$oom_kills" \
    --argjson ssh "$ssh_failures" \
    --argjson services "$failed_services" \
    --argjson failed "$currently_failed" \
    '{
      generated_at: $gen,
      period: {since: $since, until: $until},
      summary: {total_errors: $errors, total_warnings: $warnings, oom_kills: $ooms, ssh_failures: $ssh},
      failed_services: $services,
      currently_failed: $failed
    }'

  rm -rf "$tmpdir"
}

# ── Telegram Alert ──
send_telegram_alert() {
  local message="$1"
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="$TELEGRAM_CHAT_ID" \
      -d text="$message" \
      -d parse_mode="Markdown" > /dev/null 2>&1
  fi
}

# ── Main ──
main() {
  # Check journalctl exists
  if ! command -v journalctl &>/dev/null; then
    echo "Error: journalctl not found. This tool requires a systemd-based Linux system."
    exit 1
  fi

  if [[ "$FORMAT" == "json" ]]; then
    result=$(output_json)
    if [[ -n "$OUTPUT" ]]; then
      echo "$result" > "$OUTPUT"
      echo "Report saved to $OUTPUT"
    else
      echo "$result" | jq .
    fi

    # Alert if critical issues found
    if [[ "$ALERT_CMD" == "telegram" ]]; then
      errors=$(echo "$result" | jq '.summary.total_errors')
      ooms=$(echo "$result" | jq '.summary.oom_kills')
      if [[ "$errors" -gt 100 || "$ooms" -gt 0 ]]; then
        send_telegram_alert "🚨 *Journal Alert*: ${errors} errors, ${ooms} OOM kills in last period"
      fi
    fi
    return
  fi

  case $MODE in
    quick) quick_check ;;
    services) analyze_services ;;
    security) analyze_security ;;
    resources) analyze_resources ;;
    watch) watch_mode ;;
    full)
      quick_check
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      analyze_services
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      analyze_security
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      analyze_resources
      ;;
    *) echo "Unknown mode: $MODE"; exit 1 ;;
  esac

  if [[ -n "$OUTPUT" ]]; then
    echo "Note: Use --format json for file output"
  fi
}

main
