#!/bin/bash
# Caddy Web Server — Management Script
# Usage: bash manage.sh <command> [options]

set -euo pipefail

CADDYFILE="${CADDYFILE:-/etc/caddy/Caddyfile}"
CADDY_BIN=$(command -v caddy 2>/dev/null || echo "/usr/local/bin/caddy")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok() { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
err() { echo -e "${RED}❌ $*${NC}" >&2; }

# Ensure Caddy is installed
check_caddy() {
    if ! command -v caddy &>/dev/null && [ ! -f "$CADDY_BIN" ]; then
        err "Caddy not found. Run: bash scripts/install.sh"
        exit 1
    fi
}

# Parse named arguments
parse_args() {
    DOMAIN="" UPSTREAM="" ROOT="" FROM="" TO="" USER="" PASSWORD=""
    BROWSE=false UPSTREAMS=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain) DOMAIN="$2"; shift 2 ;;
            --upstream) UPSTREAMS+=("$2"); shift 2 ;;
            --root) ROOT="$2"; shift 2 ;;
            --from) FROM="$2"; shift 2 ;;
            --to) TO="$2"; shift 2 ;;
            --user) USER="$2"; shift 2 ;;
            --password) PASSWORD="$2"; shift 2 ;;
            --browse) BROWSE=true; shift ;;
            --dns-provider) DNS_PROVIDER="$2"; shift 2 ;;
            --dns-token) DNS_TOKEN="$2"; shift 2 ;;
            --rate) RATE="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # Backward compat: single --upstream
    if [ ${#UPSTREAMS[@]} -eq 0 ] && [ -n "${UPSTREAM:-}" ]; then
        UPSTREAMS=("$UPSTREAM")
    fi
}

# Ensure Caddyfile exists
ensure_caddyfile() {
    if [ ! -f "$CADDYFILE" ]; then
        sudo mkdir -p "$(dirname "$CADDYFILE")"
        echo "# Caddy configuration" | sudo tee "$CADDYFILE" >/dev/null
        echo "# Managed by caddy-server skill" | sudo tee -a "$CADDYFILE" >/dev/null
        echo "" | sudo tee -a "$CADDYFILE" >/dev/null
    fi
}

# Append site block to Caddyfile
append_site() {
    local block="$1"
    ensure_caddyfile

    # Check if domain already exists
    if [ -n "$DOMAIN" ] && grep -q "^${DOMAIN}" "$CADDYFILE" 2>/dev/null; then
        warn "Domain '$DOMAIN' already in Caddyfile. Remove first: bash manage.sh remove --domain $DOMAIN"
        return 1
    fi

    echo "" | sudo tee -a "$CADDYFILE" >/dev/null
    echo "$block" | sudo tee -a "$CADDYFILE" >/dev/null
    ok "Added site: $DOMAIN"
}

# Commands

cmd_serve() {
    parse_args "$@"
    [ -z "$DOMAIN" ] && { err "Missing --domain"; exit 1; }
    [ -z "$ROOT" ] && { err "Missing --root"; exit 1; }

    local block="${DOMAIN} {
    root * ${ROOT}
    encode gzip zstd
    file_server
}"
    append_site "$block" && cmd_reload
}

cmd_proxy() {
    parse_args "$@"
    [ -z "$DOMAIN" ] && { err "Missing --domain"; exit 1; }
    [ ${#UPSTREAMS[@]} -eq 0 ] && { err "Missing --upstream"; exit 1; }

    local upstream_str=""
    for u in "${UPSTREAMS[@]}"; do
        upstream_str+="        to $u\n"
    done

    local block
    if [ ${#UPSTREAMS[@]} -eq 1 ]; then
        block="${DOMAIN} {
    reverse_proxy ${UPSTREAMS[0]}
}"
    else
        block="${DOMAIN} {
    reverse_proxy {
$(printf "        to %s\n" "${UPSTREAMS[@]}")
        lb_policy round_robin
    }
}"
    fi

    append_site "$block" && cmd_reload
}

cmd_spa() {
    parse_args "$@"
    [ -z "$DOMAIN" ] && { err "Missing --domain"; exit 1; }
    [ -z "$ROOT" ] && { err "Missing --root"; exit 1; }

    local block="${DOMAIN} {
    root * ${ROOT}
    encode gzip zstd
    try_files {path} /index.html
    file_server
}"
    append_site "$block" && cmd_reload
}

cmd_fileserver() {
    parse_args "$@"
    [ -z "$DOMAIN" ] && { err "Missing --domain"; exit 1; }
    [ -z "$ROOT" ] && { err "Missing --root"; exit 1; }

    local browse_line=""
    $BROWSE && browse_line="    file_server browse"
    [ -z "$browse_line" ] && browse_line="    file_server"

    local block="${DOMAIN} {
    root * ${ROOT}
    encode gzip zstd
${browse_line}
}"
    append_site "$block" && cmd_reload
}

cmd_redirect() {
    parse_args "$@"
    [ -z "$FROM" ] && { err "Missing --from"; exit 1; }
    [ -z "$TO" ] && { err "Missing --to"; exit 1; }

    DOMAIN="$FROM"
    local block="${FROM} {
    redir https://${TO}{uri} permanent
}"
    append_site "$block" && cmd_reload
}

cmd_auth() {
    parse_args "$@"
    [ -z "$DOMAIN" ] && { err "Missing --domain"; exit 1; }
    [ -z "$USER" ] && { err "Missing --user"; exit 1; }
    [ -z "$PASSWORD" ] && { err "Missing --password"; exit 1; }

    local hash
    hash=$(caddy hash-password --plaintext "$PASSWORD" 2>/dev/null)

    local upstream_line=""
    [ ${#UPSTREAMS[@]} -gt 0 ] && upstream_line="    reverse_proxy ${UPSTREAMS[0]}"

    local block="${DOMAIN} {
    basicauth {
        ${USER} ${hash}
    }
${upstream_line}
}"
    append_site "$block" && cmd_reload
}

cmd_list() {
    ensure_caddyfile
    echo "📋 Configured sites in $CADDYFILE:"
    echo "---"
    grep -E '^[a-zA-Z0-9\*:.]+ \{' "$CADDYFILE" | sed 's/ {//' | while read -r site; do
        echo "  • $site"
    done
    echo "---"
}

cmd_remove() {
    parse_args "$@"
    [ -z "$DOMAIN" ] && { err "Missing --domain"; exit 1; }

    # Remove the domain block (domain line through matching closing brace)
    local tmp
    tmp=$(mktemp)
    awk -v domain="$DOMAIN" '
        BEGIN { skip=0; depth=0 }
        $0 ~ "^" domain " \\{" { skip=1; depth=1; next }
        skip && /\{/ { depth++ }
        skip && /\}/ { depth--; if (depth<=0) { skip=0 }; next }
        !skip { print }
    ' "$CADDYFILE" > "$tmp"

    sudo cp "$tmp" "$CADDYFILE"
    rm -f "$tmp"
    ok "Removed site: $DOMAIN"
    cmd_reload
}

cmd_show() {
    ensure_caddyfile
    echo "📄 $CADDYFILE:"
    echo "---"
    cat "$CADDYFILE"
    echo "---"
}

cmd_validate() {
    check_caddy
    echo "🔍 Validating Caddyfile..."
    if caddy validate --config "$CADDYFILE" 2>&1; then
        ok "Caddyfile is valid"
    else
        err "Caddyfile has errors"
        return 1
    fi
}

cmd_reload() {
    check_caddy
    if command -v systemctl &>/dev/null && systemctl is-active --quiet caddy 2>/dev/null; then
        sudo systemctl reload caddy
        ok "Caddy reloaded (zero-downtime)"
    elif pgrep -x caddy &>/dev/null; then
        caddy reload --config "$CADDYFILE" --force 2>/dev/null
        ok "Caddy reloaded"
    else
        warn "Caddy not running. Start with: bash manage.sh start"
    fi
}

cmd_start() {
    check_caddy
    if command -v systemctl &>/dev/null; then
        sudo systemctl start caddy
        ok "Caddy started"
    else
        caddy start --config "$CADDYFILE"
        ok "Caddy started (foreground)"
    fi
}

cmd_stop() {
    if command -v systemctl &>/dev/null; then
        sudo systemctl stop caddy
    else
        caddy stop 2>/dev/null || pkill caddy 2>/dev/null
    fi
    ok "Caddy stopped"
}

cmd_restart() {
    cmd_stop
    sleep 1
    cmd_start
}

cmd_status() {
    check_caddy
    echo "📊 Caddy Status"
    echo "==============="
    echo "Version: $(caddy version 2>/dev/null || echo 'unknown')"

    if command -v systemctl &>/dev/null; then
        local state
        state=$(systemctl is-active caddy 2>/dev/null || echo "inactive")
        if [ "$state" = "active" ]; then
            ok "Service: running"
        else
            warn "Service: $state"
        fi
    elif pgrep -x caddy &>/dev/null; then
        ok "Process: running (PID $(pgrep -x caddy))"
    else
        warn "Process: not running"
    fi

    echo ""
    echo "Caddyfile: $CADDYFILE"
    if [ -f "$CADDYFILE" ]; then
        local sites
        sites=$(grep -cE '^[a-zA-Z0-9\*:.]+ \{' "$CADDYFILE" 2>/dev/null || echo 0)
        echo "Sites configured: $sites"
    fi
}

cmd_logs() {
    if command -v journalctl &>/dev/null; then
        sudo journalctl -u caddy --no-pager -n 50
    else
        echo "No systemd journal. Check /var/log/caddy/ or run caddy with --log"
    fi
}

cmd_certs() {
    check_caddy
    local cert_dir="/var/lib/caddy/.local/share/caddy/certificates"
    if [ -d "$cert_dir" ]; then
        echo "🔐 Managed SSL Certificates:"
        find "$cert_dir" -name "*.crt" -o -name "*.key" 2>/dev/null | while read -r f; do
            echo "  $(basename "$(dirname "$f")")/$(basename "$f")"
        done
    else
        echo "No managed certificates found (Caddy provisions on demand)"
    fi
}

# Main dispatcher
CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in
    serve)      cmd_serve "$@" ;;
    proxy)      cmd_proxy "$@" ;;
    spa)        cmd_spa "$@" ;;
    fileserver) cmd_fileserver "$@" ;;
    redirect)   cmd_redirect "$@" ;;
    auth)       cmd_auth "$@" ;;
    list)       cmd_list ;;
    remove)     cmd_remove "$@" ;;
    show)       cmd_show ;;
    validate)   cmd_validate ;;
    reload)     cmd_reload ;;
    start)      cmd_start ;;
    stop)       cmd_stop ;;
    restart)    cmd_restart ;;
    status)     cmd_status ;;
    logs)       cmd_logs ;;
    certs)      cmd_certs ;;
    help|*)
        echo "Caddy Web Server Manager"
        echo ""
        echo "Usage: bash manage.sh <command> [options]"
        echo ""
        echo "Site commands:"
        echo "  serve       --domain <d> --root <path>         Static file serving"
        echo "  proxy       --domain <d> --upstream <host:port> Reverse proxy"
        echo "  spa         --domain <d> --root <path>         SPA with fallback routing"
        echo "  fileserver  --domain <d> --root <path> [--browse]  File server"
        echo "  redirect    --from <d> --to <d>                Domain redirect"
        echo "  auth        --domain <d> --user <u> --password <p> [--upstream <h:p>]"
        echo ""
        echo "Management:"
        echo "  list        List configured sites"
        echo "  remove      --domain <d>   Remove a site"
        echo "  show        Show Caddyfile contents"
        echo "  validate    Validate Caddyfile syntax"
        echo ""
        echo "Service:"
        echo "  start       Start Caddy"
        echo "  stop        Stop Caddy"
        echo "  restart     Restart Caddy"
        echo "  reload      Zero-downtime reload"
        echo "  status      Show Caddy status"
        echo "  logs        Show recent logs"
        echo "  certs       List managed SSL certificates"
        ;;
esac
