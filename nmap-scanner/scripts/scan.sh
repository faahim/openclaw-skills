#!/bin/bash
# Nmap Scanner — Main Scan Script
# Usage: bash scan.sh <command> [target] [options]
set -euo pipefail

VERSION="1.0.0"
DATA_DIR="$HOME/.nmap-scanner"
REPORT_DIR="$DATA_DIR/reports"
BASELINE_DIR="$DATA_DIR/baselines"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[ERR]${NC} $*"; }

has() { command -v "$1" &>/dev/null; }

# Ensure nmap is installed
if ! has nmap; then
    err "nmap not found. Run: bash scripts/install.sh"
    exit 1
fi

mkdir -p "$REPORT_DIR" "$BASELINE_DIR"

# Auto-detect local network
detect_network() {
    local net
    if [[ -n "${NMAP_DEFAULT_NETWORK:-}" ]]; then
        echo "$NMAP_DEFAULT_NETWORK"
        return
    fi
    # Try to get from ip route
    net=$(ip route 2>/dev/null | grep -E "^[0-9].*src" | head -1 | awk '{print $1}')
    if [ -n "$net" ]; then
        echo "$net"
    else
        # macOS fallback
        local gw_if
        gw_if=$(route -n get default 2>/dev/null | grep interface | awk '{print $2}')
        if [ -n "$gw_if" ]; then
            local ip_addr
            ip_addr=$(ifconfig "$gw_if" 2>/dev/null | grep "inet " | awk '{print $2}')
            echo "${ip_addr%.*}.0/24"
        else
            echo "192.168.1.0/24"
        fi
    fi
}

# Send Telegram alert (if configured)
send_alert() {
    local message="$1"
    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
        curl -sS "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TELEGRAM_CHAT_ID}" \
            -d text="🔍 Nmap Scanner Alert%0A%0A${message}" \
            -d parse_mode="HTML" >/dev/null 2>&1 || true
    fi
}

# Format timestamp
ts() { date '+%Y-%m-%d %H:%M:%S'; }
ts_file() { date '+%Y%m%d_%H%M%S'; }

# === COMMANDS ===

cmd_discover() {
    local network="${1:-$(detect_network)}"
    shift || true
    local save_name="" diff_name="" fast=false report_fmt=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --save) save_name="$2"; shift 2 ;;
            --diff) diff_name="$2"; shift 2 ;;
            --fast) fast=true; shift ;;
            --report) report_fmt="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    echo ""
    echo -e "${CYAN}=== Network Discovery: $network ===${NC}"
    echo -e "${BLUE}Started:${NC} $(ts)"
    echo ""

    local xml_out="$REPORT_DIR/discover_$(ts_file).xml"
    local nmap_args="-sn"

    if [[ "$fast" == true ]]; then
        nmap_args="-sn -T4 --max-retries 1"
    fi

    nmap $nmap_args "$network" -oX "$xml_out" 2>/dev/null | \
        grep -E "Nmap scan report|MAC Address|Host is up" | \
        while IFS= read -r line; do
            if echo "$line" | grep -q "Nmap scan report"; then
                local host ip
                host=$(echo "$line" | grep -oP "for \K[^ ]+(?= \()" || echo "")
                ip=$(echo "$line" | grep -oP "\d+\.\d+\.\d+\.\d+" || echo "")
                if [ -z "$host" ]; then host="$ip"; fi
                printf "  %-16s %s" "$ip" "$host"
            elif echo "$line" | grep -q "MAC Address"; then
                local mac vendor
                mac=$(echo "$line" | grep -oP "[0-9A-F:]{17}" || echo "unknown")
                vendor=$(echo "$line" | grep -oP "\(.*\)" || echo "")
                printf "  %s  %s\n" "$mac" "$vendor"
            fi
        done

    local host_count
    host_count=$(grep -c "status=\"up\"" "$xml_out" 2>/dev/null || echo "0")
    echo ""
    echo -e "${GREEN}Found $host_count hosts${NC}"

    # Save baseline
    if [ -n "$save_name" ]; then
        cp "$xml_out" "$BASELINE_DIR/${save_name}.xml"
        ok "Baseline saved as '$save_name'"
    fi

    # Diff against baseline
    if [ -n "$diff_name" ]; then
        local baseline="$BASELINE_DIR/${diff_name}.xml"
        if [ ! -f "$baseline" ]; then
            if [[ "$diff_name" == "last" ]]; then
                baseline=$(ls -t "$BASELINE_DIR"/*.xml 2>/dev/null | head -1)
            fi
        fi
        if [ -f "$baseline" ]; then
            echo ""
            echo -e "${CYAN}=== Changes vs $diff_name ===${NC}"
            # Extract IPs from both scans
            local old_ips new_ips
            old_ips=$(grep -oP 'addr="\K\d+\.\d+\.\d+\.\d+' "$baseline" | sort -u)
            new_ips=$(grep -oP 'addr="\K\d+\.\d+\.\d+\.\d+' "$xml_out" | sort -u)

            # New hosts
            comm -13 <(echo "$old_ips") <(echo "$new_ips") | while read -r ip; do
                echo -e "  ${GREEN}[+] NEW:  $ip${NC}"
                send_alert "New host detected: $ip"
            done

            # Gone hosts
            comm -23 <(echo "$old_ips") <(echo "$new_ips") | while read -r ip; do
                echo -e "  ${RED}[-] GONE: $ip${NC}"
                send_alert "Host disappeared: $ip"
            done

            # Save current as new baseline
            cp "$xml_out" "$BASELINE_DIR/${diff_name}.xml"
        else
            warn "Baseline '$diff_name' not found"
        fi
    fi

    # Report formats
    if [[ "$report_fmt" == "json" ]] && has jq; then
        grep -oP 'addr="\K\d+\.\d+\.\d+\.\d+' "$xml_out" | jq -R -s 'split("\n") | map(select(. != ""))' \
            > "$REPORT_DIR/discover_$(ts_file).json"
        ok "JSON report saved"
    elif [[ "$report_fmt" == "csv" ]]; then
        echo "ip,hostname,mac,vendor" > "$REPORT_DIR/discover_$(ts_file).csv"
        ok "CSV report saved"
    elif [[ "$report_fmt" == "html" ]] && has xsltproc; then
        xsltproc "$xml_out" > "$REPORT_DIR/discover_$(ts_file).html" 2>/dev/null
        ok "HTML report saved"
    fi
}

cmd_ports() {
    local target="$1"; shift
    local full=false stealth=false ports="" timing="-T3" report_fmt=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --full) full=true; shift ;;
            --stealth) stealth=true; shift ;;
            --ports) ports="$2"; shift 2 ;;
            --report) report_fmt="$2"; shift 2 ;;
            -T*) timing="$1"; shift ;;
            *) shift ;;
        esac
    done

    echo ""
    echo -e "${CYAN}=== Port Scan: $target ===${NC}"
    echo -e "${BLUE}Started:${NC} $(ts)"
    echo ""

    local nmap_args="$timing"
    if [[ "$full" == true ]]; then
        nmap_args="$nmap_args -p-"
    elif [ -n "$ports" ]; then
        nmap_args="$nmap_args -p $ports"
    fi
    if [[ "$stealth" == true ]]; then
        nmap_args="$nmap_args -sS"
    fi

    local xml_out="$REPORT_DIR/ports_$(ts_file).xml"
    nmap $nmap_args "$target" -oX "$xml_out" 2>/dev/null

    # Parse and display
    printf "  %-10s %-8s %s\n" "PORT" "STATE" "SERVICE"
    printf "  %-10s %-8s %s\n" "----" "-----" "-------"

    local open_count=0
    while IFS= read -r line; do
        local port state service
        port=$(echo "$line" | grep -oP 'portid="\K[^"]+')
        state=$(echo "$line" | grep -oP 'state="\K[^"]+')
        service=$(echo "$line" | grep -oP 'name="\K[^"]+')
        local protocol
        protocol=$(echo "$line" | grep -oP 'protocol="\K[^"]+')

        if [[ "$state" == "open" ]]; then
            printf "  ${GREEN}%-10s %-8s %s${NC}\n" "${port}/${protocol}" "$state" "$service"
            open_count=$((open_count + 1))
        elif [[ "$state" == "filtered" ]]; then
            printf "  ${YELLOW}%-10s %-8s %s${NC}\n" "${port}/${protocol}" "$state" "$service"
        fi
    done < <(grep '<port ' "$xml_out" 2>/dev/null || true)

    echo ""
    echo -e "${GREEN}$open_count open ports found${NC}"

    if [[ "$report_fmt" == "json" ]] && has jq; then
        python3 -c "
import xml.etree.ElementTree as ET, json, sys
tree = ET.parse('$xml_out')
ports = []
for p in tree.findall('.//port'):
    state = p.find('state')
    svc = p.find('service')
    ports.append({
        'port': int(p.get('portid')),
        'protocol': p.get('protocol'),
        'state': state.get('state') if state is not None else 'unknown',
        'service': svc.get('name','') if svc is not None else ''
    })
json.dump({'target': '$target', 'ports': ports}, sys.stdout, indent=2)
" > "$REPORT_DIR/ports_$(ts_file).json" 2>/dev/null
        ok "JSON report saved"
    fi
}

cmd_services() {
    local target="$1"; shift
    local report_fmt=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --report) report_fmt="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    echo ""
    echo -e "${CYAN}=== Service Detection: $target ===${NC}"
    echo -e "${BLUE}Started:${NC} $(ts)"
    echo ""

    local xml_out="$REPORT_DIR/services_$(ts_file).xml"
    nmap -sV -O --version-intensity 5 "$target" -oX "$xml_out" 2>/dev/null

    printf "  %-10s %-8s %-15s %s\n" "PORT" "STATE" "SERVICE" "VERSION"
    printf "  %-10s %-8s %-15s %s\n" "----" "-----" "-------" "-------"

    while IFS= read -r line; do
        local port state service version product
        port=$(echo "$line" | grep -oP 'portid="\K[^"]+')
        local protocol
        protocol=$(echo "$line" | grep -oP 'protocol="\K[^"]+')
        state=$(echo "$line" | grep -oP 'state="\K[^"]+' | head -1)
        service=$(echo "$line" | grep -oP 'name="\K[^"]+' | tail -1)
        product=$(echo "$line" | grep -oP 'product="\K[^"]+' || echo "")
        version=$(echo "$line" | grep -oP 'version="\K[^"]+' || echo "")

        if [[ "$state" == "open" ]]; then
            printf "  ${GREEN}%-10s %-8s %-15s %s %s${NC}\n" "${port}/${protocol}" "$state" "$service" "$product" "$version"
        fi
    done < <(grep '<port ' "$xml_out" 2>/dev/null || true)

    # OS detection
    local os_match
    os_match=$(grep -oP 'name="\K[^"]+' "$xml_out" 2>/dev/null | grep -i -E "linux|windows|macos|freebsd" | head -1 || echo "")
    local os_accuracy
    os_accuracy=$(grep -oP 'accuracy="\K[^"]+' "$xml_out" 2>/dev/null | head -1 || echo "")

    if [ -n "$os_match" ]; then
        echo ""
        echo -e "  ${BLUE}OS:${NC} $os_match (${os_accuracy}% confidence)"
    fi

    if [[ "$report_fmt" == "html" ]] && has xsltproc; then
        xsltproc "$xml_out" > "$REPORT_DIR/services_$(ts_file).html" 2>/dev/null
        ok "HTML report saved to $REPORT_DIR/"
    fi
}

cmd_vuln() {
    local target="$1"; shift

    echo ""
    echo -e "${CYAN}=== Vulnerability Scan: $target ===${NC}"
    echo -e "${BLUE}Started:${NC} $(ts)"
    warn "This may take several minutes..."
    echo ""

    local xml_out="$REPORT_DIR/vuln_$(ts_file).xml"
    nmap -sV --script vuln "$target" -oX "$xml_out" 2>/dev/null

    # Parse vulnerability output
    local vuln_count=0
    while IFS= read -r line; do
        if echo "$line" | grep -qiE "VULNERABLE|CVE-|vuln"; then
            echo -e "  ${RED}[!]${NC} $line"
            vuln_count=$((vuln_count + 1))
        fi
    done < <(nmap -sV --script vuln "$target" 2>/dev/null | grep -E "^\|" || true)

    if [[ $vuln_count -eq 0 ]]; then
        ok "No known vulnerabilities detected"
    else
        warn "$vuln_count potential vulnerabilities found"
        send_alert "Vulnerability scan on $target found $vuln_count issues"
    fi
}

cmd_os() {
    local target="$1"; shift

    echo ""
    echo -e "${CYAN}=== OS Detection: $target ===${NC}"
    echo ""

    sudo nmap -O "$target" 2>/dev/null | grep -E "OS details|Running|Aggressive OS"
}

cmd_nse() {
    local target="$1"; shift
    local scripts="safe"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --scripts) scripts="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    echo ""
    echo -e "${CYAN}=== NSE Script Scan: $target (scripts: $scripts) ===${NC}"
    echo ""

    nmap --script "$scripts" "$target" 2>/dev/null | grep -E "^\||PORT|open"
}

cmd_monitor() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-cron)
                local script_path
                script_path=$(readlink -f "$0")
                local cron_line="0 * * * * bash $script_path discover --diff last --save last 2>/dev/null"
                (crontab -l 2>/dev/null | grep -v "nmap-scanner"; echo "$cron_line") | crontab -
                ok "Cron job installed — hourly network scan with diff"
                exit 0 ;;
            *) shift ;;
        esac
    done
}

# === MAIN ===

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    discover)   cmd_discover "$@" ;;
    ports)      cmd_ports "$@" ;;
    services)   cmd_services "$@" ;;
    vuln)       cmd_vuln "$@" ;;
    os)         cmd_os "$@" ;;
    nse)        cmd_nse "$@" ;;
    monitor)    cmd_monitor "$@" ;;
    help|--help|-h)
        echo "Nmap Scanner v$VERSION"
        echo ""
        echo "Commands:"
        echo "  discover [network]     Find all hosts on network"
        echo "  ports <target>         Scan for open ports"
        echo "  services <target>      Detect services + versions"
        echo "  vuln <target>          Run vulnerability scripts"
        echo "  os <target>            Detect operating system"
        echo "  nse <target>           Run NSE scripts"
        echo "  monitor --install-cron Set up scheduled scanning"
        echo ""
        echo "Options:"
        echo "  --full          Scan all 65535 ports"
        echo "  --stealth       SYN scan (requires root)"
        echo "  --ports N,N,N   Scan specific ports"
        echo "  --save <name>   Save scan as baseline"
        echo "  --diff <name>   Compare against baseline"
        echo "  --report <fmt>  Output format: json, csv, html"
        echo "  --fast          Quick scan (less thorough)"
        ;;
    *)
        err "Unknown command: $COMMAND"
        echo "Run 'bash scan.sh help' for usage"
        exit 1 ;;
esac
