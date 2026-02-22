#!/bin/bash
# Network Diagnostics Toolkit — Main Script
# Usage: bash netdiag.sh <command> [target] [options]
set -euo pipefail

# Defaults
TIMEOUT="${NETDIAG_TIMEOUT:-10}"
PING_COUNT="${NETDIAG_PING_COUNT:-5}"
MTR_COUNT="${NETDIAG_MTR_COUNT:-10}"
SPEEDTEST_BYTES="${NETDIAG_SPEEDTEST_BYTES:-100000000}"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

usage() {
    cat <<EOF
Network Diagnostics Toolkit

Usage: bash netdiag.sh <command> [target] [options]

Commands:
  portscan <host>         Scan ports on a host
  dns <domain>            DNS record lookup
  dns-propagation <domain> Check DNS across multiple servers
  rdns <ip>               Reverse DNS lookup
  trace <host>            Traceroute to host
  mtr <host>              MTR (enhanced traceroute with stats)
  ping <host>             Ping test
  speedtest               Download speed test
  ssl <host>              SSL certificate check
  report <host>           Full diagnostic report
  interfaces              Local network interfaces
  listening               Listening ports
  connections             Active connections
  myip                    Show public IP address
  whois <domain>          WHOIS domain lookup

Options:
  --full                  Full port scan (all 65535 ports)
  --ports <list>          Scan specific ports (comma-separated)
  --version               Detect service versions
  --tcp-connect           Use TCP connect scan (no root needed)
  --type <record>         DNS record type (A, AAAA, MX, TXT, CNAME, NS, SOA)
  --count <n>             Ping/MTR count
  --no-dns                Skip DNS resolution in MTR
  --output <file>         Save output to file
  --url <url>             Custom speed test URL

EOF
    exit 0
}

# === PORT SCANNING ===
cmd_portscan() {
    local host="$1"; shift
    local scan_type="--top-ports 100"
    local extra_flags=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --full) scan_type="-p-"; shift ;;
            --ports) scan_type="-p $2"; shift 2 ;;
            --version) extra_flags="$extra_flags -sV"; shift ;;
            --tcp-connect) extra_flags="$extra_flags -sT"; shift ;;
            *) shift ;;
        esac
    done
    
    echo "=== Port Scan: $host ==="
    echo "[$(timestamp)] Scanning..."
    echo ""
    
    if ! command -v nmap &>/dev/null; then
        echo "❌ nmap not installed. Run: bash scripts/install.sh"
        return 1
    fi
    
    local start_time=$(date +%s%3N 2>/dev/null || date +%s)
    nmap $scan_type $extra_flags --open -T4 "$host" 2>/dev/null | grep -E "^(PORT|[0-9]+/)" || echo "No open ports found."
    local end_time=$(date +%s%3N 2>/dev/null || date +%s)
    
    echo ""
    local elapsed=$(( (end_time - start_time) ))
    if [ $elapsed -gt 1000 ]; then
        echo "Scan completed in $(echo "scale=1; $elapsed/1000" | bc 2>/dev/null || echo "$elapsed ms")s"
    else
        echo "Scan completed in ${elapsed}ms"
    fi
}

# === DNS LOOKUP ===
cmd_dns() {
    local domain="$1"; shift
    local record_type=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type) record_type="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    echo "=== DNS Lookup: $domain ==="
    echo ""
    
    if ! command -v dig &>/dev/null; then
        echo "❌ dig not installed. Run: bash scripts/install.sh"
        return 1
    fi
    
    if [ -n "$record_type" ]; then
        echo "$record_type Records:"
        dig +short "$domain" "$record_type" 2>/dev/null | while read -r line; do
            echo "  $line"
        done
    else
        for type in A AAAA MX NS TXT CNAME SOA; do
            local results
            results=$(dig +short "$domain" "$type" 2>/dev/null)
            if [ -n "$results" ]; then
                echo "$type Records:"
                echo "$results" | while read -r line; do
                    echo "  $line"
                done
                echo ""
            fi
        done
    fi
}

# === DNS PROPAGATION ===
cmd_dns_propagation() {
    local domain="$1"
    
    echo "=== DNS Propagation: $domain ==="
    echo ""
    
    local servers=(
        "8.8.8.8:Google"
        "1.1.1.1:Cloudflare"
        "9.9.9.9:Quad9"
        "208.67.222.222:OpenDNS"
        "8.26.56.26:Comodo"
    )
    
    printf "%-15s %-12s %s\n" "DNS Server" "Provider" "Result"
    printf "%-15s %-12s %s\n" "----------" "--------" "------"
    
    for entry in "${servers[@]}"; do
        local server="${entry%%:*}"
        local name="${entry##*:}"
        local result
        result=$(dig +short @"$server" "$domain" A 2>/dev/null | head -1)
        [ -z "$result" ] && result="(no result)"
        printf "%-15s %-12s %s\n" "$server" "$name" "$result"
    done
}

# === REVERSE DNS ===
cmd_rdns() {
    local ip="$1"
    echo "=== Reverse DNS: $ip ==="
    echo ""
    dig +short -x "$ip" 2>/dev/null || echo "(no PTR record)"
}

# === TRACEROUTE ===
cmd_trace() {
    local host="$1"
    echo "=== Route Trace: $host ==="
    echo ""
    
    if command -v traceroute &>/dev/null; then
        traceroute -m 20 -w 2 "$host" 2>/dev/null
    elif command -v mtr &>/dev/null; then
        mtr --report --report-cycles 3 "$host" 2>/dev/null
    else
        echo "❌ Neither traceroute nor mtr installed. Run: bash scripts/install.sh"
    fi
}

# === MTR ===
cmd_mtr() {
    local host="$1"; shift
    local count="$MTR_COUNT"
    local extra=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --count) count="$2"; shift 2 ;;
            --no-dns) extra="$extra --no-dns"; shift ;;
            *) shift ;;
        esac
    done
    
    echo "=== MTR Report: $host (${count} packets) ==="
    echo ""
    
    if ! command -v mtr &>/dev/null; then
        echo "❌ mtr not installed. Run: bash scripts/install.sh"
        return 1
    fi
    
    mtr --report --report-cycles "$count" $extra "$host" 2>/dev/null
}

# === PING ===
cmd_ping() {
    local host="$1"; shift
    local count="$PING_COUNT"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --count) count="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    echo "=== Ping: $host (${count} packets) ==="
    echo ""
    ping -c "$count" -W "$TIMEOUT" "$host" 2>/dev/null | tail -3
}

# === SPEED TEST ===
cmd_speedtest() {
    local url=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --url) url="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    [ -z "$url" ] && url="https://speed.cloudflare.com/__down?bytes=$SPEEDTEST_BYTES"
    
    echo "=== Speed Test ==="
    echo "[$(timestamp)]"
    echo ""
    
    local size_mb=$(echo "scale=1; $SPEEDTEST_BYTES/1048576" | bc 2>/dev/null || echo "?")
    echo "Downloading ${size_mb}MB test file..."
    
    local start=$(date +%s%3N 2>/dev/null || date +%s)
    curl -sS -o /dev/null -w "Speed: %{speed_download} bytes/sec\nTime: %{time_total}s\n" "$url" 2>/dev/null
    local end=$(date +%s%3N 2>/dev/null || date +%s)
    
    local elapsed_ms=$((end - start))
    if [ $elapsed_ms -gt 0 ] && [ $SPEEDTEST_BYTES -gt 0 ]; then
        local mbps=$(echo "scale=1; $SPEEDTEST_BYTES * 8 / $elapsed_ms / 1000" | bc 2>/dev/null || echo "?")
        echo ""
        echo "Download: ${mbps} Mbps"
    fi
}

# === SSL CHECK ===
cmd_ssl() {
    local hosts=("$@")
    
    for host in "${hosts[@]}"; do
        echo "=== SSL Certificate: $host ==="
        echo ""
        
        local cert_info
        cert_info=$(echo | openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null)
        
        if [ $? -ne 0 ] && [ -z "$cert_info" ]; then
            echo "❌ Could not connect to $host:443"
            echo ""
            continue
        fi
        
        # Subject
        local subject
        subject=$(echo "$cert_info" | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//')
        echo "Subject:    $subject"
        
        # Issuer
        local issuer
        issuer=$(echo "$cert_info" | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=//')
        echo "Issuer:     $issuer"
        
        # Dates
        local not_before not_after
        not_before=$(echo "$cert_info" | openssl x509 -noout -startdate 2>/dev/null | sed 's/notBefore=//')
        not_after=$(echo "$cert_info" | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//')
        echo "Valid From: $not_before"
        echo "Valid Until: $not_after"
        
        # Days remaining
        local expiry_epoch
        expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
        local now_epoch
        now_epoch=$(date +%s)
        if [ "$expiry_epoch" -gt 0 ]; then
            local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
            if [ $days_left -gt 30 ]; then
                echo "Days Left:  $days_left ✅"
            elif [ $days_left -gt 7 ]; then
                echo "Days Left:  $days_left ⚠️  (expiring soon)"
            else
                echo "Days Left:  $days_left 🚨 (CRITICAL)"
            fi
        fi
        
        # Protocol and cipher
        local protocol cipher
        protocol=$(echo "$cert_info" | grep "Protocol" | head -1 | awk '{print $NF}')
        cipher=$(echo "$cert_info" | grep "Cipher" | head -1 | awk '{print $NF}')
        [ -n "$protocol" ] && echo "Protocol:   $protocol"
        [ -n "$cipher" ] && echo "Cipher:     $cipher"
        
        echo ""
    done
}

# === FULL REPORT ===
cmd_report() {
    local host="$1"; shift
    local output=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output) output="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    {
        echo "========================================"
        echo "  Network Diagnostic Report"
        echo "  Host: $host"
        echo "  Date: $(timestamp)"
        echo "========================================"
        echo ""
        
        cmd_ping "$host"
        echo ""
        echo "----------------------------------------"
        echo ""
        cmd_dns "$host"
        echo "----------------------------------------"
        echo ""
        cmd_ssl "$host"
        echo "----------------------------------------"
        echo ""
        cmd_portscan "$host"
        echo ""
        echo "----------------------------------------"
        echo ""
        cmd_trace "$host"
        echo ""
        echo "========================================"
        echo "  Report complete: $(timestamp)"
        echo "========================================"
    } | if [ -n "$output" ]; then
        tee "$output"
        echo ""
        echo "Report saved to: $output"
    else
        cat
    fi
}

# === LOCAL: INTERFACES ===
cmd_interfaces() {
    echo "=== Network Interfaces ==="
    echo ""
    ip -brief addr 2>/dev/null || ifconfig 2>/dev/null || echo "❌ Cannot list interfaces"
}

# === LOCAL: LISTENING PORTS ===
cmd_listening() {
    echo "=== Listening Ports ==="
    echo ""
    if command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null
    elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null
    else
        echo "❌ Neither ss nor netstat available"
    fi
}

# === LOCAL: CONNECTIONS ===
cmd_connections() {
    echo "=== Active Connections ==="
    echo ""
    if command -v ss &>/dev/null; then
        ss -tnp 2>/dev/null | head -30
    elif command -v netstat &>/dev/null; then
        netstat -tnp 2>/dev/null | head -30
    else
        echo "❌ Neither ss nor netstat available"
    fi
    echo ""
    echo "(Showing top 30 connections)"
}

# === PUBLIC IP ===
cmd_myip() {
    echo "=== Public IP ==="
    echo ""
    local ip
    ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)
    if [ -n "$ip" ]; then
        echo "IPv4: $ip"
        # Get location info
        local geo
        geo=$(curl -s --max-time 5 "https://ipinfo.io/$ip/json" 2>/dev/null)
        if [ -n "$geo" ] && command -v jq &>/dev/null; then
            echo "City: $(echo "$geo" | jq -r '.city // "unknown"')"
            echo "Region: $(echo "$geo" | jq -r '.region // "unknown"')"
            echo "Country: $(echo "$geo" | jq -r '.country // "unknown"')"
            echo "Org: $(echo "$geo" | jq -r '.org // "unknown"')"
        fi
    else
        echo "❌ Could not determine public IP"
    fi
    
    local ip6
    ip6=$(curl -6 -s --max-time 5 https://api64.ipify.org 2>/dev/null)
    [ -n "$ip6" ] && [ "$ip6" != "$ip" ] && echo "IPv6: $ip6"
}

# === WHOIS ===
cmd_whois() {
    local domain="$1"
    echo "=== WHOIS: $domain ==="
    echo ""
    
    if ! command -v whois &>/dev/null; then
        echo "❌ whois not installed. Run: bash scripts/install.sh"
        return 1
    fi
    
    whois "$domain" 2>/dev/null | grep -iE "(domain|registrar|creation|expir|name server|status)" | head -20
}

# === MAIN DISPATCH ===
[ $# -eq 0 ] && usage

COMMAND="$1"; shift

case "$COMMAND" in
    portscan)       [ $# -eq 0 ] && { echo "Usage: netdiag.sh portscan <host>"; exit 1; }; cmd_portscan "$@" ;;
    dns)            [ $# -eq 0 ] && { echo "Usage: netdiag.sh dns <domain>"; exit 1; }; cmd_dns "$@" ;;
    dns-propagation) [ $# -eq 0 ] && { echo "Usage: netdiag.sh dns-propagation <domain>"; exit 1; }; cmd_dns_propagation "$@" ;;
    rdns)           [ $# -eq 0 ] && { echo "Usage: netdiag.sh rdns <ip>"; exit 1; }; cmd_rdns "$@" ;;
    trace)          [ $# -eq 0 ] && { echo "Usage: netdiag.sh trace <host>"; exit 1; }; cmd_trace "$@" ;;
    mtr)            [ $# -eq 0 ] && { echo "Usage: netdiag.sh mtr <host>"; exit 1; }; cmd_mtr "$@" ;;
    ping)           [ $# -eq 0 ] && { echo "Usage: netdiag.sh ping <host>"; exit 1; }; cmd_ping "$@" ;;
    speedtest)      cmd_speedtest "$@" ;;
    ssl)            [ $# -eq 0 ] && { echo "Usage: netdiag.sh ssl <host>"; exit 1; }; cmd_ssl "$@" ;;
    report)         [ $# -eq 0 ] && { echo "Usage: netdiag.sh report <host>"; exit 1; }; cmd_report "$@" ;;
    interfaces)     cmd_interfaces ;;
    listening)      cmd_listening ;;
    connections)    cmd_connections ;;
    myip)           cmd_myip ;;
    whois)          [ $# -eq 0 ] && { echo "Usage: netdiag.sh whois <domain>"; exit 1; }; cmd_whois "$@" ;;
    help|--help|-h) usage ;;
    *)              echo "Unknown command: $COMMAND"; usage ;;
esac
