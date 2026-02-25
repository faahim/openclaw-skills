#!/bin/bash
# Certificate Watcher — SSL/TLS certificate expiry monitor
# Usage: certwatch.sh check [--verbose] [--starttls proto] domain[:port]
#        certwatch.sh scan [--file domains.txt] [--warn N] [--critical N] [--alert telegram|slack|webhook] [--format json|text] domain1 domain2 ...

set -euo pipefail

# Defaults
WARN_DAYS="${CERT_WARN_DAYS:-30}"
CRITICAL_DAYS="${CERT_CRITICAL_DAYS:-7}"
TIMEOUT=10
FORMAT="text"
ALERT=""
VERBOSE=false
STARTTLS=""
ALLOW_SELF_SIGNED=false
DOMAINS_FILE=""
DOMAINS=()

# Colors (if terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  GREEN='' YELLOW='' RED='' BOLD='' NC=''
fi

usage() {
  cat <<EOF
Certificate Watcher — Monitor SSL/TLS certificate expiry

Commands:
  check [OPTIONS] DOMAIN[:PORT]    Check a single domain (detailed)
  scan  [OPTIONS] [DOMAINS...]     Scan multiple domains

Options:
  --file FILE        Read domains from file (one per line)
  --warn N           Warning threshold in days (default: $WARN_DAYS)
  --critical N       Critical threshold in days (default: $CRITICAL_DAYS)
  --alert TYPE       Send alerts: telegram, slack, webhook
  --format FORMAT    Output format: text (default), json
  --verbose          Show detailed certificate info
  --starttls PROTO   Use STARTTLS (smtp, imap, pop3, ftp)
  --allow-self-signed  Don't fail on self-signed certs
  --timeout N        Connection timeout in seconds (default: $TIMEOUT)
  -h, --help         Show this help

Environment:
  TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID  — Telegram alerts
  SLACK_WEBHOOK_URL                     — Slack alerts
  CERT_WARN_DAYS, CERT_CRITICAL_DAYS   — Default thresholds
EOF
  exit 0
}

# Get certificate info via openssl
get_cert_info() {
  local domain="$1"
  local port="${2:-443}"
  local starttls_arg=""

  if [ -n "$STARTTLS" ]; then
    starttls_arg="-starttls $STARTTLS"
  fi

  local verify_arg=""
  if $ALLOW_SELF_SIGNED; then
    verify_arg="-verify_quiet"
  fi

  # Connect and get certificate
  local cert
  cert=$(echo | timeout "$TIMEOUT" openssl s_client \
    -connect "${domain}:${port}" \
    -servername "$domain" \
    $starttls_arg \
    $verify_arg \
    2>/dev/null) || {
    echo "ERROR:Connection failed to ${domain}:${port}"
    return 1
  }

  # Extract expiry date
  local not_after
  not_after=$(echo "$cert" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2) || {
    echo "ERROR:Could not parse certificate for ${domain}"
    return 1
  }

  # Calculate days until expiry
  local expiry_epoch
  expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || date -jf "%b %d %T %Y %Z" "$not_after" +%s 2>/dev/null)
  local now_epoch
  now_epoch=$(date +%s)
  local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

  # Get issuer
  local issuer
  issuer=$(echo "$cert" | openssl x509 -noout -issuer 2>/dev/null | sed 's/^issuer=//;s/.*CN *= *//')

  # Get subject
  local subject
  subject=$(echo "$cert" | openssl x509 -noout -subject 2>/dev/null | sed 's/^subject=//;s/.*CN *= *//')

  # Determine status
  local status="ok"
  if [ "$days_left" -le 0 ]; then
    status="expired"
  elif [ "$days_left" -le "$CRITICAL_DAYS" ]; then
    status="critical"
  elif [ "$days_left" -le "$WARN_DAYS" ]; then
    status="warning"
  fi

  # Format expiry date
  local expiry_formatted
  expiry_formatted=$(date -d "$not_after" +%Y-%m-%d 2>/dev/null || date -jf "%b %d %T %Y %Z" "$not_after" +%Y-%m-%d 2>/dev/null)

  if $VERBOSE; then
    # Get additional details
    local not_before
    not_before=$(echo "$cert" | openssl x509 -noout -startdate 2>/dev/null | cut -d= -f2)
    local serial
    serial=$(echo "$cert" | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)
    local sans
    sans=$(echo "$cert" | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -oP 'DNS:\K[^,\s]+' | tr '\n' ', ' | sed 's/,$//')
    local full_issuer
    full_issuer=$(echo "$cert" | openssl x509 -noout -issuer 2>/dev/null | sed 's/^issuer=//')

    echo "VERBOSE:${domain}|${port}|${subject}|${full_issuer}|${not_before}|${not_after}|${days_left}|${serial}|${sans}|${status}|${expiry_formatted}"
  else
    echo "CERT:${domain}|${port}|${days_left}|${expiry_formatted}|${issuer}|${status}"
  fi
}

# Format single cert result for text output
format_text() {
  local line="$1"
  local type="${line%%:*}"
  local data="${line#*:}"

  if [ "$type" = "ERROR" ]; then
    echo -e "${RED}❌ ${data}${NC}"
    return
  fi

  if [ "$type" = "VERBOSE" ]; then
    IFS='|' read -r domain port subject issuer not_before not_after days_left serial sans status expiry <<< "$data"
    local status_icon="✅"
    [ "$status" = "warning" ] && status_icon="⚠️"
    [ "$status" = "critical" ] && status_icon="🚨"
    [ "$status" = "expired" ] && status_icon="💀"

    echo -e "${BOLD}🔒 Certificate Report: ${domain}${NC}"
    echo "   Subject:    ${subject}"
    echo "   Issuer:     ${issuer}"
    echo "   Valid From: ${not_before}"
    echo "   Expires:    ${not_after}"
    echo "   Days Left:  ${days_left}"
    echo "   Serial:     ${serial}"
    [ -n "$sans" ] && echo "   SANs:       ${sans}"
    echo "   Status:     ${status_icon} ${status^^}"
    return
  fi

  IFS='|' read -r domain port days_left expiry issuer status <<< "$data"

  local icon color
  case "$status" in
    ok)       icon="✅"; color="$GREEN" ;;
    warning)  icon="⚠️"; color="$YELLOW" ;;
    critical) icon="🚨"; color="$RED" ;;
    expired)  icon="💀"; color="$RED" ;;
    *)        icon="❓"; color="$NC" ;;
  esac

  printf "${color}${icon} %-25s — Valid %3d days (expires %s) — %s${NC}\n" \
    "$domain" "$days_left" "$expiry" "$issuer"
}

# Format result as JSON object
format_json_line() {
  local line="$1"
  local type="${line%%:*}"
  local data="${line#*:}"

  if [ "$type" = "ERROR" ]; then
    printf '{"domain":"%s","error":true,"message":"%s"}' "unknown" "$data"
    return
  fi

  IFS='|' read -r domain port days_left expiry issuer status <<< "$data"
  printf '{"domain":"%s","port":%s,"valid":%s,"days_left":%s,"expires":"%sT23:59:59Z","issuer":"%s","status":"%s"}' \
    "$domain" "$port" "$([ "$status" != "expired" ] && echo true || echo false)" \
    "$days_left" "$expiry" "$issuer" "$status"
}

# Send alerts
send_alert() {
  local alert_type="$1"
  local message="$2"

  case "$alert_type" in
    telegram)
      if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
        echo "Error: TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be set" >&2
        return 1
      fi
      curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=Markdown" > /dev/null
      ;;
    slack)
      if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
        echo "Error: SLACK_WEBHOOK_URL must be set" >&2
        return 1
      fi
      curl -s -X POST "$SLACK_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"${message}\"}" > /dev/null
      ;;
    webhook)
      if [ -z "${WEBHOOK_URL:-}" ]; then
        echo "Error: WEBHOOK_URL must be set" >&2
        return 1
      fi
      curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"${message}\"}" > /dev/null
      ;;
  esac
}

# Parse domains from file
parse_domains_file() {
  local file="$1"
  while IFS= read -r line; do
    line=$(echo "$line" | sed 's/#.*//' | xargs)
    [ -n "$line" ] && DOMAINS+=("$line")
  done < "$file"
}

# Parse domain:port
parse_domain() {
  local input="$1"
  local domain="${input%%:*}"
  local port="${input##*:}"
  [ "$port" = "$domain" ] && port=443
  echo "${domain}|${port}"
}

# --- Main ---

COMMAND="${1:-}"
[ -z "$COMMAND" ] && usage
shift

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --file)       DOMAINS_FILE="$2"; shift 2 ;;
    --warn)       WARN_DAYS="$2"; shift 2 ;;
    --critical)   CRITICAL_DAYS="$2"; shift 2 ;;
    --alert)      ALERT="$2"; shift 2 ;;
    --format)     FORMAT="$2"; shift 2 ;;
    --verbose)    VERBOSE=true; shift ;;
    --starttls)   STARTTLS="$2"; shift 2 ;;
    --allow-self-signed) ALLOW_SELF_SIGNED=true; shift ;;
    --timeout)    TIMEOUT="$2"; shift 2 ;;
    -h|--help)    usage ;;
    *)            DOMAINS+=("$1"); shift ;;
  esac
done

# Load domains from file if specified
[ -n "$DOMAINS_FILE" ] && parse_domains_file "$DOMAINS_FILE"

# Validate
if [ ${#DOMAINS[@]} -eq 0 ]; then
  echo "Error: No domains specified. Use --file or pass domains as arguments." >&2
  exit 1
fi

# Process based on command
case "$COMMAND" in
  check)
    # Single domain check
    IFS='|' read -r domain port <<< "$(parse_domain "${DOMAINS[0]}")"
    result=$(get_cert_info "$domain" "$port" 2>&1) || true

    if [ "$FORMAT" = "json" ]; then
      echo "[$(format_json_line "$result")]"
    else
      format_text "$result"
    fi
    ;;

  scan)
    # Multi-domain scan
    results=()
    ok=0 warn=0 crit=0 expired=0 errors=0
    alert_lines=()

    if [ "$FORMAT" = "text" ]; then
      echo -e "${BOLD}🔍 Certificate Watcher — Scanning ${#DOMAINS[@]} domains...${NC}"
      echo ""
    fi

    for entry in "${DOMAINS[@]}"; do
      IFS='|' read -r domain port <<< "$(parse_domain "$entry")"
      result=$(get_cert_info "$domain" "$port" 2>&1) || true
      results+=("$result")

      # Count statuses
      local_type="${result%%:*}"
      if [ "$local_type" = "ERROR" ]; then
        errors=$((errors + 1))
      else
        local_data="${result#*:}"
        local_status="${local_data##*|}"
        case "$local_status" in
          ok)       ok=$((ok + 1)) ;;
          warning)  warn=$((warn + 1)); alert_lines+=("$result") ;;
          critical) crit=$((crit + 1)); alert_lines+=("$result") ;;
          expired)  expired=$((expired + 1)); alert_lines+=("$result") ;;
        esac
      fi

      if [ "$FORMAT" = "text" ]; then
        format_text "$result"
      fi
    done

    if [ "$FORMAT" = "json" ]; then
      echo "["
      for i in "${!results[@]}"; do
        [ "$i" -gt 0 ] && echo ","
        format_json_line "${results[$i]}"
      done
      echo ""
      echo "]"
    else
      echo ""
      echo -e "${BOLD}Summary: ${#DOMAINS[@]} scanned | ${ok} OK | ${warn} WARNING | ${crit} CRITICAL | ${expired} EXPIRED | ${errors} ERROR${NC}"
    fi

    # Send alerts if needed
    if [ -n "$ALERT" ] && [ ${#alert_lines[@]} -gt 0 ]; then
      alert_msg="⚠️ Certificate Watcher Alert\n\n"
      for al in "${alert_lines[@]}"; do
        IFS='|' read -r ad ap adays aexp aissuer astatus <<< "${al#*:}"
        alert_msg+="${ad} — expires in ${adays} days (${aexp})\n"
      done
      alert_msg+="\nAction needed: Renew these certificates."
      send_alert "$ALERT" "$(echo -e "$alert_msg")"
      echo ""
      echo "📤 Alert sent via ${ALERT}"
    fi
    ;;

  *)
    echo "Unknown command: $COMMAND"
    echo "Use 'check' or 'scan'. Run with --help for usage."
    exit 1
    ;;
esac
