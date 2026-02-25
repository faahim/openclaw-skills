#!/bin/bash
# GoAccess Web Log Analyzer — Main Analysis Script
# Parse web server logs into HTML dashboards, terminal reports, JSON, or CSV

set -euo pipefail

# Defaults
LOG_FILE=""
LOG_FORMAT=""
DATE_FORMAT=""
TIME_FORMAT=""
OUTPUT_HTML=""
OUTPUT_JSON=""
OUTPUT_CSV=""
TERMINAL=false
REALTIME=false
PORT=7890
WS_URL=""
STDIN=false
GEOIP=false
EXCLUDE_IP=""
IGNORE_CRAWLERS=false
DATE_RANGE=""
EXTRA_ARGS=()

# Predefined formats
declare -A FORMATS=(
    ["COMBINED"]="COMBINED"
    ["COMMON"]="COMMON"
    ["VCOMBINED"]="VCOMBINED"
    ["CLOUDFRONT"]="CLOUDFRONT"
    ["SQUID"]="SQUID"
    ["W3C"]="W3C"
    ["CADDY"]="CADDY"
)

usage() {
    cat <<EOF
GoAccess Web Log Analyzer

Usage: bash analyze.sh [OPTIONS]

Required:
  --log <path>          Path to access log file
  --stdin               Read log from stdin (pipe)
  --format <name>       Log format: COMBINED, COMMON, VCOMBINED, CLOUDFRONT, SQUID, W3C, CADDY

Output (at least one required):
  --html <path>         Generate HTML dashboard
  --json <path>         Export JSON data
  --csv <path>          Export CSV data
  --terminal            Display in terminal (ncurses)
  --realtime            Start real-time HTML WebSocket server

Options:
  --port <port>         WebSocket port for realtime mode (default: 7890)
  --ws-url <url>        WebSocket URL for realtime mode
  --log-format <fmt>    Custom log format string
  --date-format <fmt>   Custom date format
  --time-format <fmt>   Custom time format
  --geoip               Enable GeoIP lookups (requires GeoLite2 DB)
  --exclude-ip <range>  Exclude IP range (e.g., 10.0.0.0-10.255.255.255)
  --ignore-crawlers     Exclude known bots/crawlers
  --date-range <range>  Filter by date range (DD/Mon/YYYY-DD/Mon/YYYY)

Examples:
  bash analyze.sh --log /var/log/nginx/access.log --format COMBINED --html /tmp/report.html
  bash analyze.sh --log /var/log/nginx/access.log --format COMBINED --terminal
  bash analyze.sh --log /var/log/nginx/access.log --format COMBINED --realtime --port 7890
  cat access.log | bash analyze.sh --stdin --format COMBINED --json /tmp/stats.json
EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --log) LOG_FILE="$2"; shift 2 ;;
        --stdin) STDIN=true; shift ;;
        --format) LOG_FORMAT="$2"; shift 2 ;;
        --log-format) DATE_FORMAT="custom"; EXTRA_ARGS+=(--log-format "$2"); shift 2 ;;
        --date-format) EXTRA_ARGS+=(--date-format "$2"); shift 2 ;;
        --time-format) EXTRA_ARGS+=(--time-format "$2"); shift 2 ;;
        --html) OUTPUT_HTML="$2"; shift 2 ;;
        --json) OUTPUT_JSON="$2"; shift 2 ;;
        --csv) OUTPUT_CSV="$2"; shift 2 ;;
        --terminal) TERMINAL=true; shift ;;
        --realtime) REALTIME=true; shift ;;
        --port) PORT="$2"; shift 2 ;;
        --ws-url) WS_URL="$2"; shift 2 ;;
        --geoip) GEOIP=true; shift ;;
        --exclude-ip) EXCLUDE_IP="$2"; shift 2 ;;
        --ignore-crawlers) IGNORE_CRAWLERS=true; shift ;;
        --date-range) DATE_RANGE="$2"; shift 2 ;;
        --help|-h) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Validate
if [[ "$STDIN" == false && -z "$LOG_FILE" ]]; then
    echo "❌ Error: --log <path> or --stdin required"
    usage
fi

if [[ "$STDIN" == false && ! -f "$LOG_FILE" ]]; then
    echo "❌ Error: Log file not found: $LOG_FILE"
    exit 1
fi

if [[ -z "$OUTPUT_HTML" && -z "$OUTPUT_JSON" && -z "$OUTPUT_CSV" && "$TERMINAL" == false && "$REALTIME" == false ]]; then
    echo "❌ Error: Specify output: --html, --json, --csv, --terminal, or --realtime"
    usage
fi

# Check goaccess is installed
if ! command -v goaccess &>/dev/null; then
    echo "❌ GoAccess not installed. Run: bash scripts/install.sh"
    exit 1
fi

# Build command
CMD=(goaccess)

# Input
if [[ "$STDIN" == true ]]; then
    CMD+=(-)
else
    CMD+=("$LOG_FILE")
fi

# Log format
if [[ -n "$LOG_FORMAT" && -n "${FORMATS[$LOG_FORMAT]:-}" ]]; then
    CMD+=(--log-format "${FORMATS[$LOG_FORMAT]}")
fi

# Output
if [[ -n "$OUTPUT_HTML" ]]; then
    mkdir -p "$(dirname "$OUTPUT_HTML")"
    CMD+=(-o "$OUTPUT_HTML")
fi

if [[ -n "$OUTPUT_JSON" ]]; then
    mkdir -p "$(dirname "$OUTPUT_JSON")"
    CMD+=(-o "$OUTPUT_JSON")
fi

if [[ -n "$OUTPUT_CSV" ]]; then
    mkdir -p "$(dirname "$OUTPUT_CSV")"
    CMD+=(-o "$OUTPUT_CSV")
fi

# Real-time mode
if [[ "$REALTIME" == true ]]; then
    CMD+=(--real-time-html --port "$PORT")
    if [[ -n "$WS_URL" ]]; then
        CMD+=(--ws-url="$WS_URL")
    fi
    if [[ -z "$OUTPUT_HTML" ]]; then
        OUTPUT_HTML="/tmp/goaccess-realtime.html"
        CMD+=(-o "$OUTPUT_HTML")
    fi
fi

# GeoIP
if [[ "$GEOIP" == true ]]; then
    GEOIP_DB=""
    for path in /usr/share/GeoIP/GeoLite2-City.mmdb /usr/local/share/GeoIP/GeoLite2-City.mmdb ~/.goaccess/GeoLite2-City.mmdb /var/lib/GeoIP/GeoLite2-City.mmdb; do
        if [[ -f "$path" ]]; then
            GEOIP_DB="$path"
            break
        fi
    done
    if [[ -n "$GEOIP_DB" ]]; then
        CMD+=(--geoip-database "$GEOIP_DB")
    else
        echo "⚠️  GeoIP database not found. Run: bash scripts/install-geoip.sh"
        echo "   Continuing without GeoIP..."
    fi
fi

# Filters
if [[ -n "$EXCLUDE_IP" ]]; then
    CMD+=(--exclude-ip "$EXCLUDE_IP")
fi

if [[ "$IGNORE_CRAWLERS" == true ]]; then
    CMD+=(--ignore-crawlers)
fi

# Extra args
CMD+=("${EXTRA_ARGS[@]}")

# Execute
echo "🔍 Analyzing logs..."

if [[ "$STDIN" == true ]]; then
    cat | "${CMD[@]}"
elif [[ "$TERMINAL" == true ]]; then
    "${CMD[@]}"
else
    "${CMD[@]}"
fi

# Report results
if [[ -n "$OUTPUT_HTML" && -f "$OUTPUT_HTML" ]]; then
    SIZE=$(du -h "$OUTPUT_HTML" | cut -f1)
    echo "✅ HTML report generated: $OUTPUT_HTML ($SIZE)"
    if [[ "$REALTIME" == true ]]; then
        echo "🔴 Real-time dashboard running on port $PORT"
        echo "   Open: http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):$PORT"
    fi
fi

if [[ -n "$OUTPUT_JSON" && -f "$OUTPUT_JSON" ]]; then
    echo "✅ JSON export: $OUTPUT_JSON"
fi

if [[ -n "$OUTPUT_CSV" && -f "$OUTPUT_CSV" ]]; then
    echo "✅ CSV export: $OUTPUT_CSV"
fi
