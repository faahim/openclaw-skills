#!/bin/bash
# PostgreSQL Tuner — Analyze system resources and generate optimized postgresql.conf
# Based on pgtune algorithms and PostgreSQL best practices

set -euo pipefail

# ── Defaults ──
WORKLOAD="mixed"
RAM_MB=""
CPUS=""
DISK_TYPE=""
MAX_CONN=""
PG_VERSION=""
DIFF_MODE=false
APPLY_MODE=false
OUTPUT_FILE="/tmp/postgresql-tuned.conf"

# ── Parse arguments ──
while [[ $# -gt 0 ]]; do
  case $1 in
    --workload) WORKLOAD="$2"; shift 2 ;;
    --ram) RAM_MB="$2"; shift 2 ;;
    --cpus) CPUS="$2"; shift 2 ;;
    --disk) DISK_TYPE="$2"; shift 2 ;;
    --connections) MAX_CONN="$2"; shift 2 ;;
    --pg-version) PG_VERSION="$2"; shift 2 ;;
    --diff) DIFF_MODE=true; shift ;;
    --apply) APPLY_MODE=true; shift ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 --workload [web|oltp|dw|mixed] [options]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Detect system resources ──
detect_ram() {
  if [[ -n "$RAM_MB" ]]; then echo "$RAM_MB"; return; fi
  if [[ -f /proc/meminfo ]]; then
    awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo
  elif command -v sysctl &>/dev/null; then
    echo $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 ))
  else
    echo "4096"  # fallback 4GB
  fi
}

detect_cpus() {
  if [[ -n "$CPUS" ]]; then echo "$CPUS"; return; fi
  nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "2"
}

detect_disk() {
  if [[ -n "$DISK_TYPE" ]]; then echo "$DISK_TYPE"; return; fi
  # Check if root disk is rotational
  if [[ -f /sys/block/sda/queue/rotational ]]; then
    rot=$(cat /sys/block/sda/queue/rotational 2>/dev/null || echo "0")
    [[ "$rot" == "0" ]] && echo "ssd" || echo "hdd"
  elif [[ -f /sys/block/vda/queue/rotational ]]; then
    rot=$(cat /sys/block/vda/queue/rotational 2>/dev/null || echo "0")
    [[ "$rot" == "0" ]] && echo "ssd" || echo "hdd"
  elif [[ -f /sys/block/nvme0n1/queue/rotational ]]; then
    echo "ssd"
  else
    echo "ssd"  # assume SSD for cloud/VM
  fi
}

detect_pg_version() {
  if [[ -n "$PG_VERSION" ]]; then echo "$PG_VERSION"; return; fi
  if command -v pg_config &>/dev/null; then
    pg_config --version 2>/dev/null | grep -oP '\d+' | head -1
  elif command -v psql &>/dev/null; then
    psql --version 2>/dev/null | grep -oP '\d+' | head -1
  else
    echo "16"  # fallback
  fi
}

find_pg_config_file() {
  # Try common locations
  local paths=(
    "/etc/postgresql/*/main/postgresql.conf"
    "/var/lib/pgsql/*/data/postgresql.conf"
    "/usr/local/pgsql/data/postgresql.conf"
    "/opt/homebrew/var/postgresql@*/postgresql.conf"
  )
  for pattern in "${paths[@]}"; do
    local found
    found=$(ls $pattern 2>/dev/null | tail -1)
    if [[ -n "$found" ]]; then echo "$found"; return; fi
  done
  echo ""
}

# ── Detect everything ──
TOTAL_RAM=$(detect_ram)
CPU_COUNT=$(detect_cpus)
DISK=$(detect_disk)
PG_VER=$(detect_pg_version)
PG_CONF=$(find_pg_config_file)

echo "🔍 System Analysis:"
echo "   RAM: ${TOTAL_RAM} MB | CPUs: ${CPU_COUNT} | Disk: ${DISK}"
echo "   PostgreSQL: ${PG_VER} | Config: ${PG_CONF:-not found}"
echo ""

# ── Calculate parameters based on workload ──

# Convert MB to various units
RAM_KB=$((TOTAL_RAM * 1024))

# shared_buffers: 25% of RAM (max 8GB for most workloads)
calc_shared_buffers() {
  local sb=$((TOTAL_RAM / 4))
  # Cap at 8GB for web/mixed, 16GB for dw
  local max_gb=8192
  [[ "$WORKLOAD" == "dw" ]] && max_gb=16384
  [[ $sb -gt $max_gb ]] && sb=$max_gb
  # Minimum 128MB
  [[ $sb -lt 128 ]] && sb=128
  echo "$sb"
}

# effective_cache_size: 50-75% of RAM
calc_effective_cache() {
  local pct=75
  [[ "$WORKLOAD" == "web" ]] && pct=75
  [[ "$WORKLOAD" == "oltp" ]] && pct=75
  [[ "$WORKLOAD" == "dw" ]] && pct=75
  [[ "$WORKLOAD" == "mixed" ]] && pct=75
  echo $((TOTAL_RAM * pct / 100))
}

# work_mem: depends on workload and connections
calc_work_mem() {
  local conn=${MAX_CONN:-200}
  case $WORKLOAD in
    web)   conn=${MAX_CONN:-200}; echo $(( (TOTAL_RAM * 1024) / conn / 4 )) ;;
    oltp)  conn=${MAX_CONN:-100}; echo $(( (TOTAL_RAM * 1024) / conn / 4 )) ;;
    dw)    conn=${MAX_CONN:-20};  echo $(( (TOTAL_RAM * 1024) / conn / 2 )) ;;
    mixed) conn=${MAX_CONN:-100}; echo $(( (TOTAL_RAM * 1024) / conn / 4 )) ;;
  esac
}

# maintenance_work_mem
calc_maintenance_work_mem() {
  local mwm=$((TOTAL_RAM / 16))
  # Max 2GB
  [[ $mwm -gt 2048 ]] && mwm=2048
  # Min 64MB
  [[ $mwm -lt 64 ]] && mwm=64
  echo "$mwm"
}

# max_connections
calc_max_connections() {
  if [[ -n "$MAX_CONN" ]]; then echo "$MAX_CONN"; return; fi
  case $WORKLOAD in
    web)   echo "200" ;;
    oltp)  echo "100" ;;
    dw)    echo "20" ;;
    mixed) echo "100" ;;
  esac
}

# wal_buffers: 3% of shared_buffers, max 64MB
calc_wal_buffers() {
  local sb=$(calc_shared_buffers)
  local wb=$((sb * 3 / 100))
  [[ $wb -gt 64 ]] && wb=64
  [[ $wb -lt 4 ]] && wb=4
  echo "$wb"
}

# Parallel workers
calc_parallel_workers() {
  local pw=$((CPU_COUNT > 8 ? 8 : CPU_COUNT))
  [[ $pw -lt 2 ]] && pw=2
  echo "$pw"
}

calc_parallel_per_gather() {
  local pg=$((CPU_COUNT / 2))
  [[ $pg -gt 4 ]] && pg=4
  [[ $pg -lt 1 ]] && pg=1
  [[ "$WORKLOAD" == "dw" ]] && pg=$((CPU_COUNT > 4 ? 4 : CPU_COUNT))
  echo "$pg"
}

# ── Format values ──
format_mb() {
  local mb=$1
  if [[ $mb -ge 1024 ]]; then
    echo "$((mb / 1024))GB"
  else
    echo "${mb}MB"
  fi
}

format_kb() {
  local kb=$1
  if [[ $kb -ge 1048576 ]]; then
    echo "$((kb / 1048576))GB"
  elif [[ $kb -ge 1024 ]]; then
    echo "$((kb / 1024))MB"
  else
    echo "${kb}kB"
  fi
}

# ── Calculate all values ──
SHARED_BUFFERS=$(calc_shared_buffers)
EFFECTIVE_CACHE=$(calc_effective_cache)
WORK_MEM=$(calc_work_mem)
MAINT_WORK_MEM=$(calc_maintenance_work_mem)
MAX_CONNECTIONS=$(calc_max_connections)
WAL_BUFFERS=$(calc_wal_buffers)
PARALLEL_WORKERS=$(calc_parallel_workers)
PARALLEL_PER_GATHER=$(calc_parallel_per_gather)

# Disk-dependent values
if [[ "$DISK" == "ssd" ]]; then
  RANDOM_PAGE_COST="1.1"
  EFFECTIVE_IO_CONCURRENCY="200"
else
  RANDOM_PAGE_COST="4"
  EFFECTIVE_IO_CONCURRENCY="2"
fi

# WAL settings by workload
case $WORKLOAD in
  web)
    MIN_WAL="1GB"
    MAX_WAL="4GB"
    CHECKPOINT_TARGET="0.9"
    ;;
  oltp)
    MIN_WAL="2GB"
    MAX_WAL="8GB"
    CHECKPOINT_TARGET="0.9"
    ;;
  dw)
    MIN_WAL="4GB"
    MAX_WAL="16GB"
    CHECKPOINT_TARGET="0.9"
    ;;
  mixed)
    MIN_WAL="1GB"
    MAX_WAL="4GB"
    CHECKPOINT_TARGET="0.9"
    ;;
esac

# huge_pages
HUGE_PAGES="off"
[[ $SHARED_BUFFERS -ge 8192 ]] && HUGE_PAGES="try"

# default_statistics_target
STATS_TARGET=100
[[ "$WORKLOAD" == "dw" ]] && STATS_TARGET=500

# ── Display ──
echo "📊 Recommended Settings ($WORKLOAD workload):"
echo "   shared_buffers = $(format_mb $SHARED_BUFFERS)"
echo "   effective_cache_size = $(format_mb $EFFECTIVE_CACHE)"
echo "   work_mem = $(format_kb $WORK_MEM)"
echo "   maintenance_work_mem = $(format_mb $MAINT_WORK_MEM)"
echo "   max_connections = $MAX_CONNECTIONS"
echo "   wal_buffers = $(format_mb $WAL_BUFFERS)"
echo "   min_wal_size = $MIN_WAL"
echo "   max_wal_size = $MAX_WAL"
echo "   random_page_cost = $RANDOM_PAGE_COST"
echo "   effective_io_concurrency = $EFFECTIVE_IO_CONCURRENCY"
echo "   max_worker_processes = $PARALLEL_WORKERS"
echo "   max_parallel_workers_per_gather = $PARALLEL_PER_GATHER"
echo "   max_parallel_workers = $PARALLEL_WORKERS"
echo "   huge_pages = $HUGE_PAGES"
echo ""

# ── Generate config ──
cat > "$OUTPUT_FILE" <<EOF
# PostgreSQL Tuned Configuration
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# System: ${TOTAL_RAM}MB RAM, ${CPU_COUNT} CPUs, ${DISK}
# Workload: ${WORKLOAD}
# PostgreSQL: ${PG_VER}

# ── Memory ──
shared_buffers = $(format_mb $SHARED_BUFFERS)
effective_cache_size = $(format_mb $EFFECTIVE_CACHE)
work_mem = $(format_kb $WORK_MEM)
maintenance_work_mem = $(format_mb $MAINT_WORK_MEM)
huge_pages = ${HUGE_PAGES}

# ── Connections ──
max_connections = ${MAX_CONNECTIONS}
superuser_reserved_connections = 3

# ── WAL ──
wal_buffers = $(format_mb $WAL_BUFFERS)
min_wal_size = ${MIN_WAL}
max_wal_size = ${MAX_WAL}
checkpoint_completion_target = ${CHECKPOINT_TARGET}
wal_compression = on

# ── Query Planner ──
random_page_cost = ${RANDOM_PAGE_COST}
effective_io_concurrency = ${EFFECTIVE_IO_CONCURRENCY}
default_statistics_target = ${STATS_TARGET}

# ── Parallelism ──
max_worker_processes = ${PARALLEL_WORKERS}
max_parallel_workers_per_gather = ${PARALLEL_PER_GATHER}
max_parallel_workers = ${PARALLEL_WORKERS}
max_parallel_maintenance_workers = ${PARALLEL_PER_GATHER}

# ── Logging ──
log_min_duration_statement = 1000
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 0

# ── Autovacuum ──
autovacuum_max_workers = 3
autovacuum_naptime = 60
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50
autovacuum_vacuum_scale_factor = 0.02
autovacuum_analyze_scale_factor = 0.01
EOF

echo "💾 Config written to: $OUTPUT_FILE"

# ── Diff mode ──
if $DIFF_MODE && [[ -n "$PG_CONF" ]] && [[ -f "$PG_CONF" ]]; then
  echo ""
  echo "📋 Diff (current → recommended):"
  echo "─────────────────────────────────"
  # Extract current values for tuned parameters
  params=(shared_buffers effective_cache_size work_mem maintenance_work_mem max_connections
          wal_buffers min_wal_size max_wal_size random_page_cost effective_io_concurrency
          max_worker_processes max_parallel_workers_per_gather huge_pages)
  for param in "${params[@]}"; do
    current=$(grep -E "^\s*${param}\s*=" "$PG_CONF" 2>/dev/null | tail -1 | sed 's/.*=\s*//' | sed 's/\s*#.*//' | xargs)
    new=$(grep -E "^\s*${param}\s*=" "$OUTPUT_FILE" 2>/dev/null | tail -1 | sed 's/.*=\s*//' | sed 's/\s*#.*//' | xargs)
    if [[ -n "$new" ]]; then
      if [[ "$current" != "$new" ]]; then
        echo "  ${param}: ${current:-<default>} → ${new}"
      else
        echo "  ${param}: ${current} (unchanged)"
      fi
    fi
  done
fi

# ── Apply mode ──
if $APPLY_MODE; then
  if [[ -z "$PG_CONF" ]]; then
    echo "❌ Cannot find postgresql.conf. Use --pg-version or set path manually."
    exit 1
  fi

  BACKUP="${PG_CONF}.backup-$(date +%Y%m%d-%H%M%S)"
  echo ""
  echo "📦 Backing up: $PG_CONF → $BACKUP"
  cp "$PG_CONF" "$BACKUP"

  echo "✏️  Applying tuned settings to $PG_CONF"

  # Read tuned config and apply each setting
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    param=$(echo "$line" | cut -d'=' -f1 | xargs)
    value=$(echo "$line" | cut -d'=' -f2- | xargs)

    # Comment out existing setting and add new one
    if grep -qE "^\s*#?\s*${param}\s*=" "$PG_CONF"; then
      sed -i "s/^\s*#\?\s*${param}\s*=.*/#&/" "$PG_CONF"
    fi
    echo "${param} = ${value}  # tuned by postgres-tuner" >> "$PG_CONF"
  done < <(grep -E "^\w" "$OUTPUT_FILE")

  echo "🔄 Restarting PostgreSQL..."
  if command -v systemctl &>/dev/null; then
    systemctl restart postgresql 2>/dev/null && echo "✅ PostgreSQL restarted!" || echo "⚠️  Restart failed. Check: systemctl status postgresql"
  elif command -v pg_ctl &>/dev/null; then
    pg_ctl restart 2>/dev/null && echo "✅ PostgreSQL restarted!" || echo "⚠️  Restart failed."
  else
    echo "⚠️  Cannot auto-restart. Please restart PostgreSQL manually."
  fi

  echo ""
  echo "🔙 To rollback: cp $BACKUP $PG_CONF && systemctl restart postgresql"
fi

echo ""
echo "✅ Done! Review the generated config before applying."
