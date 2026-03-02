#!/usr/bin/env bash
# IP Blocklist Manager — Download threat intel blocklists, load into ipset/iptables
# Requires: bash 4+, curl, ipset, iptables (run as root)
set -euo pipefail

VERSION="1.0.0"
CONF_FILE="${BLOCKLIST_CONF:-/etc/blocklist-manager.conf}"
DEFAULT_DATA_DIR="/var/lib/blocklist-manager"
DEFAULT_LOG_FILE="/var/log/blocklist-manager.log"
DEFAULT_WHITELIST="/etc/blocklist-whitelist.txt"
DEFAULT_IPSET_NAME="blocklist"
DEFAULT_IPSET_MAXELEM=200000
DEFAULT_CHAIN="INPUT"
DEFAULT_POSITION=1
DEFAULT_LOG_PREFIX="BLOCKLIST_DROP: "
DEFAULT_ENABLE_LOGGING=false

# ── Default blocklist sources ──
DEFAULT_LISTS=(
  "firehol_level1|https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset"
  "spamhaus_drop|https://www.spamhaus.org/drop/drop.txt"
  "spamhaus_edrop|https://www.spamhaus.org/drop/edrop.txt"
  "blocklist_de|https://lists.blocklist.de/lists/all.txt"
  "emerging_threats|https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt"
  "dshield_top20|https://www.dshield.org/block.txt"
  "abuse_ch_feodo|https://feodotracker.abuse.ch/downloads/ipblocklist.txt"
)

# ── Load config if exists ──
load_config() {
  if [[ -f "$CONF_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONF_FILE"
  fi
  DATA_DIR="${DATA_DIR:-$DEFAULT_DATA_DIR}"
  LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"
  WHITELIST_FILE="${WHITELIST_FILE:-$DEFAULT_WHITELIST}"
  IPSET_NAME="${IPSET_NAME:-$DEFAULT_IPSET_NAME}"
  IPSET_MAXELEM="${IPSET_MAXELEM:-$DEFAULT_IPSET_MAXELEM}"
  CHAIN="${CHAIN:-$DEFAULT_CHAIN}"
  POSITION="${POSITION:-$DEFAULT_POSITION}"
  LOG_PREFIX="${LOG_PREFIX:-$DEFAULT_LOG_PREFIX}"
  ENABLE_LOGGING="${ENABLE_LOGGING:-$DEFAULT_ENABLE_LOGGING}"
  if [[ -z "${LISTS+x}" ]] || [[ ${#LISTS[@]} -eq 0 ]]; then
    LISTS=("${DEFAULT_LISTS[@]}")
  fi
  mkdir -p "$DATA_DIR" 2>/dev/null || true
}

log() {
  local msg="[$(date -u '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root (sudo)" >&2
    exit 1
  fi
}

check_deps() {
  local missing=()
  for cmd in curl ipset iptables; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ Missing dependencies: ${missing[*]}" >&2
    echo "Install with: sudo apt-get install -y ${missing[*]}" >&2
    exit 1
  fi
}

# ── Download and parse a blocklist ──
download_list() {
  local name="$1" url="$2" outfile="$DATA_DIR/${name}.raw"
  
  if ! curl -sS --max-time 30 --retry 2 -o "$outfile" "$url" 2>/dev/null; then
    log "⚠️  Failed to download $name"
    return 1
  fi
  
  # Parse: extract valid IPs/CIDRs, skip comments and empty lines
  grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' "$outfile" 2>/dev/null \
    | sort -u > "$DATA_DIR/${name}.parsed"
  
  local count
  count=$(wc -l < "$DATA_DIR/${name}.parsed")
  log "📥 Downloading ${name}... ${count} IPs"
  echo "$count"
}

# ── Load whitelist ──
load_whitelist() {
  if [[ -f "$WHITELIST_FILE" ]]; then
    grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' "$WHITELIST_FILE" 2>/dev/null \
      | sort -u
  fi
}

# ── Update command ──
cmd_update() {
  check_root
  check_deps
  
  local dry_run=false filter_lists=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=true; shift ;;
      --lists) filter_lists="$2"; shift 2 ;;
      --verbose) set -x; shift ;;
      *) shift ;;
    esac
  done
  
  local tmpfile="$DATA_DIR/all-ips.tmp"
  > "$tmpfile"
  
  # Download all lists
  for entry in "${LISTS[@]}"; do
    local name="${entry%%|*}"
    local url="${entry#*|}"
    
    # Filter if --lists specified
    if [[ -n "$filter_lists" ]] && ! echo "$filter_lists" | grep -q "$name"; then
      continue
    fi
    
    download_list "$name" "$url" || continue
    cat "$DATA_DIR/${name}.parsed" >> "$tmpfile"
  done
  
  # Remove whitelist IPs
  local whitelist_tmp="$DATA_DIR/whitelist.tmp"
  load_whitelist > "$whitelist_tmp"
  
  if [[ -s "$whitelist_tmp" ]]; then
    sort -u "$tmpfile" | grep -vFf "$whitelist_tmp" > "$DATA_DIR/final.txt" || true
  else
    sort -u "$tmpfile" > "$DATA_DIR/final.txt"
  fi
  
  local total
  total=$(wc -l < "$DATA_DIR/final.txt")
  
  if $dry_run; then
    log "🔍 Dry run: would load $total unique IPs"
    rm -f "$tmpfile" "$whitelist_tmp"
    return 0
  fi
  
  # Create new ipset (atomic swap)
  local tmp_set="${IPSET_NAME}_tmp"
  ipset create "$tmp_set" hash:net maxelem "$IPSET_MAXELEM" -exist 2>/dev/null || \
    ipset create "$tmp_set" hash:ip maxelem "$IPSET_MAXELEM" -exist
  ipset flush "$tmp_set"
  
  # Load IPs into temp set
  while IFS= read -r ip; do
    [[ -z "$ip" ]] && continue
    ipset add "$tmp_set" "$ip" -exist 2>/dev/null || true
  done < "$DATA_DIR/final.txt"
  
  # Create main set if doesn't exist
  ipset create "$IPSET_NAME" hash:net maxelem "$IPSET_MAXELEM" -exist 2>/dev/null || \
    ipset create "$IPSET_NAME" hash:ip maxelem "$IPSET_MAXELEM" -exist
  
  # Atomic swap
  ipset swap "$tmp_set" "$IPSET_NAME"
  ipset destroy "$tmp_set" 2>/dev/null || true
  
  # Ensure iptables rule exists
  if ! iptables -C "$CHAIN" -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
    # Add logging rule if enabled
    if [[ "$ENABLE_LOGGING" == "true" ]]; then
      iptables -I "$CHAIN" "$POSITION" -m set --match-set "$IPSET_NAME" src \
        -j LOG --log-prefix "$LOG_PREFIX" --log-level 4
      iptables -I "$CHAIN" $((POSITION + 1)) -m set --match-set "$IPSET_NAME" src -j DROP
    else
      iptables -I "$CHAIN" "$POSITION" -m set --match-set "$IPSET_NAME" src -j DROP
    fi
  fi
  
  # Save timestamp
  date -u '+%Y-%m-%dT%H:%M:%SZ' > "$DATA_DIR/last-update"
  echo "$total" > "$DATA_DIR/total-ips"
  
  log "✅ Loaded ${total} unique IPs into ipset '${IPSET_NAME}'"
  log "🔒 iptables DROP rule active for set '${IPSET_NAME}'"
  
  # Cleanup
  rm -f "$tmpfile" "$whitelist_tmp"
  
  # Send alert if configured
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] && [[ -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    local msg="🔒 IP Blocklist updated: ${total} IPs blocked"
    curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=${msg}" >/dev/null 2>&1 || true
  fi
}

# ── Status command ──
cmd_status() {
  echo "IP Blocklist Manager — Status"
  echo "─────────────────────────────"
  
  if ipset list "$IPSET_NAME" &>/dev/null; then
    local count
    count=$(ipset list "$IPSET_NAME" | grep -c '^[0-9]' 2>/dev/null || echo "0")
    echo "Active set:    $IPSET_NAME ($count entries)"
  else
    echo "Active set:    NOT CREATED"
  fi
  
  if [[ -f "$DATA_DIR/last-update" ]]; then
    echo "Last updated:  $(cat "$DATA_DIR/last-update")"
  else
    echo "Last updated:  Never"
  fi
  
  local enabled=0
  for _ in "${LISTS[@]}"; do ((enabled++)); done
  echo "Lists enabled: $enabled"
  
  if iptables -C "$CHAIN" -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
    echo "iptables rule: ACTIVE ($CHAIN chain)"
  else
    echo "iptables rule: INACTIVE"
  fi
  
  # Blocked today (from kernel counters if available)
  if iptables -nvL "$CHAIN" 2>/dev/null | grep -q "$IPSET_NAME"; then
    local pkts
    pkts=$(iptables -nvL "$CHAIN" 2>/dev/null | grep "$IPSET_NAME" | grep DROP | awk '{print $1}' | head -1)
    echo "Packets dropped: ${pkts:-0}"
  fi
}

# ── Check command ──
cmd_check() {
  local ip="${1:-}"
  if [[ -z "$ip" ]]; then
    echo "Usage: $0 check <IP>" >&2
    exit 1
  fi
  
  if ipset test "$IPSET_NAME" "$ip" 2>/dev/null; then
    echo "⛔ $ip is BLOCKED"
    # Check which lists contain it
    echo "Found in:"
    for entry in "${LISTS[@]}"; do
      local name="${entry%%|*}"
      if [[ -f "$DATA_DIR/${name}.parsed" ]] && grep -q "^${ip}" "$DATA_DIR/${name}.parsed"; then
        echo "  - $name"
      fi
    done
  else
    echo "✅ $ip is NOT blocked"
  fi
}

# ── Whitelist command ──
cmd_whitelist() {
  local action="${1:-list}"
  shift || true
  
  case "$action" in
    add)
      local ip="${1:-}"
      [[ -z "$ip" ]] && { echo "Usage: $0 whitelist add <IP>"; exit 1; }
      echo "$ip" >> "$WHITELIST_FILE"
      sort -u -o "$WHITELIST_FILE" "$WHITELIST_FILE"
      echo "✅ Added $ip to whitelist"
      # Remove from active set
      ipset del "$IPSET_NAME" "$ip" 2>/dev/null || true
      ;;
    remove)
      local ip="${1:-}"
      [[ -z "$ip" ]] && { echo "Usage: $0 whitelist remove <IP>"; exit 1; }
      if [[ -f "$WHITELIST_FILE" ]]; then
        sed -i "/^${ip//./\\.}$/d" "$WHITELIST_FILE"
        echo "✅ Removed $ip from whitelist"
      fi
      ;;
    list)
      if [[ -f "$WHITELIST_FILE" ]]; then
        echo "Whitelisted IPs:"
        cat "$WHITELIST_FILE"
      else
        echo "No whitelist configured"
      fi
      ;;
    *)
      echo "Usage: $0 whitelist [add|remove|list] [IP]" >&2
      ;;
  esac
}

# ── Logging command ──
cmd_logging() {
  check_root
  local action="${1:-status}"
  
  case "$action" in
    on)
      if ! iptables -C "$CHAIN" -m set --match-set "$IPSET_NAME" src -j LOG 2>/dev/null; then
        # Find position of DROP rule and insert LOG before it
        iptables -I "$CHAIN" "$POSITION" -m set --match-set "$IPSET_NAME" src \
          -j LOG --log-prefix "$LOG_PREFIX" --log-level 4
        echo "✅ Logging enabled (prefix: ${LOG_PREFIX})"
      else
        echo "ℹ️  Logging already enabled"
      fi
      ;;
    off)
      iptables -D "$CHAIN" -m set --match-set "$IPSET_NAME" src \
        -j LOG --log-prefix "$LOG_PREFIX" --log-level 4 2>/dev/null || true
      echo "✅ Logging disabled"
      ;;
    *)
      echo "Usage: $0 logging [on|off]" >&2
      ;;
  esac
}

# ── Log viewer ──
cmd_log() {
  local tail_n=20
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tail) tail_n="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if command -v journalctl &>/dev/null; then
    journalctl -k --grep="$LOG_PREFIX" --no-pager -n "$tail_n" 2>/dev/null || \
      dmesg | grep "$LOG_PREFIX" | tail -n "$tail_n"
  else
    dmesg | grep "$LOG_PREFIX" | tail -n "$tail_n"
  fi
}

# ── Export command ──
cmd_export() {
  local detailed=false
  [[ "${1:-}" == "--detailed" ]] && detailed=true
  
  if $detailed; then
    echo "ip,source_list"
    for entry in "${LISTS[@]}"; do
      local name="${entry%%|*}"
      if [[ -f "$DATA_DIR/${name}.parsed" ]]; then
        while IFS= read -r ip; do
          echo "$ip,$name"
        done < "$DATA_DIR/${name}.parsed"
      fi
    done
  else
    ipset list "$IPSET_NAME" 2>/dev/null | grep '^[0-9]'
  fi
}

# ── Cron command ──
cmd_cron() {
  check_root
  local action="${1:-status}" interval="6h"
  shift || true
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --interval) interval="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local script_path
  script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  local cron_id="# blocklist-manager-auto-update"
  
  case "$action" in
    install)
      local cron_expr
      case "$interval" in
        1h)  cron_expr="0 * * * *" ;;
        6h)  cron_expr="0 */6 * * *" ;;
        12h) cron_expr="0 */12 * * *" ;;
        24h) cron_expr="0 4 * * *" ;;
        *)   cron_expr="0 */6 * * *" ;;
      esac
      
      # Remove existing and add new
      (crontab -l 2>/dev/null | grep -v "$cron_id"; \
       echo "$cron_expr $script_path update $cron_id") | crontab -
      echo "✅ Cron installed: $cron_expr (every $interval)"
      ;;
    remove)
      (crontab -l 2>/dev/null | grep -v "$cron_id") | crontab -
      echo "✅ Cron removed"
      ;;
    status)
      if crontab -l 2>/dev/null | grep -q "$cron_id"; then
        echo "✅ Cron active:"
        crontab -l 2>/dev/null | grep "$cron_id"
      else
        echo "❌ No cron job installed"
      fi
      ;;
    *)
      echo "Usage: $0 cron [install|remove|status] [--interval 6h]" >&2
      ;;
  esac
}

# ── Persist command (survive reboots) ──
cmd_persist() {
  check_root
  local action="${1:-install}"
  local systemd_unit="/etc/systemd/system/blocklist-restore.service"
  
  case "$action" in
    install)
      # Save current state
      ipset save > "$DATA_DIR/ipset.save"
      iptables-save > "$DATA_DIR/iptables.save"
      
      # Create systemd service for restore on boot
      cat > "$systemd_unit" << 'UNIT'
[Unit]
Description=Restore IP Blocklist on boot
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "ipset restore < /var/lib/blocklist-manager/ipset.save && iptables-restore < /var/lib/blocklist-manager/iptables.save"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
      systemctl daemon-reload
      systemctl enable blocklist-restore.service
      echo "✅ Persistence installed (systemd service)"
      ;;
    save)
      ipset save > "$DATA_DIR/ipset.save"
      iptables-save > "$DATA_DIR/iptables.save"
      echo "✅ State saved"
      ;;
    *)
      echo "Usage: $0 persist [install|save]" >&2
      ;;
  esac
}

# ── Stats command ──
cmd_stats() {
  echo "Blocklist Statistics"
  echo "────────────────────"
  
  if [[ -f "$DATA_DIR/total-ips" ]]; then
    echo "Total IPs blocked: $(cat "$DATA_DIR/total-ips")"
  fi
  
  echo ""
  echo "Per-list breakdown:"
  for entry in "${LISTS[@]}"; do
    local name="${entry%%|*}"
    if [[ -f "$DATA_DIR/${name}.parsed" ]]; then
      local count
      count=$(wc -l < "$DATA_DIR/${name}.parsed")
      printf "  %-25s %s IPs\n" "$name" "$count"
    fi
  done
  
  echo ""
  if iptables -nvL "$CHAIN" 2>/dev/null | grep -q "$IPSET_NAME"; then
    echo "Firewall counters:"
    iptables -nvL "$CHAIN" 2>/dev/null | grep "$IPSET_NAME" | \
      awk '{printf "  Packets: %s  Bytes: %s\n", $1, $2}'
  fi
}

# ── Uninstall command ──
cmd_uninstall() {
  check_root
  echo "Removing IP Blocklist Manager..."
  
  # Remove iptables rules
  iptables -D "$CHAIN" -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null || true
  iptables -D "$CHAIN" -m set --match-set "$IPSET_NAME" src -j LOG 2>/dev/null || true
  
  # Remove ipset
  ipset destroy "$IPSET_NAME" 2>/dev/null || true
  
  # Remove cron
  (crontab -l 2>/dev/null | grep -v "blocklist-manager-auto-update") | crontab - 2>/dev/null || true
  
  # Remove systemd service
  systemctl disable blocklist-restore.service 2>/dev/null || true
  rm -f /etc/systemd/system/blocklist-restore.service 2>/dev/null || true
  
  echo "✅ Uninstalled (data kept at $DATA_DIR)"
}

# ── Main ──
load_config

case "${1:-help}" in
  update)    shift; cmd_update "$@" ;;
  status)    cmd_status ;;
  check)     shift; cmd_check "$@" ;;
  whitelist) shift; cmd_whitelist "$@" ;;
  logging)   shift; cmd_logging "$@" ;;
  log)       shift; cmd_log "$@" ;;
  export)    shift; cmd_export "$@" ;;
  cron)      shift; cmd_cron "$@" ;;
  persist)   shift; cmd_persist "$@" ;;
  stats)     cmd_stats ;;
  uninstall) cmd_uninstall ;;
  version)   echo "IP Blocklist Manager v$VERSION" ;;
  help|*)
    echo "IP Blocklist Manager v$VERSION"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  update     Download blocklists and load into ipset/iptables"
    echo "  status     Show current blocking status"
    echo "  check      Check if an IP is blocked"
    echo "  whitelist  Manage whitelisted IPs"
    echo "  logging    Enable/disable blocked traffic logging"
    echo "  log        View blocked traffic log"
    echo "  export     Export blocked IPs to stdout"
    echo "  cron       Install/remove auto-update cron job"
    echo "  persist    Make rules survive reboot"
    echo "  stats      Show blocking statistics"
    echo "  uninstall  Remove all rules and sets"
    echo "  version    Show version"
    echo ""
    echo "Options:"
    echo "  --dry-run       Download only, don't apply (update)"
    echo "  --lists x,y     Update specific lists only (update)"
    echo "  --interval 6h   Cron interval (cron install)"
    echo "  --tail N        Lines to show (log)"
    echo "  --detailed      Include source info (export)"
    ;;
esac
