#!/bin/bash
# Control n8n service (start/stop/restart/logs)
set -euo pipefail

N8N_DIR="${N8N_DIR:-$HOME/.n8n}"
ACTION="${1:-status}"
LINES="${2:-50}"

cd "$N8N_DIR"

case "$ACTION" in
  start)
    echo "▶️ Starting n8n..."
    docker compose up -d
    echo "✅ Started"
    ;;
  stop)
    echo "⏹️ Stopping n8n..."
    docker compose down
    echo "✅ Stopped"
    ;;
  restart)
    echo "🔄 Restarting n8n..."
    docker compose restart
    echo "✅ Restarted"
    ;;
  logs)
    docker compose logs -f --tail "$LINES" n8n
    ;;
  *)
    echo "Usage: control.sh [start|stop|restart|logs] [lines]"
    exit 1
    ;;
esac
