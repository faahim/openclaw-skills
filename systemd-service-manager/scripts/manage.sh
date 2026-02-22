#!/bin/bash
# Manage systemd services: start/stop/restart/enable/disable/remove/set-env/reload
set -euo pipefail

SERVICE="$1"
ACTION="${2:-status}"
shift 2 || true

SERVICE_FILE="/etc/systemd/system/${SERVICE}.service"

if [[ ! -f "$SERVICE_FILE" && "$ACTION" != "status" ]]; then
  echo "❌ Service '$SERVICE' not found at $SERVICE_FILE"
  exit 1
fi

case "$ACTION" in
  start)
    systemctl start "$SERVICE"
    echo "✅ $SERVICE started"
    ;;
  stop)
    systemctl stop "$SERVICE"
    echo "✅ $SERVICE stopped"
    ;;
  restart)
    systemctl restart "$SERVICE"
    echo "✅ $SERVICE restarted"
    ;;
  enable)
    systemctl enable "$SERVICE"
    echo "✅ $SERVICE enabled (starts on boot)"
    ;;
  disable)
    systemctl disable "$SERVICE"
    echo "✅ $SERVICE disabled (won't start on boot)"
    ;;
  reload)
    systemctl daemon-reload
    systemctl restart "$SERVICE"
    echo "✅ $SERVICE reloaded and restarted"
    ;;
  status)
    systemctl status "$SERVICE" --no-pager -l
    ;;
  remove)
    echo "Removing service '$SERVICE'..."
    systemctl stop "$SERVICE" 2>/dev/null || true
    systemctl disable "$SERVICE" 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    rm -f "/etc/systemd/system/${SERVICE}.timer"
    systemctl daemon-reload
    echo "✅ $SERVICE removed"
    ;;
  set-env)
    # Replace or add Environment lines
    # Remove existing Environment lines
    sed -i '/^Environment=/d' "$SERVICE_FILE"
    # Add new ones before [Install]
    for env in "$@"; do
      sed -i "/^\[Install\]/i Environment=\"$env\"" "$SERVICE_FILE"
    done
    systemctl daemon-reload
    systemctl restart "$SERVICE"
    echo "✅ Environment updated and service restarted"
    for env in "$@"; do echo "   $env"; done
    ;;
  edit)
    ${EDITOR:-nano} "$SERVICE_FILE"
    systemctl daemon-reload
    echo "✅ Run 'sudo systemctl restart $SERVICE' to apply changes"
    ;;
  *)
    echo "❌ Unknown action: $ACTION"
    echo "Available: start|stop|restart|enable|disable|reload|status|remove|set-env|edit"
    exit 1
    ;;
esac
