#!/bin/bash
# MySQL/MariaDB Performance Tuning Script
set -euo pipefail

MYSQL_CMD="mysql"
MYSQL_ARGS=""
[[ -n "${MYSQL_HOST:-}" ]] && MYSQL_ARGS+=" -h $MYSQL_HOST"
[[ -n "${MYSQL_PORT:-}" ]] && MYSQL_ARGS+=" -P $MYSQL_PORT"
[[ -n "${MYSQL_USER:-}" ]] && MYSQL_ARGS+=" -u $MYSQL_USER"
[[ -n "${MYSQL_PASSWORD:-}" ]] && MYSQL_ARGS+=" -p$MYSQL_PASSWORD"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
run_sql() { $MYSQL_CMD $MYSQL_ARGS -N -e "$1" 2>/dev/null; }

get_total_ram_mb() {
  grep MemTotal /proc/meminfo | awk '{print int($2/1024)}'
}

parse_ram() {
  local ram="$1"
  case "$ram" in
    *G|*g) echo $(( ${ram%[Gg]} * 1024 )) ;;
    *M|*m) echo "${ram%[Mm]}" ;;
    auto)  get_total_ram_mb ;;
    *)     echo "$ram" ;;
  esac
}

calculate_settings() {
  local ram_mb="$1"
  local workload="${2:-mixed}"

  # InnoDB buffer pool: 50-70% of RAM depending on workload
  local bp_pct
  case "$workload" in
    oltp) bp_pct=70 ;;
    olap) bp_pct=60 ;;
    mixed) bp_pct=50 ;;
  esac
  local buffer_pool=$(( ram_mb * bp_pct / 100 ))

  # Buffer pool instances (1 per GB, max 64)
  local bp_instances=$(( buffer_pool / 1024 ))
  [[ $bp_instances -lt 1 ]] && bp_instances=1
  [[ $bp_instances -gt 64 ]] && bp_instances=64

  # Log file size (25% of buffer pool, max 2G)
  local log_file=$(( buffer_pool / 4 ))
  [[ $log_file -gt 2048 ]] && log_file=2048
  [[ $log_file -lt 48 ]] && log_file=48

  # Max connections based on RAM
  local max_conn
  if [[ $ram_mb -lt 1024 ]]; then max_conn=100
  elif [[ $ram_mb -lt 4096 ]]; then max_conn=200
  elif [[ $ram_mb -lt 16384 ]]; then max_conn=500
  else max_conn=1000
  fi

  # Thread cache
  local thread_cache=$(( max_conn / 4 ))
  [[ $thread_cache -gt 100 ]] && thread_cache=100

  # Table open cache
  local table_cache=$(( max_conn * 4 ))
  [[ $table_cache -gt 10000 ]] && table_cache=10000

  # Tmp table size
  local tmp_table=$(( ram_mb / 16 ))
  [[ $tmp_table -gt 256 ]] && tmp_table=256
  [[ $tmp_table -lt 16 ]] && tmp_table=16

  # Sort/join buffer
  local sort_buf=2
  local join_buf=2
  if [[ "$workload" == "olap" ]]; then
    sort_buf=8
    join_buf=8
  fi

  echo "BUFFER_POOL=${buffer_pool}M"
  echo "BP_INSTANCES=$bp_instances"
  echo "LOG_FILE=${log_file}M"
  echo "MAX_CONN=$max_conn"
  echo "THREAD_CACHE=$thread_cache"
  echo "TABLE_CACHE=$table_cache"
  echo "TMP_TABLE=${tmp_table}M"
  echo "SORT_BUF=${sort_buf}M"
  echo "JOIN_BUF=${join_buf}M"
}

apply_tuning() {
  local ram_mb="$1"
  local workload="${2:-mixed}"

  log "Tuning for ${ram_mb}MB RAM, workload: $workload"

  eval $(calculate_settings "$ram_mb" "$workload")

  # Detect config directory
  local conf_dir
  if [ -d /etc/mysql/conf.d ]; then conf_dir="/etc/mysql/conf.d"
  elif [ -d /etc/my.cnf.d ]; then conf_dir="/etc/my.cnf.d"
  else conf_dir="/etc/mysql/conf.d"; sudo mkdir -p "$conf_dir"
  fi

  local conf_file="$conf_dir/zzz-tuned.cnf"

  sudo tee "$conf_file" > /dev/null << EOF
# MySQL Tuning — Generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
# RAM: ${ram_mb}MB | Workload: $workload
[mysqld]
# InnoDB
innodb_buffer_pool_size = $BUFFER_POOL
innodb_buffer_pool_instances = $BP_INSTANCES
innodb_log_file_size = $LOG_FILE
innodb_flush_log_at_trx_commit = 1
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_io_capacity = 200
innodb_io_capacity_max = 2000

# Connections
max_connections = $MAX_CONN
thread_cache_size = $THREAD_CACHE
table_open_cache = $TABLE_CACHE

# Memory per-thread
tmp_table_size = $TMP_TABLE
max_heap_table_size = $TMP_TABLE
sort_buffer_size = $SORT_BUF
join_buffer_size = $JOIN_BUF
read_buffer_size = 256K
read_rnd_buffer_size = 512K

# Query cache (disabled in MySQL 8+, used in MariaDB/5.7)
query_cache_type = 0
query_cache_size = 0

# Logging
slow_query_log = 1
long_query_time = 2
log_queries_not_using_indexes = 0

# Networking
max_allowed_packet = 64M
wait_timeout = 600
interactive_timeout = 600

# Binary logging (for replication readiness)
# log_bin = /var/log/mysql/mysql-bin.log
# expire_logs_days = 7
EOF

  log "📝 Config written to $conf_file"
  log "Settings:"
  echo "  InnoDB Buffer Pool: $BUFFER_POOL ($BP_INSTANCES instances)"
  echo "  Log File Size:      $LOG_FILE"
  echo "  Max Connections:    $MAX_CONN"
  echo "  Thread Cache:       $THREAD_CACHE"
  echo "  Table Cache:        $TABLE_CACHE"
  echo "  Tmp Table Size:     $TMP_TABLE"
  echo "  Sort Buffer:        $SORT_BUF"
  echo "  Join Buffer:        $JOIN_BUF"

  # Restart
  log "Restarting MySQL..."
  sudo systemctl restart mysql 2>/dev/null || sudo systemctl restart mariadb 2>/dev/null || sudo service mysql restart 2>/dev/null
  log "✅ Tuning applied and MySQL restarted"
}

show_diff() {
  local ram_mb=$(get_total_ram_mb)
  eval $(calculate_settings "$ram_mb" "mixed")

  log "Current vs Recommended (${ram_mb}MB RAM, mixed workload):"
  echo ""
  printf "%-35s %-15s %-15s\n" "Setting" "Current" "Recommended"
  printf "%-35s %-15s %-15s\n" "-------" "-------" "-----------"

  local current_bp=$(run_sql "SELECT @@innodb_buffer_pool_size / 1024 / 1024;" | tr -d ' ')
  local current_conn=$(run_sql "SELECT @@max_connections;" | tr -d ' ')
  local current_tc=$(run_sql "SELECT @@thread_cache_size;" | tr -d ' ')
  local current_toc=$(run_sql "SELECT @@table_open_cache;" | tr -d ' ')

  printf "%-35s %-15s %-15s\n" "innodb_buffer_pool_size" "${current_bp}M" "$BUFFER_POOL"
  printf "%-35s %-15s %-15s\n" "max_connections" "$current_conn" "$MAX_CONN"
  printf "%-35s %-15s %-15s\n" "thread_cache_size" "$current_tc" "$THREAD_CACHE"
  printf "%-35s %-15s %-15s\n" "table_open_cache" "$current_toc" "$TABLE_CACHE"
}

# Parse arguments
ACTION="${1:-help}"
RAM="auto"
WORKLOAD="mixed"
MAX_CONN_OVERRIDE=""

shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --ram) RAM="$2"; shift 2 ;;
    --type) WORKLOAD="$2"; shift 2 ;;
    --max-connections) MAX_CONN_OVERRIDE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

case "$ACTION" in
  auto)
    RAM_MB=$(parse_ram "${RAM}")
    apply_tuning "$RAM_MB" "$WORKLOAD"
    ;;
  --diff)
    show_diff
    ;;
  --max-connections)
    [[ -n "$MAX_CONN_OVERRIDE" ]] || { echo "Usage: tune.sh --max-connections N"; exit 1; }
    run_sql "SET GLOBAL max_connections = $MAX_CONN_OVERRIDE;"
    log "✅ max_connections set to $MAX_CONN_OVERRIDE (runtime only)"
    ;;
  *)
    echo "MySQL Tuner"
    echo ""
    echo "Usage:"
    echo "  bash tune.sh auto                        Auto-tune based on system RAM"
    echo "  bash tune.sh auto --ram 4G --type oltp   Tune for 4GB RAM, OLTP workload"
    echo "  bash tune.sh auto --type olap             Tune for analytics workload"
    echo "  bash tune.sh --diff                       Show current vs recommended"
    echo "  bash tune.sh --max-connections 500         Set max connections (runtime)"
    echo ""
    echo "Workload types: oltp (transactional), olap (analytics), mixed (default)"
    ;;
esac
