#!/bin/bash
# Tinyproxy Manager — Start, stop, configure, monitor
set -euo pipefail

CONF="${TINYPROXY_CONF:-}"
LOG="${TINYPROXY_LOG:-/var/log/tinyproxy/tinyproxy.log}"
PORT="${TINYPROXY_PORT:-8888}"

# Find config file
find_conf() {
  if [ -n "$CONF" ] && [ -f "$CONF" ]; then
    echo "$CONF"
    return
  fi
  for path in /etc/tinyproxy/tinyproxy.conf /etc/tinyproxy.conf /usr/local/etc/tinyproxy/tinyproxy.conf /opt/homebrew/etc/tinyproxy/tinyproxy.conf; do
    if [ -f "$path" ]; then
      echo "$path"
      return
    fi
  done
  echo ""
}

CONF=$(find_conf)

get_port() {
  if [ -n "$CONF" ] && [ -f "$CONF" ]; then
    grep -i "^Port " "$CONF" 2>/dev/null | awk '{print $2}' || echo "$PORT"
  else
    echo "$PORT"
  fi
}

get_bind() {
  if [ -n "$CONF" ] && [ -f "$CONF" ]; then
    grep -i "^Listen " "$CONF" 2>/dev/null | awk '{print $2}' || echo "127.0.0.1"
  else
    echo "127.0.0.1"
  fi
}

cmd_start() {
  if pgrep -x tinyproxy &>/dev/null; then
    echo "⚠️  Tinyproxy already running (PID $(pgrep -x tinyproxy | head -1))"
    return 0
  fi
  
  if systemctl is-enabled tinyproxy &>/dev/null 2>&1; then
    sudo systemctl start tinyproxy
  else
    if [ -n "$CONF" ]; then
      sudo tinyproxy -c "$CONF"
    else
      sudo tinyproxy
    fi
  fi
  
  sleep 1
  if pgrep -x tinyproxy &>/dev/null; then
    local p=$(get_port)
    local b=$(get_bind)
    echo "✅ Tinyproxy started — listening on ${b}:${p}"
  else
    echo "❌ Failed to start tinyproxy. Check logs: $LOG"
    exit 1
  fi
}

cmd_stop() {
  if ! pgrep -x tinyproxy &>/dev/null; then
    echo "⚠️  Tinyproxy is not running"
    return 0
  fi
  
  if systemctl is-active --quiet tinyproxy 2>/dev/null; then
    sudo systemctl stop tinyproxy
  else
    sudo pkill -x tinyproxy
  fi
  echo "✅ Tinyproxy stopped"
}

cmd_restart() {
  cmd_stop
  sleep 1
  cmd_start
}

cmd_reload() {
  if pgrep -x tinyproxy &>/dev/null; then
    sudo pkill -HUP tinyproxy
    echo "✅ Config reloaded"
  else
    echo "⚠️  Tinyproxy not running. Starting..."
    cmd_start
  fi
}

cmd_status() {
  if pgrep -x tinyproxy &>/dev/null; then
    local pid=$(pgrep -x tinyproxy | head -1)
    local p=$(get_port)
    local b=$(get_bind)
    echo "✅ Tinyproxy is running (PID $pid)"
    echo "   Listening on ${b}:${p}"
    echo "   Config: $CONF"
    echo "   Log: $LOG"
    
    # Memory usage
    local mem=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$mem" ]; then
      echo "   Memory: $((mem / 1024))MB"
    fi
    
    # Uptime
    local start=$(ps -o lstart= -p "$pid" 2>/dev/null)
    if [ -n "$start" ]; then
      echo "   Started: $start"
    fi
  else
    echo "❌ Tinyproxy is not running"
  fi
}

cmd_health() {
  local errors=0
  
  if pgrep -x tinyproxy &>/dev/null; then
    echo "✅ Tinyproxy is running (PID $(pgrep -x tinyproxy | head -1))"
  else
    echo "❌ Tinyproxy is NOT running"
    errors=$((errors + 1))
  fi
  
  local p=$(get_port)
  local b=$(get_bind)
  if ss -tlnp 2>/dev/null | grep -q ":${p} " || netstat -tlnp 2>/dev/null | grep -q ":${p} "; then
    echo "✅ Listening on ${b}:${p}"
  else
    echo "❌ Not listening on port ${p}"
    errors=$((errors + 1))
  fi
  
  # Test proxy
  if pgrep -x tinyproxy &>/dev/null; then
    local test_result=$(curl -s -o /dev/null -w "%{http_code}" -x "http://${b}:${p}" --max-time 5 http://httpbin.org/status/200 2>/dev/null || echo "000")
    if [ "$test_result" = "200" ]; then
      echo "✅ Proxy test passed (200 OK)"
    else
      echo "⚠️  Proxy test returned: $test_result"
    fi
  fi
  
  # Log check
  if [ -f "$LOG" ]; then
    local log_size=$(du -sh "$LOG" 2>/dev/null | awk '{print $1}')
    echo "📊 Log size: $log_size"
  fi
  
  [ $errors -eq 0 ] && return 0 || return 1
}

cmd_enable() {
  sudo systemctl enable tinyproxy
  echo "✅ Tinyproxy enabled (will start on boot)"
}

cmd_disable() {
  sudo systemctl disable tinyproxy
  echo "✅ Tinyproxy disabled (will NOT start on boot)"
}

cmd_foreground() {
  echo "🔍 Running tinyproxy in foreground (Ctrl+C to stop)..."
  if [ -n "$CONF" ]; then
    sudo tinyproxy -d -c "$CONF"
  else
    sudo tinyproxy -d
  fi
}

cmd_logs() {
  local follow=false
  local grep_pattern=""
  local lines=50
  
  shift 2>/dev/null || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --follow|-f) follow=true; shift ;;
      --grep) grep_pattern="$2"; shift 2 ;;
      --lines|-n) lines="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local logfile="$LOG"
  if [ ! -f "$logfile" ]; then
    # Try journalctl
    if command -v journalctl &>/dev/null; then
      if [ -n "$grep_pattern" ]; then
        journalctl -u tinyproxy --no-pager -n "$lines" | grep -i "$grep_pattern"
      elif $follow; then
        journalctl -u tinyproxy -f
      else
        journalctl -u tinyproxy --no-pager -n "$lines"
      fi
      return
    fi
    echo "❌ No log file found at $logfile"
    exit 1
  fi
  
  if [ -n "$grep_pattern" ]; then
    grep -i "$grep_pattern" "$logfile" | tail -n "$lines"
  elif $follow; then
    tail -f "$logfile"
  else
    tail -n "$lines" "$logfile"
  fi
}

cmd_stats() {
  local logfile="$LOG"
  if [ ! -f "$logfile" ]; then
    echo "⚠️  No log file found. Enable logging first."
    exit 1
  fi
  
  echo "📊 Tinyproxy Stats"
  echo "==================="
  
  local total=$(wc -l < "$logfile")
  echo "Total log entries: $total"
  
  # Extract CONNECT and request lines
  local connects=$(grep -c "CONNECT " "$logfile" 2>/dev/null || echo "0")
  echo "HTTPS tunnels (CONNECT): $connects"
  
  local requests=$(grep -c "Request " "$logfile" 2>/dev/null || echo "0")
  echo "HTTP requests: $requests"
  
  echo ""
  echo "Top domains (last 1000 lines):"
  tail -1000 "$logfile" | grep -oP 'https?://[^/: ]+|CONNECT [^: ]+' | \
    sed 's|https\?://||;s|CONNECT ||' | sort | uniq -c | sort -rn | head -10
  
  echo ""
  echo "Log size: $(du -sh "$logfile" | awk '{print $1}')"
}

cmd_config() {
  if [ -z "$CONF" ] || [ ! -f "$CONF" ]; then
    echo "❌ Config file not found. Is tinyproxy installed?"
    exit 1
  fi
  
  shift 2>/dev/null || true
  
  if [ $# -eq 0 ]; then
    echo "Current config: $CONF"
    echo "Use --show to display, or pass options to modify."
    return
  fi
  
  while [ $# -gt 0 ]; do
    case "$1" in
      --show)
        grep -v "^#" "$CONF" | grep -v "^$"
        return
        ;;
      --backup)
        local backup="${CONF}.bak.$(date +%Y%m%d%H%M%S)"
        sudo cp "$CONF" "$backup"
        echo "✅ Config backed up to $backup"
        return
        ;;
      --restore)
        local latest=$(ls -t "${CONF}.bak."* 2>/dev/null | head -1)
        if [ -z "$latest" ]; then
          echo "❌ No backup found"
          exit 1
        fi
        sudo cp "$latest" "$CONF"
        echo "✅ Restored from $latest"
        return
        ;;
      --port)
        sudo sed -i "s/^Port .*/Port $2/" "$CONF"
        echo "✅ Port set to $2"
        shift 2
        ;;
      --bind)
        if grep -q "^Listen " "$CONF"; then
          sudo sed -i "s/^Listen .*/Listen $2/" "$CONF"
        else
          echo "Listen $2" | sudo tee -a "$CONF" >/dev/null
        fi
        echo "✅ Bind address set to $2"
        shift 2
        ;;
      --max-clients)
        sudo sed -i "s/^MaxClients .*/MaxClients $2/" "$CONF"
        echo "✅ Max clients set to $2"
        shift 2
        ;;
      --timeout)
        sudo sed -i "s/^Timeout .*/Timeout $2/" "$CONF"
        echo "✅ Timeout set to $2"
        shift 2
        ;;
      --log-level)
        sudo sed -i "s/^LogLevel .*/LogLevel $2/" "$CONF"
        echo "✅ Log level set to $2"
        shift 2
        ;;
      --allow)
        echo "Allow $2" | sudo tee -a "$CONF" >/dev/null
        echo "✅ Added allow rule: $2"
        shift 2
        ;;
      --connect-port)
        echo "ConnectPort $2" | sudo tee -a "$CONF" >/dev/null
        echo "✅ Added ConnectPort $2"
        shift 2
        ;;
      --upstream)
        if grep -q "^upstream " "$CONF"; then
          sudo sed -i "s|^upstream .*|upstream $2|" "$CONF"
        else
          echo "upstream $2" | sudo tee -a "$CONF" >/dev/null
        fi
        echo "✅ Upstream proxy set to $2"
        shift 2
        ;;
      --anonymous)
        # Add anonymous headers to strip identifying info
        for header in "Host" "User-Agent" "Referer" "Cookie"; do
          if ! grep -q "^DisableViaHeader" "$CONF"; then
            echo "DisableViaHeader Yes" | sudo tee -a "$CONF" >/dev/null
          fi
        done
        echo "✅ Anonymous mode enabled (Via header disabled)"
        shift
        ;;
      --no-anonymous)
        sudo sed -i '/^DisableViaHeader/d' "$CONF"
        echo "✅ Anonymous mode disabled"
        shift
        ;;
      --add-header)
        echo "AddHeader \"$2\"" | sudo tee -a "$CONF" >/dev/null
        echo "✅ Added header: $2"
        shift 2
        ;;
      *)
        echo "Unknown config option: $1"
        shift
        ;;
    esac
  done
}

cmd_block() {
  local domain=""
  local file=""
  
  shift 2>/dev/null || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --domain) domain="$2"; shift 2 ;;
      --file) file="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local filterfile="/etc/tinyproxy/filter"
  
  # Enable filter if not already
  if [ -n "$CONF" ] && ! grep -q "^Filter " "$CONF"; then
    echo "Filter \"$filterfile\"" | sudo tee -a "$CONF" >/dev/null
    echo "FilterURLs On" | sudo tee -a "$CONF" >/dev/null
    echo "FilterDefaultDeny No" | sudo tee -a "$CONF" >/dev/null
  fi
  
  sudo touch "$filterfile"
  
  if [ -n "$domain" ]; then
    echo "$domain" | sudo tee -a "$filterfile" >/dev/null
    echo "✅ Blocked: $domain"
  fi
  
  if [ -n "$file" ] && [ -f "$file" ]; then
    cat "$file" | sudo tee -a "$filterfile" >/dev/null
    local count=$(wc -l < "$file")
    echo "✅ Added $count domains from $file"
  fi
  
  # Deduplicate
  sudo sort -u -o "$filterfile" "$filterfile"
  echo "📋 Total blocked domains: $(wc -l < "$filterfile")"
}

cmd_allow_deny() {
  local action="$1"
  local ip=""
  local subnet=""
  shift
  
  while [ $# -gt 0 ]; do
    case "$1" in
      --ip) ip="$2"; shift 2 ;;
      --subnet) subnet="$2"; shift 2 ;;
      --list)
        grep -i "^Allow " "$CONF" 2>/dev/null || echo "No allow rules found"
        return
        ;;
      *) shift ;;
    esac
  done
  
  local target="${ip:-$subnet}"
  if [ -z "$target" ]; then
    echo "Usage: $0 $action --ip <IP> or --subnet <CIDR>"
    exit 1
  fi
  
  if [ "$action" = "allow" ]; then
    echo "Allow $target" | sudo tee -a "$CONF" >/dev/null
    echo "✅ Allowed: $target"
  else
    sudo sed -i "/^Allow ${target//\//\\/}$/d" "$CONF"
    echo "✅ Removed allow rule: $target"
  fi
}

cmd_edit() {
  ${EDITOR:-nano} "$CONF"
}

cmd_acl() {
  shift 2>/dev/null || true
  case "${1:-}" in
    --list)
      echo "📋 Access Control List:"
      grep -i "^Allow " "$CONF" 2>/dev/null || echo "  No allow rules (default: localhost only)"
      ;;
    *)
      echo "Usage: $0 acl --list"
      ;;
  esac
}

# Main dispatch
ACTION="${1:-help}"

case "$ACTION" in
  start)     cmd_start ;;
  stop)      cmd_stop ;;
  restart)   cmd_restart ;;
  reload)    cmd_reload ;;
  status)    cmd_status ;;
  health)    cmd_health ;;
  enable)    cmd_enable ;;
  disable)   cmd_disable ;;
  foreground) cmd_foreground ;;
  logs)      cmd_logs "$@" ;;
  stats)     cmd_stats ;;
  config)    cmd_config "$@" ;;
  block)     cmd_block "$@" ;;
  allow)     cmd_allow_deny "allow" "$@" ;;
  deny)      cmd_allow_deny "deny" "$@" ;;
  edit)      cmd_edit ;;
  acl)       cmd_acl "$@" ;;
  help|--help|-h)
    echo "Tinyproxy Manager"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start        Start tinyproxy"
    echo "  stop         Stop tinyproxy"
    echo "  restart      Restart tinyproxy"
    echo "  reload       Reload configuration"
    echo "  status       Show running status"
    echo "  health       Run health check"
    echo "  enable       Enable auto-start on boot"
    echo "  disable      Disable auto-start"
    echo "  foreground   Run in foreground"
    echo "  logs         View logs (--follow, --grep, --lines)"
    echo "  stats        Show request statistics"
    echo "  config       Manage configuration"
    echo "  block        Block domains (--domain, --file)"
    echo "  allow        Add allow rule (--ip, --subnet)"
    echo "  deny         Remove allow rule (--ip)"
    echo "  acl          Show access control list (--list)"
    echo "  edit         Open config in editor"
    ;;
  *)
    echo "Unknown command: $ACTION"
    echo "Run '$0 help' for usage"
    exit 1
    ;;
esac
