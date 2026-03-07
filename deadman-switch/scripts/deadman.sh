#!/usr/bin/env bash
# Dead Man's Switch — Self-hosted cron job monitor
# Monitors that scheduled jobs check in within expected intervals
set -euo pipefail

DEADMAN_DIR="${DEADMAN_DIR:-$HOME/.deadman}"
JOBS_DIR="$DEADMAN_DIR/jobs"
LOGS_DIR="$DEADMAN_DIR/logs"
CONFIG_FILE="$DEADMAN_DIR/config.json"
LOG_FILE="$LOGS_DIR/deadman.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────

ensure_dirs() {
  mkdir -p "$JOBS_DIR" "$LOGS_DIR"
}

now_epoch() {
  date +%s
}

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log_event() {
  local msg="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE"
}

human_duration() {
  local secs=$1
  if (( secs < 60 )); then echo "${secs}s"
  elif (( secs < 3600 )); then echo "$(( secs / 60 ))m"
  elif (( secs < 86400 )); then echo "$(( secs / 3600 ))h"
  else echo "$(( secs / 86400 ))d"; fi
}

get_config_value() {
  local path="$1"
  local default="${2:-}"
  if [[ -f "$CONFIG_FILE" ]]; then
    local val
    val=$(jq -r "$path // empty" "$CONFIG_FILE" 2>/dev/null || true)
    echo "${val:-$default}"
  else
    echo "$default"
  fi
}

# ─── Alert Functions ──────────────────────────────────────────────────

send_telegram() {
  local message="$1"
  local token="${DEADMAN_TELEGRAM_TOKEN:-$(get_config_value '.alert_channels.telegram.bot_token')}"
  local chat="${DEADMAN_TELEGRAM_CHAT:-$(get_config_value '.alert_channels.telegram.chat_id')}"
  
  if [[ -z "$token" || -z "$chat" ]]; then
    return 1
  fi
  
  curl -sf -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d "chat_id=${chat}" \
    -d "text=${message}" \
    -d "parse_mode=Markdown" > /dev/null 2>&1 || true
}

send_webhook() {
  local message="$1"
  local url="${DEADMAN_WEBHOOK_URL:-$(get_config_value '.alert_channels.webhook.url')}"
  
  if [[ -z "$url" ]]; then
    return 1
  fi
  
  curl -sf -X POST "$url" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"$message\", \"content\": \"$message\"}" > /dev/null 2>&1 || true
}

send_email() {
  local message="$1"
  local to="${DEADMAN_EMAIL:-$(get_config_value '.alert_channels.email.to')}"
  
  if [[ -z "$to" ]]; then
    return 1
  fi
  
  echo "$message" | mail -s "⚠️ Dead Man's Switch Alert" "$to" 2>/dev/null || true
}

send_alert() {
  local message="$1"
  local channels="${2:-}"
  
  # Default channels from config
  if [[ -z "$channels" ]]; then
    channels=$(get_config_value '.defaults.alert_channels | join(",")' "telegram")
  fi
  
  IFS=',' read -ra CHAN <<< "$channels"
  for chan in "${CHAN[@]}"; do
    chan=$(echo "$chan" | tr -d ' "[]')
    case "$chan" in
      telegram) send_telegram "$message" ;;
      webhook)  send_webhook "$message" ;;
      email)    send_email "$message" ;;
    esac
  done
}

# ─── Commands ─────────────────────────────────────────────────────────

cmd_register() {
  local name="" interval=300 grace=60 tags="" alert_msg="" alert_channels=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --interval) interval="$2"; shift 2 ;;
      --grace) grace="$2"; shift 2 ;;
      --tags) tags="$2"; shift 2 ;;
      --alert-message) alert_msg="$2"; shift 2 ;;
      --alert-channels) alert_channels="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done
  
  if [[ -z "$name" ]]; then
    echo "Error: --name is required"
    exit 1
  fi
  
  # Sanitize name
  local safe_name
  safe_name=$(echo "$name" | tr -c 'a-zA-Z0-9_-' '_')
  
  local job_file="$JOBS_DIR/${safe_name}.json"
  
  # Build tags array
  local tags_json="[]"
  if [[ -n "$tags" ]]; then
    tags_json=$(echo "$tags" | tr ',' '\n' | jq -R . | jq -s .)
  fi
  
  # Build job JSON
  jq -n \
    --arg name "$name" \
    --argjson interval "$interval" \
    --argjson grace "$grace" \
    --arg created "$(now_iso)" \
    --argjson tags "$tags_json" \
    --arg alert_msg "$alert_msg" \
    --arg alert_channels "$alert_channels" \
    '{
      name: $name,
      interval_seconds: $interval,
      grace_seconds: $grace,
      last_ping: null,
      status: "new",
      last_alert: null,
      paused_until: null,
      created_at: $created,
      alert_message: (if $alert_msg == "" then null else $alert_msg end),
      alert_channels: (if $alert_channels == "" then null else ($alert_channels | split(",")) end),
      tags: $tags
    }' > "$job_file"
  
  echo -e "${GREEN}✅ Registered job: ${name}${NC}"
  echo "   Interval: $(human_duration "$interval") | Grace: $(human_duration "$grace")"
  echo "   Ping with: bash ~/.deadman/deadman.sh ping $name"
  
  log_event "REGISTER $name interval=${interval}s grace=${grace}s"
}

cmd_ping() {
  local name="$1"
  local safe_name
  safe_name=$(echo "$name" | tr -c 'a-zA-Z0-9_-' '_')
  local job_file="$JOBS_DIR/${safe_name}.json"
  
  if [[ ! -f "$job_file" ]]; then
    echo "Error: Job '$name' not found. Register it first."
    exit 1
  fi
  
  local now
  now=$(now_iso)
  
  # Update last_ping and status
  local tmp
  tmp=$(mktemp)
  jq --arg now "$now" '.last_ping = $now | .status = "ok"' "$job_file" > "$tmp"
  mv "$tmp" "$job_file"
  
  log_event "PING $name"
}

cmd_check() {
  local tag_filter=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --tag) tag_filter="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local now_ts
  now_ts=$(now_epoch)
  local default_repeat
  default_repeat=$(get_config_value '.defaults.alert_repeat_seconds' "3600")
  local alerts_sent=0
  
  for job_file in "$JOBS_DIR"/*.json; do
    [[ -f "$job_file" ]] || continue
    
    local name interval grace last_ping status paused_until last_alert alert_msg alert_channels job_tags
    name=$(jq -r '.name' "$job_file")
    interval=$(jq -r '.interval_seconds' "$job_file")
    grace=$(jq -r '.grace_seconds' "$job_file")
    last_ping=$(jq -r '.last_ping // empty' "$job_file")
    status=$(jq -r '.status' "$job_file")
    paused_until=$(jq -r '.paused_until // empty' "$job_file")
    last_alert=$(jq -r '.last_alert // empty' "$job_file")
    alert_msg=$(jq -r '.alert_message // empty' "$job_file")
    alert_channels=$(jq -r '.alert_channels // empty | if type == "array" then join(",") else . end' "$job_file")
    job_tags=$(jq -r '.tags // [] | join(",")' "$job_file")
    
    # Tag filter
    if [[ -n "$tag_filter" ]] && ! echo "$job_tags" | grep -q "$tag_filter"; then
      continue
    fi
    
    # Skip if paused
    if [[ -n "$paused_until" ]]; then
      local pause_ts
      pause_ts=$(date -d "$paused_until" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$paused_until" +%s 2>/dev/null || echo 0)
      if (( now_ts < pause_ts )); then
        continue
      else
        # Unpause
        local tmp=$(mktemp)
        jq '.paused_until = null' "$job_file" > "$tmp"
        mv "$tmp" "$job_file"
      fi
    fi
    
    # Skip new jobs (never pinged yet)
    if [[ -z "$last_ping" || "$status" == "new" ]]; then
      continue
    fi
    
    # Calculate if overdue
    local ping_ts
    ping_ts=$(date -d "$last_ping" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_ping" +%s 2>/dev/null || echo 0)
    local deadline=$(( ping_ts + interval + grace ))
    
    if (( now_ts > deadline )); then
      local overdue=$(( now_ts - ping_ts - interval ))
      local overdue_human
      overdue_human=$(human_duration "$overdue")
      
      # Check alert dedup
      local should_alert=true
      if [[ -n "$last_alert" ]]; then
        local alert_ts
        alert_ts=$(date -d "$last_alert" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_alert" +%s 2>/dev/null || echo 0)
        if (( now_ts - alert_ts < default_repeat )); then
          should_alert=false
        fi
      fi
      
      if [[ "$should_alert" == "true" ]]; then
        local msg
        if [[ -n "$alert_msg" ]]; then
          msg="$alert_msg"
        else
          msg="⚠️ *Dead Man's Switch*: \`$name\` missed check-in (${overdue_human} overdue)"
        fi
        
        send_alert "$msg" "$alert_channels"
        alerts_sent=$((alerts_sent + 1))
        
        # Update status and last_alert
        local tmp=$(mktemp)
        jq --arg now "$(now_iso)" '.status = "late" | .last_alert = $now' "$job_file" > "$tmp"
        mv "$tmp" "$job_file"
        
        log_event "⚠️ LATE $name (${overdue_human} overdue) — alert sent"
      fi
    else
      # If was late but now ok (got a recent ping), log recovery
      if [[ "$status" == "late" ]]; then
        local tmp=$(mktemp)
        jq '.status = "ok"' "$job_file" > "$tmp"
        mv "$tmp" "$job_file"
        log_event "✅ RECOVERED $name"
      fi
    fi
  done
  
  if (( alerts_sent > 0 )); then
    echo "Checked jobs: $alerts_sent alert(s) sent"
  fi
}

cmd_list() {
  local tag_filter=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --tag) tag_filter="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  printf "${BLUE}%-20s %-10s %-8s %-22s %-8s${NC}\n" "NAME" "INTERVAL" "GRACE" "LAST PING" "STATUS"
  printf "%-20s %-10s %-8s %-22s %-8s\n" "----" "--------" "-----" "---------" "------"
  
  for job_file in "$JOBS_DIR"/*.json; do
    [[ -f "$job_file" ]] || continue
    
    local name interval grace last_ping status job_tags
    name=$(jq -r '.name' "$job_file")
    interval=$(jq -r '.interval_seconds' "$job_file")
    grace=$(jq -r '.grace_seconds' "$job_file")
    last_ping=$(jq -r '.last_ping // "never"' "$job_file")
    status=$(jq -r '.status' "$job_file")
    job_tags=$(jq -r '.tags // [] | join(",")' "$job_file")
    
    if [[ -n "$tag_filter" ]] && ! echo "$job_tags" | grep -q "$tag_filter"; then
      continue
    fi
    
    local status_icon
    case "$status" in
      ok)    status_icon="${GREEN}✅ OK${NC}" ;;
      late)  status_icon="${RED}❌ LATE${NC}" ;;
      new)   status_icon="${YELLOW}🆕 NEW${NC}" ;;
      *)     status_icon="$status" ;;
    esac
    
    # Truncate last_ping for display
    if [[ "$last_ping" != "never" ]]; then
      last_ping="${last_ping:0:19}"
    fi
    
    printf "%-20s %-10s %-8s %-22s " "$name" "$(human_duration "$interval")" "$(human_duration "$grace")" "$last_ping"
    echo -e "$status_icon"
  done
}

cmd_status() {
  local json_output=false
  [[ "${1:-}" == "--json" ]] && json_output=true
  
  local total=0 ok=0 late=0 paused=0 new_count=0
  
  for job_file in "$JOBS_DIR"/*.json; do
    [[ -f "$job_file" ]] || continue
    total=$((total + 1))
    local status paused_until
    status=$(jq -r '.status' "$job_file")
    paused_until=$(jq -r '.paused_until // empty' "$job_file")
    
    if [[ -n "$paused_until" ]]; then
      paused=$((paused + 1))
    elif [[ "$status" == "ok" ]]; then
      ok=$((ok + 1))
    elif [[ "$status" == "late" ]]; then
      late=$((late + 1))
    elif [[ "$status" == "new" ]]; then
      new_count=$((new_count + 1))
    fi
  done
  
  if $json_output; then
    jq -n \
      --argjson total "$total" \
      --argjson ok "$ok" \
      --argjson late "$late" \
      --argjson paused "$paused" \
      --argjson new "$new_count" \
      '{total: $total, ok: $ok, late: $late, paused: $paused, new: $new}'
  else
    echo "Dead Man's Switch Status"
    echo "========================"
    echo "Total jobs: $total"
    echo -e "  ${GREEN}✅ OK:${NC}     $ok"
    echo -e "  ${RED}❌ Late:${NC}   $late"
    echo -e "  ${YELLOW}⏸ Paused:${NC} $paused"
    echo -e "  🆕 New:    $new_count"
  fi
}

cmd_pause() {
  local name="$1"
  shift
  local duration="2h"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --duration) duration="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local safe_name
  safe_name=$(echo "$name" | tr -c 'a-zA-Z0-9_-' '_')
  local job_file="$JOBS_DIR/${safe_name}.json"
  
  if [[ ! -f "$job_file" ]]; then
    echo "Error: Job '$name' not found."
    exit 1
  fi
  
  # Parse duration to seconds
  local secs=7200
  if [[ "$duration" =~ ^([0-9]+)([smhd])$ ]]; then
    local num="${BASH_REMATCH[1]}"
    local unit="${BASH_REMATCH[2]}"
    case "$unit" in
      s) secs=$num ;;
      m) secs=$((num * 60)) ;;
      h) secs=$((num * 3600)) ;;
      d) secs=$((num * 86400)) ;;
    esac
  fi
  
  local until_ts=$(( $(now_epoch) + secs ))
  local until_iso
  until_iso=$(date -u -d "@$until_ts" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -r "$until_ts" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
  
  local tmp=$(mktemp)
  jq --arg until "$until_iso" '.paused_until = $until' "$job_file" > "$tmp"
  mv "$tmp" "$job_file"
  
  echo -e "${YELLOW}⏸ Paused '$name' until $until_iso${NC}"
  log_event "PAUSE $name until $until_iso"
}

cmd_resume() {
  local name="$1"
  local safe_name
  safe_name=$(echo "$name" | tr -c 'a-zA-Z0-9_-' '_')
  local job_file="$JOBS_DIR/${safe_name}.json"
  
  if [[ ! -f "$job_file" ]]; then
    echo "Error: Job '$name' not found."
    exit 1
  fi
  
  local tmp=$(mktemp)
  jq '.paused_until = null' "$job_file" > "$tmp"
  mv "$tmp" "$job_file"
  
  echo -e "${GREEN}▶ Resumed '$name'${NC}"
  log_event "RESUME $name"
}

cmd_remove() {
  local name="$1"
  local safe_name
  safe_name=$(echo "$name" | tr -c 'a-zA-Z0-9_-' '_')
  local job_file="$JOBS_DIR/${safe_name}.json"
  
  if [[ ! -f "$job_file" ]]; then
    echo "Error: Job '$name' not found."
    exit 1
  fi
  
  rm "$job_file"
  echo -e "${RED}🗑 Removed job: $name${NC}"
  log_event "REMOVE $name"
}

cmd_update() {
  local name="$1"
  shift
  local safe_name
  safe_name=$(echo "$name" | tr -c 'a-zA-Z0-9_-' '_')
  local job_file="$JOBS_DIR/${safe_name}.json"
  
  if [[ ! -f "$job_file" ]]; then
    echo "Error: Job '$name' not found."
    exit 1
  fi
  
  local tmp
  tmp=$(mktemp)
  cp "$job_file" "$tmp"
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --interval)
        jq --argjson v "$2" '.interval_seconds = $v' "$tmp" > "${tmp}.new" && mv "${tmp}.new" "$tmp"
        shift 2 ;;
      --grace)
        jq --argjson v "$2" '.grace_seconds = $v' "$tmp" > "${tmp}.new" && mv "${tmp}.new" "$tmp"
        shift 2 ;;
      --alert-repeat)
        # Store on job level
        shift 2 ;;
      *) shift ;;
    esac
  done
  
  mv "$tmp" "$job_file"
  echo -e "${GREEN}✅ Updated job: $name${NC}"
  log_event "UPDATE $name"
}

cmd_prune() {
  local days=30
  while [[ $# -gt 0 ]]; do
    case $1 in
      --days) days="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local threshold=$(( $(now_epoch) - days * 86400 ))
  local pruned=0
  
  for job_file in "$JOBS_DIR"/*.json; do
    [[ -f "$job_file" ]] || continue
    local last_ping
    last_ping=$(jq -r '.last_ping // empty' "$job_file")
    
    if [[ -z "$last_ping" ]]; then
      continue
    fi
    
    local ping_ts
    ping_ts=$(date -d "$last_ping" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_ping" +%s 2>/dev/null || echo 999999999999)
    
    if (( ping_ts < threshold )); then
      local name
      name=$(jq -r '.name' "$job_file")
      rm "$job_file"
      echo "Pruned: $name (last ping: $last_ping)"
      log_event "PRUNE $name"
      pruned=$((pruned + 1))
    fi
  done
  
  echo "Pruned $pruned job(s) older than ${days} days"
}

cmd_log() {
  local last=20
  while [[ $# -gt 0 ]]; do
    case $1 in
      --last) last="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -f "$LOG_FILE" ]]; then
    tail -n "$last" "$LOG_FILE"
  else
    echo "No log entries yet."
  fi
}

cmd_config() {
  local telegram_token="" telegram_chat="" webhook="" email="" test_mode=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --telegram-token) telegram_token="$2"; shift 2 ;;
      --telegram-chat) telegram_chat="$2"; shift 2 ;;
      --webhook) webhook="$2"; shift 2 ;;
      --email) email="$2"; shift 2 ;;
      --test) test_mode=true; shift ;;
      *) shift ;;
    esac
  done
  
  if $test_mode; then
    echo "Sending test alerts..."
    send_alert "🧪 Dead Man's Switch test alert from $(hostname)"
    echo "Done. Check your alert channels."
    return
  fi
  
  # Create or update config
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"alert_channels":{},"defaults":{"grace_seconds":300,"alert_repeat_seconds":3600,"alert_channels":["telegram"]}}' | jq . > "$CONFIG_FILE"
  fi
  
  local tmp=$(mktemp)
  cp "$CONFIG_FILE" "$tmp"
  
  if [[ -n "$telegram_token" ]]; then
    jq --arg v "$telegram_token" '.alert_channels.telegram.bot_token = $v' "$tmp" > "${tmp}.new" && mv "${tmp}.new" "$tmp"
  fi
  if [[ -n "$telegram_chat" ]]; then
    jq --arg v "$telegram_chat" '.alert_channels.telegram.chat_id = $v' "$tmp" > "${tmp}.new" && mv "${tmp}.new" "$tmp"
  fi
  if [[ -n "$webhook" ]]; then
    jq --arg v "$webhook" '.alert_channels.webhook.url = $v' "$tmp" > "${tmp}.new" && mv "${tmp}.new" "$tmp"
  fi
  if [[ -n "$email" ]]; then
    jq --arg v "$email" '.alert_channels.email.to = $v' "$tmp" > "${tmp}.new" && mv "${tmp}.new" "$tmp"
  fi
  
  mv "$tmp" "$CONFIG_FILE"
  echo -e "${GREEN}✅ Configuration updated${NC}"
  jq . "$CONFIG_FILE"
}

cmd_serve() {
  local port=8090
  while [[ $# -gt 0 ]]; do
    case $1 in
      --port) port="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  echo "Starting HTTP listener on port $port..."
  echo "Ping endpoints: GET /ping/<job-name>"
  
  # Use Python if available (more reliable than socat)
  if command -v python3 &>/dev/null; then
    python3 -c "
import http.server
import subprocess
import json
import os

class PingHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/ping/'):
            name = self.path[6:].strip('/')
            result = subprocess.run(
                ['bash', os.path.expanduser('~/.deadman/deadman.sh'), 'ping', name],
                capture_output=True, text=True
            )
            if result.returncode == 0:
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'OK')
            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(result.stderr.encode())
        elif self.path == '/status':
            result = subprocess.run(
                ['bash', os.path.expanduser('~/.deadman/deadman.sh'), 'status', '--json'],
                capture_output=True, text=True
            )
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(result.stdout.encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass  # Suppress default logging

server = http.server.HTTPServer(('0.0.0.0', $port), PingHandler)
print(f'Listening on 0.0.0.0:$port')
server.serve_forever()
" &
    echo "HTTP server started (PID: $!)"
  else
    echo "Error: python3 required for HTTP mode"
    exit 1
  fi
}

# ─── Main ─────────────────────────────────────────────────────────────

ensure_dirs

case "${1:-help}" in
  register) shift; cmd_register "$@" ;;
  ping)     shift; cmd_ping "$@" ;;
  check)    shift; cmd_check "$@" ;;
  list)     shift; cmd_list "$@" ;;
  status)   shift; cmd_status "$@" ;;
  pause)    shift; cmd_pause "$@" ;;
  resume)   shift; cmd_resume "$@" ;;
  remove)   shift; cmd_remove "$@" ;;
  update)   shift; cmd_update "$@" ;;
  prune)    shift; cmd_prune "$@" ;;
  log)      shift; cmd_log "$@" ;;
  config)   shift; cmd_config "$@" ;;
  serve)    shift; cmd_serve "$@" ;;
  help|--help|-h)
    echo "Dead Man's Switch — Self-hosted cron job monitor"
    echo ""
    echo "Usage: deadman.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  register  --name <n> --interval <s> [--grace <s>]  Register a job"
    echo "  ping      <name>                                    Record check-in"
    echo "  check     [--tag <tag>]                             Check all jobs, send alerts"
    echo "  list      [--tag <tag>]                             List all jobs"
    echo "  status    [--json]                                  Summary status"
    echo "  pause     <name> [--duration <2h>]                  Pause monitoring"
    echo "  resume    <name>                                    Resume monitoring"
    echo "  update    <name> [--interval <s>] [--grace <s>]     Update job settings"
    echo "  remove    <name>                                    Remove a job"
    echo "  prune     [--days <30>]                             Remove stale jobs"
    echo "  log       [--last <20>]                             View alert log"
    echo "  config    [--telegram-token ...] [--test]           Configure alerts"
    echo "  serve     [--port <8090>]                           Start HTTP listener"
    ;;
  *)
    echo "Unknown command: $1 (try 'help')"
    exit 1
    ;;
esac
