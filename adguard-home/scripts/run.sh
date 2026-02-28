#!/bin/bash
# AdGuard Home Manager — CLI wrapper for common operations
# Talks to the AdGuard Home REST API

set -euo pipefail

# Config — set via environment or defaults
AGH_HOST="${AGH_HOST:-http://localhost}"
AGH_PORT="${AGH_PORT:-3000}"
AGH_USER="${AGH_USER:-admin}"
AGH_PASS="${AGH_PASS:-}"
BASE_URL="${AGH_HOST}:${AGH_PORT}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err() { log "ERROR: $*" >&2; exit 1; }

# API helper with auth
api() {
  local method="$1" endpoint="$2"
  shift 2
  local auth_args=()
  if [[ -n "$AGH_USER" && -n "$AGH_PASS" ]]; then
    auth_args=(-u "${AGH_USER}:${AGH_PASS}")
  fi
  curl -sS "${auth_args[@]}" -X "$method" \
    -H "Content-Type: application/json" \
    "${BASE_URL}/control${endpoint}" "$@"
}

# --- Commands ---

cmd_status() {
  log "AdGuard Home Status:"
  local status
  status=$(api GET /status)
  echo "$status" | jq -r '
    "  Version:    \(.version)",
    "  Running:    \(.running)",
    "  DNS Port:   \(.dns_port)",
    "  HTTP Port:  \(.http_port)",
    "  Protection: \(.protection_enabled)",
    "  Language:   \(.language)"
  '
}

cmd_stats() {
  log "Query Statistics (last 24h):"
  local stats
  stats=$(api GET /stats)
  echo "$stats" | jq -r '
    "  Total queries:      \(.num_dns_queries)",
    "  Blocked:            \(.num_blocked_filtering)",
    "  Blocked (%%):        \(if .num_dns_queries > 0 then ((.num_blocked_filtering / .num_dns_queries * 10000 | floor) / 100) else 0 end)%",
    "  Malware blocked:    \(.num_replaced_safebrowsing)",
    "  Adult blocked:      \(.num_replaced_parental)",
    "  Avg response (ms):  \(.avg_processing_time * 1000 | floor)"
  '
}

cmd_top() {
  log "Top Queried Domains:"
  api GET /stats | jq -r '.top_queried_domains[:10][] | to_entries[] | "  \(.value)\t\(.key)"'
  echo ""
  log "Top Blocked Domains:"
  api GET /stats | jq -r '.top_blocked_domains[:10][] | to_entries[] | "  \(.value)\t\(.key)"'
  echo ""
  log "Top Clients:"
  api GET /stats | jq -r '.top_clients[:10][] | to_entries[] | "  \(.value)\t\(.key)"'
}

cmd_query_log() {
  local limit="${1:-20}"
  log "Recent Queries (last $limit):"
  api GET "/querylog?limit=${limit}&response_status=all" | jq -r '
    .data[:'"$limit"'][] |
    "\(.time | split("T")[1] | split(".")[0]) \(if .reason == "FilteredBlackList" then "❌" elif .reason == "" then "✅" else "⚠️" end) \(.question.name) ← \(.client)"
  '
}

cmd_enable() {
  log "Enabling DNS protection..."
  api POST /dns_config --data '{"protection_enabled": true}' >/dev/null
  log "✅ Protection enabled"
}

cmd_disable() {
  local duration="${1:-0}"
  if [[ "$duration" -gt 0 ]]; then
    log "Disabling DNS protection for ${duration} seconds..."
    api POST /protection --data "{\"enabled\": false, \"duration\": ${duration}000}" >/dev/null
    log "⏸️  Protection disabled for ${duration}s"
  else
    log "Disabling DNS protection..."
    api POST /dns_config --data '{"protection_enabled": false}' >/dev/null
    log "⏸️  Protection disabled (indefinitely)"
  fi
}

cmd_add_filter() {
  local name="$1" url="$2"
  log "Adding filter list: $name"
  api POST /filtering/add_url --data "{\"name\": \"${name}\", \"url\": \"${url}\", \"enabled\": true}" >/dev/null
  log "✅ Filter added: $name ($url)"
}

cmd_remove_filter() {
  local url="$1"
  log "Removing filter: $url"
  api POST /filtering/remove_url --data "{\"url\": \"${url}\"}" >/dev/null
  log "✅ Filter removed"
}

cmd_list_filters() {
  log "Active Filter Lists:"
  api GET /filtering/status | jq -r '
    .filters[] |
    "  \(if .enabled then "✅" else "❌" end) \(.name) (\(.rules_count) rules, updated \(.last_updated | split("T")[0]))\n     \(.url)"
  '
}

cmd_refresh_filters() {
  log "Refreshing all filter lists..."
  api POST /filtering/refresh --data '{"whitelist": false}' >/dev/null
  log "✅ Filters refreshed"
}

cmd_add_rule() {
  local rule="$1"
  log "Adding custom rule: $rule"
  local existing
  existing=$(api GET /filtering/status | jq -r '.user_rules | join("\n")')
  local new_rules
  if [[ -z "$existing" ]]; then
    new_rules="$rule"
  else
    new_rules="${existing}\n${rule}"
  fi
  api POST /filtering/set_rules --data "{\"rules\": $(echo -e "$new_rules" | jq -Rs 'split("\n") | map(select(. != ""))')}" >/dev/null
  log "✅ Rule added"
}

cmd_list_rules() {
  log "Custom Filtering Rules:"
  api GET /filtering/status | jq -r '.user_rules[] | "  \(.)"'
}

cmd_block_domain() {
  local domain="$1"
  cmd_add_rule "||${domain}^"
  log "🚫 Domain blocked: $domain"
}

cmd_allow_domain() {
  local domain="$1"
  cmd_add_rule "@@||${domain}^"
  log "✅ Domain allowed: $domain"
}

cmd_clients() {
  log "Configured Clients:"
  api GET /clients | jq -r '
    .clients[] |
    "  \(.name) [\(.ids | join(", "))]",
    "    Filtering: \(if .filtering_enabled then "✅" else "❌" end) | SafeBrowsing: \(if .safebrowsing_enabled then "✅" else "❌" end) | Parental: \(if .parental_enabled then "✅" else "❌" end)"
  '
}

cmd_dns_config() {
  log "DNS Configuration:"
  api GET /dns_info | jq -r '
    "  Upstream DNS:    \(.upstream_dns | join(", "))",
    "  Bootstrap DNS:   \(.bootstrap_dns | join(", "))",
    "  Rate limit:      \(.ratelimit) req/s",
    "  Cache size:      \(.cache_size) bytes",
    "  DNSSEC:          \(.dnssec_enabled)",
    "  Blocking mode:   \(.blocking_mode)"
  '
}

cmd_set_upstream() {
  local dns_servers=("$@")
  local json_arr
  json_arr=$(printf '%s\n' "${dns_servers[@]}" | jq -Rs 'split("\n") | map(select(. != ""))')
  log "Setting upstream DNS: ${dns_servers[*]}"
  api POST /dns_config --data "{\"upstream_dns\": ${json_arr}}" >/dev/null
  log "✅ Upstream DNS updated"
}

cmd_test_upstream() {
  log "Testing upstream DNS servers..."
  local config
  config=$(api GET /dns_info | jq '{upstream_dns, bootstrap_dns}')
  api POST /test_upstream_dns --data "$config" | jq -r 'to_entries[] | "  \(.key): \(.value)"'
}

cmd_backup() {
  local backup_dir="${1:-./adguard-backups}"
  mkdir -p "$backup_dir"
  local ts
  ts=$(date +%Y%m%d_%H%M%S)
  local backup_file="${backup_dir}/adguard_backup_${ts}.json"

  log "Creating backup..."
  {
    echo '{'
    echo '"status":'; api GET /status; echo ','
    echo '"dns_config":'; api GET /dns_info; echo ','
    echo '"filtering":'; api GET /filtering/status; echo ','
    echo '"clients":'; api GET /clients; echo ','
    echo '"backed_up_at": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"'
    echo '}'
  } | jq '.' > "$backup_file"

  log "✅ Backup saved to $backup_file"
}

cmd_health() {
  log "Health Check:"
  
  # Check if service is running
  if api GET /status >/dev/null 2>&1; then
    echo "  Service:     ✅ Running"
  else
    echo "  Service:     ❌ Not responding"
    return 1
  fi

  # Check DNS resolution
  local dns_port
  dns_port=$(api GET /status | jq -r '.dns_port')
  if dig @127.0.0.1 -p "$dns_port" google.com +short +time=2 >/dev/null 2>&1; then
    echo "  DNS Resolve: ✅ Working"
  else
    echo "  DNS Resolve: ❌ Failed"
  fi

  # Check filter freshness
  local oldest_update
  oldest_update=$(api GET /filtering/status | jq -r '[.filters[].last_updated] | sort | .[0] // "never"')
  echo "  Oldest filter: $oldest_update"

  # Stats summary
  local stats
  stats=$(api GET /stats)
  local queries blocked
  queries=$(echo "$stats" | jq '.num_dns_queries')
  blocked=$(echo "$stats" | jq '.num_blocked_filtering')
  echo "  Queries (24h): $queries | Blocked: $blocked"
}

# --- Main ---

usage() {
  cat <<EOF
AdGuard Home Manager

Usage: $(basename "$0") <command> [args]

Environment:
  AGH_HOST  AdGuard Home host (default: http://localhost)
  AGH_PORT  AdGuard Home port (default: 3000)
  AGH_USER  Admin username (default: admin)
  AGH_PASS  Admin password (required for auth)

Commands:
  status              Show service status
  stats               Show query statistics (24h)
  top                 Show top domains, blocked domains, clients
  query-log [N]       Show last N queries (default: 20)
  health              Run health check (service + DNS + filters)

  enable              Enable DNS protection
  disable [seconds]   Disable protection (optionally for N seconds)

  list-filters        List active filter lists
  add-filter <name> <url>  Add a filter list
  remove-filter <url>      Remove a filter list
  refresh-filters     Force refresh all filter lists

  list-rules          List custom filtering rules
  add-rule <rule>     Add custom adblock rule
  block <domain>      Block a domain
  allow <domain>      Whitelist a domain

  clients             List configured clients
  dns-config          Show DNS configuration
  set-upstream <dns>  Set upstream DNS servers
  test-upstream       Test upstream DNS connectivity

  backup [dir]        Backup config to JSON file

Examples:
  $(basename "$0") status
  $(basename "$0") block ads.example.com
  $(basename "$0") allow safe-site.com
  $(basename "$0") add-filter "Steven Black" "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
  $(basename "$0") set-upstream "https://dns.cloudflare.com/dns-query" "https://dns.google/dns-query"
  $(basename "$0") disable 300  # Disable for 5 minutes
  AGH_PASS=mypassword $(basename "$0") stats
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

CMD="$1"
shift

case "$CMD" in
  status)          cmd_status ;;
  stats)           cmd_stats ;;
  top)             cmd_top ;;
  query-log)       cmd_query_log "${1:-20}" ;;
  health)          cmd_health ;;
  enable)          cmd_enable ;;
  disable)         cmd_disable "${1:-0}" ;;
  list-filters)    cmd_list_filters ;;
  add-filter)      cmd_add_filter "$1" "$2" ;;
  remove-filter)   cmd_remove_filter "$1" ;;
  refresh-filters) cmd_refresh_filters ;;
  list-rules)      cmd_list_rules ;;
  add-rule)        cmd_add_rule "$1" ;;
  block)           cmd_block_domain "$1" ;;
  allow)           cmd_allow_domain "$1" ;;
  clients)         cmd_clients ;;
  dns-config)      cmd_dns_config ;;
  set-upstream)    cmd_set_upstream "$@" ;;
  test-upstream)   cmd_test_upstream ;;
  backup)          cmd_backup "${1:-./adguard-backups}" ;;
  help|--help|-h)  usage ;;
  *)               err "Unknown command: $CMD. Run '$(basename "$0") help' for usage." ;;
esac
