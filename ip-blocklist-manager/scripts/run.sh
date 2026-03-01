#!/bin/bash
# IP Blocklist Manager — Download threat feeds, manage ipset/iptables blocklists
# Requires: bash 4+, curl, ipset, iptables (root/sudo)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"

# Load config
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

# Defaults (if config not loaded)
IPSET_NAME="${IPSET_NAME:-ip-blocklist}"
IPSET_MAXELEM="${IPSET_MAXELEM:-131072}"
DATA_DIR="${DATA_DIR:-/var/lib/ip-blocklist}"
LOG_FILE="${LOG_FILE:-/var/log/ip-blocklist.log}"
WHITELIST_FILE="${WHITELIST_FILE:-${SCRIPT_DIR}/whitelist.txt}"
CUSTOM_FEEDS_FILE="${CUSTOM_FEEDS_FILE:-${SCRIPT_DIR}/custom-feeds.txt}"
CRON_SCHEDULE="${CRON_SCHEDULE:-0 */6 * * *}"
LOG_BLOCKED="${LOG_BLOCKED:-true}"
LOG_PREFIX="${LOG_PREFIX:-[BLOCKLIST] }"

# Feed toggles
FEED_SPAMHAUS_DROP="${FEED_SPAMHAUS_DROP:-true}"
FEED_SPAMHAUS_EDROP="${FEED_SPAMHAUS_EDROP:-true}"
FEED_ABUSECH_FEODO="${FEED_ABUSECH_FEODO:-true}"
FEED_ABUSECH_SSLBL="${FEED_ABUSECH_SSLBL:-true}"
FEED_EMERGINGTHREATS="${FEED_EMERGINGTHREATS:-true}"
FEED_BLOCKLIST_DE="${FEED_BLOCKLIST_DE:-true}"
FEED_CINSSCORE="${FEED_CINSSCORE:-false}"
FEED_DSHIELD="${FEED_DSHIELD:-true}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Timestamp
ts() { date -u '+%Y-%m-%d %H:%M:%S'; }
log() { echo -e "[$(ts)] $*"; }
log_file() { echo "[$(ts)] $*" >> "$LOG_FILE" 2>/dev/null || true; }

# Parse arguments
ACTION=""
DRY_RUN=false
PERSIST=false
QUIET=false
INSTALL_CRON=false
REMOVE_CRON=false
INSTALL_SYSTEMD=false
EXPORT=false
ANNOTATED=false
SHOW_LOG=0
WHITELIST_ADD=""
WHITELIST_REMOVE=""
WHITELIST_SHOW=false
REMOVE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --apply) ACTION="apply"; shift ;;
    --dry-run) DRY_RUN=true; ACTION="dryrun"; shift ;;
    --status) ACTION="status"; shift ;;
    --persist) PERSIST=true; shift ;;
    --no-persist) PERSIST=false; shift ;;
    --quiet) QUIET=true; shift ;;
    --install-cron) INSTALL_CRON=true; shift ;;
    --remove-cron) REMOVE_CRON=true; shift ;;
    --install-systemd) INSTALL_SYSTEMD=true; shift ;;
    --export) EXPORT=true; ACTION="export"; shift ;;
    --annotated) ANNOTATED=true; shift ;;
    --log) SHOW_LOG="${2:-50}"; ACTION="log"; shift; shift 2>/dev/null || true ;;
    --whitelist-add) WHITELIST_ADD="$2"; ACTION="whitelist"; shift 2 ;;
    --whitelist-remove) WHITELIST_REMOVE="$2"; ACTION="whitelist"; shift 2 ;;
    --whitelist-show) WHITELIST_SHOW=true; ACTION="whitelist"; shift ;;
    --remove) REMOVE=true; ACTION="remove"; shift ;;
    --version) echo "IP Blocklist Manager v${VERSION}"; exit 0 ;;
    --help|-h) ACTION="help"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

[[ -z "$ACTION" ]] && ACTION="help"

# ========== FEED DEFINITIONS ==========

declare -A FEEDS

[[ "$FEED_SPAMHAUS_DROP" == "true" ]] && \
  FEEDS[spamhaus-drop]="https://www.spamhaus.org/drop/drop.txt"
[[ "$FEED_SPAMHAUS_EDROP" == "true" ]] && \
  FEEDS[spamhaus-edrop]="https://www.spamhaus.org/drop/edrop.txt"
[[ "$FEED_ABUSECH_FEODO" == "true" ]] && \
  FEEDS[abusech-feodo]="https://feodotracker.abuse.ch/downloads/ipblocklist.txt"
[[ "$FEED_ABUSECH_SSLBL" == "true" ]] && \
  FEEDS[abusech-sslbl]="https://sslbl.abuse.ch/blacklist/sslipblacklist.txt"
[[ "$FEED_EMERGINGTHREATS" == "true" ]] && \
  FEEDS[emergingthreats]="https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt"
[[ "$FEED_BLOCKLIST_DE" == "true" ]] && \
  FEEDS[blocklist-de]="https://lists.blocklist.de/lists/all.txt"
[[ "$FEED_CINSSCORE" == "true" ]] && \
  FEEDS[cinsscore]="https://cinsscore.com/list/ci-badguys.txt"
[[ "$FEED_DSHIELD" == "true" ]] && \
  FEEDS[dshield]="https://feeds.dshield.org/block.txt"

# ========== FUNCTIONS ==========

download_feed() {
  local name="$1" url="$2" outfile="$3"
  local tmp="${outfile}.tmp"
  
  if ! curl -sS --max-time 30 --retry 2 -o "$tmp" "$url" 2>/dev/null; then
    log "${RED}✗${NC} Failed to download ${name}"
    log_file "FAIL download ${name} from ${url}"
    return 1
  fi
  
  # Extract IPs/CIDRs (strip comments, empty lines)
  grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' "$tmp" | sort -u > "$outfile"
  local count
  count=$(wc -l < "$outfile")
  
  if [[ "$QUIET" != "true" ]]; then
    log "${GREEN}✓${NC} ${name}: ${count} IPs"
  fi
  log_file "OK ${name}: ${count} IPs"
  
  rm -f "$tmp"
  echo "$count"
}

load_whitelist() {
  if [[ -f "$WHITELIST_FILE" ]]; then
    grep -vE '^\s*#|^\s*$' "$WHITELIST_FILE" 2>/dev/null || true
  fi
}

merge_feeds() {
  local merged="$1"
  local whitelist_tmp
  whitelist_tmp=$(mktemp)
  
  load_whitelist > "$whitelist_tmp"
  
  # Merge all feed files, deduplicate, remove whitelisted
  cat "${DATA_DIR}"/feeds/*.ips 2>/dev/null | sort -u | while read -r ip; do
    local dominated=false
    while read -r wl; do
      [[ -z "$wl" ]] && continue
      # Simple prefix match for CIDRs (basic, not full CIDR math)
      if [[ "$ip" == "$wl" ]]; then
        dominated=true
        break
      fi
    done < "$whitelist_tmp"
    [[ "$dominated" == "false" ]] && echo "$ip"
  done > "$merged"
  
  rm -f "$whitelist_tmp"
}

apply_ipset() {
  local merged="$1"
  local count
  count=$(wc -l < "$merged")
  
  # Create or flush ipset
  if ipset list "$IPSET_NAME" &>/dev/null; then
    ipset flush "$IPSET_NAME"
  else
    ipset create "$IPSET_NAME" hash:net maxelem "$IPSET_MAXELEM" -exist
  fi
  
  # Bulk load via restore (much faster than individual adds)
  local restore_tmp
  restore_tmp=$(mktemp)
  echo "create ${IPSET_NAME} hash:net maxelem ${IPSET_MAXELEM} -exist" > "$restore_tmp"
  while read -r ip; do
    echo "add ${IPSET_NAME} ${ip} -exist" >> "$restore_tmp"
  done < "$merged"
  
  ipset restore -f "$restore_tmp" 2>/dev/null || {
    # Fallback: load one by one (slower but handles edge cases)
    while read -r ip; do
      ipset add "$IPSET_NAME" "$ip" -exist 2>/dev/null || true
    done < "$merged"
  }
  
  rm -f "$restore_tmp"
  
  # Add iptables rule if not exists
  if ! iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
    iptables -I INPUT 1 -m set --match-set "$IPSET_NAME" src -j DROP
    log "iptables DROP rule added for ${IPSET_NAME}"
  fi
  
  # Optional: log blocked connections
  if [[ "$LOG_BLOCKED" == "true" ]]; then
    if ! iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j LOG --log-prefix "$LOG_PREFIX" 2>/dev/null; then
      iptables -I INPUT 1 -m set --match-set "$IPSET_NAME" src -j LOG --log-prefix "$LOG_PREFIX" --log-level 4
    fi
  fi
  
  log "${GREEN}✅ Loaded ${count} IPs into ipset '${IPSET_NAME}'${NC}"
  log_file "APPLIED ${count} IPs to ${IPSET_NAME}"
  
  # Save last-update timestamp
  echo "$(ts)" > "${DATA_DIR}/last-update"
  echo "$count" > "${DATA_DIR}/last-count"
}

persist_rules() {
  # Save ipset
  ipset save > /etc/ipset.conf 2>/dev/null || ipset save > "${DATA_DIR}/ipset.conf"
  
  # Save iptables
  if command -v iptables-save &>/dev/null; then
    iptables-save > /etc/iptables.rules 2>/dev/null || iptables-save > "${DATA_DIR}/iptables.rules"
  fi
  
  log "Rules persisted for reboot"
}

# ========== ACTIONS ==========

do_apply() {
  mkdir -p "${DATA_DIR}/feeds"
  
  local total=0
  for name in "${!FEEDS[@]}"; do
    local url="${FEEDS[$name]}"
    local outfile="${DATA_DIR}/feeds/${name}.ips"
    local count
    count=$(download_feed "$name" "$url" "$outfile" || echo "0")
    total=$((total + count))
  done
  
  # Load custom feeds
  if [[ -f "$CUSTOM_FEEDS_FILE" ]]; then
    local i=0
    while read -r url; do
      [[ -z "$url" || "$url" == \#* ]] && continue
      i=$((i + 1))
      local outfile="${DATA_DIR}/feeds/custom-${i}.ips"
      download_feed "custom-${i}" "$url" "$outfile" || true
    done < "$CUSTOM_FEEDS_FILE"
  fi
  
  # Merge and deduplicate
  local merged="${DATA_DIR}/merged.ips"
  merge_feeds "$merged"
  
  local unique_count
  unique_count=$(wc -l < "$merged")
  log "Total unique IPs after dedup + whitelist: ${unique_count}"
  
  # Apply to ipset/iptables
  apply_ipset "$merged"
  
  # Persist if requested
  [[ "$PERSIST" == "true" ]] && persist_rules
  
  # Install cron if requested
  [[ "$INSTALL_CRON" == "true" ]] && do_install_cron
  
  # Install systemd if requested
  [[ "$INSTALL_SYSTEMD" == "true" ]] && do_install_systemd
}

do_dryrun() {
  mkdir -p "${DATA_DIR}/feeds"
  
  local total=0
  local feed_counts=""
  for name in "${!FEEDS[@]}"; do
    local url="${FEEDS[$name]}"
    local outfile="${DATA_DIR}/feeds/${name}.ips"
    local count
    count=$(download_feed "$name" "$url" "$outfile" || echo "0")
    total=$((total + count))
    feed_counts="${feed_counts}\n  ${name}: ${count}"
  done
  
  echo ""
  echo -e "${YELLOW}[DRY RUN]${NC} Would block approximately ${total} IPs from ${#FEEDS[@]} feeds"
  echo -e "Feed breakdown:${feed_counts}"
  echo ""
  echo "Run with --apply to activate blocking."
}

do_status() {
  echo "=== IP Blocklist Manager Status ==="
  echo ""
  
  if ipset list "$IPSET_NAME" &>/dev/null; then
    local entries
    entries=$(ipset list "$IPSET_NAME" | grep "Number of entries:" | awk '{print $NF}')
    echo -e "Status: ${GREEN}ACTIVE${NC}"
    echo "  Ipset name: ${IPSET_NAME}"
    echo "  IPs blocked: ${entries}"
    
    if [[ -f "${DATA_DIR}/last-update" ]]; then
      echo "  Last updated: $(cat "${DATA_DIR}/last-update")"
    fi
    
    # Show iptables rule
    if iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null; then
      echo -e "  iptables rule: ${GREEN}active${NC}"
    else
      echo -e "  iptables rule: ${RED}missing${NC}"
    fi
    
    # Show feeds
    echo "  Feeds:"
    for f in "${DATA_DIR}"/feeds/*.ips; do
      [[ ! -f "$f" ]] && continue
      local fname count
      fname=$(basename "$f" .ips)
      count=$(wc -l < "$f")
      echo "    ${fname}: ${count} IPs"
    done
  else
    echo -e "Status: ${RED}INACTIVE${NC}"
    echo "Run: sudo bash scripts/run.sh --apply"
  fi
  
  echo ""
  
  # Show blocked count from logs (last 24h)
  if [[ -f /var/log/syslog ]]; then
    local blocked_today
    blocked_today=$(grep -c "${LOG_PREFIX}" /var/log/syslog 2>/dev/null || echo "0")
    echo "Blocked connections (in syslog): ${blocked_today}"
  fi
}

do_export() {
  if ipset list "$IPSET_NAME" &>/dev/null; then
    ipset list "$IPSET_NAME" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?'
  else
    echo "No active blocklist. Run --apply first." >&2
    exit 1
  fi
}

do_log() {
  if [[ -f /var/log/syslog ]]; then
    grep "${LOG_PREFIX}" /var/log/syslog | tail -n "$SHOW_LOG"
  elif [[ -f /var/log/messages ]]; then
    grep "${LOG_PREFIX}" /var/log/messages | tail -n "$SHOW_LOG"
  elif command -v journalctl &>/dev/null; then
    journalctl --no-pager -g "${LOG_PREFIX}" | tail -n "$SHOW_LOG"
  else
    echo "No log source found. Check kernel log or journalctl."
  fi
}

do_whitelist() {
  if [[ -n "$WHITELIST_ADD" ]]; then
    echo "$WHITELIST_ADD" >> "$WHITELIST_FILE"
    log "Added ${WHITELIST_ADD} to whitelist"
    echo "Note: Run --apply again to refresh rules."
  fi
  
  if [[ -n "$WHITELIST_REMOVE" ]]; then
    if [[ -f "$WHITELIST_FILE" ]]; then
      local tmp
      tmp=$(mktemp)
      grep -v "^${WHITELIST_REMOVE}$" "$WHITELIST_FILE" > "$tmp" || true
      mv "$tmp" "$WHITELIST_FILE"
      log "Removed ${WHITELIST_REMOVE} from whitelist"
      echo "Note: Run --apply again to refresh rules."
    fi
  fi
  
  if [[ "$WHITELIST_SHOW" == "true" ]]; then
    echo "=== Whitelist ==="
    if [[ -f "$WHITELIST_FILE" ]]; then
      cat "$WHITELIST_FILE"
    else
      echo "(empty)"
    fi
  fi
}

do_remove() {
  # Remove iptables rules
  iptables -D INPUT -m set --match-set "$IPSET_NAME" src -j DROP 2>/dev/null || true
  iptables -D INPUT -m set --match-set "$IPSET_NAME" src -j LOG --log-prefix "$LOG_PREFIX" --log-level 4 2>/dev/null || true
  
  # Destroy ipset
  ipset destroy "$IPSET_NAME" 2>/dev/null || true
  
  log "${GREEN}✅ Removed all blocklist rules${NC}"
  
  if [[ "$REMOVE_CRON" == "true" ]]; then
    crontab -l 2>/dev/null | grep -v "ip-blocklist" | crontab - 2>/dev/null || true
    log "Removed cron job"
  fi
}

do_install_cron() {
  local script_path
  script_path="$(cd "$SCRIPT_DIR" && pwd)/run.sh"
  
  (crontab -l 2>/dev/null | grep -v "ip-blocklist"; \
   echo "${CRON_SCHEDULE} ${script_path} --apply --quiet >> ${LOG_FILE} 2>&1 # ip-blocklist") | crontab -
  
  log "Cron job installed: ${CRON_SCHEDULE}"
}

do_install_systemd() {
  local script_path
  script_path="$(cd "$SCRIPT_DIR" && pwd)/run.sh"
  
  cat > /etc/systemd/system/ip-blocklist.service << EOF
[Unit]
Description=IP Blocklist Manager
After=network-online.target

[Service]
Type=oneshot
ExecStart=${script_path} --apply --quiet
StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}
EOF

  cat > /etc/systemd/system/ip-blocklist.timer << EOF
[Unit]
Description=IP Blocklist Auto-Update

[Timer]
OnBootSec=5min
OnUnitActiveSec=6h
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now ip-blocklist.timer
  log "systemd timer installed and started"
}

do_help() {
  cat << 'EOF'
IP Blocklist Manager v1.0.0

Usage: bash run.sh [OPTIONS]

Actions:
  --apply              Download feeds and apply iptables/ipset rules
  --dry-run            Preview what would be blocked (no changes)
  --status             Show current blocklist status
  --export             Export blocked IPs to stdout
  --log [N]            Show last N blocked connections (default: 50)
  --remove             Remove all blocklist rules

Options:
  --persist            Save rules to survive reboots
  --no-persist         Don't persist (default)
  --quiet              Minimal output (for cron)
  --install-cron       Add cron job for auto-updates
  --remove-cron        Remove cron job (use with --remove)
  --install-systemd    Create systemd service + timer

Whitelist:
  --whitelist-add IP   Add IP/CIDR to whitelist
  --whitelist-remove IP Remove IP/CIDR from whitelist
  --whitelist-show     Show current whitelist

Other:
  --version            Show version
  --help               Show this help

Examples:
  sudo bash run.sh --apply                    # Block malicious IPs
  sudo bash run.sh --apply --persist          # Block + survive reboots
  sudo bash run.sh --dry-run                  # Preview only
  sudo bash run.sh --status                   # Check status
  sudo bash run.sh --remove --remove-cron     # Uninstall everything
EOF
}

# ========== MAIN ==========

case "$ACTION" in
  apply) do_apply ;;
  dryrun) do_dryrun ;;
  status) do_status ;;
  export) do_export ;;
  log) do_log ;;
  whitelist) do_whitelist ;;
  remove) do_remove ;;
  help) do_help ;;
  *) do_help ;;
esac
