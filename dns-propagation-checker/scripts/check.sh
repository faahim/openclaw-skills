#!/bin/bash
# DNS Propagation Checker — Check DNS records across 20+ global resolvers
# Usage: bash check.sh <domain> <record-type> [options]
#
# Options:
#   --expect <value>       Only mark ✅ if resolver returns this exact value
#   --json                 Output JSON instead of table
#   --csv                  Output CSV instead of table
#   --wait                 Keep checking until full propagation
#   --interval <seconds>   Check interval for --wait mode (default: 30)
#   --resolvers <file>     Custom resolvers file (IP|Name per line)
#   --show-auth            Show authoritative nameserver result first
#   --timeout <seconds>    Per-query timeout (default: 3)

set -euo pipefail

# --- Defaults ---
TIMEOUT="${DNS_TIMEOUT:-3}"
PARALLEL="${DNS_PARALLEL:-5}"
OUTPUT_FORMAT="table"
EXPECT=""
WAIT_MODE=false
WAIT_INTERVAL=30
SHOW_AUTH=false
CUSTOM_RESOLVERS=""

# --- Built-in Global Resolvers ---
DEFAULT_RESOLVERS=(
  "8.8.8.8|Google Public DNS"
  "8.8.4.4|Google Public DNS 2"
  "1.1.1.1|Cloudflare"
  "1.0.0.1|Cloudflare 2"
  "9.9.9.9|Quad9"
  "149.112.112.112|Quad9 Secondary"
  "208.67.222.222|OpenDNS"
  "208.67.220.220|OpenDNS Secondary"
  "156.154.70.1|Neustar UltraDNS"
  "156.154.71.1|Neustar Secondary"
  "185.228.168.9|CleanBrowsing"
  "185.228.169.9|CleanBrowsing 2"
  "76.76.2.0|Control D"
  "76.76.10.0|Control D 2"
  "94.140.14.14|AdGuard DNS"
  "94.140.15.15|AdGuard DNS 2"
  "77.88.8.8|Yandex DNS"
  "77.88.8.1|Yandex DNS 2"
  "180.76.76.76|Baidu DNS"
  "223.5.5.5|Alibaba DNS"
)

# --- Parse Arguments ---
DOMAIN="${1:-}"
RECORD_TYPE="${2:-A}"
shift 2 2>/dev/null || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expect) EXPECT="$2"; shift 2 ;;
    --json) OUTPUT_FORMAT="json"; shift ;;
    --csv) OUTPUT_FORMAT="csv"; shift ;;
    --wait) WAIT_MODE=true; shift ;;
    --interval) WAIT_INTERVAL="$2"; shift 2 ;;
    --resolvers) CUSTOM_RESOLVERS="$2"; shift 2 ;;
    --show-auth) SHOW_AUTH=true; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$DOMAIN" ]]; then
  echo "Usage: bash check.sh <domain> [record-type] [options]"
  echo ""
  echo "Record types: A, AAAA, CNAME, MX, TXT, NS, SOA, SRV, CAA, PTR"
  echo ""
  echo "Options:"
  echo "  --expect <value>       Match against expected value"
  echo "  --json                 JSON output"
  echo "  --csv                  CSV output"
  echo "  --wait                 Monitor until full propagation"
  echo "  --interval <seconds>   Wait interval (default: 30)"
  echo "  --resolvers <file>     Custom resolvers (IP|Name per line)"
  echo "  --show-auth            Show authoritative answer first"
  echo "  --timeout <seconds>    Query timeout (default: 3)"
  exit 1
fi

# Check dig is available
if ! command -v dig &>/dev/null; then
  echo "❌ 'dig' not found. Install it:"
  echo "   Ubuntu/Debian: sudo apt-get install -y dnsutils"
  echo "   RHEL/CentOS:   sudo yum install -y bind-utils"
  echo "   macOS:          already included"
  exit 1
fi

RECORD_TYPE=$(echo "$RECORD_TYPE" | tr '[:lower:]' '[:upper:]')

# --- Load Resolvers ---
RESOLVERS=()
if [[ -n "$CUSTOM_RESOLVERS" && -f "$CUSTOM_RESOLVERS" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    RESOLVERS+=("$line")
  done < "$CUSTOM_RESOLVERS"
else
  RESOLVERS=("${DEFAULT_RESOLVERS[@]}")
fi

# --- Get Authoritative Answer ---
get_auth_value() {
  local ns
  ns=$(dig +short NS "$DOMAIN" 2>/dev/null | head -1)
  if [[ -n "$ns" ]]; then
    dig +short +time="$TIMEOUT" "$RECORD_TYPE" "$DOMAIN" "@$ns" 2>/dev/null | sort | tr '\n' ',' | sed 's/,$//'
  fi
}

# --- Query Single Resolver ---
query_resolver() {
  local ip="$1"
  local name="$2"
  local start end elapsed value

  start=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)
  value=$(dig +short +time="$TIMEOUT" +tries=1 "$RECORD_TYPE" "$DOMAIN" "@$ip" 2>/dev/null | sort | tr '\n' ',' | sed 's/,$//')
  end=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)

  if [[ "$start" == "0" || "$end" == "0" ]]; then
    elapsed=0
  else
    elapsed=$((end - start))
  fi

  [[ -z "$value" ]] && value="(no response)"

  echo "${ip}|${name}|${value}|${elapsed}"
}

# --- Run Check ---
run_check() {
  local results=()
  local match_count=0
  local total=${#RESOLVERS[@]}
  local auth_value=""

  # Get authoritative value if no --expect and for comparison
  if [[ -z "$EXPECT" ]] || $SHOW_AUTH; then
    auth_value=$(get_auth_value)
  fi

  local compare_value="${EXPECT:-$auth_value}"

  # Query all resolvers
  local tmpdir
  tmpdir=$(mktemp -d)
  local pids=()
  local idx=0

  for entry in "${RESOLVERS[@]}"; do
    local ip="${entry%%|*}"
    local name="${entry##*|}"
    (
      result=$(query_resolver "$ip" "$name")
      echo "$result" > "$tmpdir/$idx"
    ) &
    pids+=($!)
    idx=$((idx + 1))

    # Throttle parallel queries
    if (( ${#pids[@]} >= PARALLEL )); then
      wait "${pids[0]}" 2>/dev/null || true
      pids=("${pids[@]:1}")
    fi
  done

  # Wait for remaining
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done

  # Collect results
  for ((i=0; i<total; i++)); do
    if [[ -f "$tmpdir/$i" ]]; then
      results+=("$(cat "$tmpdir/$i")")
    fi
  done
  rm -rf "$tmpdir"

  # Count matches
  for result in "${results[@]}"; do
    local val
    val=$(echo "$result" | cut -d'|' -f3)
    if [[ -n "$compare_value" && "$val" == "$compare_value" ]]; then
      match_count=$((match_count + 1))
    elif [[ -z "$compare_value" && "$val" != "(no response)" ]]; then
      match_count=$((match_count + 1))
    fi
  done

  local pct=0
  if (( total > 0 )); then
    pct=$((match_count * 100 / total))
  fi

  # --- Output ---
  case "$OUTPUT_FORMAT" in
    json)
      local json_results="["
      local first=true
      for result in "${results[@]}"; do
        local ip name val lat match_str
        ip=$(echo "$result" | cut -d'|' -f1)
        name=$(echo "$result" | cut -d'|' -f2)
        val=$(echo "$result" | cut -d'|' -f3)
        lat=$(echo "$result" | cut -d'|' -f4)
        if [[ -n "$compare_value" && "$val" == "$compare_value" ]]; then
          match_str="true"
        else
          match_str="false"
        fi
        $first || json_results+=","
        first=false
        json_results+="{\"resolver\":\"$ip\",\"name\":\"$name\",\"value\":\"$val\",\"match\":$match_str,\"latency_ms\":$lat}"
      done
      json_results+="]"
      echo "{\"domain\":\"$DOMAIN\",\"record_type\":\"$RECORD_TYPE\",\"expected\":\"${compare_value}\",\"checked_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"propagation_pct\":$pct,\"matched\":$match_count,\"total\":$total,\"results\":$json_results}"
      ;;

    csv)
      echo "resolver,name,value,match,latency_ms"
      for result in "${results[@]}"; do
        local ip name val lat match_str
        ip=$(echo "$result" | cut -d'|' -f1)
        name=$(echo "$result" | cut -d'|' -f2)
        val=$(echo "$result" | cut -d'|' -f3)
        lat=$(echo "$result" | cut -d'|' -f4)
        if [[ -n "$compare_value" && "$val" == "$compare_value" ]]; then
          match_str="true"
        else
          match_str="false"
        fi
        echo "\"$ip\",\"$name\",\"$val\",$match_str,$lat"
      done
      ;;

    table)
      echo ""
      echo "DNS Propagation Check: $DOMAIN ($RECORD_TYPE)"
      if [[ -n "$compare_value" ]]; then
        echo "Expected: $compare_value"
      else
        echo "Expected: (showing all results)"
      fi
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""

      if $SHOW_AUTH && [[ -n "$auth_value" ]]; then
        printf " 🔑  %-16s %-24s %-30s\n" "AUTHORITATIVE" "" "$auth_value"
        echo ""
      fi

      for result in "${results[@]}"; do
        local ip name val lat icon
        ip=$(echo "$result" | cut -d'|' -f1)
        name=$(echo "$result" | cut -d'|' -f2)
        val=$(echo "$result" | cut -d'|' -f3)
        lat=$(echo "$result" | cut -d'|' -f4)

        if [[ -n "$compare_value" && "$val" == "$compare_value" ]]; then
          icon="✅"
        elif [[ "$val" == "(no response)" ]]; then
          icon="⏱️"
        else
          icon="❌"
        fi

        printf " %s  %-16s %-24s %-30s %4sms\n" "$icon" "$ip" "$name" "$val" "$lat"
      done

      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      # Progress bar
      local bar_len=20
      local filled=$((pct * bar_len / 100))
      local empty=$((bar_len - filled))
      local bar=""
      for ((i=0; i<filled; i++)); do bar+="█"; done
      for ((i=0; i<empty; i++)); do bar+="░"; done

      printf "Propagation: %d/%d resolvers (%d%%) %s\n" "$match_count" "$total" "$pct" "$bar"
      echo ""
      ;;
  esac

  # Return propagation percentage for wait mode
  return $((100 - pct))
}

# --- Main ---
if $WAIT_MODE; then
  echo "Monitoring DNS propagation for $DOMAIN ($RECORD_TYPE)..."
  [[ -n "$EXPECT" ]] && echo "Waiting for: $EXPECT"
  echo "Checking every ${WAIT_INTERVAL}s (Ctrl+C to stop)"
  echo ""

  while true; do
    run_check || true
    ret=$?
    if [[ $ret -eq 0 ]]; then
      echo "🎉 Full propagation achieved!"
      exit 0
    fi
    echo "⏳ Waiting ${WAIT_INTERVAL}s before next check..."
    sleep "$WAIT_INTERVAL"
  done
else
  run_check
fi
