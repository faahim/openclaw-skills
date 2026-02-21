#!/bin/bash
# Uptime Monitor — Check URLs/APIs, alert on downtime
# Usage: bash monitor.sh [options]
# Requires: curl, jq, bash 4+

set -euo pipefail

# Defaults
CONFIG_FILE=""
SINGLE_URL=""
INTERVAL=300
TIMEOUT=10
ALERT_TYPE=""
EXPECT_STATUS="2"  # 2xx
EXPECT_BODY=""
CHECK_SSL=false
SSL_WARN_DAYS=30
LOG_FILE=""
MAX_LOG_LINES=10000
CONSECUTIVE_FAILS=0
ALERT_THRESHOLD=2
ALERT_SENT=false
DAEMON=false
STATE_DIR="${HOME}/.uptime-monitor"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  cat <<EOF
Uptime Monitor — Monitor URLs and APIs, alert on downtime

USAGE:
  bash monitor.sh --url <url> [options]
  bash monitor.sh --config <file.json> [options]

SINGLE URL MODE:
  --url <url>           URL to monitor
  --interval <sec>      Check interval in seconds (default: 300)
  --timeout <sec>       Request timeout in seconds (default: 10)
  --expect-status <N>   Expected HTTP status prefix (default: 2 for 2xx)
  --expect-body <str>   Expected string in response body
  --check-ssl           Check SSL certificate expiry
  --ssl-warn <days>     Alert if SSL expires within N days (default: 30)
  --alert <type>        Alert type: telegram, webhook, email, script
  --log <file>          Log results to file
  --threshold <N>       Consecutive failures before alerting (default: 2)
  --daemon              Run as background daemon

CONFIG MODE:
  --config <file>       JSON config file with multiple monitors

ALERT ENVIRONMENT VARIABLES:
  TELEGRAM_BOT_TOKEN    Telegram bot token
  TELEGRAM_CHAT_ID      Telegram chat ID
  WEBHOOK_URL           Webhook URL for alerts
  SMTP_HOST/SMTP_PORT   SMTP server for email alerts
  SMTP_USER/SMTP_PASS   SMTP credentials
  ALERT_EMAIL           Destination email
  ALERT_SCRIPT          Path to custom alert script

EXAMPLES:
  # Monitor a URL every 5 minutes
  bash monitor.sh --url https://example.com --interval 300

  # Monitor with Telegram alerts
  export TELEGRAM_BOT_TOKEN="123:ABC"
  export TELEGRAM_CHAT_ID="456"
  bash monitor.sh --url https://example.com --alert telegram

  # Monitor API with body check
  bash monitor.sh --url https://api.example.com/health --expect-body '"status":"ok"'

  # Check SSL expiry
  bash monitor.sh --url https://example.com --check-ssl --ssl-warn 30

  # Use config file for multiple URLs
  bash monitor.sh --config monitors.json
EOF
  exit 0
}

log_msg() {
  local timestamp
  timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
  local msg="[$timestamp] $1"
  echo -e "$msg"
  if [[ -n "$LOG_FILE" ]]; then
    echo "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    # Rotate log
    if [[ -f "$LOG_FILE" ]]; then
      local lines
      lines=$(wc -l < "$LOG_FILE")
      if (( lines > MAX_LOG_LINES )); then
        tail -n "$((MAX_LOG_LINES / 2))" "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
      fi
    fi
  fi
}

send_alert() {
  local subject="$1"
  local body="$2"
  local alert_type="${3:-$ALERT_TYPE}"

  case "$alert_type" in
    telegram)
      if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        log_msg "${YELLOW}⚠ Telegram alert skipped — TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set${NC}"
        return 1
      fi
      curl -sf -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="🚨 ${subject}
${body}" \
        -d parse_mode="HTML" > /dev/null 2>&1 || true
      log_msg "${GREEN}📤 Telegram alert sent${NC}"
      ;;
    webhook)
      if [[ -z "${WEBHOOK_URL:-}" ]]; then
        log_msg "${YELLOW}⚠ Webhook alert skipped — WEBHOOK_URL not set${NC}"
        return 1
      fi
      curl -sf -X POST "${WEBHOOK_URL}" \
        -H "Content-Type: application/json" \
        -d "{\"subject\":\"${subject}\",\"body\":\"${body}\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > /dev/null 2>&1 || true
      log_msg "${GREEN}📤 Webhook alert sent${NC}"
      ;;
    email)
      if [[ -z "${SMTP_HOST:-}" || -z "${ALERT_EMAIL:-}" ]]; then
        log_msg "${YELLOW}⚠ Email alert skipped — SMTP_HOST or ALERT_EMAIL not set${NC}"
        return 1
      fi
      # Use curl for SMTP
      curl -sf --url "smtp://${SMTP_HOST}:${SMTP_PORT:-587}" \
        --ssl-reqd \
        --mail-from "${SMTP_USER}" \
        --mail-rcpt "${ALERT_EMAIL}" \
        --user "${SMTP_USER}:${SMTP_PASS}" \
        -T <(echo -e "Subject: ${subject}\nFrom: ${SMTP_USER}\nTo: ${ALERT_EMAIL}\n\n${body}") > /dev/null 2>&1 || true
      log_msg "${GREEN}📤 Email alert sent${NC}"
      ;;
    script)
      if [[ -n "${ALERT_SCRIPT:-}" && -x "${ALERT_SCRIPT}" ]]; then
        "${ALERT_SCRIPT}" "${subject}" "${body}" || true
        log_msg "${GREEN}📤 Custom script alert sent${NC}"
      fi
      ;;
    *)
      # No alert configured, just log
      ;;
  esac
}

check_url() {
  local url="$1"
  local timeout="${2:-$TIMEOUT}"
  local expect_status="${3:-$EXPECT_STATUS}"
  local expect_body="${4:-$EXPECT_BODY}"

  local start_ms
  start_ms=$(($(date +%s%N) / 1000000))

  local tmpfile
  tmpfile=$(mktemp)

  local http_code
  http_code=$(curl -sS -o "$tmpfile" -w "%{http_code}" \
    --max-time "$timeout" \
    --connect-timeout "$((timeout / 2 + 1))" \
    -L "$url" 2>/dev/null) || http_code="000"

  local end_ms
  end_ms=$(($(date +%s%N) / 1000000))
  local elapsed=$((end_ms - start_ms))

  local status="up"
  local reason=""

  # Check HTTP status
  if [[ "$http_code" == "000" ]]; then
    status="down"
    reason="TIMEOUT/CONNECTION_FAILED"
  elif [[ ! "$http_code" =~ ^${expect_status} ]]; then
    status="down"
    reason="HTTP_${http_code}"
  fi

  # Check body if expected
  if [[ "$status" == "up" && -n "$expect_body" ]]; then
    if ! grep -q "$expect_body" "$tmpfile" 2>/dev/null; then
      status="down"
      reason="BODY_MISMATCH"
    fi
  fi

  rm -f "$tmpfile"

  if [[ "$status" == "up" ]]; then
    log_msg "${GREEN}✅ ${url} — ${http_code} OK (${elapsed}ms)${NC}"
  else
    log_msg "${RED}❌ ${url} — ${reason} (${elapsed}ms)${NC}"
  fi

  echo "${status}|${http_code}|${elapsed}|${reason}"
}

check_ssl() {
  local url="$1"
  local warn_days="${2:-$SSL_WARN_DAYS}"

  local host
  host=$(echo "$url" | sed -E 's|https?://([^/:]+).*|\1|')

  local expiry
  expiry=$(echo | openssl s_client -servername "$host" -connect "${host}:443" 2>/dev/null | \
    openssl x509 -noout -enddate 2>/dev/null | \
    sed 's/notAfter=//')

  if [[ -z "$expiry" ]]; then
    log_msg "${RED}❌ SSL check failed for ${host} — could not retrieve certificate${NC}"
    echo "error|0"
    return
  fi

  local expiry_epoch
  expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry" +%s 2>/dev/null)
  local now_epoch
  now_epoch=$(date +%s)
  local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

  if (( days_left < 0 )); then
    log_msg "${RED}❌ SSL EXPIRED for ${host} — expired ${days_left#-} days ago${NC}"
    echo "expired|${days_left}"
  elif (( days_left < warn_days )); then
    log_msg "${YELLOW}⚠️ SSL WARNING for ${host} — expires in ${days_left} days (${expiry})${NC}"
    echo "warning|${days_left}"
  else
    log_msg "${GREEN}🔐 SSL OK for ${host} — valid for ${days_left} days (${expiry})${NC}"
    echo "ok|${days_left}"
  fi
}

# State management for alert deduplication
mkdir -p "$STATE_DIR"

get_state() {
  local key
  key=$(echo "$1" | md5sum | cut -d' ' -f1)
  cat "${STATE_DIR}/${key}" 2>/dev/null || echo "0|false"
}

set_state() {
  local key
  key=$(echo "$1" | md5sum | cut -d' ' -f1)
  echo "$2" > "${STATE_DIR}/${key}"
}

monitor_single() {
  local url="$1"
  log_msg "🔍 Monitoring ${url} every ${INTERVAL}s (timeout: ${TIMEOUT}s)"

  while true; do
    local result
    result=$(check_url "$url" "$TIMEOUT" "$EXPECT_STATUS" "$EXPECT_BODY")
    local status
    status=$(echo "$result" | cut -d'|' -f1)

    local state
    state=$(get_state "$url")
    local fails
    fails=$(echo "$state" | cut -d'|' -f1)
    local alerted
    alerted=$(echo "$state" | cut -d'|' -f2)

    if [[ "$status" == "down" ]]; then
      fails=$((fails + 1))
      if (( fails >= ALERT_THRESHOLD )) && [[ "$alerted" != "true" ]]; then
        local reason
        reason=$(echo "$result" | cut -d'|' -f4)
        send_alert "DOWN: ${url}" "Status: ${reason}\nConsecutive failures: ${fails}\nThreshold: ${ALERT_THRESHOLD}"
        alerted="true"
      fi
      set_state "$url" "${fails}|${alerted}"
    else
      if [[ "$alerted" == "true" ]]; then
        send_alert "RECOVERED: ${url}" "Service is back up after ${fails} consecutive failures."
        log_msg "${GREEN}🎉 ${url} recovered after ${fails} failures${NC}"
      fi
      set_state "$url" "0|false"
    fi

    if [[ "$CHECK_SSL" == true ]]; then
      local ssl_result
      ssl_result=$(check_ssl "$url" "$SSL_WARN_DAYS")
      local ssl_status
      ssl_status=$(echo "$ssl_result" | cut -d'|' -f1)
      local ssl_days
      ssl_days=$(echo "$ssl_result" | cut -d'|' -f2)

      if [[ "$ssl_status" == "expired" || "$ssl_status" == "warning" ]]; then
        send_alert "SSL ${ssl_status^^}: ${url}" "Days remaining: ${ssl_days}"
      fi
    fi

    sleep "$INTERVAL"
  done
}

monitor_config() {
  local config="$1"

  if [[ ! -f "$config" ]]; then
    echo "Error: Config file not found: $config"
    exit 1
  fi

  local count
  count=$(jq '.monitors | length' "$config")
  log_msg "📋 Loading ${count} monitors from ${config}"

  for i in $(seq 0 $((count - 1))); do
    local url interval timeout expect_status expect_body check_ssl_flag alert_type
    url=$(jq -r ".monitors[$i].url" "$config")
    interval=$(jq -r ".monitors[$i].interval // 300" "$config")
    timeout=$(jq -r ".monitors[$i].timeout // 10" "$config")
    expect_status=$(jq -r ".monitors[$i].expect_status // \"2\"" "$config")
    expect_body=$(jq -r ".monitors[$i].expect_body // \"\"" "$config")
    check_ssl_flag=$(jq -r ".monitors[$i].check_ssl // false" "$config")
    alert_type=$(jq -r ".monitors[$i].alert // \"${ALERT_TYPE}\"" "$config")

    (
      INTERVAL="$interval"
      TIMEOUT="$timeout"
      EXPECT_STATUS="$expect_status"
      EXPECT_BODY="$expect_body"
      CHECK_SSL="$check_ssl_flag"
      ALERT_TYPE="$alert_type"
      monitor_single "$url"
    ) &

    log_msg "  → Started monitor for ${url} (every ${interval}s)"
  done

  log_msg "✅ All monitors running. Press Ctrl+C to stop."
  wait
}

# Parse arguments
[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h) usage ;;
    --url) SINGLE_URL="$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --expect-status) EXPECT_STATUS="$2"; shift 2 ;;
    --expect-body) EXPECT_BODY="$2"; shift 2 ;;
    --check-ssl) CHECK_SSL=true; shift ;;
    --ssl-warn) SSL_WARN_DAYS="$2"; shift 2 ;;
    --alert) ALERT_TYPE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --threshold) ALERT_THRESHOLD="$2"; shift 2 ;;
    --daemon) DAEMON=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate
if [[ -z "$SINGLE_URL" && -z "$CONFIG_FILE" ]]; then
  echo "Error: Specify --url or --config"
  exit 1
fi

# Run
if [[ -n "$CONFIG_FILE" ]]; then
  if [[ "$DAEMON" == true ]]; then
    monitor_config "$CONFIG_FILE" &
    echo "Monitor daemon started (PID: $!)"
  else
    monitor_config "$CONFIG_FILE"
  fi
else
  if [[ "$DAEMON" == true ]]; then
    monitor_single "$SINGLE_URL" &
    echo "Monitor daemon started (PID: $!)"
  else
    monitor_single "$SINGLE_URL"
  fi
fi
