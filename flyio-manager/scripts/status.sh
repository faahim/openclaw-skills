#!/bin/bash
# Check Fly.io app status, logs, and machine health
# Usage: bash status.sh [--logs] [--machines] [--app NAME]

set -euo pipefail

PREFIX="[flyio-manager]"
ACTION="status"
APP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --logs) ACTION="logs"; shift ;;
        --machines) ACTION="machines"; shift ;;
        --app) APP="$2"; shift 2 ;;
        *) echo "$PREFIX Unknown option: $1"; exit 1 ;;
    esac
done

if ! command -v fly &>/dev/null; then
    echo "$PREFIX flyctl not found. Run: bash scripts/install.sh"
    exit 1
fi

APP_FLAG=""
[[ -n "$APP" ]] && APP_FLAG="--app $APP"

case "$ACTION" in
    status)
        echo "$PREFIX App Status:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fly status $APP_FLAG
        echo ""
        echo "$PREFIX IPs:"
        fly ips list $APP_FLAG 2>/dev/null || true
        echo ""
        echo "$PREFIX Recent releases:"
        fly releases $APP_FLAG --limit 5 2>/dev/null || true
        ;;
    logs)
        echo "$PREFIX Streaming logs (Ctrl+C to stop)..."
        fly logs $APP_FLAG
        ;;
    machines)
        echo "$PREFIX Machine details:"
        fly machine list $APP_FLAG
        echo ""
        echo "$PREFIX Scale config:"
        fly scale show $APP_FLAG 2>/dev/null || true
        ;;
esac
