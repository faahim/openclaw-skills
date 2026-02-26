#!/usr/bin/env bash
# Hosts File Manager — Manage /etc/hosts, block ads/trackers, custom DNS mappings
# https://github.com/faahim/openclaw-skills

set -euo pipefail

HOSTS_FILE="/etc/hosts"
CONFIG_DIR="${HOME}/.config/hosts-manager"
WHITELIST_FILE="${CONFIG_DIR}/whitelist.txt"
CUSTOM_HOSTS_FILE="${CONFIG_DIR}/custom-hosts.txt"
BACKUP_DIR="/etc"
MARKER_START="# === HOSTS-MANAGER BLOCKLIST START ==="
MARKER_END="# === HOSTS-MANAGER BLOCKLIST END ==="
CUSTOM_START="# === HOSTS-MANAGER CUSTOM START ==="
CUSTOM_END="# === HOSTS-MANAGER CUSTOM END ==="
META_FILE="${CONFIG_DIR}/meta.json"

# Blocklist URLs
declare -A BLOCKLISTS=(
    ["steven-black"]="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    ["steven-black-fakenews"]="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews/hosts"
    ["steven-black-social"]="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/social/hosts"
    ["energized-basic"]="https://block.energized.pro/basic/formats/hosts.txt"
    ["energized-ultimate"]="https://block.energized.pro/ultimate/formats/hosts.txt"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}✅ $*${NC}"; }
log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_err()  { echo -e "${RED}❌ $*${NC}" >&2; }

ensure_config_dir() {
    mkdir -p "$CONFIG_DIR"
    [[ -f "$WHITELIST_FILE" ]] || touch "$WHITELIST_FILE"
    [[ -f "$CUSTOM_HOSTS_FILE" ]] || touch "$CUSTOM_HOSTS_FILE"
}

backup_hosts() {
    local backup="${BACKUP_DIR}/hosts.bak.$(date +%Y-%m-%d_%H%M%S)"
    cp "$HOSTS_FILE" "$backup"
    log_ok "Backed up $HOSTS_FILE to $backup"
}

get_whitelist() {
    if [[ -f "$WHITELIST_FILE" ]]; then
        grep -v '^\s*#' "$WHITELIST_FILE" | grep -v '^\s*$' || true
    fi
}

get_custom_hosts() {
    if [[ -f "$CUSTOM_HOSTS_FILE" ]]; then
        grep -v '^\s*#' "$CUSTOM_HOSTS_FILE" | grep -v '^\s*$' || true
    fi
}

# Extract the "clean" hosts (without our managed sections)
get_original_hosts() {
    if grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
        sed "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE" | sed "/$CUSTOM_START/,/$CUSTOM_END/d"
    elif grep -q "$CUSTOM_START" "$HOSTS_FILE" 2>/dev/null; then
        sed "/$CUSTOM_START/,/$CUSTOM_END/d" "$HOSTS_FILE"
    else
        cat "$HOSTS_FILE"
    fi
}

count_blocked() {
    if grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
        sed -n "/$MARKER_START/,/$MARKER_END/p" "$HOSTS_FILE" | grep -c '^0\.0\.0\.0 ' || echo 0
    else
        echo 0
    fi
}

count_custom() {
    if grep -q "$CUSTOM_START" "$HOSTS_FILE" 2>/dev/null; then
        sed -n "/$CUSTOM_START/,/$CUSTOM_END/p" "$HOSTS_FILE" | grep -cv '^\s*#\|^\s*$' || echo 0
    else
        echo 0
    fi
}

save_meta() {
    local list_name="${1:-none}"
    local count="${2:-0}"
    cat > "$META_FILE" <<EOF
{"list":"$list_name","count":$count,"updated":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
}

get_meta() {
    if [[ -f "$META_FILE" ]]; then
        cat "$META_FILE"
    else
        echo '{"list":"none","count":0}'
    fi
}

write_hosts() {
    local original="$1"
    local blocklist="$2"
    local custom="$3"
    local tmpfile
    tmpfile=$(mktemp)

    {
        echo "$original"
        echo ""
        if [[ -n "$custom" ]]; then
            echo "$CUSTOM_START"
            echo "$custom"
            echo "$CUSTOM_END"
            echo ""
        fi
        if [[ -n "$blocklist" ]]; then
            echo "$MARKER_START"
            echo "$blocklist"
            echo "$MARKER_END"
        fi
    } > "$tmpfile"

    mv "$tmpfile" "$HOSTS_FILE"
    chmod 644 "$HOSTS_FILE"
}

cmd_status() {
    local blocked custom whitelist_count
    blocked=$(count_blocked)
    custom=$(count_custom)
    whitelist_count=$(get_whitelist | wc -l | tr -d ' ')
    local meta
    meta=$(get_meta)
    local list_name
    list_name=$(echo "$meta" | grep -o '"list":"[^"]*"' | cut -d'"' -f4)

    echo "╔══════════════════════════════════════╗"
    echo "║       Hosts File Manager Status      ║"
    echo "╠══════════════════════════════════════╣"
    printf "║  Blocked domains:  %-17s ║\n" "$blocked"
    printf "║  Custom entries:   %-17s ║\n" "$custom"
    printf "║  Whitelisted:      %-17s ║\n" "$whitelist_count"
    printf "║  Active blocklist: %-17s ║\n" "${list_name:-none}"
    printf "║  Hosts file:       %-17s ║\n" "$HOSTS_FILE"
    echo "╚══════════════════════════════════════╝"
}

cmd_block() {
    local list_name=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --list) list_name="$2"; shift 2 ;;
            *) log_err "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$list_name" ]]; then
        log_err "Usage: hosts-manager.sh block --list <list-name>"
        echo "Available lists: ${!BLOCKLISTS[*]}"
        exit 1
    fi

    local url="${BLOCKLISTS[$list_name]:-}"
    if [[ -z "$url" ]]; then
        log_err "Unknown blocklist: $list_name"
        echo "Available: ${!BLOCKLISTS[*]}"
        exit 1
    fi

    backup_hosts
    log_info "Downloading $list_name blocklist..."

    local tmpfile
    tmpfile=$(mktemp)
    if ! curl -sL "$url" -o "$tmpfile"; then
        log_err "Failed to download blocklist"
        rm -f "$tmpfile"
        exit 1
    fi

    # Parse hosts file: extract 0.0.0.0 entries, skip comments/localhost
    local blocklist
    blocklist=$(grep '^0\.0\.0\.0 ' "$tmpfile" | \
        awk '{print $1, $2}' | \
        grep -v 'localhost' | \
        grep -v '0\.0\.0\.0 0\.0\.0\.0' | \
        sort -u)

    # Also grab 127.0.0.1 blocked entries and convert to 0.0.0.0
    local extra
    extra=$(grep '^127\.0\.0\.1 ' "$tmpfile" | \
        awk '{print "0.0.0.0", $2}' | \
        grep -v 'localhost' | \
        grep -v 'local$' | \
        grep -v 'broadcasthost' | \
        sort -u)

    blocklist=$(echo -e "${blocklist}\n${extra}" | sort -u)
    rm -f "$tmpfile"

    # Apply whitelist
    local whitelist
    whitelist=$(get_whitelist)
    if [[ -n "$whitelist" ]]; then
        local wl_pattern
        wl_pattern=$(echo "$whitelist" | sed 's/\./\\./g' | paste -sd'|' -)
        blocklist=$(echo "$blocklist" | grep -Ev " ($wl_pattern)$" || true)
    fi

    local count
    count=$(echo "$blocklist" | wc -l | tr -d ' ')

    # Build new hosts file
    local original custom_entries
    original=$(get_original_hosts)
    custom_entries=$(get_custom_hosts)

    write_hosts "$original" "$blocklist" "$custom_entries"
    save_meta "$list_name" "$count"

    log_ok "Applied blocklist — $count domains now blocked"
    local wl_count
    wl_count=$(echo "$whitelist" | grep -c . || echo 0)
    log_info "Whitelist: $wl_count domains preserved"
}

cmd_update() {
    local meta list_name
    meta=$(get_meta)
    list_name=$(echo "$meta" | grep -o '"list":"[^"]*"' | cut -d'"' -f4)

    if [[ -z "$list_name" || "$list_name" == "none" ]]; then
        log_err "No blocklist active. Use: hosts-manager.sh block --list <name>"
        exit 1
    fi

    local old_count
    old_count=$(count_blocked)
    cmd_block --list "$list_name"
    local new_count
    new_count=$(count_blocked)
    local diff=$((new_count - old_count))

    if [[ $diff -gt 0 ]]; then
        log_info "Updated: $old_count → $new_count domains blocked (+$diff new)"
    elif [[ $diff -lt 0 ]]; then
        log_info "Updated: $old_count → $new_count domains blocked ($diff removed)"
    else
        log_info "No changes — $new_count domains blocked"
    fi
}

cmd_add() {
    local ip="$1" hostname="$2"
    if [[ -z "$ip" || -z "$hostname" ]]; then
        log_err "Usage: hosts-manager.sh add <ip> <hostname>"
        exit 1
    fi

    ensure_config_dir

    # Check if already exists
    if grep -q "^${ip} ${hostname}$" "$CUSTOM_HOSTS_FILE" 2>/dev/null; then
        log_warn "Entry already exists: $ip $hostname"
        return 0
    fi

    echo "$ip $hostname" >> "$CUSTOM_HOSTS_FILE"

    backup_hosts

    local original blocklist_content custom_entries
    original=$(get_original_hosts)

    if grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
        blocklist_content=$(sed -n "/$MARKER_START/,/$MARKER_END/{/$MARKER_START/d;/$MARKER_END/d;p}" "$HOSTS_FILE")
    else
        blocklist_content=""
    fi

    custom_entries=$(get_custom_hosts)
    write_hosts "$original" "$blocklist_content" "$custom_entries"

    log_ok "Added: $ip $hostname"
}

cmd_remove() {
    local hostname="$1"
    if [[ -z "$hostname" ]]; then
        log_err "Usage: hosts-manager.sh remove <hostname>"
        exit 1
    fi

    ensure_config_dir
    backup_hosts

    # Remove from custom hosts file
    if [[ -f "$CUSTOM_HOSTS_FILE" ]]; then
        sed -i "/ ${hostname}$/d" "$CUSTOM_HOSTS_FILE"
    fi

    # Remove from hosts file directly
    local tmpfile
    tmpfile=$(mktemp)
    grep -v " ${hostname}$" "$HOSTS_FILE" > "$tmpfile" || true
    mv "$tmpfile" "$HOSTS_FILE"
    chmod 644 "$HOSTS_FILE"

    log_ok "Removed: $hostname"
}

cmd_whitelist() {
    local domain="$1"
    if [[ -z "$domain" ]]; then
        log_err "Usage: hosts-manager.sh whitelist <domain>"
        exit 1
    fi

    ensure_config_dir

    if grep -qx "$domain" "$WHITELIST_FILE" 2>/dev/null; then
        log_warn "Already whitelisted: $domain"
        return 0
    fi

    echo "$domain" >> "$WHITELIST_FILE"
    log_ok "Whitelisted: $domain"
    log_info "Run 'hosts-manager.sh update' to re-apply blocklist without this domain"
}

cmd_list() {
    local mode="${1:---all}"
    case "$mode" in
        --custom)
            echo "=== Custom Entries ==="
            if grep -q "$CUSTOM_START" "$HOSTS_FILE" 2>/dev/null; then
                sed -n "/$CUSTOM_START/,/$CUSTOM_END/{/$CUSTOM_START/d;/$CUSTOM_END/d;p}" "$HOSTS_FILE" | grep -v '^\s*$'
            else
                echo "(none)"
            fi
            ;;
        --blocked)
            echo "=== Blocked Domains (first 50) ==="
            if grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
                sed -n "/$MARKER_START/,/$MARKER_END/{/$MARKER_START/d;/$MARKER_END/d;p}" "$HOSTS_FILE" | head -50
            else
                echo "(none)"
            fi
            local total
            total=$(count_blocked)
            echo "--- Total: $total blocked domains ---"
            ;;
        --all|*)
            cmd_list --custom
            echo ""
            cmd_list --blocked
            ;;
    esac
}

cmd_search() {
    local pattern="$1"
    if [[ -z "$pattern" ]]; then
        log_err "Usage: hosts-manager.sh search <pattern>"
        exit 1
    fi

    echo "=== Search: $pattern ==="
    grep -i "$pattern" "$HOSTS_FILE" | head -20 || echo "(no matches)"
}

cmd_backups() {
    echo "=== Available Backups ==="
    ls -la ${BACKUP_DIR}/hosts.bak.* 2>/dev/null || echo "(no backups found)"
}

cmd_restore() {
    local backup="${1:-}"
    if [[ -z "$backup" ]]; then
        backup=$(ls -t ${BACKUP_DIR}/hosts.bak.* 2>/dev/null | head -1)
        if [[ -z "$backup" ]]; then
            log_err "No backups found"
            exit 1
        fi
    fi

    if [[ ! -f "$backup" ]]; then
        log_err "Backup not found: $backup"
        exit 1
    fi

    cp "$backup" "$HOSTS_FILE"
    chmod 644 "$HOSTS_FILE"
    log_ok "Restored from $backup"
}

cmd_flush() {
    if command -v systemd-resolve &>/dev/null; then
        systemd-resolve --flush-caches 2>/dev/null && log_ok "Flushed systemd-resolved DNS cache"
    elif command -v resolvectl &>/dev/null; then
        resolvectl flush-caches 2>/dev/null && log_ok "Flushed resolvectl DNS cache"
    elif [[ -f /etc/init.d/nscd ]]; then
        /etc/init.d/nscd restart 2>/dev/null && log_ok "Restarted nscd"
    elif command -v dscacheutil &>/dev/null; then
        dscacheutil -flushcache 2>/dev/null
        killall -HUP mDNSResponder 2>/dev/null
        log_ok "Flushed macOS DNS cache"
    else
        log_warn "Could not detect DNS cache service. You may need to restart networking."
    fi
}

cmd_reset() {
    backup_hosts

    local original custom_entries
    original=$(get_original_hosts)
    custom_entries=$(get_custom_hosts)

    write_hosts "$original" "" "$custom_entries"
    save_meta "none" 0

    log_ok "Reset — all blocklist entries removed"
    log_info "Custom entries preserved"
}

# Main
ensure_config_dir

case "${1:-}" in
    status)    cmd_status ;;
    block)     shift; cmd_block "$@" ;;
    update)    cmd_update ;;
    add)       shift; cmd_add "${1:-}" "${2:-}" ;;
    remove)    shift; cmd_remove "${1:-}" ;;
    whitelist) shift; cmd_whitelist "${1:-}" ;;
    list)      shift; cmd_list "${1:-}" ;;
    search)    shift; cmd_search "${1:-}" ;;
    backups)   cmd_backups ;;
    restore)   shift; cmd_restore "${1:-}" ;;
    flush)     cmd_flush ;;
    reset)     cmd_reset ;;
    *)
        echo "Hosts File Manager — Block ads, manage DNS mappings"
        echo ""
        echo "Usage: hosts-manager.sh <command> [options]"
        echo ""
        echo "Commands:"
        echo "  status              Show current hosts file stats"
        echo "  block --list <name> Apply a blocklist (steven-black, energized-basic, etc.)"
        echo "  update              Refresh the active blocklist"
        echo "  add <ip> <host>     Add a custom hosts entry"
        echo "  remove <hostname>   Remove a hostname"
        echo "  whitelist <domain>  Add domain to whitelist (never blocked)"
        echo "  list [--custom|--blocked|--all]  Show entries"
        echo "  search <pattern>    Search hosts file"
        echo "  backups             List available backups"
        echo "  restore [path]      Restore from backup"
        echo "  flush               Flush DNS cache"
        echo "  reset               Remove all blocklist entries"
        echo ""
        echo "Available blocklists:"
        for name in "${!BLOCKLISTS[@]}"; do
            echo "  - $name"
        done
        ;;
esac
