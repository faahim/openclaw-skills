#!/bin/bash
# Vikunja Management Script
set -euo pipefail

VIKUNJA_DIR="${VIKUNJA_DIR:-$HOME/vikunja}"
VIKUNJA_PORT="${VIKUNJA_PORT:-3456}"
BASE_URL="http://localhost:$VIKUNJA_PORT"

usage() {
    cat << EOF
Usage: $(basename "$0") <command> [options]

Commands:
  status          Show Vikunja container status
  logs [N]        Show last N log lines (default: 50)
  update          Pull latest image and restart
  stop            Stop Vikunja
  start           Start Vikunja
  restart         Restart Vikunja
  info            Show server info (version, etc.)
  login USER PASS Get API token
  projects TOKEN  List projects
  tasks TOKEN PID List tasks in project
  health          Quick health check

EOF
}

cmd_status() {
    docker ps --filter name=vikunja --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"
}

cmd_logs() {
    local lines="${1:-50}"
    docker logs vikunja --tail "$lines" 2>&1
}

cmd_update() {
    cd "$VIKUNJA_DIR"
    echo "📦 Pulling latest Vikunja..."
    docker compose pull
    docker compose up -d
    echo "✅ Updated and restarted."
}

cmd_stop() {
    cd "$VIKUNJA_DIR" && docker compose stop
    echo "⏹️  Vikunja stopped."
}

cmd_start() {
    cd "$VIKUNJA_DIR" && docker compose start
    echo "▶️  Vikunja started."
}

cmd_restart() {
    cd "$VIKUNJA_DIR" && docker compose restart
    echo "🔄 Vikunja restarted."
}

cmd_info() {
    curl -sf "$BASE_URL/api/v1/info" | jq . 2>/dev/null || echo "❌ Cannot reach Vikunja at $BASE_URL"
}

cmd_login() {
    local user="$1" pass="$2"
    curl -sf -X POST "$BASE_URL/api/v1/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$user\",\"password\":\"$pass\"}" | jq -r '.token'
}

cmd_projects() {
    local token="$1"
    curl -sf "$BASE_URL/api/v1/projects" \
        -H "Authorization: Bearer $token" | jq '.[] | {id, title, description}'
}

cmd_tasks() {
    local token="$1" pid="$2"
    curl -sf "$BASE_URL/api/v1/projects/$pid/tasks" \
        -H "Authorization: Bearer $token" | jq '.[] | {id, title, priority, done, due_date}'
}

cmd_health() {
    if curl -sf "$BASE_URL/api/v1/info" &>/dev/null; then
        echo "✅ Vikunja is healthy at $BASE_URL"
        curl -sf "$BASE_URL/api/v1/info" | jq '{version, frontend_url}' 2>/dev/null
    else
        echo "❌ Vikunja is not responding at $BASE_URL"
        cmd_status
        return 1
    fi
}

case "${1:-help}" in
    status)   cmd_status ;;
    logs)     cmd_logs "${2:-50}" ;;
    update)   cmd_update ;;
    stop)     cmd_stop ;;
    start)    cmd_start ;;
    restart)  cmd_restart ;;
    info)     cmd_info ;;
    login)    cmd_login "$2" "$3" ;;
    projects) cmd_projects "$2" ;;
    tasks)    cmd_tasks "$2" "$3" ;;
    health)   cmd_health ;;
    *)        usage ;;
esac
