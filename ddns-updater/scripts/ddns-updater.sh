#!/usr/bin/env bash
# DDNS Updater — Automatically update DNS records when your public IP changes
# Supports: Cloudflare, DuckDNS, Namecheap, Generic Webhook
set -uo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
PROVIDER=""
DOMAIN=""
ZONE=""
CONFIG=""
INTERVAL=0
DAEMON=false
FORCE=false
DRY_RUN=false
IPV6=false
ALERT=""
WEBHOOK_URL=""
IP_OVERRIDE=""
IP_CHECK_URL="${DDNS_IP_CHECK_URL:-https://api.ipify.org}"
IP_CACHE_FILE="${DDNS_IP_CACHE:-/tmp/ddns-last-ip}"
LOG_FILE="${DDNS_LOG_FILE:-}"
ALL_PROVIDERS=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo -e "$msg"
  [[ -n "$LOG_FILE" ]] && echo -e "$msg" >> "$LOG_FILE"
}

usage() {
  cat <<EOF
DDNS Updater v${VERSION}

Usage: $(basename "$0") [OPTIONS]

Options:
  --provider <name>      DNS provider (cloudflare|duckdns|namecheap|webhook)
  --domain <domain>      Domain/subdomain to update
  --zone <zone>          Zone/root domain (for namecheap)
  --config <file>        YAML config file path
  --all                  Update all providers in config
  --interval <sec>       Check interval in seconds (daemon mode)
  --daemon               Run continuously
  --force                Force update even if IP unchanged
  --dry-run              Preview changes without updating
  --ipv6                 Use IPv6 instead of IPv4
  --alert <type>         Alert on change (telegram|webhook)
  --webhook-url <url>    Webhook URL for generic provider
  --ip <addr>            Use specific IP instead of auto-detect
  --ip-source <cmd>      Custom command to get IP
  --log <file>           Log file path
  --help                 Show this help
  --version              Show version

Environment Variables:
  CF_API_TOKEN           Cloudflare API token
  CF_ZONE_ID             Cloudflare Zone ID
  DUCKDNS_TOKEN          DuckDNS token
  NAMECHEAP_PASSWORD     Namecheap DDNS password
  TELEGRAM_BOT_TOKEN     Telegram bot token (for alerts)
  TELEGRAM_CHAT_ID       Telegram chat ID (for alerts)
  DDNS_IP_CHECK_URL      Custom IP check URL (default: https://api.ipify.org)
  DDNS_IP_CACHE          IP cache file path (default: /tmp/ddns-last-ip)
  DDNS_LOG_FILE          Log file path

Examples:
  # Cloudflare one-shot
  $(basename "$0") --provider cloudflare --domain home.example.com

  # DuckDNS daemon mode
  $(basename "$0") --provider duckdns --domain myhost --interval 300 --daemon

  # Cron job with alerts
  $(basename "$0") --provider cloudflare --domain home.example.com --alert telegram
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --provider) PROVIDER="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --zone) ZONE="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --all) ALL_PROVIDERS=true; shift ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --daemon) DAEMON=true; shift ;;
    --force) FORCE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --ipv6) IPV6=true; shift ;;
    --alert) ALERT="$2"; shift 2 ;;
    --webhook-url) WEBHOOK_URL="$2"; shift 2 ;;
    --ip) IP_OVERRIDE="$2"; shift 2 ;;
    --ip-source) IP_CHECK_URL="custom"; IP_SOURCE_CMD="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --help) usage ;;
    --version) echo "DDNS Updater v${VERSION}"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Get current public IP
get_public_ip() {
  local ip=""
  if [[ -n "$IP_OVERRIDE" ]]; then
    ip="$IP_OVERRIDE"
  elif [[ "$IP_CHECK_URL" == "custom" ]]; then
    ip=$(eval "$IP_SOURCE_CMD" 2>/dev/null)
  elif [[ "$IPV6" == true ]]; then
    ip=$(curl -s -6 --max-time 10 "https://api6.ipify.org" 2>/dev/null)
  else
    # Try multiple sources
    for url in "$IP_CHECK_URL" "https://ifconfig.me" "https://icanhazip.com" "https://ipinfo.io/ip"; do
      ip=$(curl -s --max-time 10 "$url" 2>/dev/null | tr -d '[:space:]')
      [[ -n "$ip" ]] && break
    done
  fi

  if [[ -z "$ip" ]]; then
    log "❌ Failed to detect public IP"
    return 1
  fi

  echo "$ip"
}

# Get cached IP
get_cached_ip() {
  local cache_key="${1:-default}"
  local cache_file="${IP_CACHE_FILE}.${cache_key}"
  [[ -f "$cache_file" ]] && cat "$cache_file" || echo ""
}

# Save IP to cache
save_cached_ip() {
  local ip="$1"
  local cache_key="${2:-default}"
  local cache_file="${IP_CACHE_FILE}.${cache_key}"
  mkdir -p "$(dirname "$cache_file")"
  echo "$ip" > "$cache_file"
}

# Send alert
send_alert() {
  local message="$1"

  if [[ "$ALERT" == "telegram" ]]; then
    local token="${TELEGRAM_BOT_TOKEN:-}"
    local chat_id="${TELEGRAM_CHAT_ID:-}"
    if [[ -n "$token" && -n "$chat_id" ]]; then
      curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${message}" \
        -d "parse_mode=HTML" > /dev/null 2>&1
      log "📨 Alert sent to Telegram"
    else
      log "⚠️ Telegram alert configured but TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set"
    fi
  elif [[ "$ALERT" == "webhook" && -n "$WEBHOOK_URL" ]]; then
    curl -s -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"${message}\"}" > /dev/null 2>&1
    log "📨 Alert sent to webhook"
  fi
}

# === Provider: Cloudflare ===
update_cloudflare() {
  local domain="$1"
  local ip="$2"
  local token="${CF_API_TOKEN:-}"
  local zone_id="${CF_ZONE_ID:-}"

  if [[ -z "$token" || -z "$zone_id" ]]; then
    log "❌ Cloudflare: CF_API_TOKEN and CF_ZONE_ID required"
    return 1
  fi

  # Get record ID
  local response
  response=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=A&name=${domain}" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json")

  local record_id
  record_id=$(echo "$response" | jq -r '.result[0].id // empty')
  local current_ip
  current_ip=$(echo "$response" | jq -r '.result[0].content // empty')

  if [[ -z "$record_id" ]]; then
    # Try AAAA for IPv6
    if [[ "$IPV6" == true ]]; then
      response=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=AAAA&name=${domain}" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json")
      record_id=$(echo "$response" | jq -r '.result[0].id // empty')
      current_ip=$(echo "$response" | jq -r '.result[0].content // empty')
    fi

    if [[ -z "$record_id" ]]; then
      log "❌ Cloudflare: Record not found for ${domain}. Create it first in the dashboard."
      return 1
    fi
  fi

  log "📝 DNS record ${domain} points to ${current_ip}"

  if [[ "$current_ip" == "$ip" && "$FORCE" != true ]]; then
    log "✅ ${domain} already points to ${ip} — no update needed"
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log "${YELLOW}[DRY RUN]${NC} Would update ${domain} → ${ip}"
    return 0
  fi

  local record_type="A"
  [[ "$IPV6" == true ]] && record_type="AAAA"

  local update_response
  update_response=$(curl -s -X PUT \
    "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"${record_type}\",\"name\":\"${domain}\",\"content\":\"${ip}\",\"ttl\":1,\"proxied\":false}")

  local success
  success=$(echo "$update_response" | jq -r '.success')

  if [[ "$success" == "true" ]]; then
    log "${GREEN}✅ Updated ${domain} → ${ip}${NC}"
    send_alert "🔄 DDNS Updated: ${domain} → ${ip} (was ${current_ip})"
    return 0
  else
    local errors
    errors=$(echo "$update_response" | jq -r '.errors[0].message // "Unknown error"')
    log "${RED}❌ Cloudflare update failed: ${errors}${NC}"
    return 1
  fi
}

# === Provider: DuckDNS ===
update_duckdns() {
  local domain="$1"
  local ip="$2"
  local token="${DUCKDNS_TOKEN:-}"

  if [[ -z "$token" ]]; then
    log "❌ DuckDNS: DUCKDNS_TOKEN required"
    return 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log "${YELLOW}[DRY RUN]${NC} Would update ${domain}.duckdns.org → ${ip}"
    return 0
  fi

  local ip_param="ip=${ip}"
  [[ "$IPV6" == true ]] && ip_param="ipv6=${ip}"

  local response
  response=$(curl -s "https://www.duckdns.org/update?domains=${domain}&token=${token}&${ip_param}")

  if [[ "$response" == "OK" ]]; then
    log "${GREEN}✅ Updated ${domain}.duckdns.org → ${ip}${NC}"
    send_alert "🔄 DDNS Updated: ${domain}.duckdns.org → ${ip}"
    return 0
  else
    log "${RED}❌ DuckDNS update failed: ${response}${NC}"
    return 1
  fi
}

# === Provider: Namecheap ===
update_namecheap() {
  local domain="$1"
  local ip="$2"
  local password="${NAMECHEAP_PASSWORD:-}"
  local zone="${ZONE:-}"

  if [[ -z "$password" || -z "$zone" ]]; then
    log "❌ Namecheap: NAMECHEAP_PASSWORD and --zone required"
    return 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log "${YELLOW}[DRY RUN]${NC} Would update ${domain}.${zone} → ${ip}"
    return 0
  fi

  local response
  response=$(curl -s "https://dynamicdns.park-your-domain.com/update?host=${domain}&domain=${zone}&password=${password}&ip=${ip}")

  if echo "$response" | grep -q "<ErrCount>0</ErrCount>"; then
    log "${GREEN}✅ Updated ${domain}.${zone} → ${ip}${NC}"
    send_alert "🔄 DDNS Updated: ${domain}.${zone} → ${ip}"
    return 0
  else
    local err
    err=$(echo "$response" | grep -oP '<Err1>\K[^<]+' || echo "Unknown error")
    log "${RED}❌ Namecheap update failed: ${err}${NC}"
    return 1
  fi
}

# === Provider: Generic Webhook ===
update_webhook() {
  local domain="$1"
  local ip="$2"

  if [[ -z "$WEBHOOK_URL" ]]; then
    log "❌ Webhook: --webhook-url required"
    return 1
  fi

  local url="${WEBHOOK_URL//\{IP\}/$ip}"
  url="${url//\{DOMAIN\}/$domain}"

  if [[ "$DRY_RUN" == true ]]; then
    log "${YELLOW}[DRY RUN]${NC} Would call: ${url}"
    return 0
  fi

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$url")

  if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    log "${GREEN}✅ Webhook update successful (HTTP ${http_code})${NC}"
    return 0
  else
    log "${RED}❌ Webhook failed (HTTP ${http_code})${NC}"
    return 1
  fi
}

# Route to provider
update_dns() {
  local provider="$1"
  local domain="$2"
  local ip="$3"

  case "$provider" in
    cloudflare) update_cloudflare "$domain" "$ip" ;;
    duckdns) update_duckdns "$domain" "$ip" ;;
    namecheap) update_namecheap "$domain" "$ip" ;;
    webhook) update_webhook "$domain" "$ip" ;;
    *) log "❌ Unknown provider: ${provider}"; return 1 ;;
  esac
}

# Main update cycle
run_update() {
  local ip
  ip=$(get_public_ip) || return 1
  log "🔍 Current IP: ${ip}"

  local cache_key="${PROVIDER}-${DOMAIN}"
  local cached_ip
  cached_ip=$(get_cached_ip "$cache_key")

  if [[ "$ip" == "$cached_ip" && "$FORCE" != true ]]; then
    log "ℹ️  IP unchanged (${ip}) — skipping update"
    return 0
  fi

  if update_dns "$PROVIDER" "$DOMAIN" "$ip"; then
    save_cached_ip "$ip" "$cache_key"
  fi
}

# Validate inputs
if [[ -z "$PROVIDER" && -z "$CONFIG" ]]; then
  echo "Error: --provider or --config required. Use --help for usage."
  exit 1
fi

if [[ -z "$DOMAIN" && -z "$CONFIG" ]]; then
  echo "Error: --domain required. Use --help for usage."
  exit 1
fi

# Run
if [[ "$DAEMON" == true && "$INTERVAL" -gt 0 ]]; then
  log "🚀 DDNS Updater v${VERSION} — daemon mode (interval: ${INTERVAL}s)"
  log "   Provider: ${PROVIDER} | Domain: ${DOMAIN}"
  while true; do
    run_update || true
    sleep "$INTERVAL"
  done
else
  run_update
fi
