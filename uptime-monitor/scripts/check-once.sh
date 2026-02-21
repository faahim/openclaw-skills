#!/bin/bash
# Quick one-shot check — useful for cron jobs or OpenClaw agent calls
# Usage: bash check-once.sh <url> [timeout_seconds]

set -euo pipefail

URL="${1:?Usage: check-once.sh <url> [timeout]}"
TIMEOUT="${2:-10}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

start_ms=$(($(date +%s%N) / 1000000))

http_code=$(curl -sS -o /dev/null -w "%{http_code}" \
  --max-time "$TIMEOUT" \
  --connect-timeout "$((TIMEOUT / 2 + 1))" \
  -L "$URL" 2>/dev/null) || http_code="000"

end_ms=$(($(date +%s%N) / 1000000))
elapsed=$((end_ms - start_ms))
timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

# SSL check
host=$(echo "$URL" | sed -E 's|https?://([^/:]+).*|\1|')
ssl_days=""
if [[ "$URL" =~ ^https ]]; then
  expiry=$(echo | openssl s_client -servername "$host" -connect "${host}:443" 2>/dev/null | \
    openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//')
  if [[ -n "$expiry" ]]; then
    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
    now_epoch=$(date +%s)
    ssl_days=$(( (expiry_epoch - now_epoch) / 86400 ))
  fi
fi

# Output JSON for easy parsing
if [[ "$http_code" =~ ^2 ]]; then
  status="up"
  echo -e "${GREEN}✅ ${URL} — ${http_code} OK (${elapsed}ms)${NC}"
else
  status="down"
  echo -e "${RED}❌ ${URL} — ${http_code} FAILED (${elapsed}ms)${NC}"
fi

# Machine-readable output
cat <<EOF
{"url":"${URL}","status":"${status}","http_code":${http_code},"latency_ms":${elapsed},"ssl_days_left":${ssl_days:-null},"checked_at":"${timestamp}"}
EOF
