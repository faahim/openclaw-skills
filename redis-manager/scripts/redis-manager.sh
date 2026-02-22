#!/bin/bash
# Redis Manager — Main Script
# Usage: bash redis-manager.sh <command> [options]

set -euo pipefail

# ── Defaults ──────────────────────────────────────
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
CONFIG_DIR="$HOME/.redis-manager"
CREDENTIALS_FILE="$CONFIG_DIR/credentials"

# Load password from credentials file if not set
if [[ -z "$REDIS_PASSWORD" && -f "$CREDENTIALS_FILE" ]]; then
  REDIS_PASSWORD=$(cat "$CREDENTIALS_FILE" 2>/dev/null || true)
fi

# ── Helpers ───────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

log() { echo -e "${GREEN}✅${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
err() { echo -e "${RED}❌${NC} $1" >&2; }

rcli() {
  local auth_args=()
  [[ -n "$REDIS_PASSWORD" ]] && auth_args=(-a "$REDIS_PASSWORD" --no-auth-warning)
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" "${auth_args[@]}" "$@"
}

require_redis() {
  if ! command -v redis-cli &>/dev/null; then
    err "redis-cli not found. Run: bash scripts/install.sh"
    exit 1
  fi
  if ! rcli ping 2>/dev/null | grep -q PONG; then
    err "Cannot connect to Redis at $REDIS_HOST:$REDIS_PORT"
    exit 1
  fi
}

human_bytes() {
  local bytes=$1
  if (( bytes >= 1073741824 )); then
    printf "%.2f GB" "$(echo "scale=2; $bytes/1073741824" | bc)"
  elif (( bytes >= 1048576 )); then
    printf "%.2f MB" "$(echo "scale=2; $bytes/1048576" | bc)"
  elif (( bytes >= 1024 )); then
    printf "%.2f KB" "$(echo "scale=2; $bytes/1024" | bc)"
  else
    printf "%d B" "$bytes"
  fi
}

# ── Commands ──────────────────────────────────────

cmd_status() {
  require_redis
  local info
  info=$(rcli INFO all 2>/dev/null)
  
  local version=$(echo "$info" | grep "^redis_version:" | cut -d: -f2 | tr -d '\r')
  local uptime_sec=$(echo "$info" | grep "^uptime_in_seconds:" | cut -d: -f2 | tr -d '\r')
  local mode=$(echo "$info" | grep "^redis_mode:" | cut -d: -f2 | tr -d '\r')
  local port=$(echo "$info" | grep "^tcp_port:" | cut -d: -f2 | tr -d '\r')
  local pid=$(echo "$info" | grep "^process_id:" | cut -d: -f2 | tr -d '\r')
  local mem_used=$(echo "$info" | grep "^used_memory:" | cut -d: -f2 | tr -d '\r')
  local mem_max=$(echo "$info" | grep "^maxmemory:" | cut -d: -f2 | tr -d '\r')
  local total_keys=$(rcli DBSIZE 2>/dev/null | grep -oP '\d+')
  local clients=$(echo "$info" | grep "^connected_clients:" | cut -d: -f2 | tr -d '\r')
  local ops=$(echo "$info" | grep "^instantaneous_ops_per_sec:" | cut -d: -f2 | tr -d '\r')
  local hits=$(echo "$info" | grep "^keyspace_hits:" | cut -d: -f2 | tr -d '\r')
  local misses=$(echo "$info" | grep "^keyspace_misses:" | cut -d: -f2 | tr -d '\r')
  local rdb_status=$(echo "$info" | grep "^rdb_last_bgsave_status:" | cut -d: -f2 | tr -d '\r')
  local rdb_time=$(echo "$info" | grep "^rdb_last_save_time:" | cut -d: -f2 | tr -d '\r')
  local aof_enabled=$(echo "$info" | grep "^aof_enabled:" | cut -d: -f2 | tr -d '\r')

  # Calculate uptime
  local days=$((uptime_sec / 86400))
  local hours=$(( (uptime_sec % 86400) / 3600 ))
  local mins=$(( (uptime_sec % 3600) / 60 ))
  local secs=$((uptime_sec % 60))
  local uptime_str="${days}d ${hours}h ${mins}m ${secs}s"

  # Memory display
  local mem_used_h=$(human_bytes "$mem_used")
  local mem_pct="∞"
  local mem_max_h="unlimited"
  if [[ "$mem_max" -gt 0 ]]; then
    mem_max_h=$(human_bytes "$mem_max")
    mem_pct=$(echo "scale=1; $mem_used * 100 / $mem_max" | bc)"%"
  fi

  # Hit rate
  local hit_rate="N/A"
  if [[ "$hits" -gt 0 || "$misses" -gt 0 ]]; then
    local total_access=$((hits + misses))
    if [[ "$total_access" -gt 0 ]]; then
      hit_rate=$(echo "scale=1; $hits * 100 / $total_access" | bc)"%"
    fi
  fi

  # RDB age
  local rdb_age_str="never"
  if [[ -n "$rdb_time" && "$rdb_time" -gt 0 ]]; then
    local now=$(date +%s)
    local rdb_age=$((now - rdb_time))
    if [[ $rdb_age -lt 60 ]]; then
      rdb_age_str="${rdb_age}s ago"
    elif [[ $rdb_age -lt 3600 ]]; then
      rdb_age_str="$((rdb_age / 60))m ago"
    else
      rdb_age_str="$((rdb_age / 3600))h ago"
    fi
  fi

  local aof_str="disabled"
  [[ "$aof_enabled" == "1" ]] && aof_str="enabled"

  echo -e "${BOLD}Redis Status${NC}"
  echo "════════════════════════════════════════"
  echo -e "  Version:      ${CYAN}${version}${NC}"
  echo -e "  Uptime:       ${uptime_str}"
  echo -e "  Mode:         ${mode}"
  echo -e "  Port:         ${port}"
  echo -e "  PID:          ${pid}"
  echo -e "  Memory Used:  ${mem_used_h} / ${mem_max_h} (${mem_pct})"
  echo -e "  Keys:         ${total_keys}"
  echo -e "  Clients:      ${clients} connected"
  echo -e "  Ops/sec:      ${ops}"
  echo -e "  Hit Rate:     ${hit_rate}"
  echo -e "  RDB Status:   Last save ${rdb_age_str} (${rdb_status})"
  echo -e "  AOF Status:   ${aof_str}"
  echo "════════════════════════════════════════"
}

cmd_health() {
  require_redis
  local quiet=false
  local alert_memory=0
  local alert_cmd=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --quiet) quiet=true; shift ;;
      --alert-memory) alert_memory=$2; shift 2 ;;
      --alert-cmd) alert_cmd="$2"; shift 2 ;;
      --verbose) shift ;; # reserved
      *) shift ;;
    esac
  done

  local info=$(rcli INFO all 2>/dev/null)
  local mem_used=$(echo "$info" | grep "^used_memory:" | cut -d: -f2 | tr -d '\r')
  local mem_max=$(echo "$info" | grep "^maxmemory:" | cut -d: -f2 | tr -d '\r')
  local total_keys=$(rcli DBSIZE 2>/dev/null | grep -oP '\d+')
  local ops=$(echo "$info" | grep "^instantaneous_ops_per_sec:" | cut -d: -f2 | tr -d '\r')
  local hits=$(echo "$info" | grep "^keyspace_hits:" | cut -d: -f2 | tr -d '\r')
  local misses=$(echo "$info" | grep "^keyspace_misses:" | cut -d: -f2 | tr -d '\r')

  local mem_pct=0
  if [[ "$mem_max" -gt 0 ]]; then
    mem_pct=$(echo "scale=1; $mem_used * 100 / $mem_max" | bc)
  fi

  local hit_rate="N/A"
  local total_access=$((hits + misses))
  if [[ "$total_access" -gt 0 ]]; then
    hit_rate=$(echo "scale=1; $hits * 100 / $total_access" | bc)"%"
  fi

  local mem_h=$(human_bytes "$mem_used")
  local mem_max_h="unlimited"
  [[ "$mem_max" -gt 0 ]] && mem_max_h=$(human_bytes "$mem_max")

  local status_icon="✅"
  if [[ "$mem_max" -gt 0 ]]; then
    local pct_int=${mem_pct%.*}
    [[ "$pct_int" -ge 90 ]] && status_icon="🔴"
    [[ "$pct_int" -ge 70 && "$pct_int" -lt 90 ]] && status_icon="⚠️"
  fi

  local ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[${ts}] ${status_icon} Memory: ${mem_h} / ${mem_max_h} (${mem_pct}%) | Keys: ${total_keys} | Ops/s: ${ops} | Hit: ${hit_rate}"

  # Alert check
  if [[ "$alert_memory" -gt 0 && "$mem_max" -gt 0 ]]; then
    local pct_int=${mem_pct%.*}
    if [[ "$pct_int" -ge "$alert_memory" ]]; then
      export MEMORY_PCT="$mem_pct"
      if [[ -n "$alert_cmd" ]]; then
        eval "$alert_cmd"
        echo "🚨 Alert sent: Redis memory at ${mem_pct}%"
      else
        echo "🚨 ALERT: Redis memory at ${mem_pct}% (threshold: ${alert_memory}%)"
      fi
    fi
  fi
}

cmd_monitor() {
  local interval=30
  local alert_memory=0
  local alert_cmd=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --interval) interval=$2; shift 2 ;;
      --alert-memory) alert_memory=$2; shift 2 ;;
      --alert-cmd) alert_cmd="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  echo "Monitoring Redis every ${interval}s (Ctrl+C to stop)"
  echo ""
  while true; do
    cmd_health --alert-memory "$alert_memory" --alert-cmd "$alert_cmd"
    sleep "$interval"
  done
}

cmd_config() {
  require_redis
  local maxmemory=""
  local eviction=""
  local slowlog_threshold=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --maxmemory) maxmemory=$2; shift 2 ;;
      --eviction) eviction=$2; shift 2 ;;
      --slowlog-threshold) slowlog_threshold=$2; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -n "$maxmemory" ]]; then
    rcli CONFIG SET maxmemory "$maxmemory" >/dev/null
    log "maxmemory set to $maxmemory"
  fi

  if [[ -n "$eviction" ]]; then
    rcli CONFIG SET maxmemory-policy "$eviction" >/dev/null
    log "eviction policy set to $eviction"
  fi

  if [[ -n "$slowlog_threshold" ]]; then
    rcli CONFIG SET slowlog-log-slower-than "$slowlog_threshold" >/dev/null
    log "slowlog threshold set to ${slowlog_threshold}μs"
  fi

  # Persist config changes
  rcli CONFIG REWRITE >/dev/null 2>&1 || warn "Could not persist config (CONFIG REWRITE failed — manual save needed)"
}

cmd_harden() {
  require_redis
  local password=""
  local bind_addr=""
  local disable_cmds=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --password) password=$2; shift 2 ;;
      --bind) bind_addr=$2; shift 2 ;;
      --disable-commands) disable_cmds=$2; shift 2 ;;
      *) shift ;;
    esac
  done

  mkdir -p "$CONFIG_DIR"

  if [[ -n "$password" ]]; then
    rcli CONFIG SET requirepass "$password" >/dev/null
    echo "$password" > "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"
    REDIS_PASSWORD="$password"
    log "Password set (saved to $CREDENTIALS_FILE)"
  fi

  if [[ -n "$bind_addr" ]]; then
    rcli CONFIG SET bind "$bind_addr" >/dev/null 2>&1 || warn "bind requires redis.conf edit + restart"
    log "Bind address: $bind_addr"
  fi

  if [[ -n "$disable_cmds" ]]; then
    # Disabling commands requires redis.conf editing
    local conf_file=$(rcli CONFIG GET dir 2>/dev/null | tail -1)/redis.conf
    if [[ -f "$conf_file" || -f /etc/redis/redis.conf ]]; then
      [[ ! -f "$conf_file" ]] && conf_file="/etc/redis/redis.conf"
      for cmd in $disable_cmds; do
        if ! grep -q "rename-command $cmd" "$conf_file" 2>/dev/null; then
          echo "rename-command $cmd \"\"" | sudo tee -a "$conf_file" >/dev/null
        fi
      done
      log "Disabled commands: $disable_cmds"
      warn "Restart Redis to apply: sudo systemctl restart redis-server"
    else
      warn "Could not find redis.conf — disable commands manually"
    fi
  fi

  rcli CONFIG REWRITE >/dev/null 2>&1 || true
}

cmd_backup() {
  require_redis
  local output="/tmp/redis-backup"
  local s3_bucket=""
  local s3_prefix="redis/"
  local list_mode=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --output) output=$2; shift 2 ;;
      --s3-bucket) s3_bucket=$2; shift 2 ;;
      --s3-prefix) s3_prefix=$2; shift 2 ;;
      --list) list_mode=true; shift ;;
      *) shift ;;
    esac
  done

  mkdir -p "$output"

  if $list_mode; then
    echo "Available backups in $output:"
    ls -lhS "$output"/dump-*.rdb 2>/dev/null || echo "  (none)"
    return
  fi

  local ts=$(date +%Y-%m-%dT%H%M%S)
  local filename="dump-${ts}.rdb"
  
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Triggering BGSAVE..."
  rcli BGSAVE >/dev/null

  # Wait for save to complete
  local max_wait=60
  local waited=0
  while [[ $waited -lt $max_wait ]]; do
    local saving=$(rcli LASTSAVE 2>/dev/null)
    sleep 2
    local saving2=$(rcli LASTSAVE 2>/dev/null)
    [[ "$saving" != "$saving2" ]] && break
    # Check if already done
    local bg_status=$(rcli INFO persistence 2>/dev/null | grep "rdb_bgsave_in_progress:" | cut -d: -f2 | tr -d '\r')
    [[ "$bg_status" == "0" ]] && break
    waited=$((waited + 2))
  done

  # Find the RDB file
  local redis_dir=$(rcli CONFIG GET dir 2>/dev/null | tail -1)
  local rdb_file=$(rcli CONFIG GET dbfilename 2>/dev/null | tail -1)
  local src="${redis_dir}/${rdb_file}"

  if [[ -f "$src" ]]; then
    cp "$src" "${output}/${filename}"
    local size=$(du -h "${output}/${filename}" | cut -f1)
    log "RDB saved: ${output}/${filename} (${size})"
  else
    err "Could not find RDB file at $src"
    return 1
  fi

  # S3 upload
  if [[ -n "$s3_bucket" ]]; then
    if command -v aws &>/dev/null; then
      aws s3 cp "${output}/${filename}" "s3://${s3_bucket}/${s3_prefix}${filename}" --quiet
      log "Uploaded to s3://${s3_bucket}/${s3_prefix}${filename}"
    else
      warn "AWS CLI not installed — skipping S3 upload"
    fi
  fi
}

cmd_restore() {
  require_redis
  local file=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --file) file=$2; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$file" || ! -f "$file" ]]; then
    err "Backup file not found: $file"
    exit 1
  fi

  local redis_dir=$(rcli CONFIG GET dir 2>/dev/null | tail -1)
  local rdb_file=$(rcli CONFIG GET dbfilename 2>/dev/null | tail -1)
  local target="${redis_dir}/${rdb_file}"

  warn "This will REPLACE the current Redis data!"
  read -p "Continue? [y/N] " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

  # Stop Redis, replace RDB, restart
  echo "Stopping Redis..."
  rcli SHUTDOWN NOSAVE 2>/dev/null || sudo systemctl stop redis-server 2>/dev/null || true
  
  cp "$file" "$target"
  
  echo "Starting Redis..."
  sudo systemctl start redis-server 2>/dev/null || redis-server &
  
  sleep 2
  if rcli ping 2>/dev/null | grep -q PONG; then
    local keys=$(rcli DBSIZE 2>/dev/null | grep -oP '\d+')
    log "Restored from $file ($keys keys loaded)"
  else
    err "Redis failed to start after restore"
  fi
}

cmd_keys() {
  require_redis
  local pattern=""
  local big=0
  local delete=false
  local export_file=""
  local count_mode=false
  local ttl_report=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --count) count_mode=true; pattern=$2; shift 2 ;;
      --big) big=$2; shift 2 ;;
      --delete) delete=true; pattern=$2; shift 2 ;;
      --export) pattern=$2; shift 2 ;;
      --output) export_file=$2; shift 2 ;;
      --ttl-report) ttl_report=true; shift ;;
      *) shift ;;
    esac
  done

  if $count_mode && [[ -n "$pattern" ]]; then
    local count=0
    local total_mem=0
    local cursor=0
    
    while true; do
      local result=$(rcli SCAN "$cursor" MATCH "$pattern" COUNT 1000 2>/dev/null)
      cursor=$(echo "$result" | head -1)
      local keys=$(echo "$result" | tail -n +2)
      
      while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        count=$((count + 1))
        local mem=$(rcli MEMORY USAGE "$key" 2>/dev/null || echo 0)
        total_mem=$((total_mem + mem))
      done <<< "$keys"
      
      [[ "$cursor" == "0" ]] && break
    done

    local mem_h=$(human_bytes "$total_mem")
    echo -e "${BOLD}Key Pattern Analysis: ${pattern}${NC}"
    echo "════════════════════════════════════"
    echo "  Matching Keys:  ${count}"
    echo "  Total Memory:   ${mem_h}"
    echo "════════════════════════════════════"
    return
  fi

  if [[ "$big" -gt 0 ]]; then
    echo -e "${BOLD}Top ${big} Keys by Memory${NC}"
    echo "════════════════════════════════════════════════════"
    
    rcli --bigkeys 2>/dev/null | head -$((big + 20))
    return
  fi

  if $delete && [[ -n "$pattern" ]]; then
    local count=0
    local cursor=0
    
    # Count first
    while true; do
      local result=$(rcli SCAN "$cursor" MATCH "$pattern" COUNT 1000 2>/dev/null)
      cursor=$(echo "$result" | head -1)
      local keys=$(echo "$result" | tail -n +2)
      while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        count=$((count + 1))
      done <<< "$keys"
      [[ "$cursor" == "0" ]] && break
    done

    warn "About to delete $count keys matching '$pattern'"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

    local deleted=0
    cursor=0
    while true; do
      local result=$(rcli SCAN "$cursor" MATCH "$pattern" COUNT 100 2>/dev/null)
      cursor=$(echo "$result" | head -1)
      local keys=$(echo "$result" | tail -n +2)
      while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        rcli DEL "$key" >/dev/null 2>&1
        deleted=$((deleted + 1))
      done <<< "$keys"
      [[ "$cursor" == "0" ]] && break
    done
    log "Deleted $deleted keys matching '$pattern'"
    return
  fi

  if $ttl_report; then
    echo -e "${BOLD}TTL Report${NC}"
    echo "════════════════════════════════════"
    
    local no_ttl=0
    local with_ttl=0
    local expiring_1h=0
    local expiring_24h=0
    local cursor=0
    local sampled=0
    local max_sample=5000

    while true; do
      local result=$(rcli SCAN "$cursor" COUNT 500 2>/dev/null)
      cursor=$(echo "$result" | head -1)
      local keys=$(echo "$result" | tail -n +2)
      while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        sampled=$((sampled + 1))
        local ttl=$(rcli TTL "$key" 2>/dev/null)
        if [[ "$ttl" == "-1" ]]; then
          no_ttl=$((no_ttl + 1))
        elif [[ "$ttl" -gt 0 ]]; then
          with_ttl=$((with_ttl + 1))
          [[ "$ttl" -le 3600 ]] && expiring_1h=$((expiring_1h + 1))
          [[ "$ttl" -le 86400 ]] && expiring_24h=$((expiring_24h + 1))
        fi
        [[ "$sampled" -ge "$max_sample" ]] && break 2
      done <<< "$keys"
      [[ "$cursor" == "0" ]] && break
    done

    echo "  Sampled:          ${sampled} keys"
    echo "  No TTL (persist):  ${no_ttl}"
    echo "  With TTL:          ${with_ttl}"
    echo "  Expiring <1h:      ${expiring_1h}"
    echo "  Expiring <24h:     ${expiring_24h}"
    echo "════════════════════════════════════"
    return
  fi
}

cmd_slowlog() {
  require_redis
  local entries=$(rcli SLOWLOG GET 25 2>/dev/null)
  
  echo -e "${BOLD}Slow Queries (last 25)${NC}"
  echo "═══════════════════════════════════════════════════════"
  
  # Parse slowlog output
  rcli SLOWLOG GET 25 2>/dev/null | while IFS= read -r line; do
    echo "  $line"
  done
  
  echo "═══════════════════════════════════════════════════════"
}

cmd_replication_status() {
  require_redis
  local info=$(rcli INFO replication 2>/dev/null)
  
  echo -e "${BOLD}Replication Status${NC}"
  echo "════════════════════════════════════"
  echo "$info" | grep -E "^(role|connected_slaves|master_|slave)" | while IFS=: read -r key val; do
    printf "  %-25s %s\n" "$key:" "$(echo "$val" | tr -d '\r')"
  done
  echo "════════════════════════════════════"
}

cmd_replicate() {
  require_redis
  local master_host=""
  local master_port="6379"
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --master-host) master_host=$2; shift 2 ;;
      --master-port) master_port=$2; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$master_host" ]]; then
    err "Specify --master-host"
    exit 1
  fi

  rcli REPLICAOF "$master_host" "$master_port" >/dev/null
  log "Configured as replica of $master_host:$master_port"
  sleep 2
  cmd_replication_status
}

# ── Main ──────────────────────────────────────────

usage() {
  echo "Redis Manager"
  echo ""
  echo "Usage: bash redis-manager.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  status              Show Redis instance status"
  echo "  health              One-shot health check"
  echo "  monitor             Continuous monitoring"
  echo "  config              Update Redis configuration"
  echo "  harden              Apply security best practices"
  echo "  backup              Create RDB backup (optional S3 upload)"
  echo "  restore             Restore from RDB backup"
  echo "  keys                Key management (count, big keys, delete, export)"
  echo "  slowlog             Show slow query log"
  echo "  replication-status  Show replication info"
  echo "  replicate           Configure as replica"
  echo ""
  echo "Environment:"
  echo "  REDIS_HOST     (default: 127.0.0.1)"
  echo "  REDIS_PORT     (default: 6379)"
  echo "  REDIS_PASSWORD (or ~/.redis-manager/credentials)"
}

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  status) cmd_status ;;
  health) cmd_health "$@" ;;
  monitor) cmd_monitor "$@" ;;
  config) cmd_config "$@" ;;
  harden) cmd_harden "$@" ;;
  backup) cmd_backup "$@" ;;
  restore) cmd_restore "$@" ;;
  keys) cmd_keys "$@" ;;
  slowlog) cmd_slowlog ;;
  replication-status) cmd_replication_status ;;
  replicate) cmd_replicate "$@" ;;
  *) usage ;;
esac
