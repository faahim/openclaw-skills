#!/bin/bash
# HAProxy Manager — Management Script
# Manages backends, frontends, SSL, stats, and config generation

set -euo pipefail

STATE_FILE="${HAPROXY_STATE:-$HOME/.haproxy-manager/state.json}"
HAPROXY_CFG="${HAPROXY_CONFIG:-/etc/haproxy/haproxy.cfg}"
BACKUP_DIR="$HOME/.haproxy-manager/backups"

# Ensure state file exists
if [ ! -f "$STATE_FILE" ]; then
    echo "❌ State file not found. Run 'bash scripts/install.sh' first."
    exit 1
fi

# ────────────────────────────────────────
# Helpers
# ────────────────────────────────────────

json_read() { jq -r "$1" "$STATE_FILE"; }
json_write() {
    local tmp
    tmp=$(jq "$@" "$STATE_FILE")
    echo "$tmp" > "$STATE_FILE"
}

timestamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ────────────────────────────────────────
# Commands
# ────────────────────────────────────────

cmd_add_backend() {
    local name="" servers="" port="" balance="roundrobin" mode="http"
    local health_check="" health_interval=10 ssl_cert="" ssl_key=""
    local sticky="" rate_limit="" redirect_http="false" health_check_tcp="false"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift 2 ;;
            --servers) servers="$2"; shift 2 ;;
            --port) port="$2"; shift 2 ;;
            --balance) balance="$2"; shift 2 ;;
            --mode) mode="$2"; shift 2 ;;
            --health-check) health_check="$2"; shift 2 ;;
            --health-interval) health_interval="$2"; shift 2 ;;
            --health-check-tcp) health_check_tcp="true"; shift ;;
            --ssl-cert) ssl_cert="$2"; shift 2 ;;
            --ssl-key) ssl_key="$2"; shift 2 ;;
            --redirect-http) redirect_http="true"; shift ;;
            --sticky) shift; sticky="$*"; break ;;
            --rate-limit) rate_limit="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$name" ] || [ -z "$servers" ] || [ -z "$port" ]; then
        echo "❌ Required: --name, --servers, --port"
        echo "   Usage: manage.sh add-backend --name myapp --servers 'host1:port,host2:port' --port 80"
        exit 1
    fi

    # Parse servers into JSON array
    local server_json="[]"
    IFS=',' read -ra ADDR <<< "$servers"
    for s in "${ADDR[@]}"; do
        s=$(echo "$s" | xargs) # trim whitespace
        local host="${s%%:*}"
        local sport="${s##*:}"
        server_json=$(echo "$server_json" | jq --arg h "$host" --arg p "$sport" '. + [{"host": $h, "port": ($p | tonumber), "state": "enabled"}]')
    done

    # Handle SSL: combine cert+key into single PEM
    local ssl_pem=""
    if [ -n "$ssl_cert" ] && [ -n "$ssl_key" ]; then
        ssl_pem="/etc/haproxy/certs/${name}.pem"
        echo "📜 SSL: Will combine cert+key into $ssl_pem"
    fi

    # Add backend to state
    json_write \
        --arg name "$name" \
        --arg port "$port" \
        --arg balance "$balance" \
        --arg mode "$mode" \
        --arg hc "$health_check" \
        --arg hi "$health_interval" \
        --arg hctcp "$health_check_tcp" \
        --arg ssl "$ssl_pem" \
        --arg redir "$redirect_http" \
        --arg sticky "$sticky" \
        --arg rl "$rate_limit" \
        --argjson servers "$server_json" \
        '.backends += [{
            "name": $name,
            "port": ($port | tonumber),
            "balance": $balance,
            "mode": $mode,
            "servers": $servers,
            "health_check": $hc,
            "health_interval": ($hi | tonumber),
            "health_check_tcp": ($hctcp == "true"),
            "ssl_pem": $ssl,
            "redirect_http": ($redir == "true"),
            "sticky": $sticky,
            "rate_limit": $rl,
            "created_at": (now | todate)
        }]'

    local count
    count=$(echo "$server_json" | jq 'length')
    echo "✅ Backend '$name' added"
    echo "   Frontend: *:$port → $name ($count servers, $balance)"
    [ -n "$health_check" ] && echo "   Health check: GET $health_check every ${health_interval}s"
    [ "$health_check_tcp" = "true" ] && echo "   Health check: TCP every ${health_interval}s"
    [ -n "$ssl_pem" ] && echo "   SSL: Terminating at HAProxy"
    [ "$redirect_http" = "true" ] && echo "   HTTP→HTTPS redirect enabled"
    [ -n "$sticky" ] && echo "   Sticky sessions: $sticky"
    [ -n "$rate_limit" ] && echo "   Rate limit: $rate_limit per IP"
    echo "   Run 'bash scripts/manage.sh apply' to activate"
}

cmd_add_server() {
    local backend="" server=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backend) backend="$2"; shift 2 ;;
            --server) server="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$backend" ] || [ -z "$server" ]; then
        echo "❌ Required: --backend, --server"
        exit 1
    fi

    local host="${server%%:*}"
    local port="${server##*:}"

    json_write \
        --arg b "$backend" --arg h "$host" --arg p "$port" \
        '(.backends[] | select(.name == $b) | .servers) += [{"host": $h, "port": ($p | tonumber), "state": "enabled"}]'

    echo "✅ Server $server added to backend '$backend'"
}

cmd_drain_server() {
    local backend="" server=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backend) backend="$2"; shift 2 ;;
            --server) server="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local host="${server%%:*}"
    local port="${server##*:}"

    json_write \
        --arg b "$backend" --arg h "$host" --arg p "$port" \
        '(.backends[] | select(.name == $b) | .servers[] | select(.host == $h and .port == ($p | tonumber)) | .state) = "drain"'

    echo "🔄 Server $server set to DRAIN in backend '$backend'"
    echo "   Existing connections will finish, no new connections routed"
}

cmd_enable_stats() {
    local port=9090 user="admin" pass="admin"
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port) port="$2"; shift 2 ;;
            --user) user="$2"; shift 2 ;;
            --pass) pass="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    json_write \
        --arg p "$port" --arg u "$user" --arg pw "$pass" \
        '.stats = {"enabled": true, "port": ($p | tonumber), "user": $u, "pass": $pw}'

    echo "✅ Stats dashboard enabled"
    echo "   URL: http://localhost:$port/stats"
    echo "   Auth: $user / $pass"
}

cmd_apply() {
    echo "🔧 Generating HAProxy config..."

    # Backup existing config
    if [ -f "$HAPROXY_CFG" ]; then
        cp "$HAPROXY_CFG" "$BACKUP_DIR/haproxy.cfg.$(date +%Y%m%d%H%M%S)"
    fi

    # Generate config
    local cfg=""

    # Global section
    cfg+="# Generated by HAProxy Manager — $(timestamp)\n"
    cfg+="# Do not edit manually. Use 'manage.sh' commands.\n\n"
    cfg+="global\n"
    cfg+="    log $(json_read '.global.log')\n"
    cfg+="    maxconn $(json_read '.global.maxconn')\n"
    cfg+="    chroot $(json_read '.global.chroot')\n"
    cfg+="    user $(json_read '.global.user')\n"
    cfg+="    group $(json_read '.global.group')\n"
    cfg+="    daemon\n"
    cfg+="    stats socket /run/haproxy/admin.sock mode 660 level admin\n"
    cfg+="    stats timeout 30s\n\n"

    # Defaults section
    cfg+="defaults\n"
    cfg+="    log     global\n"
    cfg+="    option  httplog\n"
    cfg+="    option  dontlognull\n"
    cfg+="    timeout connect 5000ms\n"
    cfg+="    timeout client  50000ms\n"
    cfg+="    timeout server  50000ms\n"
    cfg+="    errorfile 400 /etc/haproxy/errors/400.http\n"
    cfg+="    errorfile 403 /etc/haproxy/errors/403.http\n"
    cfg+="    errorfile 408 /etc/haproxy/errors/408.http\n"
    cfg+="    errorfile 500 /etc/haproxy/errors/500.http\n"
    cfg+="    errorfile 502 /etc/haproxy/errors/502.http\n"
    cfg+="    errorfile 503 /etc/haproxy/errors/503.http\n"
    cfg+="    errorfile 504 /etc/haproxy/errors/504.http\n\n"

    # Stats section
    local stats_enabled
    stats_enabled=$(json_read '.stats.enabled')
    if [ "$stats_enabled" = "true" ]; then
        local stats_port stats_user stats_pass
        stats_port=$(json_read '.stats.port')
        stats_user=$(json_read '.stats.user')
        stats_pass=$(json_read '.stats.pass')
        cfg+="listen stats\n"
        cfg+="    bind *:$stats_port\n"
        cfg+="    mode http\n"
        cfg+="    stats enable\n"
        cfg+="    stats uri /stats\n"
        cfg+="    stats refresh 5s\n"
        cfg+="    stats auth $stats_user:$stats_pass\n"
        cfg+="    stats admin if TRUE\n\n"
    fi

    # Generate frontends and backends
    local backend_count
    backend_count=$(jq '.backends | length' "$STATE_FILE")

    for ((i=0; i<backend_count; i++)); do
        local bname bport bbalance bmode bhc bhi bssl bsticky brl bhctcp bredirect
        bname=$(jq -r ".backends[$i].name" "$STATE_FILE")
        bport=$(jq -r ".backends[$i].port" "$STATE_FILE")
        bbalance=$(jq -r ".backends[$i].balance" "$STATE_FILE")
        bmode=$(jq -r ".backends[$i].mode" "$STATE_FILE")
        bhc=$(jq -r ".backends[$i].health_check // empty" "$STATE_FILE")
        bhi=$(jq -r ".backends[$i].health_interval" "$STATE_FILE")
        bssl=$(jq -r ".backends[$i].ssl_pem // empty" "$STATE_FILE")
        bsticky=$(jq -r ".backends[$i].sticky // empty" "$STATE_FILE")
        brl=$(jq -r ".backends[$i].rate_limit // empty" "$STATE_FILE")
        bhctcp=$(jq -r ".backends[$i].health_check_tcp // false" "$STATE_FILE")
        bredirect=$(jq -r ".backends[$i].redirect_http // false" "$STATE_FILE")

        # HTTP redirect frontend (if SSL + redirect)
        if [ "$bredirect" = "true" ] && [ -n "$bssl" ]; then
            cfg+="frontend ft_${bname}_http\n"
            cfg+="    bind *:80\n"
            cfg+="    mode http\n"
            cfg+="    redirect scheme https code 301\n\n"
        fi

        # Frontend
        cfg+="frontend ft_${bname}\n"
        if [ -n "$bssl" ]; then
            cfg+="    bind *:$bport ssl crt $bssl\n"
        else
            cfg+="    bind *:$bport\n"
        fi
        cfg+="    mode $bmode\n"

        # Rate limiting
        if [ -n "$brl" ]; then
            local rl_count="${brl%%/*}"
            local rl_period="${brl##*/}"
            cfg+="    stick-table type ip size 100k expire $rl_period store http_req_rate($rl_period)\n"
            cfg+="    http-request track-sc0 src\n"
            cfg+="    http-request deny deny_status 429 if { sc_http_req_rate(0) gt $rl_count }\n"
        fi

        cfg+="    default_backend bk_${bname}\n\n"

        # Backend
        cfg+="backend bk_${bname}\n"
        cfg+="    mode $bmode\n"
        cfg+="    balance $bbalance\n"

        # Health check
        if [ -n "$bhc" ] && [ "$bmode" = "http" ]; then
            cfg+="    option httpchk GET $bhc\n"
            cfg+="    http-check expect status 200\n"
        fi

        # Sticky sessions
        if [ -n "$bsticky" ]; then
            cfg+="    $bsticky\n"
        fi

        # Servers
        local server_count
        server_count=$(jq ".backends[$i].servers | length" "$STATE_FILE")
        for ((j=0; j<server_count; j++)); do
            local shost sport sstate
            shost=$(jq -r ".backends[$i].servers[$j].host" "$STATE_FILE")
            sport=$(jq -r ".backends[$i].servers[$j].port" "$STATE_FILE")
            sstate=$(jq -r ".backends[$i].servers[$j].state" "$STATE_FILE")

            local server_line="    server ${bname}_${j} ${shost}:${sport}"
            
            if [ "$bmode" = "http" ] && [ -n "$bhc" ]; then
                server_line+=" check inter ${bhi}s"
            elif [ "$bhctcp" = "true" ]; then
                server_line+=" check inter ${bhi}s"
            fi

            if [ "$sstate" = "drain" ]; then
                server_line+=" disabled"
            fi

            cfg+="$server_line\n"
        done
        cfg+="\n"
    done

    # Write config
    echo -e "$cfg" | sudo tee "$HAPROXY_CFG" > /dev/null
    echo "✅ Config written to $HAPROXY_CFG"

    # Validate
    if sudo haproxy -c -f "$HAPROXY_CFG" 2>/dev/null; then
        echo "✅ Config validation passed"
        echo "   Reload: sudo systemctl reload haproxy"
    else
        echo "❌ Config validation FAILED"
        echo "   Check: sudo haproxy -c -f $HAPROXY_CFG"
        return 1
    fi
}

cmd_status() {
    echo "📊 HAProxy Manager Status"
    echo "========================="
    echo ""

    # Check if HAProxy is running
    if systemctl is-active --quiet haproxy 2>/dev/null; then
        echo "🟢 HAProxy: RUNNING"
        echo "   $(haproxy -v 2>&1 | head -1)"
    else
        echo "🔴 HAProxy: STOPPED"
    fi

    echo ""
    echo "Configured Backends:"
    local count
    count=$(jq '.backends | length' "$STATE_FILE")
    
    if [ "$count" = "0" ]; then
        echo "   (none)"
    else
        for ((i=0; i<count; i++)); do
            local name port balance mode scount
            name=$(jq -r ".backends[$i].name" "$STATE_FILE")
            port=$(jq -r ".backends[$i].port" "$STATE_FILE")
            balance=$(jq -r ".backends[$i].balance" "$STATE_FILE")
            mode=$(jq -r ".backends[$i].mode" "$STATE_FILE")
            scount=$(jq ".backends[$i].servers | length" "$STATE_FILE")
            echo "   📦 $name — :$port ($mode, $balance, $scount servers)"
        done
    fi

    # Stats info
    local stats_enabled
    stats_enabled=$(json_read '.stats.enabled')
    if [ "$stats_enabled" = "true" ]; then
        echo ""
        echo "📈 Stats: http://localhost:$(json_read '.stats.port')/stats"
    fi
}

cmd_health() {
    echo "🏥 Backend Health Check"
    echo "======================="
    echo ""

    local count
    count=$(jq '.backends | length' "$STATE_FILE")

    for ((i=0; i<count; i++)); do
        local bname bmode
        bname=$(jq -r ".backends[$i].name" "$STATE_FILE")
        bmode=$(jq -r ".backends[$i].mode" "$STATE_FILE")
        echo "Backend: $bname"

        local scount
        scount=$(jq ".backends[$i].servers | length" "$STATE_FILE")
        for ((j=0; j<scount; j++)); do
            local shost sport sstate
            shost=$(jq -r ".backends[$i].servers[$j].host" "$STATE_FILE")
            sport=$(jq -r ".backends[$i].servers[$j].port" "$STATE_FILE")
            sstate=$(jq -r ".backends[$i].servers[$j].state" "$STATE_FILE")

            if [ "$sstate" = "drain" ]; then
                echo "  🔄 ${shost}:${sport} — DRAINING"
                continue
            fi

            # Quick connectivity check
            local start_ms end_ms elapsed
            start_ms=$(date +%s%3N)
            if timeout 5 bash -c "echo > /dev/tcp/$shost/$sport" 2>/dev/null; then
                end_ms=$(date +%s%3N)
                elapsed=$((end_ms - start_ms))
                echo "  ✅ ${shost}:${sport} — UP (${elapsed}ms)"
            else
                echo "  ❌ ${shost}:${sport} — DOWN (connection failed)"
            fi
        done
        echo ""
    done
}

cmd_backup() {
    if [ -f "$HAPROXY_CFG" ]; then
        local backup_file="$BACKUP_DIR/haproxy.cfg.$(date +%Y%m%d%H%M%S)"
        cp "$HAPROXY_CFG" "$backup_file"
        cp "$STATE_FILE" "$BACKUP_DIR/state.json.$(date +%Y%m%d%H%M%S)"
        echo "✅ Backup saved to $BACKUP_DIR/"
    else
        echo "⚠️ No config file to backup yet"
    fi
}

cmd_validate() {
    if [ -f "$HAPROXY_CFG" ]; then
        echo "🔍 Validating $HAPROXY_CFG..."
        if sudo haproxy -c -f "$HAPROXY_CFG"; then
            echo "✅ Config is valid"
        else
            echo "❌ Config has errors"
            exit 1
        fi
    else
        echo "⚠️ No config file found. Run 'manage.sh apply' first."
    fi
}

cmd_check_ssl() {
    local cert="" key=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cert) cert="$2"; shift 2 ;;
            --key) key="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$cert" ] || [ -z "$key" ]; then
        echo "❌ Required: --cert, --key"
        exit 1
    fi

    local cert_md5 key_md5
    cert_md5=$(openssl x509 -noout -modulus -in "$cert" 2>/dev/null | openssl md5)
    key_md5=$(openssl rsa -noout -modulus -in "$key" 2>/dev/null | openssl md5)

    if [ "$cert_md5" = "$key_md5" ]; then
        echo "✅ Certificate and key match"
        openssl x509 -noout -subject -enddate -in "$cert"
    else
        echo "❌ Certificate and key DO NOT match"
        exit 1
    fi
}

# ────────────────────────────────────────
# Router
# ────────────────────────────────────────

CMD="${1:-help}"
shift || true

case "$CMD" in
    add-backend)    cmd_add_backend "$@" ;;
    add-server)     cmd_add_server "$@" ;;
    drain-server)   cmd_drain_server "$@" ;;
    enable-stats)   cmd_enable_stats "$@" ;;
    apply)          cmd_apply ;;
    status)         cmd_status ;;
    health)         cmd_health ;;
    backup)         cmd_backup ;;
    validate)       cmd_validate ;;
    check-ssl)      cmd_check_ssl "$@" ;;
    raw-config)     echo "⚠️ raw-config: edit $STATE_FILE directly for advanced directives" ;;
    add-acl)        echo "⚠️ ACL routing: edit generated config after 'apply' for advanced routing" ;;
    help|*)
        echo "HAProxy Manager — Commands:"
        echo ""
        echo "  add-backend   Add a new backend + frontend"
        echo "  add-server    Add server to existing backend"
        echo "  drain-server  Drain a server (stop new connections)"
        echo "  enable-stats  Enable stats dashboard"
        echo "  apply         Generate HAProxy config from state"
        echo "  status        Show current configuration"
        echo "  health        Check backend server connectivity"
        echo "  backup        Backup current config"
        echo "  validate      Validate HAProxy config syntax"
        echo "  check-ssl     Verify SSL cert/key match"
        echo ""
        echo "Examples:"
        echo "  manage.sh add-backend --name web --servers 'app1:8080,app2:8080' --port 80"
        echo "  manage.sh enable-stats --port 9090 --user admin --pass secret"
        echo "  manage.sh apply"
        echo "  manage.sh health"
        ;;
esac
