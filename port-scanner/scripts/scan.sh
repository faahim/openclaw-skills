#!/bin/bash
# Port Scanner & Security Auditor — Main scan script
# Requires: nmap, jq, bash 4+

set -euo pipefail

# ── Defaults ──
TARGET=""
TARGETS_FILE=""
MODE="quick"
PORTS=""
OUTPUT=""
FORMAT="text"
ALERT=""
NMAP_ARGS=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="$SCRIPT_DIR/security-rules.json"

# ── Parse Arguments ──
while [[ $# -gt 0 ]]; do
  case $1 in
    --target) TARGET="$2"; shift 2 ;;
    --targets-file) TARGETS_FILE="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --ports) PORTS="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --alert) ALERT="$2"; shift 2 ;;
    --nmap-args) NMAP_ARGS="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: scan.sh --target <host|CIDR> [options]"
      echo ""
      echo "Options:"
      echo "  --target <host>       Target host, IP, or CIDR range"
      echo "  --targets-file <file> File with one target per line"
      echo "  --mode <mode>         quick|full|discover (default: quick)"
      echo "  --ports <ports>       Comma-separated port list (e.g. 22,80,443)"
      echo "  --output <file>       Save JSON report to file"
      echo "  --format <fmt>        text|json (default: text)"
      echo "  --alert <method>      telegram|email (send alert on findings)"
      echo "  --nmap-args <args>    Custom nmap arguments (advanced)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Validate ──
if [[ -z "$TARGET" && -z "$TARGETS_FILE" ]]; then
  echo "❌ Error: --target or --targets-file required"
  echo "Run: scan.sh --help"
  exit 1
fi

if ! command -v nmap &>/dev/null; then
  echo "❌ Error: nmap not installed"
  echo "Install: sudo apt-get install -y nmap  (or: brew install nmap)"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "⚠️  Warning: jq not installed — JSON output disabled"
  echo "Install: sudo apt-get install -y jq  (or: brew install jq)"
  FORMAT="text"
fi

# ── Load Security Rules ──
CRITICAL_PORTS="3306,5432,6379,27017,9200,11211"
WARN_PORTS="22,21,23,25,445,3389"
EXPECTED_OPEN="80,443"
MAX_OPEN=20

if [[ -f "$RULES_FILE" ]]; then
  CRITICAL_PORTS=$(jq -r '.critical_ports | join(",")' "$RULES_FILE" 2>/dev/null || echo "$CRITICAL_PORTS")
  WARN_PORTS=$(jq -r '.warn_ports | join(",")' "$RULES_FILE" 2>/dev/null || echo "$WARN_PORTS")
  EXPECTED_OPEN=$(jq -r '.expected_open | join(",")' "$RULES_FILE" 2>/dev/null || echo "$EXPECTED_OPEN")
  MAX_OPEN=$(jq -r '.max_open_ports // 20' "$RULES_FILE" 2>/dev/null || echo "$MAX_OPEN")
fi

# ── Build nmap Command ──
build_nmap_cmd() {
  local target="$1"
  local cmd="nmap"

  if [[ -n "$NMAP_ARGS" ]]; then
    cmd="$cmd $NMAP_ARGS"
  else
    case "$MODE" in
      quick)
        cmd="$cmd -sT -T4 --top-ports 1000 -sV --version-intensity 2"
        ;;
      full)
        cmd="$cmd -sT -T4 -p- -sV -sC --version-intensity 5 -O"
        ;;
      discover)
        cmd="$cmd -sn -T4"
        ;;
      *)
        echo "❌ Unknown mode: $MODE (use: quick|full|discover)"
        exit 1
        ;;
    esac
  fi

  if [[ -n "$PORTS" ]]; then
    cmd="$cmd -p $PORTS"
  fi

  # Always output XML for parsing
  cmd="$cmd -oX - $target"
  echo "$cmd"
}

# ── Parse nmap XML Output ──
parse_xml_to_json() {
  local xml="$1"
  local target="$2"

  # Extract host and port info using grep/sed (no python dependency)
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local ports_json="[]"
  local os_info="unknown"
  local host_state="unknown"

  # Check host state
  if echo "$xml" | grep -q 'state="up"'; then
    host_state="up"
  elif echo "$xml" | grep -q 'state="down"'; then
    host_state="down"
  fi

  # Extract ports
  ports_json=$(echo "$xml" | grep -oP '<port protocol="[^"]*" portid="[^"]*">.*?</port>' | while read -r line; do
    local proto port state service version
    proto=$(echo "$line" | grep -oP 'protocol="\K[^"]*')
    port=$(echo "$line" | grep -oP 'portid="\K[^"]*')
    state=$(echo "$line" | grep -oP 'state="\K[^"]*' | head -1)
    service=$(echo "$line" | grep -oP 'name="\K[^"]*' | head -1)
    version=$(echo "$line" | grep -oP 'product="\K[^"]*' | head -1)
    ver_num=$(echo "$line" | grep -oP 'version="\K[^"]*' | head -1)
    [[ -n "$ver_num" ]] && version="$version $ver_num"

    echo "{\"port\":$port,\"protocol\":\"$proto\",\"state\":\"$state\",\"service\":\"${service:-unknown}\",\"version\":\"${version:-}\"}"
  done | jq -s '.' 2>/dev/null || echo "[]")

  # Extract OS (if available)
  os_info=$(echo "$xml" | grep -oP 'name="\K[^"]*' | head -1 || echo "unknown")

  # Build JSON report
  cat <<EOF
{
  "target": "$target",
  "scan_time": "$timestamp",
  "mode": "$MODE",
  "host_state": "$host_state",
  "ports": $ports_json,
  "os_guess": "$os_info",
  "summary": {
    "total_open": $(echo "$ports_json" | jq '[.[] | select(.state == "open")] | length' 2>/dev/null || echo 0),
    "total_closed": $(echo "$ports_json" | jq '[.[] | select(.state == "closed")] | length' 2>/dev/null || echo 0),
    "total_filtered": $(echo "$ports_json" | jq '[.[] | select(.state == "filtered")] | length' 2>/dev/null || echo 0)
  }
}
EOF
}

# ── Security Analysis ──
analyze_security() {
  local report_json="$1"
  local findings="[]"
  local critical=0
  local warnings=0

  # Check critical ports (databases open to internet)
  IFS=',' read -ra CRIT_ARR <<< "$CRITICAL_PORTS"
  for cp in "${CRIT_ARR[@]}"; do
    local is_open
    is_open=$(echo "$report_json" | jq --argjson p "$cp" '[.ports[] | select(.port == $p and .state == "open")] | length' 2>/dev/null || echo 0)
    if [[ "$is_open" -gt 0 ]]; then
      local svc
      svc=$(echo "$report_json" | jq -r --argjson p "$cp" '.ports[] | select(.port == $p) | .service' 2>/dev/null || echo "unknown")
      findings=$(echo "$findings" | jq --arg msg "🔴 CRITICAL: Port $cp ($svc) is open — database/cache ports should not be public" --arg sev "critical" '. += [{"severity": $sev, "message": $msg}]')
      ((critical++))
    fi
  done

  # Check warning ports
  IFS=',' read -ra WARN_ARR <<< "$WARN_PORTS"
  for wp in "${WARN_ARR[@]}"; do
    # Skip if expected open
    if echo ",$EXPECTED_OPEN," | grep -q ",$wp,"; then
      continue
    fi
    local is_open
    is_open=$(echo "$report_json" | jq --argjson p "$wp" '[.ports[] | select(.port == $p and .state == "open")] | length' 2>/dev/null || echo 0)
    if [[ "$is_open" -gt 0 ]]; then
      local svc
      svc=$(echo "$report_json" | jq -r --argjson p "$wp" '.ports[] | select(.port == $p) | .service' 2>/dev/null || echo "unknown")
      findings=$(echo "$findings" | jq --arg msg "⚠️  WARNING: Port $wp ($svc) is open — consider restricting access" --arg sev "warning" '. += [{"severity": $sev, "message": $msg}]')
      ((warnings++))
    fi
  done

  # Check total open ports
  local total_open
  total_open=$(echo "$report_json" | jq '.summary.total_open' 2>/dev/null || echo 0)
  if [[ "$total_open" -gt "$MAX_OPEN" ]]; then
    findings=$(echo "$findings" | jq --arg msg "⚠️  WARNING: $total_open ports open (threshold: $MAX_OPEN) — review for unnecessary services" --arg sev "warning" '. += [{"severity": $sev, "message": $msg}]')
    ((warnings++))
  fi

  # Return analysis
  cat <<EOF
{
  "critical": $critical,
  "warnings": $warnings,
  "findings": $findings
}
EOF
}

# ── Display Report (Text) ──
display_report() {
  local report="$1"
  local analysis="$2"
  local target
  target=$(echo "$report" | jq -r '.target')

  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  printf "║  PORT SCAN REPORT — %-40s ║\n" "$target"
  echo "╠══════════════════════════════════════════════════════════════╣"

  local host_state
  host_state=$(echo "$report" | jq -r '.host_state')

  if [[ "$host_state" != "up" ]]; then
    echo "║  Host appears to be DOWN or not responding                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    return
  fi

  # Port table
  printf "║ %-8s %-8s %-14s %-28s ║\n" "PORT" "STATE" "SERVICE" "VERSION"
  echo "║──────────────────────────────────────────────────────────────║"

  echo "$report" | jq -r '.ports[] | select(.state == "open") | "\(.port)/\(.protocol) \(.state) \(.service) \(.version)"' 2>/dev/null | while read -r port state svc ver; do
    printf "║ %-8s %-8s %-14s %-28s ║\n" "$port" "$state" "$svc" "${ver:0:28}"
  done

  # Summary
  local total_open warnings critical
  total_open=$(echo "$report" | jq '.summary.total_open')
  critical=$(echo "$analysis" | jq '.critical')
  warnings=$(echo "$analysis" | jq '.warnings')

  echo "╠══════════════════════════════════════════════════════════════╣"
  printf "║ Open: %-4s │ Critical: %-4s │ Warnings: %-18s ║\n" "$total_open" "$critical" "$warnings"

  # Findings
  local finding_count
  finding_count=$(echo "$analysis" | jq '.findings | length')
  if [[ "$finding_count" -gt 0 ]]; then
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "$analysis" | jq -r '.findings[].message' | while read -r finding; do
      printf "║ %-60s ║\n" "${finding:0:60}"
    done
  fi

  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
}

# ── Send Alerts ──
send_alert() {
  local method="$1"
  local target="$2"
  local analysis="$3"

  local critical warnings
  critical=$(echo "$analysis" | jq '.critical')
  warnings=$(echo "$analysis" | jq '.warnings')

  if [[ "$critical" -eq 0 && "$warnings" -eq 0 ]]; then
    return  # No findings, no alert
  fi

  local msg="🔒 Port Scan Alert — $target\n"
  msg+="Critical: $critical | Warnings: $warnings\n\n"
  msg+=$(echo "$analysis" | jq -r '.findings[].message' | head -10)

  case "$method" in
    telegram)
      if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
          -d chat_id="$TELEGRAM_CHAT_ID" \
          -d text="$msg" \
          -d parse_mode="Markdown" > /dev/null 2>&1
        echo "📨 Alert sent to Telegram"
      else
        echo "⚠️  Telegram not configured (set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID)"
      fi
      ;;
    email)
      if [[ -n "${ALERT_EMAIL:-}" ]]; then
        echo -e "$msg" | mail -s "🔒 Port Scan Alert — $target" "$ALERT_EMAIL" 2>/dev/null
        echo "📨 Alert sent to $ALERT_EMAIL"
      else
        echo "⚠️  Email not configured (set ALERT_EMAIL)"
      fi
      ;;
  esac
}

# ── Main ──
main() {
  local targets=()

  if [[ -n "$TARGET" ]]; then
    targets+=("$TARGET")
  fi

  if [[ -n "$TARGETS_FILE" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      targets+=("$line")
    done < "$TARGETS_FILE"
  fi

  local all_reports="[]"

  for t in "${targets[@]}"; do
    echo "🔍 Scanning $t (mode: $MODE)..."

    # Run nmap
    local nmap_cmd
    nmap_cmd=$(build_nmap_cmd "$t")
    local xml_output
    xml_output=$(eval "$nmap_cmd" 2>/dev/null) || {
      echo "❌ nmap failed for $t — try with sudo for full scan capabilities"
      continue
    }

    # Handle discover mode differently
    if [[ "$MODE" == "discover" ]]; then
      echo ""
      echo "📡 Network Discovery — $t"
      echo "─────────────────────────────"
      echo "$xml_output" | grep -oP 'addr="\K[^"]*' | while read -r ip; do
        echo "  ✅ $ip — alive"
      done
      echo ""
      continue
    fi

    # Parse to JSON
    local report
    report=$(parse_xml_to_json "$xml_output" "$t")

    # Security analysis
    local analysis
    analysis=$(analyze_security "$report")

    # Merge analysis into report
    local full_report
    full_report=$(echo "$report" | jq --argjson a "$analysis" '. + {security: $a}')

    # Display
    if [[ "$FORMAT" == "text" ]]; then
      display_report "$report" "$analysis"
    fi

    # Collect
    all_reports=$(echo "$all_reports" | jq --argjson r "$full_report" '. += [$r]')

    # Alert
    if [[ -n "$ALERT" ]]; then
      send_alert "$ALERT" "$t" "$analysis"
    fi
  done

  # Save output
  if [[ -n "$OUTPUT" ]]; then
    local output_dir
    output_dir=$(dirname "$OUTPUT")
    mkdir -p "$output_dir" 2>/dev/null || true

    if [[ ${#targets[@]} -eq 1 ]]; then
      echo "$all_reports" | jq '.[0]' > "$OUTPUT"
    else
      echo "$all_reports" > "$OUTPUT"
    fi
    echo "💾 Report saved to $OUTPUT"
  fi

  # JSON to stdout
  if [[ "$FORMAT" == "json" && -z "$OUTPUT" ]]; then
    if [[ ${#targets[@]} -eq 1 ]]; then
      echo "$all_reports" | jq '.[0]'
    else
      echo "$all_reports" | jq '.'
    fi
  fi
}

main
