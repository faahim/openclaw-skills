#!/bin/bash
# Manage Gatus health dashboard
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/gatus}"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
GATUS_URL="${GATUS_URL:-http://localhost:8080}"

usage() {
  echo "Usage: manage.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  status      Check if Gatus is running"
  echo "  list        List monitored endpoints"
  echo "  results     Show recent check results"
  echo "  add         Add an endpoint to config"
  echo "  reload      Restart Gatus to apply config changes"
  echo "  validate    Validate config syntax"
  echo "  backup      Backup config and data"
  exit 0
}

cmd_status() {
  echo "🔍 Checking Gatus..."
  
  # Check Docker
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^gatus$'; then
    echo "✅ Gatus container is running"
    docker ps --filter name=gatus --format "   Image: {{.Image}}\n   Status: {{.Status}}\n   Ports: {{.Ports}}"
  elif systemctl is-active gatus &>/dev/null; then
    echo "✅ Gatus systemd service is active"
  elif pgrep -x gatus &>/dev/null; then
    echo "✅ Gatus process is running (PID: $(pgrep -x gatus))"
  else
    echo "❌ Gatus is not running"
    return 1
  fi

  # Check API
  if curl -sf "$GATUS_URL/api/v1/endpoints/statuses" &>/dev/null; then
    ENDPOINT_COUNT=$(curl -sf "$GATUS_URL/api/v1/endpoints/statuses" | jq 'length')
    echo "   Endpoints monitored: $ENDPOINT_COUNT"
    echo "   Dashboard: $GATUS_URL"
  fi
}

cmd_list() {
  if curl -sf "$GATUS_URL/api/v1/endpoints/statuses" &>/dev/null; then
    echo "📋 Monitored Endpoints:"
    curl -sf "$GATUS_URL/api/v1/endpoints/statuses" | jq -r '.[] | 
      "  " + (if .results[-1].success then "✅" else "❌" end) + " " + .name + 
      " (" + .group + ") — " + 
      (if .results[-1].success then "OK" else "FAILING" end) + 
      " [" + (.results[-1].duration | tostring) + "ms]"'
  else
    echo "⚠️  Cannot reach Gatus API at $GATUS_URL"
    echo "   Listing from config file instead:"
    if command -v yq &>/dev/null; then
      yq '.endpoints[].name' "$CONFIG_FILE"
    else
      grep '  - name:' "$CONFIG_FILE" | sed 's/.*name: /  /'
    fi
  fi
}

cmd_results() {
  local ENDPOINT="${1:-}"
  if [[ -z "$ENDPOINT" ]]; then
    curl -sf "$GATUS_URL/api/v1/endpoints/statuses" | jq -r '.[] | 
      "\n📊 " + .name + " (" + .group + ")",
      "   Last " + (.results | length | tostring) + " checks:",
      (.results[-5:] | reverse[] | 
        "   " + (if .success then "✅" else "❌" end) + 
        " " + .timestamp[:19] + " — " + (.duration | tostring) + "ms" +
        (if .errors | length > 0 then " — " + (.errors | join(", ")) else "" end)
      )'
  else
    curl -sf "$GATUS_URL/api/v1/endpoints/statuses" | jq -r --arg name "$ENDPOINT" '
      .[] | select(.name == $name) | 
      "📊 " + .name,
      (.results | reverse[] | 
        "  " + (if .success then "✅" else "❌" end) + 
        " " + .timestamp[:19] + " — " + (.duration | tostring) + "ms"
      )'
  fi
}

cmd_add() {
  local NAME="" URL="" INTERVAL="5m" CONDITION='[STATUS] == 200' GROUP="default"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) NAME="$2"; shift 2 ;;
      --url) URL="$2"; shift 2 ;;
      --interval) INTERVAL="$2"; shift 2 ;;
      --condition) CONDITION="$2"; shift 2 ;;
      --group) GROUP="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$NAME" || -z "$URL" ]]; then
    echo "Usage: manage.sh add --name NAME --url URL [--interval 5m] [--group default] [--condition '[STATUS] == 200']"
    exit 1
  fi

  cat >> "$CONFIG_FILE" << EOF

  - name: $NAME
    group: $GROUP
    url: "$URL"
    interval: $INTERVAL
    conditions:
      - "$CONDITION"
EOF

  echo "✅ Added endpoint '$NAME' to config"
  echo "   Run 'manage.sh reload' to apply changes"
}

cmd_reload() {
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^gatus$'; then
    docker restart gatus
    echo "✅ Gatus container restarted"
  elif systemctl is-active gatus &>/dev/null; then
    sudo systemctl restart gatus
    echo "✅ Gatus service restarted"
  else
    echo "⚠️  Gatus not found as Docker container or systemd service"
    echo "   Restart it manually"
  fi
}

cmd_validate() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config not found at $CONFIG_FILE"
    exit 1
  fi
  
  # Basic YAML validation
  if command -v yq &>/dev/null; then
    if yq '.' "$CONFIG_FILE" > /dev/null 2>&1; then
      echo "✅ Config YAML is valid"
      ENDPOINTS=$(yq '.endpoints | length' "$CONFIG_FILE")
      echo "   Endpoints defined: $ENDPOINTS"
    else
      echo "❌ Config YAML has syntax errors"
      yq '.' "$CONFIG_FILE"
      exit 1
    fi
  elif command -v python3 &>/dev/null; then
    if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
      echo "✅ Config YAML is valid"
    else
      echo "❌ Config YAML has syntax errors"
      exit 1
    fi
  else
    echo "⚠️  No YAML validator available (install yq or python3)"
    echo "   Config file exists at $CONFIG_FILE"
  fi
}

cmd_backup() {
  local BACKUP_DIR="${1:-$HOME/gatus-backup-$(date +%Y%m%d)}"
  mkdir -p "$BACKUP_DIR"
  
  cp "$CONFIG_FILE" "$BACKUP_DIR/" 2>/dev/null && echo "✅ Config backed up"
  [[ -f "$CONFIG_DIR/.env" ]] && cp "$CONFIG_DIR/.env" "$BACKUP_DIR/"
  [[ -f "$CONFIG_DIR/docker-compose.yaml" ]] && cp "$CONFIG_DIR/docker-compose.yaml" "$BACKUP_DIR/"
  
  # Try to backup SQLite data
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^gatus$'; then
    docker cp gatus:/data/gatus.db "$BACKUP_DIR/" 2>/dev/null && echo "✅ Database backed up"
  fi
  
  echo "📦 Backup saved to $BACKUP_DIR/"
}

case "${1:-help}" in
  status) cmd_status ;;
  list) cmd_list ;;
  results) shift; cmd_results "$@" ;;
  add) shift; cmd_add "$@" ;;
  reload) cmd_reload ;;
  validate) cmd_validate ;;
  backup) shift; cmd_backup "$@" ;;
  *) usage ;;
esac
