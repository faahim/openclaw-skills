#!/bin/bash
# MySQL/MariaDB Health Check Script
set -euo pipefail

MYSQL_CMD="mysql"
MYSQL_ARGS=""
[[ -n "${MYSQL_HOST:-}" ]] && MYSQL_ARGS+=" -h $MYSQL_HOST"
[[ -n "${MYSQL_PORT:-}" ]] && MYSQL_ARGS+=" -P $MYSQL_PORT"
[[ -n "${MYSQL_USER:-}" ]] && MYSQL_ARGS+=" -u $MYSQL_USER"
[[ -n "${MYSQL_PASSWORD:-}" ]] && MYSQL_ARGS+=" -p$MYSQL_PASSWORD"

JSON_MODE=false
CHECK=""

log() { [[ "$JSON_MODE" == "false" ]] && echo "$1"; }
run_sql() { $MYSQL_CMD $MYSQL_ARGS -N -e "$1" 2>/dev/null; }

check_connections() {
  local max=$(run_sql "SELECT @@max_connections;")
  local current=$(run_sql "SELECT COUNT(*) FROM information_schema.processlist;")
  local pct=$(( current * 100 / max ))

  if [[ "$JSON_MODE" == "true" ]]; then
    echo "\"connections\": {\"current\": $current, \"max\": $max, \"percent\": $pct}"
  else
    local status="✅"
    [[ $pct -gt 80 ]] && status="⚠️"
    [[ $pct -gt 95 ]] && status="❌"
    echo "$status Connections: $current / $max ($pct%)"
  fi
}

check_uptime() {
  local seconds=$(run_sql "SELECT VARIABLE_VALUE FROM information_schema.global_status WHERE VARIABLE_NAME='Uptime';")
  local days=$(( seconds / 86400 ))
  local hours=$(( (seconds % 86400) / 3600 ))

  if [[ "$JSON_MODE" == "true" ]]; then
    echo "\"uptime\": {\"seconds\": $seconds, \"days\": $days}"
  else
    echo "⏱️  Uptime: ${days}d ${hours}h"
  fi
}

check_buffer_pool() {
  local total=$(run_sql "SELECT @@innodb_buffer_pool_size / 1024 / 1024;")
  local used=$(run_sql "SELECT VARIABLE_VALUE FROM information_schema.global_status WHERE VARIABLE_NAME='Innodb_buffer_pool_bytes_data';" 2>/dev/null)
  used=${used:-0}
  local used_mb=$(( used / 1024 / 1024 ))
  local total_int=${total%.*}

  if [[ "$JSON_MODE" == "true" ]]; then
    echo "\"buffer_pool\": {\"total_mb\": $total_int, \"used_mb\": $used_mb}"
  else
    local pct=0
    [[ $total_int -gt 0 ]] && pct=$(( used_mb * 100 / total_int ))
    echo "🧠 Buffer Pool: ${used_mb}MB / ${total_int}MB ($pct% used)"
  fi
}

check_slow_queries() {
  local slow_enabled=$(run_sql "SELECT @@slow_query_log;")
  local slow_count=$(run_sql "SELECT VARIABLE_VALUE FROM information_schema.global_status WHERE VARIABLE_NAME='Slow_queries';")
  local threshold=$(run_sql "SELECT @@long_query_time;")

  if [[ "$JSON_MODE" == "true" ]]; then
    echo "\"slow_queries\": {\"enabled\": $slow_enabled, \"count\": $slow_count, \"threshold\": $threshold}"
  else
    if [[ "$slow_enabled" == "1" ]]; then
      echo "🐌 Slow Queries: $slow_count (threshold: ${threshold}s)"

      # Show top slow queries if log exists
      local log_file=$(run_sql "SELECT @@slow_query_log_file;" 2>/dev/null)
      if [[ -f "$log_file" ]] && [[ -r "$log_file" ]]; then
        local top="${1:-10}"
        echo "   Top $top slow queries:"
        sudo grep -A2 "^# Query_time" "$log_file" 2>/dev/null | tail -$(( top * 3 )) | head -$(( top * 3 ))
      fi
    else
      echo "🐌 Slow Query Log: DISABLED"
    fi
  fi
}

check_replication() {
  local slave_status=$(run_sql "SHOW SLAVE STATUS\G" 2>/dev/null || run_sql "SHOW REPLICA STATUS\G" 2>/dev/null)

  if [[ -z "$slave_status" ]]; then
    if [[ "$JSON_MODE" == "true" ]]; then
      echo "\"replication\": {\"role\": \"standalone\"}"
    else
      echo "🔗 Replication: Not configured"
    fi
    return
  fi

  local io_running=$(echo "$slave_status" | grep "Slave_IO_Running" | awk '{print $2}')
  local sql_running=$(echo "$slave_status" | grep "Slave_SQL_Running:" | awk '{print $2}')
  local lag=$(echo "$slave_status" | grep "Seconds_Behind_Master" | awk '{print $2}')

  if [[ "$JSON_MODE" == "true" ]]; then
    echo "\"replication\": {\"io_running\": \"$io_running\", \"sql_running\": \"$sql_running\", \"lag_seconds\": $lag}"
  else
    local status="✅"
    [[ "$io_running" != "Yes" || "$sql_running" != "Yes" ]] && status="❌"
    [[ "${lag:-0}" -gt 60 ]] && status="⚠️"
    echo "$status Replication: IO=$io_running SQL=$sql_running Lag=${lag}s"
  fi
}

check_disk() {
  local datadir=$(run_sql "SELECT @@datadir;")
  local disk_info=$(df -h "$datadir" 2>/dev/null | tail -1)
  local used_pct=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')
  local avail=$(echo "$disk_info" | awk '{print $4}')

  if [[ "$JSON_MODE" == "true" ]]; then
    echo "\"disk\": {\"used_percent\": $used_pct, \"available\": \"$avail\", \"datadir\": \"$datadir\"}"
  else
    local status="✅"
    [[ $used_pct -gt 80 ]] && status="⚠️"
    [[ $used_pct -gt 95 ]] && status="❌"
    echo "$status Disk: ${used_pct}% used ($avail free) — $datadir"
  fi
}

check_version() {
  local ver=$(run_sql "SELECT VERSION();")
  if [[ "$JSON_MODE" == "true" ]]; then
    echo "\"version\": \"$ver\""
  else
    echo "📦 Version: $ver"
  fi
}

check_qps() {
  local questions=$(run_sql "SELECT VARIABLE_VALUE FROM information_schema.global_status WHERE VARIABLE_NAME='Questions';")
  local uptime=$(run_sql "SELECT VARIABLE_VALUE FROM information_schema.global_status WHERE VARIABLE_NAME='Uptime';")
  local qps=$(( questions / uptime ))

  if [[ "$JSON_MODE" == "true" ]]; then
    echo "\"qps\": $qps"
  else
    echo "⚡ Queries/sec: $qps (avg)"
  fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --json)         JSON_MODE=true; shift ;;
    --connections)  CHECK="connections"; shift ;;
    --slow-queries) CHECK="slow"; shift ;;
    --replication)  CHECK="replication"; shift ;;
    --disk)         CHECK="disk"; shift ;;
    --top)          TOP="$2"; shift 2 ;;
    *)              shift ;;
  esac
done

if [[ "$JSON_MODE" == "true" ]]; then
  echo "{"
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  check_version | sed 's/^/  /; s/$/, /'
  check_connections | sed 's/^/  /; s/$/, /'
  check_uptime | sed 's/^/  /; s/$/, /'
  check_buffer_pool | sed 's/^/  /; s/$/, /'
  check_slow_queries | sed 's/^/  /; s/$/, /'
  check_qps | sed 's/^/  /'
  echo ""
  echo "}"
elif [[ -n "$CHECK" ]]; then
  case "$CHECK" in
    connections) check_connections ;;
    slow)        check_slow_queries "${TOP:-10}" ;;
    replication) check_replication ;;
    disk)        check_disk ;;
  esac
else
  echo "═══════════════════════════════════"
  echo "  MySQL Health Check"
  echo "  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "═══════════════════════════════════"
  echo ""
  check_version
  check_uptime
  check_connections
  check_buffer_pool
  check_qps
  check_slow_queries
  check_replication
  check_disk
  echo ""
  echo "═══════════════════════════════════"
fi
