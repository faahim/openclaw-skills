#!/usr/bin/env bash
# DNS Benchmark Tool — Test DNS resolvers for speed and reliability
# Usage: bash dns-benchmark.sh [OPTIONS]

set -euo pipefail

# ─── Defaults ───────────────────────────────────────────────────────
QUERIES=${DNS_BENCH_QUERIES:-20}
TIMEOUT=${DNS_BENCH_TIMEOUT:-3}
DOMAINS_STR=${DNS_BENCH_DOMAINS:-"google.com,github.com,cloudflare.com,amazon.com,wikipedia.org"}
OUTPUT_JSON=false
CHECK_DNSSEC=false
SHOW_HISTOGRAM=false
APPLY_WINNER=false
INCLUDE_CURRENT=false
PRIVACY_ONLY=false
CUSTOM_RESOLVERS=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Resolvers (name:ip) ───────────────────────────────────────────
declare -A RESOLVERS=(
  ["Cloudflare"]="1.1.1.1"
  ["Google"]="8.8.8.8"
  ["Quad9"]="9.9.9.9"
  ["OpenDNS"]="208.67.222.222"
  ["NextDNS"]="45.90.28.0"
  ["Comodo"]="8.26.56.26"
  ["CleanBrowsing"]="185.228.168.9"
  ["AdGuard"]="94.140.14.14"
  ["Mullvad"]="194.242.2.2"
  ["Control-D"]="76.76.2.0"
  ["LibreDNS"]="116.202.176.26"
  ["DNS.SB"]="185.222.222.222"
)

RESOLVER_ORDER=("Cloudflare" "Google" "Quad9" "OpenDNS" "NextDNS" "Comodo" "CleanBrowsing" "AdGuard" "Mullvad" "Control-D" "LibreDNS" "DNS.SB")

PRIVACY_RESOLVERS=("Cloudflare" "Quad9" "Mullvad" "NextDNS" "LibreDNS")

# ─── Parse Arguments ───────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --queries) QUERIES="$2"; shift 2 ;;
    --domains) DOMAINS_STR="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --json) OUTPUT_JSON=true; shift ;;
    --check-dnssec) CHECK_DNSSEC=true; shift ;;
    --histogram) SHOW_HISTOGRAM=true; shift ;;
    --apply) APPLY_WINNER=true; shift ;;
    --include-current) INCLUDE_CURRENT=true; shift ;;
    --privacy-only) PRIVACY_ONLY=true; shift ;;
    --resolvers) CUSTOM_RESOLVERS="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: dns-benchmark.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --queries N         Number of queries per resolver (default: 20)"
      echo "  --domains LIST      Comma-separated test domains"
      echo "  --timeout N         Timeout per query in seconds (default: 3)"
      echo "  --json              Output results as JSON"
      echo "  --check-dnssec      Test DNSSEC validation support"
      echo "  --histogram         Show latency distribution"
      echo "  --apply             Apply fastest resolver to system"
      echo "  --include-current   Include currently configured resolver"
      echo "  --privacy-only      Test only no-logging resolvers"
      echo "  --resolvers LIST    Comma-separated custom resolver IPs"
      echo "  --help              Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Dependency Check ──────────────────────────────────────────────
for cmd in dig bc awk sort; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Required command not found: $cmd"
    [[ "$cmd" == "dig" ]] && echo "   Install: sudo apt-get install dnsutils (Debian) or sudo dnf install bind-utils (RHEL)"
    [[ "$cmd" == "bc" ]] && echo "   Install: sudo apt-get install bc"
    exit 1
  fi
done

# ─── Setup ─────────────────────────────────────────────────────────
IFS=',' read -ra DOMAINS <<< "$DOMAINS_STR"

# Handle custom resolvers
if [[ -n "$CUSTOM_RESOLVERS" ]]; then
  declare -A RESOLVERS=()
  RESOLVER_ORDER=()
  IFS=',' read -ra CUSTOM_IPS <<< "$CUSTOM_RESOLVERS"
  for ip in "${CUSTOM_IPS[@]}"; do
    ip=$(echo "$ip" | xargs)  # trim whitespace
    RESOLVERS["$ip"]="$ip"
    RESOLVER_ORDER+=("$ip")
  done
fi

# Handle --include-current
if [[ "$INCLUDE_CURRENT" == true ]]; then
  CURRENT_DNS=$(grep -m1 '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' || echo "")
  if [[ -n "$CURRENT_DNS" && -z "${RESOLVERS[$CURRENT_DNS]+x}" ]]; then
    RESOLVERS["Current ($CURRENT_DNS)"]="$CURRENT_DNS"
    RESOLVER_ORDER=("Current ($CURRENT_DNS)" "${RESOLVER_ORDER[@]}")
  fi
fi

# Handle --privacy-only
if [[ "$PRIVACY_ONLY" == true ]]; then
  FILTERED=()
  for name in "${RESOLVER_ORDER[@]}"; do
    for priv in "${PRIVACY_RESOLVERS[@]}"; do
      if [[ "$name" == "$priv" ]]; then
        FILTERED+=("$name")
        break
      fi
    done
  done
  RESOLVER_ORDER=("${FILTERED[@]}")
fi

# ─── Functions ─────────────────────────────────────────────────────

# Query a DNS resolver and return latency in ms (or "timeout")
query_dns() {
  local resolver=$1
  local domain=$2
  local result
  result=$(dig @"$resolver" "$domain" A +noall +stats +time="$TIMEOUT" +tries=1 2>/dev/null | grep "Query time:" | awk '{print $4}')
  if [[ -z "$result" ]]; then
    echo "timeout"
  else
    echo "$result"
  fi
}

# Check DNSSEC support
check_dnssec() {
  local resolver=$1
  local result
  result=$(dig @"$resolver" dnssec-failed.org A +dnssec +time="$TIMEOUT" +tries=1 2>/dev/null | grep -c "SERVFAIL" || true)
  if [[ "$result" -ge 1 ]]; then
    echo "yes"
  else
    echo "no"
  fi
}

# Calculate statistics from an array of numbers
calc_stats() {
  local -a values=("$@")
  local count=${#values[@]}
  
  if [[ $count -eq 0 ]]; then
    echo "0 0 0 0 0"
    return
  fi
  
  # Sort values
  local sorted
  sorted=$(printf '%s\n' "${values[@]}" | sort -n)
  
  # Sum
  local sum=0
  for v in "${values[@]}"; do
    sum=$(echo "$sum + $v" | bc)
  done
  
  # Average
  local avg
  avg=$(echo "scale=1; $sum / $count" | bc)
  
  # Median
  local mid=$((count / 2))
  local median
  median=$(echo "$sorted" | sed -n "$((mid + 1))p")
  
  # Min/Max
  local min max
  min=$(echo "$sorted" | head -1)
  max=$(echo "$sorted" | tail -1)
  
  echo "$avg $median $min $max $count"
}

# ─── Main ──────────────────────────────────────────────────────────

TOTAL_RESOLVERS=${#RESOLVER_ORDER[@]}

if [[ "$OUTPUT_JSON" != true ]]; then
  echo ""
  echo "DNS Benchmark — Testing $TOTAL_RESOLVERS resolvers × $QUERIES queries each"
  echo "═══════════════════════════════════════════════════════════════════"
  echo ""
fi

# Results storage
declare -A RESULT_AVG RESULT_MED RESULT_MIN RESULT_MAX RESULT_LOSS RESULT_DNSSEC
declare -a ALL_LATENCIES

for name in "${RESOLVER_ORDER[@]}"; do
  ip="${RESOLVERS[$name]}"
  
  if [[ "$OUTPUT_JSON" != true ]]; then
    printf "  Testing %-20s (%s) ... " "$name" "$ip"
  fi
  
  # Run queries
  latencies=()
  timeouts=0
  total_run=0
  
  for ((q=1; q<=QUERIES; q++)); do
    # Cycle through domains
    domain_idx=$(( (q - 1) % ${#DOMAINS[@]} ))
    domain="${DOMAINS[$domain_idx]}"
    
    result=$(query_dns "$ip" "$domain")
    total_run=$((total_run + 1))
    
    if [[ "$result" == "timeout" ]]; then
      timeouts=$((timeouts + 1))
    else
      latencies+=("$result")
    fi
  done
  
  # Calculate stats
  loss_pct=0
  if [[ $total_run -gt 0 ]]; then
    loss_pct=$(echo "scale=1; $timeouts * 100 / $total_run" | bc)
  fi
  
  if [[ ${#latencies[@]} -gt 0 ]]; then
    read -r avg med min max cnt <<< "$(calc_stats "${latencies[@]}")"
  else
    avg="999.9"; med="999.9"; min="999.9"; max="999.9"
  fi
  
  # DNSSEC check
  dnssec="—"
  if [[ "$CHECK_DNSSEC" == true ]]; then
    dnssec_result=$(check_dnssec "$ip")
    if [[ "$dnssec_result" == "yes" ]]; then
      dnssec="✅"
    else
      dnssec="❌"
    fi
  fi
  
  RESULT_AVG[$name]="$avg"
  RESULT_MED[$name]="$med"
  RESULT_MIN[$name]="$min"
  RESULT_MAX[$name]="$max"
  RESULT_LOSS[$name]="$loss_pct"
  RESULT_DNSSEC[$name]="$dnssec"
  
  if [[ "$OUTPUT_JSON" != true ]]; then
    echo "avg=${avg}ms med=${med}ms loss=${loss_pct}%"
  fi
done

# ─── Sort by median latency ───────────────────────────────────────
SORTED_NAMES=()
while IFS= read -r line; do
  SORTED_NAMES+=("$line")
done < <(
  for name in "${RESOLVER_ORDER[@]}"; do
    echo "${RESULT_MED[$name]} $name"
  done | sort -n | awk '{$1=""; print substr($0,2)}'
)

# ─── Output ────────────────────────────────────────────────────────

if [[ "$OUTPUT_JSON" == true ]]; then
  echo "{"
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"queries_per_resolver\": $QUERIES,"
  echo "  \"results\": ["
  first=true
  rank=1
  for name in "${SORTED_NAMES[@]}"; do
    ip="${RESOLVERS[$name]}"
    [[ "$first" == true ]] && first=false || echo ","
    printf '    {"rank":%d,"name":"%s","ip":"%s","avg_ms":%s,"median_ms":%s,"min_ms":%s,"max_ms":%s,"loss_pct":%s,"dnssec":"%s"}' \
      "$rank" "$name" "$ip" "${RESULT_AVG[$name]}" "${RESULT_MED[$name]}" "${RESULT_MIN[$name]}" "${RESULT_MAX[$name]}" "${RESULT_LOSS[$name]}" "${RESULT_DNSSEC[$name]}"
    rank=$((rank + 1))
  done
  echo ""
  echo "  ]"
  echo "}"
else
  echo ""
  echo " Results (sorted by median latency):"
  echo " ─────────────────────────────────────────────────────────────────────────"
  printf " %-3s %-22s %-18s %7s %7s %7s %7s %6s" "#" "Resolver" "IP" "Avg" "Med" "Min" "Max" "Loss"
  [[ "$CHECK_DNSSEC" == true ]] && printf " %7s" "DNSSEC"
  echo ""
  echo " ─────────────────────────────────────────────────────────────────────────"
  
  rank=1
  for name in "${SORTED_NAMES[@]}"; do
    ip="${RESOLVERS[$name]}"
    printf " %-3d %-22s %-18s %5sms %5sms %5sms %5sms %5s%%" \
      "$rank" "$name" "$ip" \
      "${RESULT_AVG[$name]}" "${RESULT_MED[$name]}" \
      "${RESULT_MIN[$name]}" "${RESULT_MAX[$name]}" \
      "${RESULT_LOSS[$name]}"
    [[ "$CHECK_DNSSEC" == true ]] && printf "   %s" "${RESULT_DNSSEC[$name]}"
    echo ""
    rank=$((rank + 1))
  done
  
  echo ""
  WINNER="${SORTED_NAMES[0]}"
  WINNER_IP="${RESOLVERS[$WINNER]}"
  WINNER_MED="${RESULT_MED[$WINNER]}"
  echo " 🏆 Winner: $WINNER ($WINNER_IP) — ${WINNER_MED}ms median"
  echo ""
  
  # Histogram
  if [[ "$SHOW_HISTOGRAM" == true ]]; then
    echo " Latency Distribution:"
    echo " ─────────────────────"
    # Simplified: just show top 3
    for name in "${SORTED_NAMES[@]:0:3}"; do
      echo "  $name (${RESOLVERS[$name]}):"
      echo "    Avg: ${RESULT_AVG[$name]}ms | Med: ${RESULT_MED[$name]}ms | Range: ${RESULT_MIN[$name]}-${RESULT_MAX[$name]}ms"
    done
    echo ""
  fi
  
  # Apply winner
  if [[ "$APPLY_WINNER" == true ]]; then
    echo " Applying $WINNER ($WINNER_IP) as system DNS..."
    
    if command -v resolvectl &>/dev/null; then
      # systemd-resolved
      echo " Detected systemd-resolved"
      sudo resolvectl dns "$(ip route show default | awk '{print $5}' | head -1)" "$WINNER_IP"
      echo " ✅ Applied via resolvectl"
    elif [[ -f /etc/resolv.conf ]]; then
      # Direct resolv.conf
      echo " Updating /etc/resolv.conf..."
      sudo cp /etc/resolv.conf /etc/resolv.conf.bak
      echo "nameserver $WINNER_IP" | sudo tee /etc/resolv.conf > /dev/null
      echo " ✅ Applied. Backup saved to /etc/resolv.conf.bak"
    else
      echo " ❌ Could not detect DNS configuration method"
      echo "    Manually set DNS to: $WINNER_IP"
    fi
    echo ""
  fi
fi
