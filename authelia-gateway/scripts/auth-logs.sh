#!/bin/bash
set -euo pipefail

# Authelia Auth Log Viewer
# View and filter authentication events

CONTAINER="authelia"
TAIL=50
FAILED_ONLY=false
SINCE=""
SUMMARY=false
DATE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --tail) TAIL="$2"; shift 2 ;;
    --failed) FAILED_ONLY=true; shift ;;
    --since) SINCE="$2"; shift 2 ;;
    --summary) SUMMARY=true; shift ;;
    --date) DATE="$2"; shift 2 ;;
    --container) CONTAINER="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: bash scripts/auth-logs.sh [options]"
      echo "  --tail <n>        Number of lines (default: 50)"
      echo "  --failed          Show only failed attempts"
      echo "  --since <time>    Filter since (e.g., '1 hour ago')"
      echo "  --summary         Show summary statistics"
      echo "  --date <date>     Filter by date (today, yesterday, YYYY-MM-DD)"
      exit 0
      ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# Resolve date
if [[ "$DATE" == "today" ]]; then
  DATE=$(date +%Y-%m-%d)
elif [[ "$DATE" == "yesterday" ]]; then
  DATE=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)
fi

# Build docker logs command
LOG_CMD="docker logs $CONTAINER --tail $TAIL"
if [[ -n "$SINCE" ]]; then
  LOG_CMD="docker logs $CONTAINER --since \"$SINCE\""
fi

if $SUMMARY; then
  echo "📊 Authelia Auth Summary"
  echo "========================"
  
  LOGS=$(eval "$LOG_CMD" 2>&1)
  
  if [[ -n "$DATE" ]]; then
    LOGS=$(echo "$LOGS" | grep "$DATE" || true)
  fi
  
  TOTAL=$(echo "$LOGS" | grep -c "method=\|level=" || echo "0")
  SUCCESSFUL=$(echo "$LOGS" | grep -ci "successful\|1FA\|2FA" || echo "0")
  FAILED=$(echo "$LOGS" | grep -ci "failed\|unsuccessful\|banned" || echo "0")
  BANNED=$(echo "$LOGS" | grep -ci "banned\|regulation" || echo "0")
  
  echo "Total events:     $TOTAL"
  echo "Successful:       $SUCCESSFUL"
  echo "Failed:           $FAILED"
  echo "Banned IPs:       $BANNED"
  
  if [[ "$FAILED" -gt 0 ]]; then
    echo ""
    echo "⚠️  Recent failed attempts:"
    echo "$LOGS" | grep -i "failed\|unsuccessful" | tail -5
  fi
else
  if $FAILED_ONLY; then
    eval "$LOG_CMD" 2>&1 | grep -i "failed\|unsuccessful\|banned\|invalid" | \
      { [[ -n "$DATE" ]] && grep "$DATE" || cat; } | tail -"$TAIL"
  else
    eval "$LOG_CMD" 2>&1 | \
      { [[ -n "$DATE" ]] && grep "$DATE" || cat; }
  fi
fi
