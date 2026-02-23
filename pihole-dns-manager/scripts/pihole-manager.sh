#!/bin/bash
# Pi-hole DNS Manager — Management Script
# Manage blocklists, whitelist/blacklist, stats, backup/restore, alerts

set -euo pipefail

PIHOLE_HOST="${PIHOLE_HOST:-http://localhost}"
PIHOLE_API_KEY="${PIHOLE_API_KEY:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
BACKUP_DIR="${HOME}/pihole-backups"

# ─── Helpers ───────────────────────────────────────────

api_get() {
  local endpoint="$1"
  if [[ -n "$PIHOLE_API_KEY" ]]; then
    curl -s "${PIHOLE_HOST}/admin/api.php?${endpoint}&auth=${PIHOLE_API_KEY}"
  else
    curl -s "${PIHOLE_HOST}/admin/api.php?${endpoint}"
  fi
}

send_telegram() {
  local msg="$1"
  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "text=${msg}" \
      -d "parse_mode=HTML" >/dev/null 2>&1
    echo "📨 Report sent to Telegram"
  else
    echo "⚠️  Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID for Telegram alerts"
  fi
}

require_pihole() {
  if ! command -v pihole &>/dev/null; then
    echo "❌ Pi-hole is not installed. Run: bash scripts/install.sh"
    exit 1
  fi
}

require_sudo() {
  if [[ $EUID -ne 0 ]]; then
    echo "❌ This command requires root/sudo"
    exit 1
  fi
}

# ─── Commands ──────────────────────────────────────────

cmd_status() {
  require_pihole
  local data
  data=$(api_get "summaryRaw")

  local status domains_blocked dns_queries ads_blocked ads_pct
  status=$(echo "$data" | jq -r '.status // "unknown"')
  domains_blocked=$(echo "$data" | jq -r '.domains_being_blocked // 0')
  dns_queries=$(echo "$data" | jq -r '.dns_queries_today // 0')
  ads_blocked=$(echo "$data" | jq -r '.ads_blocked_today // 0')
  ads_pct=$(echo "$data" | jq -r '.ads_percentage_today // 0')

  local status_icon="❌ Disabled"
  [[ "$status" == "enabled" ]] && status_icon="✅ Active (blocking)"

  local ip
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')

  echo "🛡️ Pi-hole Status"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "Status:                %s\n" "$status_icon"
  printf "Domains on blocklist:  %s\n" "$domains_blocked"
  printf "DNS queries today:     %s\n" "$dns_queries"
  printf "Queries blocked:       %s (%.1f%%)\n" "$ads_blocked" "$ads_pct"
  printf "Web interface:         http://%s/admin\n" "${ip:-localhost}"

  # FTL version
  if command -v pihole &>/dev/null; then
    local ver
    ver=$(pihole -v -c 2>/dev/null | head -1 || echo "unknown")
    printf "Version:               %s\n" "$ver"
  fi
}

cmd_stats() {
  require_pihole
  local json_mode=false
  [[ "${1:-}" == "--json" ]] && json_mode=true

  local data
  data=$(api_get "summaryRaw")

  if $json_mode; then
    echo "$data" | jq .
  else
    cmd_status
  fi
}

cmd_top_blocked() {
  require_pihole
  local count="${1:-10}"
  local data
  data=$(api_get "topItems=${count}")
  echo "🚫 Top ${count} Blocked Domains"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$data" | jq -r '.top_ads | to_entries | sort_by(-.value) | .[] | "\(.value)\t\(.key)"' 2>/dev/null || echo "No data (check API key)"
}

cmd_top_permitted() {
  require_pihole
  local count="${1:-10}"
  local data
  data=$(api_get "topItems=${count}")
  echo "✅ Top ${count} Permitted Domains"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$data" | jq -r '.top_queries | to_entries | sort_by(-.value) | .[] | "\(.value)\t\(.key)"' 2>/dev/null || echo "No data (check API key)"
}

cmd_top_clients() {
  require_pihole
  local data
  data=$(api_get "getQuerySources&auth=${PIHOLE_API_KEY}")
  echo "📱 Top Clients"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$data" | jq -r '.top_sources | to_entries | sort_by(-.value) | .[:10] | .[] | "\(.value)\t\(.key)"' 2>/dev/null || echo "No data (check API key)"
}

cmd_query_log() {
  require_pihole
  local domain="${1:-}"
  [[ -z "$domain" ]] && { echo "Usage: pihole-manager.sh query-log <domain>"; exit 1; }
  echo "🔍 Query log for: ${domain}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
  pihole -q "$domain" 2>/dev/null || echo "No results"
}

cmd_blocklists() {
  require_pihole
  echo "📋 Current Blocklists"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
  sqlite3 /etc/pihole/gravity.db "SELECT id, address, enabled, number FROM adlist;" 2>/dev/null | while IFS='|' read -r id addr enabled count; do
    local icon="✅"
    [[ "$enabled" == "0" ]] && icon="❌"
    printf "%s [%s] %s (%s domains)\n" "$icon" "$id" "$addr" "${count:-?}"
  done || pihole -q -adlist 2>/dev/null || echo "Could not read blocklists"
}

cmd_blocklist_add() {
  require_pihole
  require_sudo
  local url="${1:-}"
  [[ -z "$url" ]] && { echo "Usage: pihole-manager.sh blocklist-add <url>"; exit 1; }
  sqlite3 /etc/pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, enabled) VALUES ('${url}', 1);" 2>/dev/null
  echo "✅ Added blocklist: ${url}"
  echo "Run 'pihole-manager.sh gravity-update' to apply"
}

cmd_blocklist_pack() {
  require_pihole
  require_sudo
  local pack="${1:-}"
  case "$pack" in
    malware)
      cmd_blocklist_add "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
      cmd_blocklist_add "https://urlhaus.abuse.ch/downloads/hostfile/"
      cmd_blocklist_add "https://malware-filter.gitlab.io/malware-filter/phishing-filter-hosts.txt"
      ;;
    tracking)
      cmd_blocklist_add "https://v.firebog.net/hosts/Easyprivacy.txt"
      cmd_blocklist_add "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
      cmd_blocklist_add "https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt"
      ;;
    social)
      cmd_blocklist_add "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/social/hosts"
      ;;
    ads-aggressive)
      cmd_blocklist_add "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
      cmd_blocklist_add "https://v.firebog.net/hosts/AdguardDNS.txt"
      cmd_blocklist_add "https://adaway.org/hosts.txt"
      cmd_blocklist_add "https://v.firebog.net/hosts/Easylist.txt"
      ;;
    *)
      echo "Available packs: malware, tracking, social, ads-aggressive"
      exit 1
      ;;
  esac
  echo ""
  echo "🔄 Run 'pihole-manager.sh gravity-update' to apply changes"
}

cmd_gravity_update() {
  require_pihole
  require_sudo
  echo "🔄 Updating gravity (this may take a minute)..."
  pihole -g
  echo "✅ Gravity updated"
}

cmd_whitelist() {
  require_pihole
  local domain="${1:-}"
  [[ -z "$domain" ]] && { echo "Usage: pihole-manager.sh whitelist <domain>"; exit 1; }
  pihole -w "$domain"
  echo "✅ Whitelisted: ${domain}"
}

cmd_whitelist_file() {
  require_pihole
  local file="${1:-}"
  [[ ! -f "$file" ]] && { echo "File not found: ${file}"; exit 1; }
  while IFS= read -r domain; do
    [[ -n "$domain" && ! "$domain" =~ ^# ]] && pihole -w "$domain"
  done < "$file"
  echo "✅ Whitelisted domains from ${file}"
}

cmd_whitelist_show() {
  require_pihole
  echo "✅ Whitelisted Domains"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
  pihole -w -l 2>/dev/null || sqlite3 /etc/pihole/gravity.db "SELECT domain FROM domainlist WHERE type=0;" 2>/dev/null
}

cmd_whitelist_remove() {
  require_pihole
  local domain="${1:-}"
  pihole -w -d "$domain"
  echo "✅ Removed from whitelist: ${domain}"
}

cmd_blacklist() {
  require_pihole
  local domain="${1:-}"
  [[ -z "$domain" ]] && { echo "Usage: pihole-manager.sh blacklist <domain>"; exit 1; }
  pihole -b "$domain"
  echo "✅ Blacklisted: ${domain}"
}

cmd_blacklist_show() {
  require_pihole
  echo "🚫 Blacklisted Domains"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
  pihole -b -l 2>/dev/null || sqlite3 /etc/pihole/gravity.db "SELECT domain FROM domainlist WHERE type=1;" 2>/dev/null
}

cmd_blacklist_remove() {
  require_pihole
  local domain="${1:-}"
  pihole -b -d "$domain"
  echo "✅ Removed from blacklist: ${domain}"
}

cmd_enable() {
  require_pihole
  pihole enable
  echo "✅ Pi-hole blocking enabled"
}

cmd_disable() {
  require_pihole
  local duration="${1:-}"
  if [[ -n "$duration" ]]; then
    # Parse duration (5m, 1h, 30s)
    local seconds
    case "$duration" in
      *m) seconds=$(( ${duration%m} * 60 )) ;;
      *h) seconds=$(( ${duration%h} * 3600 )) ;;
      *s) seconds="${duration%s}" ;;
      *)  seconds="$duration" ;;
    esac
    pihole disable "${seconds}s"
    echo "⏸️ Pi-hole disabled for ${duration}"
  else
    pihole disable
    echo "⏸️ Pi-hole disabled indefinitely. Run 'enable' to re-enable."
  fi
}

cmd_daily_report() {
  require_pihole
  local data
  data=$(api_get "summaryRaw")

  local dns_queries ads_blocked ads_pct domains_blocked top_domain
  dns_queries=$(echo "$data" | jq -r '.dns_queries_today // 0')
  ads_blocked=$(echo "$data" | jq -r '.ads_blocked_today // 0')
  ads_pct=$(echo "$data" | jq -r '.ads_percentage_today // 0')
  domains_blocked=$(echo "$data" | jq -r '.domains_being_blocked // 0')

  # Get top blocked domain
  local top_data
  top_data=$(api_get "topItems=1")
  top_domain=$(echo "$top_data" | jq -r '.top_ads | to_entries | sort_by(-.value) | .[0] | "\(.key) (\(.value))"' 2>/dev/null || echo "N/A")

  local today
  today=$(date '+%Y-%m-%d')

  local report="🛡️ <b>Pi-hole Daily Report — ${today}</b>
━━━━━━━━━━━━━━━━━━━━━━━━
Total queries:    ${dns_queries}
Blocked:          ${ads_blocked} (${ads_pct}%)
Top blocked:      ${top_domain}
Blocklist size:   ${domains_blocked} domains
Status:           ✅ Active"

  echo "$report"
  send_telegram "$report"
}

cmd_setup_cron_report() {
  local schedule="${1:-0 8 * * *}"
  local script_path
  script_path="$(cd "$(dirname "$0")" && pwd)/pihole-manager.sh"

  # Add to crontab
  (crontab -l 2>/dev/null; echo "${schedule} PIHOLE_API_KEY='${PIHOLE_API_KEY}' TELEGRAM_BOT_TOKEN='${TELEGRAM_BOT_TOKEN}' TELEGRAM_CHAT_ID='${TELEGRAM_CHAT_ID}' bash ${script_path} daily-report") | crontab -
  echo "✅ Daily report cron set: ${schedule}"
}

cmd_backup() {
  require_pihole
  mkdir -p "$BACKUP_DIR"
  local backup_file="${BACKUP_DIR}/pihole-backup-$(date '+%Y-%m-%d-%H%M%S').tar.gz"

  local tmp_dir
  tmp_dir=$(mktemp -d)

  # Copy Pi-hole config files
  cp /etc/pihole/setupVars.conf "${tmp_dir}/" 2>/dev/null || true
  cp /etc/pihole/gravity.db "${tmp_dir}/" 2>/dev/null || true
  cp /etc/pihole/custom.list "${tmp_dir}/" 2>/dev/null || true
  cp /etc/pihole/pihole-FTL.conf "${tmp_dir}/" 2>/dev/null || true
  cp -r /etc/dnsmasq.d/ "${tmp_dir}/dnsmasq.d/" 2>/dev/null || true

  # Create archive
  tar -czf "$backup_file" -C "$tmp_dir" .
  rm -rf "$tmp_dir"

  echo "✅ Backup saved to: ${backup_file}"
  echo "   Size: $(du -h "$backup_file" | awk '{print $1}')"
}

cmd_restore() {
  require_pihole
  require_sudo
  local backup_file="${1:-}"
  [[ ! -f "$backup_file" ]] && { echo "❌ Backup file not found: ${backup_file}"; exit 1; }

  echo "⚠️  Restoring from: ${backup_file}"
  echo "   This will overwrite current Pi-hole config."
  read -rp "   Continue? (y/N) " confirm
  [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "Cancelled."; exit 0; }

  local tmp_dir
  tmp_dir=$(mktemp -d)
  tar -xzf "$backup_file" -C "$tmp_dir"

  cp "${tmp_dir}/setupVars.conf" /etc/pihole/ 2>/dev/null || true
  cp "${tmp_dir}/gravity.db" /etc/pihole/ 2>/dev/null || true
  cp "${tmp_dir}/custom.list" /etc/pihole/ 2>/dev/null || true
  cp "${tmp_dir}/pihole-FTL.conf" /etc/pihole/ 2>/dev/null || true
  cp -r "${tmp_dir}/dnsmasq.d/"* /etc/dnsmasq.d/ 2>/dev/null || true

  rm -rf "$tmp_dir"

  # Restart Pi-hole
  pihole restartdns
  echo "✅ Restored and restarted Pi-hole"
}

cmd_backup_list() {
  mkdir -p "$BACKUP_DIR"
  echo "📦 Available Backups"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
  ls -lh "${BACKUP_DIR}/"pihole-backup-*.tar.gz 2>/dev/null | awk '{print $5, $9}' || echo "No backups found"
}

cmd_local_dns_add() {
  require_sudo
  local domain="${1:-}"
  local ip="${2:-}"
  [[ -z "$domain" || -z "$ip" ]] && { echo "Usage: pihole-manager.sh local-dns-add <domain> <ip>"; exit 1; }
  echo "${ip} ${domain}" >> /etc/pihole/custom.list
  pihole restartdns
  echo "✅ Local DNS: ${domain} → ${ip}"
}

cmd_local_dns_list() {
  echo "🌐 Local DNS Records"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
  cat /etc/pihole/custom.list 2>/dev/null | while read -r ip domain; do
    printf "%s → %s\n" "$domain" "$ip"
  done || echo "No local DNS records"
}

cmd_local_dns_remove() {
  require_sudo
  local domain="${1:-}"
  [[ -z "$domain" ]] && { echo "Usage: pihole-manager.sh local-dns-remove <domain>"; exit 1; }
  sed -i "/ ${domain}$/d" /etc/pihole/custom.list
  pihole restartdns
  echo "✅ Removed local DNS: ${domain}"
}

cmd_cname_add() {
  require_sudo
  local domain="${1:-}"
  local target="${2:-}"
  [[ -z "$domain" || -z "$target" ]] && { echo "Usage: pihole-manager.sh cname-add <domain> <target>"; exit 1; }
  echo "cname=${domain},${target}" >> /etc/dnsmasq.d/05-pihole-custom-cname.conf
  pihole restartdns
  echo "✅ CNAME: ${domain} → ${target}"
}

cmd_cname_list() {
  echo "🔗 CNAME Records"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
  cat /etc/dnsmasq.d/05-pihole-custom-cname.conf 2>/dev/null | grep "^cname=" | sed 's/cname=//' | while IFS=',' read -r domain target; do
    printf "%s → %s\n" "$domain" "$target"
  done || echo "No CNAME records"
}

cmd_regex_add() {
  require_pihole
  local pattern="${1:-}"
  [[ -z "$pattern" ]] && { echo "Usage: pihole-manager.sh regex-add <pattern>"; exit 1; }
  pihole --regex "$pattern"
  echo "✅ Regex blacklist added: ${pattern}"
}

cmd_regex_whitelist_add() {
  require_pihole
  local pattern="${1:-}"
  [[ -z "$pattern" ]] && { echo "Usage: pihole-manager.sh regex-whitelist-add <pattern>"; exit 1; }
  pihole --regex -w "$pattern"
  echo "✅ Regex whitelist added: ${pattern}"
}

cmd_regex_list() {
  require_pihole
  echo "🔤 Regex Filters"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Blacklist:"
  sqlite3 /etc/pihole/gravity.db "SELECT domain FROM domainlist WHERE type=3;" 2>/dev/null || echo "  (none)"
  echo ""
  echo "Whitelist:"
  sqlite3 /etc/pihole/gravity.db "SELECT domain FROM domainlist WHERE type=2;" 2>/dev/null || echo "  (none)"
}

cmd_update() {
  require_pihole
  require_sudo
  if [[ "${1:-}" == "--check" ]]; then
    pihole -up --check-only
  else
    pihole -up
    echo "✅ Pi-hole updated"
  fi
}

# ─── Router ────────────────────────────────────────────

CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in
  status)             cmd_status ;;
  stats)              cmd_stats "$@" ;;
  top-blocked)        cmd_top_blocked "$@" ;;
  top-permitted)      cmd_top_permitted "$@" ;;
  top-clients)        cmd_top_clients ;;
  query-log)          cmd_query_log "$@" ;;
  blocklists)         cmd_blocklists ;;
  blocklist-add)      cmd_blocklist_add "$@" ;;
  blocklist-pack)     cmd_blocklist_pack "$@" ;;
  gravity-update)     cmd_gravity_update ;;
  whitelist)          cmd_whitelist "$@" ;;
  whitelist-file)     cmd_whitelist_file "$@" ;;
  whitelist-show)     cmd_whitelist_show ;;
  whitelist-remove)   cmd_whitelist_remove "$@" ;;
  blacklist)          cmd_blacklist "$@" ;;
  blacklist-show)     cmd_blacklist_show ;;
  blacklist-remove)   cmd_blacklist_remove "$@" ;;
  enable)             cmd_enable ;;
  disable)            cmd_disable "$@" ;;
  daily-report)       cmd_daily_report ;;
  setup-cron-report)  cmd_setup_cron_report "$@" ;;
  backup)             cmd_backup ;;
  restore)            cmd_restore "$@" ;;
  backup-list)        cmd_backup_list ;;
  local-dns-add)      cmd_local_dns_add "$@" ;;
  local-dns-list)     cmd_local_dns_list ;;
  local-dns-remove)   cmd_local_dns_remove "$@" ;;
  cname-add)          cmd_cname_add "$@" ;;
  cname-list)         cmd_cname_list ;;
  regex-add)          cmd_regex_add "$@" ;;
  regex-whitelist-add) cmd_regex_whitelist_add "$@" ;;
  regex-list)         cmd_regex_list ;;
  update)             cmd_update "$@" ;;
  help|--help|-h)
    echo "Pi-hole DNS Manager"
    echo ""
    echo "Usage: pihole-manager.sh <command> [args]"
    echo ""
    echo "Status & Stats:"
    echo "  status              Show Pi-hole status"
    echo "  stats [--json]      Show stats (optional JSON output)"
    echo "  top-blocked [N]     Top N blocked domains (default 10)"
    echo "  top-permitted [N]   Top N permitted domains"
    echo "  top-clients         Top querying clients"
    echo "  query-log <domain>  Search query log for domain"
    echo ""
    echo "Blocklists:"
    echo "  blocklists                  List current blocklists"
    echo "  blocklist-add <url>         Add a blocklist URL"
    echo "  blocklist-pack <pack>       Add a pack (malware|tracking|social|ads-aggressive)"
    echo "  gravity-update              Apply blocklist changes"
    echo ""
    echo "Whitelist / Blacklist:"
    echo "  whitelist <domain>          Allow a domain"
    echo "  whitelist-file <file>       Whitelist domains from file"
    echo "  whitelist-show              List whitelisted domains"
    echo "  whitelist-remove <domain>   Remove from whitelist"
    echo "  blacklist <domain>          Block a domain"
    echo "  blacklist-show              List blacklisted domains"
    echo "  blacklist-remove <domain>   Remove from blacklist"
    echo ""
    echo "Control:"
    echo "  enable              Enable blocking"
    echo "  disable [duration]  Disable blocking (e.g., 5m, 1h)"
    echo ""
    echo "DNS Records:"
    echo "  local-dns-add <domain> <ip>   Add local DNS record"
    echo "  local-dns-list                List local DNS records"
    echo "  local-dns-remove <domain>     Remove local DNS record"
    echo "  cname-add <domain> <target>   Add CNAME record"
    echo "  cname-list                    List CNAME records"
    echo ""
    echo "Regex:"
    echo "  regex-add <pattern>           Add regex blacklist"
    echo "  regex-whitelist-add <pattern> Add regex whitelist"
    echo "  regex-list                    List regex filters"
    echo ""
    echo "Reports & Alerts:"
    echo "  daily-report            Generate and send daily report"
    echo "  setup-cron-report [sch] Set up cron for daily report"
    echo ""
    echo "Backup & Update:"
    echo "  backup              Backup Pi-hole config"
    echo "  restore <file>      Restore from backup"
    echo "  backup-list         List available backups"
    echo "  update [--check]    Update Pi-hole"
    ;;
  *)
    echo "Unknown command: ${CMD}. Run with 'help' for usage."
    exit 1
    ;;
esac
