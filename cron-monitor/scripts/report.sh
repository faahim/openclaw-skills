#!/bin/bash
# report.sh — Generate cron job uptime report from historical data
set -euo pipefail

DAYS=7
FORMAT="markdown"
DATA_DIR="${CRON_MONITOR_DATA:-$HOME/.cron-monitor/data}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

while [[ $# -gt 0 ]]; do
    case $1 in
        --days) DAYS="$2"; shift 2 ;;
        --format) FORMAT="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

HOURS=$((DAYS * 24))

# Use check-history to generate report
exec bash "$SCRIPT_DIR/check-history.sh" --hours "$HOURS" --format "$FORMAT"
