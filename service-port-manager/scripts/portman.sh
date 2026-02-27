#!/bin/bash
# Service Port Manager — Scan, manage, and secure local service ports
# Version: 1.0.0

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Defaults
OUTPUT_FORMAT="table"  # table, json, csv

usage() {
    cat <<EOF
${BOLD}Service Port Manager${NC} — Scan, manage, and secure local service ports

${BOLD}Usage:${NC}
  portman.sh <command> [options]

${BOLD}Commands:${NC}
  scan              List all listening ports
  check <port>      Check if a specific port is in use
  kill <port>       Kill the process using a port
  conflicts         Detect port conflicts (multiple processes on same port)
  range <from-to>   Scan a port range
  common            Check all common service ports
  audit             Security audit of open ports
  watch <port>      Monitor connections on a port in real-time
  report            Generate full port report
  firewall <cmd>    Manage UFW firewall rules

${BOLD}Options:${NC}
  --tcp             TCP ports only
  --udp             UDP ports only
  --all             Include non-listening states
  --user <name>     Filter by user
  --json            Output as JSON
  --csv             Output as CSV
  --force           Force kill (SIGKILL)
  --quiet           Minimal output (for automation)
  --from <ip/cidr>  Restrict firewall rule to source IP

${BOLD}Examples:${NC}
  portman.sh scan
  portman.sh check 3000
  portman.sh kill 8080 --force
  portman.sh firewall allow 443
  portman.sh audit --quiet
EOF
}

# Parse global options from remaining args
PROTO_FILTER=""
SHOW_ALL=false
USER_FILTER=""
FORCE=false
QUIET=false
FIREWALL_FROM=""

parse_opts() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tcp) PROTO_FILTER="tcp" ;;
            --udp) PROTO_FILTER="udp" ;;
            --all) SHOW_ALL=true ;;
            --user) USER_FILTER="$2"; shift ;;
            --json) OUTPUT_FORMAT="json" ;;
            --csv) OUTPUT_FORMAT="csv" ;;
            --force) FORCE=true ;;
            --quiet) QUIET=true ;;
            --from) FIREWALL_FROM="$2"; shift ;;
            *) ;; # ignore unknown for flexibility
        esac
        shift
    done
}

# ─── SCAN ────────────────────────────────────────────────────────────────────

cmd_scan() {
    local ss_flags="-tlnp"
    [[ "$PROTO_FILTER" == "udp" ]] && ss_flags="-ulnp"
    [[ -z "$PROTO_FILTER" ]] && ss_flags="-tulnp"
    $SHOW_ALL && ss_flags="${ss_flags/l/a}"

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        scan_json "$ss_flags"
        return
    fi

    if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        echo "port,proto,pid,process,user,state,bind_address"
    else
        printf "${BOLD}%-7s %-6s %-7s %-18s %-12s %-10s %s${NC}\n" "PORT" "PROTO" "PID" "PROCESS" "USER" "STATE" "BIND"
        echo "─────────────────────────────────────────────────────────────────────────"
    fi

    # Determine column offset: -tu adds Netid column (5 cols before process), -t or -u alone has 4
    local addr_col=4
    if [[ "$ss_flags" == *t* ]] && [[ "$ss_flags" == *u* ]]; then
        addr_col=5
    fi

    ss $ss_flags 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        # Use awk to parse — ss columns can be tricky with variable whitespace
        local state=$(echo "$line" | awk '{print $1}')
        local local_addr=$(echo "$line" | awk -v c="$addr_col" '{print $c}')
        local process_info=$(echo "$line" | grep -oP 'users:\(\(.*?\)\)' 2>/dev/null || echo "")
        
        # Parse port from local address (handle IPv6 like [::]:port)
        local port bind
        if [[ "$local_addr" =~ ^\[.*\]:([0-9]+)$ ]]; then
            port="${BASH_REMATCH[1]}"
            bind=$(echo "$local_addr" | sed 's/:[0-9]*$//')
        else
            port="${local_addr##*:}"
            bind="${local_addr%:*}"
        fi
        
        # Skip if port didn't parse
        [[ "$port" =~ ^[0-9]+$ ]] || continue
        
        # Parse protocol
        local proto="tcp"
        if [[ "$state" == "udp" ]] || [[ "$state" == "UNCONN" ]]; then
            proto="udp"
            [[ "$state" == "udp" ]] && state=$(echo "$line" | awk '{print $2}')
        elif [[ "$state" == "tcp" ]]; then
            state=$(echo "$line" | awk '{print $2}')
        fi
        
        # Parse PID and process name from users:(("name",pid=123,fd=4))
        local pid="" pname=""
        if [[ "$process_info" =~ pid=([0-9]+) ]]; then
            pid="${BASH_REMATCH[1]}"
        fi
        if [[ "$process_info" =~ \"([^\"]+)\" ]]; then
            pname="${BASH_REMATCH[1]}"
        fi
        
        # Get user from PID
        local user="-"
        if [[ -n "$pid" ]]; then
            user=$(ps -o user= -p "$pid" 2>/dev/null || echo "-")
        fi

        # Apply user filter
        if [[ -n "$USER_FILTER" ]] && [[ "$user" != "$USER_FILTER" ]]; then
            continue
        fi

        # Normalize state
        local display_state="LISTEN"
        [[ "$state" == "UNCONN" ]] && display_state="LISTEN"
        [[ "$state" == "ESTAB" ]] && display_state="ESTABLISHED"
        [[ "$state" == "TIME-WAIT" ]] && display_state="TIME_WAIT"

        if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
            echo "$port,$proto,$pid,$pname,$user,$display_state,$bind"
        else
            printf "%-7s %-6s %-7s %-18s %-12s %-10s %s\n" "$port" "$proto" "${pid:--}" "${pname:--}" "$user" "$display_state" "$bind"
        fi
    done | sort -t, -k1 -n 2>/dev/null || sort -k1 -n
}

scan_json() {
    local ss_flags="$1"
    echo "["
    local first=true
    local jaddr_col=4
    if [[ "$ss_flags" == *t* ]] && [[ "$ss_flags" == *u* ]]; then jaddr_col=5; fi
    ss $ss_flags 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        local state=$(echo "$line" | awk '{print $1}')
        local local_addr=$(echo "$line" | awk -v c="$jaddr_col" '{print $c}')
        local process_info=$(echo "$line" | grep -oP 'users:\(\(.*?\)\)' 2>/dev/null || echo "")
        local port bind
        if [[ "$local_addr" =~ ^\[.*\]:([0-9]+)$ ]]; then
            port="${BASH_REMATCH[1]}"; bind=$(echo "$local_addr" | sed 's/:[0-9]*$//')
        else
            port="${local_addr##*:}"; bind="${local_addr%:*}"
        fi
        [[ "$port" =~ ^[0-9]+$ ]] || continue
        local proto="tcp"
        if [[ "$state" == "udp" ]] || [[ "$state" == "UNCONN" ]]; then proto="udp"; fi
        local pid="" pname=""
        [[ "$process_info" =~ pid=([0-9]+) ]] && pid="${BASH_REMATCH[1]}"
        [[ "$process_info" =~ \"([^\"]+)\" ]] && pname="${BASH_REMATCH[1]}"
        local user="-"
        [[ -n "$pid" ]] && user=$(ps -o user= -p "$pid" 2>/dev/null || echo "-")
        
        if [[ -n "$USER_FILTER" ]] && [[ "$user" != "$USER_FILTER" ]]; then continue; fi
        
        $first || echo ","
        first=false
        printf '  {"port":%s,"proto":"%s","pid":%s,"process":"%s","user":"%s","bind":"%s"}' \
            "$port" "$proto" "${pid:-null}" "${pname:--}" "$user" "$bind"
    done
    echo ""
    echo "]"
}

# ─── CHECK ───────────────────────────────────────────────────────────────────

cmd_check() {
    local port=$1
    
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        echo -e "${RED}Error: Invalid port number '$port'. Must be 1-65535.${NC}"
        exit 1
    fi

    local result=$(ss -tlnp "sport = :$port" 2>/dev/null | tail -n +2)
    local udp_result=$(ss -ulnp "sport = :$port" 2>/dev/null | tail -n +2)
    
    if [[ -z "$result" ]] && [[ -z "$udp_result" ]]; then
        if [[ "$OUTPUT_FORMAT" == "json" ]]; then
            echo "{\"port\":$port,\"in_use\":false}"
        else
            echo -e "${GREEN}✅ Port $port is free — safe to use${NC}"
        fi
        return 0
    fi

    # Port is in use — gather details
    local combined="$result"$'\n'"$udp_result"
    combined=$(echo "$combined" | sed '/^$/d')

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "{\"port\":$port,\"in_use\":true,\"processes\":["
        local first=true
        echo "$combined" | while read -r state recv_q send_q local_addr peer_addr process_info; do
            local pid="" pname=""
            [[ "$process_info" =~ pid=([0-9]+) ]] && pid="${BASH_REMATCH[1]}"
            [[ "$process_info" =~ \"([^\"]+)\" ]] && pname="${BASH_REMATCH[1]}"
            local user=$(ps -o user= -p "$pid" 2>/dev/null || echo "-")
            $first || echo ","
            first=false
            printf '{"pid":%s,"process":"%s","user":"%s"}' "${pid:-null}" "${pname:--}" "$user"
        done
        echo "]}"
        return 1
    fi

    echo -e "${RED}❌ Port $port is in use${NC}"
    echo "$combined" | while read -r state recv_q send_q local_addr peer_addr process_info; do
        local pid="" pname=""
        [[ "$process_info" =~ pid=([0-9]+) ]] && pid="${BASH_REMATCH[1]}"
        [[ "$process_info" =~ \"([^\"]+)\" ]] && pname="${BASH_REMATCH[1]}"
        local user=$(ps -o user= -p "$pid" 2>/dev/null || echo "-")
        local bind=$(echo "$local_addr" | rev | cut -d: -f2- | rev)
        
        echo -e "  ${BOLD}PID:${NC}     ${pid:--}"
        echo -e "  ${BOLD}Process:${NC} ${pname:--}"
        echo -e "  ${BOLD}User:${NC}    $user"
        echo -e "  ${BOLD}Bind:${NC}    $bind"
        
        # Get full command line
        if [[ -n "$pid" ]]; then
            local cmdline=$(ps -o args= -p "$pid" 2>/dev/null || echo "-")
            echo -e "  ${BOLD}Command:${NC} $cmdline"
            # Get start time
            local start=$(ps -o lstart= -p "$pid" 2>/dev/null || echo "-")
            echo -e "  ${BOLD}Started:${NC} $start"
        fi
        
        # Count active connections
        local conn_count=$(ss -tn "sport = :$port" 2>/dev/null | tail -n +2 | wc -l)
        echo -e "  ${BOLD}Active connections:${NC} $conn_count"
    done
    return 1
}

# ─── KILL ────────────────────────────────────────────────────────────────────

cmd_kill() {
    local port=$1
    
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid port number '$port'${NC}"
        exit 1
    fi

    # Find PIDs on port
    local pids=$(lsof -t -i:"$port" 2>/dev/null || ss -tlnp "sport = :$port" 2>/dev/null | grep -oP 'pid=\K[0-9]+')
    
    if [[ -z "$pids" ]]; then
        echo -e "${GREEN}✅ Port $port is already free${NC}"
        return 0
    fi

    local signal="-15"  # SIGTERM
    $FORCE && signal="-9"  # SIGKILL

    for pid in $pids; do
        local pname=$(ps -o comm= -p "$pid" 2>/dev/null || echo "unknown")
        echo -e "${YELLOW}🔪 Killing PID $pid ($pname) on port $port...${NC}"
        kill $signal "$pid" 2>/dev/null || {
            echo -e "${RED}   Permission denied. Try: sudo bash scripts/portman.sh kill $port${NC}"
            return 1
        }
    done

    # Verify port is free
    sleep 1
    if ss -tlnp "sport = :$port" 2>/dev/null | tail -n +2 | grep -q .; then
        echo -e "${RED}❌ Port $port still in use. Try --force${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Port $port is now free${NC}"
    fi
}

# ─── CONFLICTS ───────────────────────────────────────────────────────────────

cmd_conflicts() {
    echo -e "${BOLD}Checking for port conflicts...${NC}"
    
    local found=false
    # Get ports with multiple listeners
    ss -tlnp 2>/dev/null | tail -n +2 | awk '{print $4}' | rev | cut -d: -f1 | rev | sort | uniq -d | while read -r port; do
        found=true
        echo -e "\n${YELLOW}⚠️  Port $port:${NC}"
        ss -tlnp "sport = :$port" 2>/dev/null | tail -n +2 | while read -r state recv_q send_q local_addr peer_addr process_info; do
            local pid="" pname=""
            [[ "$process_info" =~ pid=([0-9]+) ]] && pid="${BASH_REMATCH[1]}"
            [[ "$process_info" =~ \"([^\"]+)\" ]] && pname="${BASH_REMATCH[1]}"
            local user=$(ps -o user= -p "$pid" 2>/dev/null || echo "-")
            local bind=$(echo "$local_addr" | rev | cut -d: -f2- | rev)
            echo -e "  PID $pid — $pname (user: $user, bind: $bind)"
        done
    done

    if ! $found 2>/dev/null; then
        echo -e "${GREEN}✅ No port conflicts detected${NC}"
    fi
}

# ─── RANGE ───────────────────────────────────────────────────────────────────

cmd_range() {
    local range=$1
    local from=${range%-*}
    local to=${range#*-}

    if ! [[ "$from" =~ ^[0-9]+$ ]] || ! [[ "$to" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid range format. Use: range 8000-9000${NC}"
        exit 1
    fi

    echo -e "${BOLD}Scanning ports $from-$to...${NC}"
    
    local in_use=0
    local total=$((to - from + 1))

    ss -tlnp 2>/dev/null | tail -n +2 | while read -r state recv_q send_q local_addr peer_addr process_info; do
        local port=$(echo "$local_addr" | rev | cut -d: -f1 | rev)
        if [[ "$port" -ge "$from" ]] && [[ "$port" -le "$to" ]]; then
            local pid="" pname=""
            [[ "$process_info" =~ pid=([0-9]+) ]] && pid="${BASH_REMATCH[1]}"
            [[ "$process_info" =~ \"([^\"]+)\" ]] && pname="${BASH_REMATCH[1]}"
            echo -e "  ${GREEN}$port${NC}  ✅ $pname (PID ${pid:--})"
            in_use=$((in_use + 1))
        fi
    done

    # Summary line
    local used_count=$(ss -tlnp 2>/dev/null | tail -n +2 | awk '{print $4}' | rev | cut -d: -f1 | rev | awk -v f="$from" -v t="$to" '$1>=f && $1<=t' | wc -l)
    local free_count=$((total - used_count))
    echo -e "\n  ${BOLD}$used_count ports in use, $free_count free${NC}"
}

# ─── COMMON ──────────────────────────────────────────────────────────────────

cmd_common() {
    declare -A COMMON_PORTS=(
        [22]="SSH" [80]="HTTP" [443]="HTTPS" [3000]="Dev Server"
        [3306]="MySQL" [5432]="PostgreSQL" [6379]="Redis"
        [8080]="Alt HTTP" [8443]="Alt HTTPS" [27017]="MongoDB"
        [9090]="Prometheus" [9200]="Elasticsearch" [5672]="RabbitMQ"
        [1883]="MQTT" [53]="DNS" [25]="SMTP" [587]="SMTP TLS"
        [143]="IMAP" [993]="IMAPS" [110]="POP3" [995]="POP3S"
    )

    echo -e "${BOLD}Common Service Ports:${NC}"
    
    for port in $(echo "${!COMMON_PORTS[@]}" | tr ' ' '\n' | sort -n); do
        local label="${COMMON_PORTS[$port]}"
        local result=$(ss -tlnp "sport = :$port" 2>/dev/null | tail -n +2)
        
        if [[ -n "$result" ]]; then
            local pname=""
            [[ "$result" =~ \"([^\"]+)\" ]] && pname="${BASH_REMATCH[1]}"
            printf "  %-6s %-15s ${GREEN}✅ %s${NC}\n" "$port" "($label)" "$pname"
        else
            printf "  %-6s %-15s ${RED}❌ free${NC}\n" "$port" "($label)"
        fi
    done
}

# ─── AUDIT ───────────────────────────────────────────────────────────────────

cmd_audit() {
    echo -e "${BOLD}🔒 Security Audit:${NC}\n"
    
    local warnings=0
    local recommendations=()

    ss -tlnp 2>/dev/null | tail -n +2 | while read -r state recv_q send_q local_addr peer_addr process_info; do
        local port=$(echo "$local_addr" | rev | cut -d: -f1 | rev)
        local bind=$(echo "$local_addr" | rev | cut -d: -f2- | rev)
        local pid="" pname=""
        [[ "$process_info" =~ pid=([0-9]+) ]] && pid="${BASH_REMATCH[1]}"
        [[ "$process_info" =~ \"([^\"]+)\" ]] && pname="${BASH_REMATCH[1]}"

        # Check if bound to all interfaces
        if [[ "$bind" == "*" ]] || [[ "$bind" == "0.0.0.0" ]] || [[ "$bind" == "[::]" ]]; then
            # Warn for database/internal services exposed to all interfaces
            case "$port" in
                3306|5432|6379|27017|9200|5672|11211)
                    echo -e "  ${YELLOW}⚠️  Port $port ($pname) is open to ALL interfaces ($bind)${NC}"
                    echo -e "     ${BLUE}→ Recommendation: Bind to 127.0.0.1 for security${NC}"
                    warnings=$((warnings + 1))
                    ;;
                22)
                    echo -e "  ${YELLOW}⚠️  Port $port ($pname) is open to ALL interfaces${NC}"
                    echo -e "     ${BLUE}→ Recommendation: Restrict via UFW or bind to specific IP${NC}"
                    warnings=$((warnings + 1))
                    ;;
                80|443|8080|8443)
                    echo -e "  ${GREEN}✅ Port $port ($pname) — public web port, OK on all interfaces${NC}"
                    ;;
                *)
                    echo -e "  ${YELLOW}⚠️  Port $port ($pname) is open to ALL interfaces ($bind)${NC}"
                    echo -e "     ${BLUE}→ Review if this needs to be public${NC}"
                    warnings=$((warnings + 1))
                    ;;
            esac
        else
            echo -e "  ${GREEN}✅ Port $port ($pname) — bound to $bind only${NC}"
        fi
    done

    # Check firewall status
    echo ""
    if command -v ufw &>/dev/null; then
        local ufw_status=$(sudo ufw status 2>/dev/null | head -1 || echo "unknown")
        if echo "$ufw_status" | grep -q "inactive"; then
            echo -e "  ${RED}⚠️  UFW firewall is INACTIVE${NC}"
            echo -e "     ${BLUE}→ Recommendation: Enable with 'sudo ufw enable'${NC}"
        elif echo "$ufw_status" | grep -q "active"; then
            echo -e "  ${GREEN}✅ UFW firewall is active${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️  UFW not installed — no firewall detected${NC}"
        echo -e "     ${BLUE}→ Recommendation: Install with 'sudo apt-get install ufw'${NC}"
    fi
}

# ─── WATCH ───────────────────────────────────────────────────────────────────

cmd_watch() {
    local port=$1
    local interval=2

    echo -e "${BOLD}Watching port $port (Ctrl+C to stop)...${NC}\n"

    while true; do
        local total=$(ss -tn "sport = :$port" 2>/dev/null | tail -n +2 | wc -l)
        local estab=$(ss -tn "sport = :$port" state established 2>/dev/null | tail -n +2 | wc -l)
        local tw=$(ss -tn "sport = :$port" state time-wait 2>/dev/null | tail -n +2 | wc -l)
        local syn=$(ss -tn "sport = :$port" state syn-recv 2>/dev/null | tail -n +2 | wc -l)
        local cw=$(ss -tn "sport = :$port" state close-wait 2>/dev/null | tail -n +2 | wc -l)

        printf "\r[%s] Port %s — %s connections (%s ESTAB, %s TW, %s SYN, %s CW)    " \
            "$(date +%H:%M:%S)" "$port" "$total" "$estab" "$tw" "$syn" "$cw"
        
        sleep "$interval"
    done
}

# ─── REPORT ──────────────────────────────────────────────────────────────────

cmd_report() {
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "{"
        echo "  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"hostname\": \"$(hostname)\","
        echo "  \"ports\":"
        cmd_scan
        echo "}"
    elif [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        cmd_scan
    else
        echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}  Service Port Report — $(hostname)${NC}"
        echo -e "${BOLD}  Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)${NC}"
        echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}\n"
        
        echo -e "${BOLD}Listening Ports:${NC}\n"
        cmd_scan
        
        echo -e "\n${BOLD}Common Services:${NC}\n"
        cmd_common
        
        echo -e "\n${BOLD}Security Audit:${NC}\n"
        cmd_audit
    fi
}

# ─── FIREWALL ────────────────────────────────────────────────────────────────

cmd_firewall() {
    local subcmd=${1:-status}
    local port=${2:-}

    if ! command -v ufw &>/dev/null; then
        echo -e "${RED}Error: UFW not installed. Install with: sudo apt-get install ufw${NC}"
        exit 1
    fi

    case "$subcmd" in
        status)
            sudo ufw status verbose 2>/dev/null || echo "Run with sudo for firewall status"
            ;;
        allow)
            if [[ -z "$port" ]]; then
                echo -e "${RED}Error: Specify a port. Usage: firewall allow 8080${NC}"
                exit 1
            fi
            if [[ -n "$FIREWALL_FROM" ]]; then
                echo -e "${BLUE}Allowing port $port from $FIREWALL_FROM...${NC}"
                sudo ufw allow from "$FIREWALL_FROM" to any port "$port"
            else
                echo -e "${BLUE}Allowing port $port...${NC}"
                sudo ufw allow "$port"
            fi
            echo -e "${GREEN}✅ Rule added${NC}"
            ;;
        deny)
            if [[ -z "$port" ]]; then
                echo -e "${RED}Error: Specify a port. Usage: firewall deny 3306${NC}"
                exit 1
            fi
            echo -e "${BLUE}Blocking port $port...${NC}"
            sudo ufw deny "$port"
            echo -e "${GREEN}✅ Rule added${NC}"
            ;;
        remove)
            if [[ -z "$port" ]]; then
                echo -e "${RED}Error: Specify a port. Usage: firewall remove 8080${NC}"
                exit 1
            fi
            echo -e "${BLUE}Removing rules for port $port...${NC}"
            sudo ufw delete allow "$port" 2>/dev/null
            sudo ufw delete deny "$port" 2>/dev/null
            echo -e "${GREEN}✅ Rules removed${NC}"
            ;;
        *)
            echo -e "${RED}Unknown firewall command: $subcmd${NC}"
            echo "Available: status, allow, deny, remove"
            exit 1
            ;;
    esac
}

# ─── MAIN ────────────────────────────────────────────────────────────────────

main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi

    local cmd=$1
    shift

    # Extract positional arg (port/range) and options
    local positional=""
    local fw_subcmd="" fw_port=""
    local opts=()
    
    case "$cmd" in
        firewall)
            fw_subcmd="${1:-status}"
            [[ $# -gt 0 ]] && shift
            fw_port="${1:-}"
            [[ $# -gt 0 ]] && shift
            parse_opts "$@"
            cmd_firewall "$fw_subcmd" "$fw_port"
            ;;
        scan)
            parse_opts "$@"
            cmd_scan
            ;;
        check)
            positional="${1:?Error: Specify a port number}"
            shift
            parse_opts "$@"
            cmd_check "$positional"
            ;;
        kill)
            positional="${1:?Error: Specify a port number}"
            shift
            parse_opts "$@"
            cmd_kill "$positional"
            ;;
        conflicts)
            parse_opts "$@"
            cmd_conflicts
            ;;
        range)
            positional="${1:?Error: Specify a port range (e.g., 8000-9000)}"
            shift
            parse_opts "$@"
            cmd_range "$positional"
            ;;
        common)
            parse_opts "$@"
            cmd_common
            ;;
        audit)
            parse_opts "$@"
            cmd_audit
            ;;
        watch)
            positional="${1:?Error: Specify a port number}"
            shift
            parse_opts "$@"
            cmd_watch "$positional"
            ;;
        report)
            parse_opts "$@"
            cmd_report
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown command: $cmd${NC}"
            usage
            exit 1
            ;;
    esac
}

main "$@"
