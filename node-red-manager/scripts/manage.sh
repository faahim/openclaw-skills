#!/bin/bash
# Node-RED Manager — Service Management
set -euo pipefail

NR_DIR="${NODE_RED_DIR:-$HOME/.node-red}"
NR_PORT="${NODE_RED_PORT:-1880}"
NR_BIND="${NODE_RED_BIND:-0.0.0.0}"
ACTION="${1:-help}"

# Detect if running in Docker mode
is_docker() {
  [ -f "$NR_DIR/docker-compose.yml" ] && command -v docker &>/dev/null
}

# Detect if systemd service exists
has_service() {
  systemctl list-unit-files nodered.service &>/dev/null 2>&1
}

case "$ACTION" in
  start)
    if is_docker; then
      echo "🐳 Starting Node-RED (Docker)..."
      cd "$NR_DIR" && docker compose up -d
    elif has_service; then
      echo "🚀 Starting Node-RED service..."
      sudo systemctl start nodered
    else
      echo "🚀 Starting Node-RED..."
      nohup node-red --port "$NR_PORT" --userDir "$NR_DIR" > "$NR_DIR/node-red.log" 2>&1 &
      echo $! > "$NR_DIR/node-red.pid"
    fi
    sleep 2
    echo "✅ Node-RED started at http://localhost:${NR_PORT}"
    ;;

  stop)
    if is_docker; then
      echo "🛑 Stopping Node-RED (Docker)..."
      cd "$NR_DIR" && docker compose down
    elif has_service; then
      echo "🛑 Stopping Node-RED service..."
      sudo systemctl stop nodered
    elif [ -f "$NR_DIR/node-red.pid" ]; then
      kill "$(cat "$NR_DIR/node-red.pid")" 2>/dev/null || true
      rm -f "$NR_DIR/node-red.pid"
    fi
    echo "✅ Node-RED stopped"
    ;;

  restart)
    $0 stop
    sleep 1
    $0 start
    ;;

  enable)
    if is_docker; then
      echo "✅ Docker containers auto-restart via restart policy"
    elif has_service; then
      sudo systemctl enable nodered
      echo "✅ Node-RED enabled (starts on boot)"
    else
      echo "⚠️  No systemd service found. Run install.sh first."
    fi
    ;;

  disable)
    if has_service; then
      sudo systemctl disable nodered
      echo "✅ Node-RED disabled (won't start on boot)"
    fi
    ;;

  status)
    echo "📊 Node-RED Status"
    echo "=================="

    # Check if running
    if is_docker; then
      RUNNING=$(docker ps --filter name=node-red --format '{{.Status}}' 2>/dev/null)
      if [ -n "$RUNNING" ]; then
        echo "✅ Node-RED: running (Docker — $RUNNING)"
      else
        echo "❌ Node-RED: stopped (Docker)"
      fi
    elif has_service; then
      if systemctl is-active nodered &>/dev/null; then
        UPTIME=$(systemctl show nodered --property=ActiveEnterTimestamp --value 2>/dev/null || echo "unknown")
        echo "✅ Node-RED: running (systemd)"
        echo "   Started: $UPTIME"
      else
        echo "❌ Node-RED: stopped (systemd)"
      fi
    else
      if [ -f "$NR_DIR/node-red.pid" ] && kill -0 "$(cat "$NR_DIR/node-red.pid")" 2>/dev/null; then
        echo "✅ Node-RED: running (PID $(cat "$NR_DIR/node-red.pid"))"
      else
        echo "❌ Node-RED: stopped"
      fi
    fi

    # Port check
    if command -v ss &>/dev/null; then
      if ss -tlnp 2>/dev/null | grep -q ":${NR_PORT} "; then
        echo "✅ Port ${NR_PORT}: listening"
      else
        echo "❌ Port ${NR_PORT}: not listening"
      fi
    fi

    # Version
    if command -v node-red &>/dev/null; then
      echo "   Node-RED: $(node-red --help 2>&1 | head -1 | grep -oP 'v[\d.]+' || echo 'installed')"
    fi
    if command -v node &>/dev/null; then
      echo "   Node.js: $(node -v)"
    fi

    # User dir
    echo "   User dir: $NR_DIR"

    # Memory (if running via systemd)
    if has_service && systemctl is-active nodered &>/dev/null; then
      PID=$(systemctl show nodered --property=MainPID --value 2>/dev/null)
      if [ -n "$PID" ] && [ "$PID" != "0" ]; then
        RSS=$(ps -o rss= -p "$PID" 2>/dev/null | tr -d ' ')
        if [ -n "$RSS" ]; then
          echo "   Memory: $((RSS / 1024))MB RSS"
        fi
      fi
    fi

    # Flows info
    if [ -f "$NR_DIR/flows.json" ]; then
      TABS=$(grep -c '"type":"tab"' "$NR_DIR/flows.json" 2>/dev/null || echo 0)
      NODES=$(jq 'length' "$NR_DIR/flows.json" 2>/dev/null || echo "?")
      echo "   Flows: $TABS tabs, $NODES nodes"
    fi
    ;;

  version)
    echo "📦 Node-RED Version Check"
    if command -v node-red &>/dev/null; then
      CURRENT=$(npm list -g node-red --json 2>/dev/null | jq -r '.dependencies."node-red".version // "unknown"')
      echo "   Current: $CURRENT"
    fi
    LATEST=$(npm view node-red version 2>/dev/null || echo "unknown")
    echo "   Latest:  $LATEST"
    if [ "$CURRENT" != "$LATEST" ] && [ "$LATEST" != "unknown" ]; then
      echo "   ⬆️  Update available!"
    else
      echo "   ✅ Up to date"
    fi
    ;;

  update)
    echo "⬆️  Updating Node-RED..."
    if is_docker; then
      cd "$NR_DIR" && docker compose pull && docker compose up -d
    else
      npm install -g --unsafe-perm node-red
      $0 restart
    fi
    echo "✅ Node-RED updated"
    ;;

  logs)
    LINES="${2:-50}"
    if is_docker; then
      docker logs --tail "$LINES" node-red
    elif has_service; then
      journalctl -u nodered -n "$LINES" --no-pager
    elif [ -f "$NR_DIR/node-red.log" ]; then
      tail -n "$LINES" "$NR_DIR/node-red.log"
    else
      echo "No logs found"
    fi
    ;;

  enable-projects)
    SETTINGS="$NR_DIR/settings.js"
    if [ ! -f "$SETTINGS" ]; then
      echo "⚠️  Settings file not found. Start Node-RED once first."
      exit 1
    fi
    if grep -q "editorTheme" "$SETTINGS" && grep -q "projects" "$SETTINGS"; then
      echo "Projects may already be configured. Check $SETTINGS"
    else
      # Append projects config
      cat >> "$SETTINGS" <<'EOF'

// Projects feature (added by Node-RED Manager)
module.exports.editorTheme = module.exports.editorTheme || {};
module.exports.editorTheme.projects = { enabled: true };
EOF
      echo "✅ Projects enabled. Restart Node-RED to apply."
    fi
    ;;

  health)
    # Quick health check (exit code 0 = healthy)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:${NR_PORT}/" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
      echo "✅ Node-RED: healthy (HTTP $HTTP_CODE)"
      exit 0
    else
      echo "❌ Node-RED: unhealthy (HTTP $HTTP_CODE)"
      exit 1
    fi
    ;;

  help|*)
    echo "Node-RED Manager"
    echo ""
    echo "Usage: bash scripts/manage.sh <command>"
    echo ""
    echo "Commands:"
    echo "  start            Start Node-RED"
    echo "  stop             Stop Node-RED"
    echo "  restart          Restart Node-RED"
    echo "  enable           Enable auto-start on boot"
    echo "  disable          Disable auto-start"
    echo "  status           Show status, version, memory, flow info"
    echo "  version          Check current vs latest version"
    echo "  update           Update Node-RED to latest"
    echo "  logs [N]         Show last N log lines (default: 50)"
    echo "  enable-projects  Enable git-based Projects feature"
    echo "  health           Quick health check (for monitoring)"
    echo "  help             Show this help"
    ;;
esac
