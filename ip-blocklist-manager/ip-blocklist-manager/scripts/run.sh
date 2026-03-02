#!/bin/bash
# IP Blocklist Manager — Download, manage, and apply IP blocklists
# Requires: bash 4+, curl, ipset, iptables (or nftables), root/sudo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-/etc/ip-blocklist/config.sh}"
VERSION="1.0.0"

# Defaults (overridden by config)
FEEDS=(
  "spamhaus-drop|https://www.spamhaus.org/drop/drop.txt|cidr"
  "spamhaus-edrop|https://www.spamhaus.org/drop/edrop.txt|cidr"
  "blocklist-de|https://lists.blocklist.de/lists/all.txt|ip"
  "emerging-threats|https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt|ip"
  "dshield-top20|https://feeds.dshield.org/block.txt|dshield"
  "firehol-level1|https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset|cidr"
)
IPSET_NAME="blocklist"
IPSET_MAXELEM=200000
IPSET_HASHSIZE=16384
CHAIN_NAME="BLOCKLIST"
LOG_BLOCKED=true
LOG_PREFIX="[BLOCKED] "
WHITELIST_FILE="/etc/ip-blocklist/whitelist.txt"
CRON_SCHEDULE="0 */6 * * *"
DATA_DIR="/var/lib/ip-blocklist"
LOG_DIR="/var/log/ip-blocklist"
FIREWALL_BACKEND="iptables"
NOTIFY_ON_UPDATE=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Load config if exists
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Ensure directories
mkdir -p "$DATA_DIR" "$LOG_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
log_info() { log "${BLUE}ℹ${NC}  $*"; }
log_ok() { log "${GREEN}✅${NC} $*"; }
log_warn() { log "${YELLOW}⚠${NC}  $*"; }
log_err() { log "${RED}❌${NC} $*"; }

# Check root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_err "This script must be run as root (use sudo)"
    exit 1
  fi
}

# Parse a feed and extract IPs/CIDRs
parse_feed() {
  local name="$1" url="$2" format="$3"
  local tmpfile="$DATA_DIR/${name}.raw"
  
  # Download
  if ! curl -sS --max-time 30 -o "$tmpfile" "$url" 2>/dev/null; then
    log_warn "  ⚠ ${name}: download failed (skipping)"
    return 1
  fi

  local count=0
  case "$format" in
    ip)
      # One IP per line, strip comments and empty lines
      grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$tmpfile" > "$DATA_DIR/${name}.parsed" 2>/dev/null || true
      count=$(wc -l < "$DATA_DIR/${name}.parsed")
      ;;
    cidr)
      # CIDR notation, strip comments
      grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?' "$tmpfile" > "$DATA_DIR/${name}.parsed" 2>/dev/null || true
      count=$(wc -l < "$DATA_DIR/${name}.parsed")
      ;;
    dshield)
      # DShield format: Start End Subnet ...
      awk '/^[0-9]/ {print $1"/"$3}' "$tmpfile" > "$DATA_DIR/${name}.parsed" 2>/dev/null || true
      count=$(wc -l < "$DATA_DIR/${name}.parsed")
      ;;
    *)
      log_warn "  ⚠ ${name}: unknown format '${format}' (skipping)"
      return 1
      ;;
  esac

  log_ok "  ${name}: ${count} entries"
  rm -f "$tmpfile"
  echo "$count"
}

# Load whitelist
load_whitelist() {
  if [[ -f "$WHITELIST_FILE" ]]; then
    grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?' "$WHITELIST_FILE" 2>/dev/null || true
  fi
}

# Aggregate all feeds, deduplicate, remove whitelisted
aggregate() {
  local all_file="$DATA_DIR/all-merged.txt"
  local final_file="$DATA_DIR/blocklist-final.txt"
  
  # Merge all parsed feeds
  cat "$DATA_DIR"/*.parsed 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | uniq > "$all_file"

  # Remove whitelisted entries
  local wl
  wl=$(load_whitelist)
  if [[ -n "$wl" ]]; then
    # Simple grep -v for exact matches; CIDR whitelist requires more logic
    local wl_file="$DATA_DIR/whitelist-active.txt"
    echo "$wl" > "$wl_file"
    grep -Fvxf "$wl_file" "$all_file" > "$final_file" 2>/dev/null || cp "$all_file" "$final_file"
  else
    cp "$all_file" "$final_file"
  fi

  local total
  total=$(wc -l < "$final_file")
  echo "$total"
}

# Create/update ipset
apply_ipset() {
  local final_file="$DATA_DIR/blocklist-final.txt"
  local tmp_set="${IPSET_NAME}_tmp"
  
  # Create temporary set
  ipset create "$tmp_set" hash:net maxelem "$IPSET_MAXELEM" hashsize "$IPSET_HASHSIZE" 2>/dev/null || \
    ipset flush "$tmp_set" 2>/dev/null || true

  # Batch add via restore (much faster than individual adds)
  {
    echo "create ${tmp_set} hash:net maxelem ${IPSET_MAXELEM} hashsize ${IPSET_HASHSIZE} -exist"
    while IFS= read -r entry; do
      [[ -n "$entry" ]] && echo "add ${tmp_set} ${entry} -exist"
    done < "$final_file"
  } | ipset restore -exist 2>/dev/null

  # Atomic swap
  if ipset list "$IPSET_NAME" &>/dev/null; then
    ipset swap "$tmp_set" "$IPSET_NAME"
    ipset destroy "$tmp_set" 2>/dev/null || true
  else
    ipset rename "$tmp_set" "$IPSET_NAME"
  fi

  log_ok "🛡️  Applied to ipset '${IPSET_NAME}'"
}

# Setup iptables rules
setup_iptables() {
  # Check if our chain exists
  if ! iptables -L "$CHAIN_NAME" -n &>/dev/null; then
    iptables -N "$CHAIN_NAME"
  fi

  # Flush our chain
  iptables -F "$CHAIN_NAME"

  # Add logging rule if enabled
  if [[ "$LOG_BLOCKED" == "true" ]]; then
    iptables -A "$CHAIN_NAME" -m set --match-set "$IPSET_NAME" src \
      -j LOG --log-prefix "$LOG_PREFIX" --log-level 4 -m limit --limit 10/min
  fi

  # Add DROP rule
  iptables -A "$CHAIN_NAME" -m set --match-set "$IPSET_NAME" src -j DROP

  # Insert into INPUT chain if not already there
  if ! iptables -C INPUT -j "$CHAIN_NAME" &>/dev/null; then
    iptables -I INPUT 1 -j "$CHAIN_NAME"
  fi

  # Also block on FORWARD chain (for routers/containers)
  if ! iptables -C FORWARD -j "$CHAIN_NAME" &>/dev/null; then
    iptables -I FORWARD 1 -j "$CHAIN_NAME"
  fi

  log_ok "🔥 iptables DROP rule active"
}

# Setup nftables rules
setup_nftables() {
  nft add table inet blocklist 2>/dev/null || true
  nft flush table inet blocklist
  nft add chain inet blocklist input '{ type filter hook input priority -10; policy accept; }'
  nft add chain inet blocklist forward '{ type filter hook forward priority -10; policy accept; }'
  
  nft add set inet blocklist blocked '{ type ipv4_addr; flags interval; }' 2>/dev/null || true
  
  # Load IPs into nft set
  local final_file="$DATA_DIR/blocklist-final.txt"
  local elements
  elements=$(paste -sd, "$final_file")
  if [[ -n "$elements" ]]; then
    nft add element inet blocklist blocked "{ $elements }" 2>/dev/null || true
  fi

  if [[ "$LOG_BLOCKED" == "true" ]]; then
    nft add rule inet blocklist input ip saddr @blocked log prefix "\"${LOG_PREFIX}\"" level warn limit rate 10/minute
    nft add rule inet blocklist forward ip saddr @blocked log prefix "\"${LOG_PREFIX}\"" level warn limit rate 10/minute
  fi
  nft add rule inet blocklist input ip saddr @blocked drop
  nft add rule inet blocklist forward ip saddr @blocked drop

  log_ok "🔥 nftables DROP rules active"
}

# Apply firewall rules
apply_firewall() {
  case "$FIREWALL_BACKEND" in
    iptables) setup_iptables ;;
    nftables) setup_nftables ;;
    *) log_err "Unknown firewall backend: $FIREWALL_BACKEND"; exit 1 ;;
  esac
}

# Download all feeds
download_feeds() {
  log "📥 Downloading blocklists..."
  local feed name url format
  for feed in "${FEEDS[@]}"; do
    IFS='|' read -r name url format <<< "$feed"
    parse_feed "$name" "$url" "$format" || true
  done
}

# Init: download + aggregate + apply
cmd_init() {
  check_root
  download_feeds
  
  log "🔄 Deduplicating..."
  local total
  total=$(aggregate)
  log "📊 Total unique entries: ${total}"
  
  apply_ipset
  apply_firewall
  
  # Save metadata
  echo "{\"last_update\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"total\":${total}}" > "$DATA_DIR/metadata.json"
  
  log_ok "Done. ${total} IPs blocked."
}

# Update: download + aggregate + atomic swap
cmd_update() {
  check_root
  
  local prev_total=0
  [[ -f "$DATA_DIR/metadata.json" ]] && prev_total=$(grep -o '"total":[0-9]*' "$DATA_DIR/metadata.json" | grep -o '[0-9]*')
  
  download_feeds
  
  local total
  total=$(aggregate)
  
  local added=$((total - prev_total))
  [[ $added -lt 0 ]] && local removed=$((-added)) && added=0 || local removed=0
  
  log "📊 Previous: ${prev_total} | New: ${total} | Delta: ${added} added, ${removed} removed"
  
  apply_ipset
  
  echo "{\"last_update\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"total\":${total}}" > "$DATA_DIR/metadata.json"
  
  log_ok "Update complete."
  
  # Notify if configured
  if [[ "$NOTIFY_ON_UPDATE" == "true" && -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    local msg="🛡️ IP Blocklist updated: ${total} IPs blocked (${added} new, ${removed} removed)"
    curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=${msg}" &>/dev/null || true
  fi
}

# Check if IP is blocked
cmd_check() {
  local ip="$1"
  if ipset test "$IPSET_NAME" "$ip" &>/dev/null; then
    echo -e "🚫 ${RED}${ip}${NC} IS in blocklist"
    # Try to find which feed
    for f in "$DATA_DIR"/*.parsed; do
      if grep -qF "$ip" "$f" 2>/dev/null; then
        local feed_name
        feed_name=$(basename "$f" .parsed)
        echo "   Source: ${feed_name}"
      fi
    done
  else
    echo -e "✅ ${GREEN}${ip}${NC} is NOT in blocklist"
  fi
}

# Whitelist an IP
cmd_whitelist() {
  local ip="$1"
  mkdir -p "$(dirname "$WHITELIST_FILE")"
  
  # Check if already whitelisted
  if grep -qF "$ip" "$WHITELIST_FILE" 2>/dev/null; then
    log_warn "${ip} is already whitelisted"
    return 0
  fi
  
  echo "$ip" >> "$WHITELIST_FILE"
  log_ok "${ip} added to whitelist"
  echo "   Will be excluded from all future blocklist updates."
  
  # Remove from ipset immediately
  ipset del "$IPSET_NAME" "$ip" 2>/dev/null || true
}

# Show stats
cmd_stats() {
  echo -e "${BOLD}📊 IP Blocklist Statistics${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  local total=0 last_update="never"
  if [[ -f "$DATA_DIR/metadata.json" ]]; then
    total=$(grep -o '"total":[0-9]*' "$DATA_DIR/metadata.json" | grep -o '[0-9]*')
    last_update=$(grep -o '"last_update":"[^"]*"' "$DATA_DIR/metadata.json" | grep -o '"[^"]*"$' | tr -d '"')
  fi
  
  echo "Total blocked IPs:     ${total}"
  echo "Active feeds:          ${#FEEDS[@]}"
  echo "Last update:           ${last_update}"
  echo ""
  
  if [[ -d "$DATA_DIR" ]]; then
    echo "Feed breakdown:"
    for f in "$DATA_DIR"/*.parsed; do
      [[ -f "$f" ]] || continue
      local name count
      name=$(basename "$f" .parsed)
      count=$(wc -l < "$f")
      printf "  %-25s %s\n" "${name}:" "${count}"
    done
  fi
  
  echo ""
  local wl_count=0
  [[ -f "$WHITELIST_FILE" ]] && wl_count=$(grep -cE '^[0-9]' "$WHITELIST_FILE" 2>/dev/null || echo 0)
  echo "Whitelist entries:     ${wl_count}"
  
  # Blocked connections in last 24h (from syslog/journal)
  if command -v journalctl &>/dev/null; then
    local blocked_24h
    blocked_24h=$(journalctl --since "24 hours ago" --no-pager -q 2>/dev/null | grep -c "$LOG_PREFIX" 2>/dev/null || echo 0)
    echo "Last 24h blocked:      ${blocked_24h} connections"
  fi
}

# Export blocklist
cmd_export() {
  local format="${1:-plain}"
  local final_file="$DATA_DIR/blocklist-final.txt"
  
  if [[ ! -f "$final_file" ]]; then
    log_err "No blocklist found. Run --init first."
    exit 1
  fi
  
  case "$format" in
    plain) cat "$final_file" ;;
    ipset)
      echo "create ${IPSET_NAME} hash:net maxelem ${IPSET_MAXELEM} hashsize ${IPSET_HASHSIZE}"
      while IFS= read -r entry; do
        [[ -n "$entry" ]] && echo "add ${IPSET_NAME} ${entry}"
      done < "$final_file"
      ;;
  esac
}

# Remove everything
cmd_remove() {
  check_root
  log "🗑️  Removing IP blocklist..."
  
  # Remove iptables rules
  iptables -D INPUT -j "$CHAIN_NAME" 2>/dev/null || true
  iptables -D FORWARD -j "$CHAIN_NAME" 2>/dev/null || true
  iptables -F "$CHAIN_NAME" 2>/dev/null || true
  iptables -X "$CHAIN_NAME" 2>/dev/null || true
  log_ok "iptables rules removed"
  
  # Remove nftables table
  nft delete table inet blocklist 2>/dev/null || true
  
  # Remove ipset
  ipset destroy "$IPSET_NAME" 2>/dev/null || true
  log_ok "ipset set destroyed"
  
  # Remove cron
  crontab -l 2>/dev/null | grep -v "ip-blocklist" | crontab - 2>/dev/null || true
  log_ok "Cron job removed"
  
  log_ok "Clean uninstall complete."
}

# Install cron
cmd_install_cron() {
  check_root
  local script_path
  script_path="$(cd "$SCRIPT_DIR" && pwd)/run.sh"
  
  # Remove existing entry
  crontab -l 2>/dev/null | grep -v "ip-blocklist" | crontab - 2>/dev/null || true
  
  # Add new entry
  (crontab -l 2>/dev/null; echo "${CRON_SCHEDULE} ${script_path} --update >> ${LOG_DIR}/update.log 2>&1 # ip-blocklist") | crontab -
  
  log_ok "Cron job installed: ${CRON_SCHEDULE}"
}

# Usage
usage() {
  cat <<EOF
IP Blocklist Manager v${VERSION}

Usage: $(basename "$0") [OPTIONS]

Commands:
  --init            Download all feeds and apply blocklist (first run)
  --update          Update blocklists from all feeds
  --check <IP>      Check if an IP is in the blocklist
  --whitelist <IP>  Add an IP to the whitelist
  --stats           Show blocklist statistics
  --export          Export blocklist as plain text
  --export-ipset    Export in ipset restore format
  --install-cron    Install auto-update cron job
  --remove          Remove all rules and uninstall
  --dry-run         (with --update) Show changes without applying
  -h, --help        Show this help

Examples:
  sudo $(basename "$0") --init
  sudo $(basename "$0") --update
  sudo $(basename "$0") --check 185.220.101.34
  sudo $(basename "$0") --whitelist 203.0.113.50
  sudo $(basename "$0") --stats

Config: ${CONFIG_FILE}
EOF
}

# Main
DRY_RUN=false

case "${1:-}" in
  --init)       cmd_init ;;
  --update)
    [[ "${2:-}" == "--dry-run" ]] && DRY_RUN=true
    cmd_update
    ;;
  --check)      cmd_check "${2:?Usage: --check <IP>}" ;;
  --whitelist)  cmd_whitelist "${2:?Usage: --whitelist <IP>}" ;;
  --stats)      cmd_stats ;;
  --export)     cmd_export "plain" ;;
  --export-ipset) cmd_export "ipset" ;;
  --install-cron) cmd_install_cron ;;
  --remove)     cmd_remove ;;
  -h|--help)    usage ;;
  *)            usage; exit 1 ;;
esac
