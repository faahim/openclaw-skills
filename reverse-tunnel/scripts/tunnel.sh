#!/bin/bash
# Reverse Tunnel Manager — Start, stop, list, and manage tunnels
set -euo pipefail

TUNNEL_DIR="${TUNNEL_DIR:-$HOME/.reverse-tunnel}"
PID_DIR="$TUNNEL_DIR/pids"
LOG_DIR="$TUNNEL_DIR/logs"
STATE_FILE="$TUNNEL_DIR/tunnels.json"

mkdir -p "$PID_DIR" "$LOG_DIR"
[ -f "$STATE_FILE" ] || echo '[]' > "$STATE_FILE"

# ─── Helpers ─────────────────────────────────────────────────────

log() { echo "[$(date '+%H:%M:%S')] $*"; }
err() { echo "[$(date '+%H:%M:%S')] ❌ $*" >&2; }

gen_id() {
  echo "t-$(date +%s | tail -c 4)"
}

add_state() {
  local id="$1" backend="$2" port="$3" url="$4" pid="$5"
  local tmp=$(mktemp)
  jq --arg id "$id" --arg b "$backend" --arg p "$port" --arg u "$url" --arg pid "$pid" \
    '. += [{"id":$id,"backend":$b,"local_port":($p|tonumber),"public_url":$u,"pid":($pid|tonumber),"started_at":(now|todate),"status":"active"}]' \
    "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

remove_state() {
  local id="$1"
  local tmp=$(mktemp)
  jq --arg id "$id" 'map(select(.id != $id))' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

notify_telegram() {
  local msg="$1"
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=${msg}" -d "parse_mode=Markdown" >/dev/null 2>&1 || true
  fi
}

# ─── Start Tunnel ────────────────────────────────────────────────

cmd_start() {
  local backend="" port="" name="" subdomain="" server="" log_requests=false restart_on_fail=false max_retries=3 notify=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --backend) backend="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --subdomain) subdomain="$2"; shift 2 ;;
      --server) server="$2"; shift 2 ;;
      --log-requests) log_requests=true; shift ;;
      --restart-on-fail) restart_on_fail=true; shift ;;
      --max-retries) max_retries="$2"; shift 2 ;;
      --notify) notify="$2"; shift 2 ;;
      *) err "Unknown option: $1"; exit 1 ;;
    esac
  done

  [ -z "$backend" ] && { err "Missing --backend (cloudflared|bore|localtunnel)"; exit 1; }
  [ -z "$port" ] && { err "Missing --port"; exit 1; }

  local id=$(gen_id)
  local logfile="$LOG_DIR/${id}.log"
  local pidfile="$PID_DIR/${id}.pid"
  local url=""

  case "$backend" in
    cloudflared)
      if ! command -v cloudflared &>/dev/null; then
        err "cloudflared not installed. Run: bash scripts/install.sh cloudflared"
        exit 1
      fi

      if [ -n "$name" ]; then
        # Named tunnel (requires login)
        cloudflared tunnel run --url "http://localhost:${port}" "$name" > "$logfile" 2>&1 &
      else
        # Quick tunnel (no auth needed)
        cloudflared tunnel --url "http://localhost:${port}" > "$logfile" 2>&1 &
      fi
      local pid=$!
      echo "$pid" > "$pidfile"

      # Wait for URL to appear in logs
      log "⏳ Starting cloudflared tunnel on port $port..."
      local attempts=0
      while [ $attempts -lt 30 ]; do
        url=$(grep -oP 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$logfile" 2>/dev/null | head -1 || true)
        [ -n "$url" ] && break
        # Also check for named tunnel URLs
        url=$(grep -oP 'https://[a-zA-Z0-9.-]+' "$logfile" 2>/dev/null | grep -v 'github\|cloudflare\|api\.' | tail -1 || true)
        [ -n "$url" ] && break
        sleep 1
        ((attempts++))
      done

      if [ -z "$url" ]; then
        url="(pending — check $logfile)"
      fi

      add_state "$id" "$backend" "$port" "$url" "$pid"
      log "🚇 Tunnel active: $url → localhost:$port (pid: $pid)"
      ;;

    bore)
      if ! command -v bore &>/dev/null; then
        err "bore not installed. Run: bash scripts/install.sh bore"
        exit 1
      fi

      local bore_server="${server:-bore.pub}"
      bore local "$port" --to "$bore_server" > "$logfile" 2>&1 &
      local pid=$!
      echo "$pid" > "$pidfile"

      log "⏳ Starting bore tunnel on port $port..."
      local attempts=0
      while [ $attempts -lt 15 ]; do
        url=$(grep -oP "${bore_server}:\d+" "$logfile" 2>/dev/null | head -1 || true)
        [ -n "$url" ] && break
        sleep 1
        ((attempts++))
      done

      [ -z "$url" ] && url="${bore_server}:(pending)"
      add_state "$id" "$backend" "$port" "$url" "$pid"
      log "🚇 Tunnel active: $url → localhost:$port (pid: $pid)"
      ;;

    localtunnel|lt)
      local lt_cmd="lt"
      if ! command -v lt &>/dev/null; then
        lt_cmd="npx localtunnel"
      fi

      local lt_args="--port $port"
      [ -n "$subdomain" ] && lt_args="$lt_args --subdomain $subdomain"

      $lt_cmd $lt_args > "$logfile" 2>&1 &
      local pid=$!
      echo "$pid" > "$pidfile"

      log "⏳ Starting localtunnel on port $port..."
      local attempts=0
      while [ $attempts -lt 20 ]; do
        url=$(grep -oP 'https://[a-zA-Z0-9-]+\.loca\.lt' "$logfile" 2>/dev/null | head -1 || true)
        [ -n "$url" ] && break
        sleep 1
        ((attempts++))
      done

      [ -z "$url" ] && url="(pending — check $logfile)"
      add_state "$id" "$backend" "$port" "$url" "$pid"
      log "🚇 Tunnel active: $url → localhost:$port (pid: $pid)"
      ;;

    *)
      err "Unknown backend: $backend (use cloudflared, bore, or localtunnel)"
      exit 1
      ;;
  esac

  # Notify
  if [ -n "$notify" ] && [ "$notify" = "telegram" ]; then
    notify_telegram "🚇 Tunnel started: $url → localhost:$port ($backend)"
  fi

  # Log requests mode (tail the log)
  if [ "$log_requests" = true ]; then
    tail -f "$logfile"
  fi

  # Auto-restart mode
  if [ "$restart_on_fail" = true ]; then
    local retries=0
    while [ $retries -lt $max_retries ]; do
      wait "$pid" 2>/dev/null || true
      if ! kill -0 "$pid" 2>/dev/null; then
        ((retries++))
        log "⚠️  Tunnel died. Restarting ($retries/$max_retries)..."
        cmd_start --backend "$backend" --port "$port" ${name:+--name "$name"} ${subdomain:+--subdomain "$subdomain"} ${server:+--server "$server"}
        return $?
      fi
    done
    err "Max retries ($max_retries) reached. Tunnel stopped."
  fi
}

# ─── Stop Tunnel ─────────────────────────────────────────────────

cmd_stop() {
  local id="${1:-}"
  [ -z "$id" ] && { err "Usage: tunnel.sh stop <tunnel-id>"; exit 1; }

  local pidfile="$PID_DIR/${id}.pid"
  if [ -f "$pidfile" ]; then
    local pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      log "🛑 Stopped tunnel $id (pid: $pid)"
    else
      log "⚠️  Tunnel $id already stopped"
    fi
    rm -f "$pidfile"
  else
    err "No tunnel found with id: $id"
    exit 1
  fi

  remove_state "$id"
}

# ─── Stop All ────────────────────────────────────────────────────

cmd_stop_all() {
  for pidfile in "$PID_DIR"/*.pid; do
    [ -f "$pidfile" ] || continue
    local id=$(basename "$pidfile" .pid)
    cmd_stop "$id"
  done
  log "🛑 All tunnels stopped"
}

# ─── List Tunnels ────────────────────────────────────────────────

cmd_list() {
  # Clean up dead tunnels first
  local tmp=$(mktemp)
  jq -c '.[]' "$STATE_FILE" 2>/dev/null | while read -r entry; do
    local pid=$(echo "$entry" | jq -r '.pid')
    if ! kill -0 "$pid" 2>/dev/null; then
      local id=$(echo "$entry" | jq -r '.id')
      remove_state "$id"
      rm -f "$PID_DIR/${id}.pid"
    fi
  done

  local count=$(jq 'length' "$STATE_FILE" 2>/dev/null || echo 0)
  if [ "$count" = "0" ]; then
    echo "No active tunnels."
    return
  fi

  printf "%-8s %-14s %-18s %-50s %s\n" "ID" "Backend" "Local" "Public URL" "Status"
  printf "%-8s %-14s %-18s %-50s %s\n" "──────" "────────────" "────────────────" "────────────────────────────────────────────────" "──────"

  jq -r '.[] | [.id, .backend, "localhost:\(.local_port)", .public_url, .status] | @tsv' "$STATE_FILE" | \
    while IFS=$'\t' read -r id backend local url status; do
      printf "%-8s %-14s %-18s %-50s %s\n" "$id" "$backend" "$local" "$url" "$status"
    done
}

# ─── Create Named Tunnel (cloudflared) ───────────────────────────

cmd_create() {
  local name="" port=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$name" ] && { err "Missing --name"; exit 1; }

  if ! command -v cloudflared &>/dev/null; then
    err "cloudflared required. Run: bash scripts/install.sh cloudflared"
    exit 1
  fi

  cloudflared tunnel create "$name"
  log "✅ Named tunnel '$name' created"

  if [ -n "$port" ]; then
    log "Starting tunnel..."
    cmd_start --backend cloudflared --port "$port" --name "$name"
  fi
}

# ─── DNS Configuration ───────────────────────────────────────────

cmd_dns() {
  local name="" hostname=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --hostname) hostname="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$name" ] && { err "Missing --name"; exit 1; }
  [ -z "$hostname" ] && { err "Missing --hostname"; exit 1; }

  cloudflared tunnel route dns "$name" "$hostname"
  log "✅ DNS configured: $hostname → tunnel '$name'"
}

# ─── Systemd Service ─────────────────────────────────────────────

cmd_service() {
  local backend="" port="" name="" enable=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --backend) backend="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --enable) enable=true; shift ;;
      *) shift ;;
    esac
  done

  local svc_name="tunnel-${name:-${backend}-${port}}"
  local script_path="$(cd "$(dirname "$0")" && pwd)/tunnel.sh"

  cat > "/tmp/${svc_name}.service" <<EOF
[Unit]
Description=Reverse Tunnel: ${name:-${backend}:${port}}
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash ${script_path} start --backend ${backend} --port ${port} ${name:+--name $name}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  if [ -w /etc/systemd/system ]; then
    mv "/tmp/${svc_name}.service" "/etc/systemd/system/${svc_name}.service"
    systemctl daemon-reload
    if [ "$enable" = true ]; then
      systemctl enable --now "$svc_name"
      log "✅ Service $svc_name enabled and started"
    else
      log "✅ Service $svc_name created. Enable with: systemctl enable --now $svc_name"
    fi
  else
    mkdir -p "$HOME/.config/systemd/user"
    mv "/tmp/${svc_name}.service" "$HOME/.config/systemd/user/${svc_name}.service"
    systemctl --user daemon-reload
    if [ "$enable" = true ]; then
      systemctl --user enable --now "$svc_name"
      log "✅ User service $svc_name enabled and started"
    else
      log "✅ User service created at ~/.config/systemd/user/${svc_name}.service"
    fi
  fi
}

# ─── Start All from Config ───────────────────────────────────────

cmd_start_all() {
  local config=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --config) config="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$config" ] && { err "Missing --config"; exit 1; }
  [ ! -f "$config" ] && { err "Config file not found: $config"; exit 1; }

  if ! command -v yq &>/dev/null; then
    err "yq required for config parsing. Install: pip install yq"
    exit 1
  fi

  local count=$(yq '.tunnels | length' "$config")
  for ((i=0; i<count; i++)); do
    local backend=$(yq -r ".tunnels[$i].backend" "$config")
    local port=$(yq -r ".tunnels[$i].local_port" "$config")
    local name=$(yq -r ".tunnels[$i].name // empty" "$config")
    local subdomain=$(yq -r ".tunnels[$i].subdomain // empty" "$config")
    local server=$(yq -r ".tunnels[$i].server // empty" "$config")
    local auto=$(yq -r ".tunnels[$i].auto_start // true" "$config")

    if [ "$auto" = "true" ]; then
      log "Starting tunnel: $name ($backend:$port)"
      cmd_start --backend "$backend" --port "$port" ${name:+--name "$name"} ${subdomain:+--subdomain "$subdomain"} ${server:+--server "$server"} &
    fi
  done

  wait
  log "✅ All configured tunnels started"
}

# ─── Main ────────────────────────────────────────────────────────

CMD="${1:-}"
shift 2>/dev/null || true

case "$CMD" in
  start) cmd_start "$@" ;;
  stop) cmd_stop "$@" ;;
  stop-all) cmd_stop_all ;;
  list) cmd_list ;;
  create) cmd_create "$@" ;;
  dns) cmd_dns "$@" ;;
  service) cmd_service "$@" ;;
  start-all) cmd_start_all "$@" ;;
  *)
    echo "Reverse Tunnel Manager"
    echo ""
    echo "Usage: bash tunnel.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start       Start a tunnel (--backend, --port required)"
    echo "  stop        Stop a tunnel by ID"
    echo "  stop-all    Stop all active tunnels"
    echo "  list        List active tunnels"
    echo "  create      Create named Cloudflare tunnel"
    echo "  dns         Configure DNS for named tunnel"
    echo "  service     Create systemd service for a tunnel"
    echo "  start-all   Start tunnels from config file"
    echo ""
    echo "Examples:"
    echo "  bash tunnel.sh start --backend cloudflared --port 3000"
    echo "  bash tunnel.sh start --backend bore --port 8080"
    echo "  bash tunnel.sh list"
    echo "  bash tunnel.sh stop t-001"
    ;;
esac
