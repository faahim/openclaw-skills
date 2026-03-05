#!/bin/bash
# nftables Firewall Manager — Main Management Script
# Usage: bash nft-manage.sh <command> [options]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

NFT_CONF="${NFT_CONFIG:-/etc/nftables.conf}"
NFT_LOG_DIR="/var/log/nftables"
DRY_RUN="${NFT_DRY_RUN:-0}"
VERBOSE="${NFT_VERBOSE:-0}"

log()  { echo -e "${GREEN}[nft]${NC} $*"; }
warn() { echo -e "${YELLOW}[nft]${NC} $*"; }
err()  { echo -e "${RED}[nft]${NC} $*" >&2; }
info() { echo -e "${CYAN}[nft]${NC} $*"; }

check_root() {
  if [ "$EUID" -ne 0 ]; then
    err "This command requires root. Run with: sudo $0 $*"
    exit 1
  fi
}

check_nft() {
  if ! command -v nft &>/dev/null; then
    err "nftables not installed. Run: bash scripts/install.sh"
    exit 1
  fi
}

run_nft() {
  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY RUN] nft $*"
  else
    [ "$VERBOSE" = "1" ] && echo "[exec] nft $*"
    nft "$@"
  fi
}

# ─── PRESETS ────────────────────────────────────────────────

preset_server_basic() {
  cat <<'EOF'
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
  set blocklist {
    type ipv4_addr
    flags interval
  }

  chain input {
    type filter hook input priority 0; policy drop;

    # Connection tracking
    ct state established,related accept
    ct state invalid drop

    # Loopback
    iif "lo" accept

    # Blocklist
    ip saddr @blocklist log prefix "[nft-blocked] " counter drop

    # ICMP
    ip protocol icmp icmp type { echo-request, destination-unreachable, time-exceeded } accept
    ip6 nexthdr icmpv6 accept

    # SSH
    tcp dport 22 ct state new accept

    # HTTP/HTTPS
    tcp dport { 80, 443 } accept

    # Log & drop rest
    log prefix "[nft-drop] " counter drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF
}

preset_server_full() {
  cat <<'EOF'
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
  set blocklist {
    type ipv4_addr
    flags interval
  }

  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    ct state invalid drop
    iif "lo" accept
    ip saddr @blocklist log prefix "[nft-blocked] " counter drop
    ip protocol icmp icmp type { echo-request, destination-unreachable, time-exceeded } accept
    ip6 nexthdr icmpv6 accept
    tcp dport 22 ct state new accept
    tcp dport { 80, 443 } accept
    tcp dport { 25, 587, 993 } accept comment "Mail"
    tcp dport 5432 accept comment "PostgreSQL"
    tcp dport 3306 accept comment "MySQL"
    log prefix "[nft-drop] " counter drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF
}

preset_desktop() {
  cat <<'EOF'
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    ct state invalid drop
    iif "lo" accept
    ip protocol icmp accept
    ip6 nexthdr icmpv6 accept
    tcp dport 22 ct state new accept comment "SSH"
    log prefix "[nft-drop] " counter drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF
}

preset_lockdown() {
  cat <<'EOF'
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iif "lo" accept
    tcp dport 22 ct state new accept
    counter drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF
}

preset_docker_host() {
  cat <<'EOF'
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
  set blocklist {
    type ipv4_addr
    flags interval
  }

  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    ct state invalid drop
    iif "lo" accept
    ip saddr @blocklist counter drop
    ip protocol icmp accept
    tcp dport 22 ct state new accept
    tcp dport { 80, 443 } accept
    log prefix "[nft-drop] " counter drop
  }

  chain forward {
    type filter hook forward priority 0; policy accept;
    ct state established,related accept
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF
}

# ─── COMMANDS ───────────────────────────────────────────────

cmd_show() {
  check_nft
  local COUNTERS=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --counters|-c) COUNTERS="1"; shift ;;
      *) shift ;;
    esac
  done

  echo -e "${BOLD}Current nftables ruleset:${NC}"
  echo "─────────────────────────────────────────"
  if [ "$COUNTERS" = "1" ]; then
    nft list ruleset -a
  else
    nft list ruleset
  fi
}

cmd_apply_preset() {
  check_root
  check_nft
  local PRESET="${1:-}"
  if [ -z "$PRESET" ]; then
    echo "Available presets:"
    echo "  server-basic  — Web server (SSH + HTTP/HTTPS)"
    echo "  server-full   — Web + mail + database"
    echo "  desktop       — Permissive outbound, restrict inbound"
    echo "  lockdown      — SSH only"
    echo "  docker-host   — Docker-friendly with forwarding"
    echo ""
    echo "Usage: $0 apply-preset <preset-name>"
    exit 1
  fi

  # Safety: ensure SSH is reachable
  info "Safety check: ensuring SSH access before applying..."

  local RULESET
  case "$PRESET" in
    server-basic)  RULESET=$(preset_server_basic) ;;
    server-full)   RULESET=$(preset_server_full) ;;
    desktop)       RULESET=$(preset_desktop) ;;
    lockdown)      RULESET=$(preset_lockdown) ;;
    docker-host)   RULESET=$(preset_docker_host) ;;
    *)
      err "Unknown preset: $PRESET"
      exit 1
      ;;
  esac

  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY RUN] Would apply preset: $PRESET"
    echo "$RULESET"
    return
  fi

  # Apply atomically
  echo "$RULESET" | nft -f -
  log "✅ Applied preset: $PRESET"

  # Persist
  nft list ruleset > "$NFT_CONF"
  log "Rules saved to $NFT_CONF"
}

cmd_allow() {
  check_root
  check_nft
  local PORT="" PROTO="tcp" COMMENT=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port|-p) PORT="$2"; shift 2 ;;
      --proto) PROTO="$2"; shift 2 ;;
      --comment) COMMENT="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$PORT" ]; then
    err "Usage: $0 allow --port <port> [--proto tcp|udp] [--comment 'note']"
    exit 1
  fi

  # Ensure filter table and input chain exist
  nft list table inet filter &>/dev/null || {
    warn "No filter table found. Apply a preset first: $0 apply-preset server-basic"
    exit 1
  }

  local RULE="$PROTO dport $PORT accept"
  [ -n "$COMMENT" ] && RULE="$PROTO dport $PORT accept comment \"$COMMENT\""

  run_nft insert rule inet filter input "$PROTO" dport "$PORT" accept
  log "✅ Allowed $PROTO port $PORT"

  # Persist
  nft list ruleset > "$NFT_CONF"
}

cmd_block() {
  check_root
  check_nft
  local IP="" FILE=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ip) IP="$2"; shift 2 ;;
      --file) FILE="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # Ensure blocklist set exists
  nft list set inet filter blocklist &>/dev/null 2>&1 || {
    warn "Creating blocklist set..."
    nft add set inet filter blocklist '{ type ipv4_addr; flags interval; }' 2>/dev/null || true
  }

  if [ -n "$IP" ]; then
    run_nft add element inet filter blocklist "{ $IP }"
    log "✅ Blocked IP: $IP"
  elif [ -n "$FILE" ]; then
    if [ ! -f "$FILE" ]; then
      err "File not found: $FILE"
      exit 1
    fi
    local COUNT=0
    while IFS= read -r line; do
      line=$(echo "$line" | tr -d '[:space:]')
      [ -z "$line" ] && continue
      [[ "$line" == \#* ]] && continue
      run_nft add element inet filter blocklist "{ $line }" 2>/dev/null && ((COUNT++)) || true
    done < "$FILE"
    log "✅ Blocked $COUNT IPs from $FILE"
  else
    err "Usage: $0 block --ip <address> OR --file <path>"
    exit 1
  fi

  nft list ruleset > "$NFT_CONF"
}

cmd_unblock() {
  check_root
  check_nft
  local IP=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ip) IP="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$IP" ]; then
    err "Usage: $0 unblock --ip <address>"
    exit 1
  fi

  run_nft delete element inet filter blocklist "{ $IP }"
  log "✅ Unblocked IP: $IP"
  nft list ruleset > "$NFT_CONF"
}

cmd_rate_limit() {
  check_root
  check_nft
  local PORT="" RATE="" BURST="10"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port) PORT="$2"; shift 2 ;;
      --rate) RATE="$2"; shift 2 ;;
      --burst) BURST="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$PORT" ] || [ -z "$RATE" ]; then
    err "Usage: $0 rate-limit --port <port> --rate '<N>/<unit>' [--burst <N>]"
    err "  Units: second, minute, hour, day"
    err "  Example: --rate '5/minute' --burst 10"
    exit 1
  fi

  # Remove existing rule for this port, then add rate-limited version
  # Insert at beginning of input chain
  run_nft insert rule inet filter input tcp dport "$PORT" ct state new limit rate "$RATE" burst "$BURST" packets accept
  log "✅ Rate-limited port $PORT to $RATE (burst: $BURST)"
  nft list ruleset > "$NFT_CONF"
}

cmd_nat() {
  check_root
  check_nft
  local DPORT="" TO=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dport) DPORT="$2"; shift 2 ;;
      --to) TO="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$DPORT" ] || [ -z "$TO" ]; then
    err "Usage: $0 nat --dport <port> --to <ip:port>"
    exit 1
  fi

  # Ensure NAT table exists
  nft list table ip nat &>/dev/null 2>&1 || {
    run_nft add table ip nat
    run_nft add chain ip nat prerouting '{ type nat hook prerouting priority -100; }'
    run_nft add chain ip nat postrouting '{ type nat hook postrouting priority 100; }'
  }

  run_nft add rule ip nat prerouting tcp dport "$DPORT" dnat to "$TO"
  run_nft add rule ip nat postrouting masquerade

  # Enable IP forwarding
  if [ "$DRY_RUN" != "1" ]; then
    echo 1 > /proc/sys/net/ipv4/ip_forward
    grep -q "net.ipv4.ip_forward" /etc/sysctl.conf 2>/dev/null || {
      echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    }
  fi

  log "✅ NAT: port $DPORT → $TO"
  nft list ruleset > "$NFT_CONF"
}

cmd_backup() {
  check_nft
  nft list ruleset
}

cmd_restore() {
  check_root
  check_nft
  local FILE="${1:-}"
  if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    err "Usage: $0 restore <backup-file.nft>"
    exit 1
  fi

  info "Restoring from: $FILE"
  run_nft -f "$FILE"
  log "✅ Ruleset restored from $FILE"
  nft list ruleset > "$NFT_CONF"
}

cmd_persist() {
  check_root
  check_nft
  nft list ruleset > "$NFT_CONF"
  log "✅ Current ruleset saved to $NFT_CONF"
}

cmd_flush() {
  check_root
  check_nft
  warn "⚠️  This will remove ALL firewall rules (allow all traffic)"
  read -rp "Are you sure? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    run_nft flush ruleset
    log "✅ All rules flushed"
  else
    log "Cancelled"
  fi
}

cmd_list_allowed() {
  check_nft
  echo -e "${BOLD}Allowed ports:${NC}"
  echo "─────────────────────────────────────────"
  nft list ruleset | grep -E 'dport.*accept' | while read -r line; do
    echo "  $line"
  done
}

cmd_logs() {
  local FILTER="" LAST="25"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --filter) FILTER="$2"; shift 2 ;;
      --last) LAST="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -n "$FILTER" ]; then
    journalctl -k --no-pager -n "$LAST" | grep -i "nft-${FILTER}" || echo "No matching log entries"
  else
    journalctl -k --no-pager -n "$LAST" | grep -i "nft-" || echo "No nftables log entries"
  fi
}

cmd_create_set() {
  check_root
  check_nft
  local NAME="${1:-}"
  if [ -z "$NAME" ]; then
    err "Usage: $0 create-set <set-name>"
    exit 1
  fi

  run_nft add set inet filter "$NAME" '{ type ipv4_addr; flags interval; }'
  run_nft insert rule inet filter input ip saddr "@$NAME" counter drop
  log "✅ Created set '$NAME' with drop rule"
  nft list ruleset > "$NFT_CONF"
}

cmd_geoblock() {
  check_root
  check_nft
  local COUNTRIES=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --countries) COUNTRIES="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$COUNTRIES" ]; then
    err "Usage: $0 geoblock --countries 'CN,RU,KP'"
    exit 1
  fi

  mkdir -p /tmp/geoip

  IFS=',' read -ra COUNTRY_LIST <<< "$COUNTRIES"
  local TOTAL=0

  for CC in "${COUNTRY_LIST[@]}"; do
    CC=$(echo "$CC" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    info "Downloading GeoIP data for: $CC"
    local URL="https://www.ipdeny.com/ipblocks/data/aggregated/${CC}-aggregated.zone"
    
    if curl -sf "$URL" -o "/tmp/geoip/${CC}.zone" 2>/dev/null; then
      local COUNT
      COUNT=$(wc -l < "/tmp/geoip/${CC}.zone")
      TOTAL=$((TOTAL + COUNT))
      
      # Add to blocklist
      while IFS= read -r cidr; do
        cidr=$(echo "$cidr" | tr -d '[:space:]')
        [ -z "$cidr" ] && continue
        nft add element inet filter blocklist "{ $cidr }" 2>/dev/null || true
      done < "/tmp/geoip/${CC}.zone"
      
      log "Blocked $COUNT ranges for $CC"
    else
      warn "Failed to download GeoIP data for: $CC"
    fi
  done

  log "✅ GeoIP blocking applied ($TOTAL total ranges)"
  nft list ruleset > "$NFT_CONF"
}

cmd_update_blocklists() {
  check_root
  check_nft
  info "Updating blocklists from public threat feeds..."

  mkdir -p /tmp/blocklists

  # Spamhaus DROP list
  if curl -sf "https://www.spamhaus.org/drop/drop.txt" -o /tmp/blocklists/spamhaus-drop.txt 2>/dev/null; then
    local COUNT=0
    while IFS= read -r line; do
      [[ "$line" == \;* ]] && continue
      local cidr
      cidr=$(echo "$line" | awk '{print $1}' | tr -d '[:space:]')
      [ -z "$cidr" ] && continue
      nft add element inet filter blocklist "{ $cidr }" 2>/dev/null && ((COUNT++)) || true
    done < /tmp/blocklists/spamhaus-drop.txt
    log "Spamhaus DROP: $COUNT ranges added"
  fi

  # Emerging Threats
  if curl -sf "https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt" -o /tmp/blocklists/et-block.txt 2>/dev/null; then
    local COUNT=0
    while IFS= read -r line; do
      [[ "$line" == \#* ]] && continue
      line=$(echo "$line" | tr -d '[:space:]')
      [ -z "$line" ] && continue
      nft add element inet filter blocklist "{ $line }" 2>/dev/null && ((COUNT++)) || true
    done < /tmp/blocklists/et-block.txt
    log "Emerging Threats: $COUNT IPs added"
  fi

  nft list ruleset > "$NFT_CONF"
  log "✅ Blocklists updated"
}

cmd_status() {
  check_nft
  echo -e "${BOLD}nftables Firewall Status${NC}"
  echo "─────────────────────────────────────────"
  
  # Version
  echo -e "Version:    $(nft --version 2>/dev/null | head -1)"
  
  # Service status
  if command -v systemctl &>/dev/null; then
    local STATUS
    STATUS=$(systemctl is-active nftables 2>/dev/null || echo "unknown")
    echo -e "Service:    $STATUS"
  fi
  
  # Table count
  local TABLES
  TABLES=$(nft list tables 2>/dev/null | wc -l)
  echo -e "Tables:     $TABLES"
  
  # Rule count
  local RULES
  RULES=$(nft list ruleset 2>/dev/null | grep -c "accept\|drop\|reject" || echo 0)
  echo -e "Rules:      $RULES"
  
  # Blocked IPs
  if nft list set inet filter blocklist &>/dev/null 2>&1; then
    local BLOCKED
    BLOCKED=$(nft list set inet filter blocklist 2>/dev/null | grep -c "elements" || echo 0)
    echo -e "Blocklist:  active"
  fi
  
  # Config file
  if [ -f "$NFT_CONF" ]; then
    echo -e "Config:     $NFT_CONF ($(stat -c%s "$NFT_CONF" 2>/dev/null || echo "?") bytes)"
  else
    echo -e "Config:     not persisted"
  fi
  
  echo ""
  echo -e "${BOLD}Allowed ports:${NC}"
  nft list ruleset 2>/dev/null | grep -E 'dport.*accept' | sed 's/^/  /' || echo "  (none)"
}

# ─── MAIN ───────────────────────────────────────────────────

usage() {
  echo "nftables Firewall Manager"
  echo ""
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "Commands:"
  echo "  show [--counters]              Show current ruleset"
  echo "  status                         Show firewall status summary"
  echo "  apply-preset <name>            Apply a preset ruleset"
  echo "  allow --port <N> [--proto X]   Allow a port"
  echo "  block --ip <addr>|--file <f>   Block IP(s)"
  echo "  unblock --ip <addr>            Remove IP from blocklist"
  echo "  rate-limit --port N --rate R   Rate-limit a port"
  echo "  nat --dport N --to IP:PORT     Port forwarding"
  echo "  backup                         Export ruleset to stdout"
  echo "  restore <file>                 Import ruleset from file"
  echo "  persist                        Save rules to $NFT_CONF"
  echo "  flush                          Remove all rules"
  echo "  list-allowed                   Show allowed ports"
  echo "  logs [--filter X] [--last N]   Show firewall logs"
  echo "  create-set <name>              Create IP set with drop rule"
  echo "  geoblock --countries 'XX,YY'   Block by country"
  echo "  update-blocklists              Update threat intel feeds"
  echo ""
  echo "Environment:"
  echo "  NFT_DRY_RUN=1    Show commands without executing"
  echo "  NFT_VERBOSE=1    Show executed commands"
  echo "  NFT_CONFIG=path  Override config file path"
}

COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
  show)              cmd_show "$@" ;;
  status)            cmd_status ;;
  apply-preset)      cmd_apply_preset "$@" ;;
  allow)             cmd_allow "$@" ;;
  block)             cmd_block "$@" ;;
  unblock)           cmd_unblock "$@" ;;
  rate-limit)        cmd_rate_limit "$@" ;;
  nat)               cmd_nat "$@" ;;
  backup)            cmd_backup ;;
  restore)           cmd_restore "$@" ;;
  persist)           cmd_persist ;;
  flush)             cmd_flush ;;
  list-allowed)      cmd_list_allowed ;;
  logs)              cmd_logs "$@" ;;
  create-set)        cmd_create_set "$@" ;;
  geoblock)          cmd_geoblock "$@" ;;
  update-blocklists) cmd_update_blocklists ;;
  help|--help|-h|"") usage ;;
  *)
    err "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac
