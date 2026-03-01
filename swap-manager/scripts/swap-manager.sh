#!/bin/bash
# Swap & Memory Manager — Create, resize, optimize swap and zram on Linux
# https://github.com/faahim/openclaw-skills
set -euo pipefail

VERSION="1.0.0"
SWAP_FILE="${SWAP_FILE:-/swapfile}"
SYSCTL_CONF="/etc/sysctl.d/99-swap-manager.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $*"; }
log_err()  { echo -e "${RED}[✗]${NC} $*"; }
log_info() { echo -e "${BLUE}[i]${NC} $*"; }

# ─── Helpers ───

bytes_to_mb() { echo $(( $1 / 1024 )); }

parse_size() {
  local size="$1"
  case "${size^^}" in
    *G) echo $(( ${size%[gG]} * 1024 )) ;;
    *M) echo "${size%[mM]}" ;;
    *)  echo "$size" ;;
  esac
}

get_mem_info() {
  local total_kb used_kb free_kb available_kb
  total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  available_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
  free_kb=$(awk '/^MemFree:/ {print $2}' /proc/meminfo)
  used_kb=$(( total_kb - available_kb ))
  
  TOTAL_MB=$(( total_kb / 1024 ))
  USED_MB=$(( used_kb / 1024 ))
  FREE_MB=$(( available_kb / 1024 ))
  USED_PCT=$(( used_kb * 100 / total_kb ))
}

get_swap_info() {
  local total_kb used_kb free_kb
  total_kb=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)
  used_kb=$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)
  free_kb=$used_kb
  used_kb=$(( total_kb - free_kb ))
  
  SWAP_TOTAL_MB=$(( total_kb / 1024 ))
  SWAP_USED_MB=$(( used_kb / 1024 ))
  SWAP_FREE_MB=$(( free_kb / 1024 ))
}

# ─── Commands ───

cmd_status() {
  get_mem_info
  get_swap_info
  local swappiness vfs_cache
  swappiness=$(cat /proc/sys/vm/swappiness)
  vfs_cache=$(cat /proc/sys/vm/vfs_cache_pressure)

  echo ""
  echo "═══ Memory & Swap Status ═══"
  echo "RAM:  Total: ${TOTAL_MB}MB  Used: ${USED_MB}MB  Free: ${FREE_MB}MB  (${USED_PCT}% used)"
  echo "Swap: Total: ${SWAP_TOTAL_MB}MB  Used: ${SWAP_USED_MB}MB  Free: ${SWAP_FREE_MB}MB"
  echo "Swappiness: ${swappiness}"
  echo "VFS Cache Pressure: ${vfs_cache}"
  echo ""
  
  echo "Active swap devices:"
  if swapon --show 2>/dev/null | grep -q .; then
    swapon --show 2>/dev/null | sed 's/^/  /'
  else
    echo "  (none)"
  fi
  echo ""

  # Recommendations
  echo "Recommendations:"
  if [[ $SWAP_TOTAL_MB -eq 0 ]]; then
    log_warn "No swap configured — OOM kills likely under load"
  fi
  if [[ $swappiness -gt 30 ]]; then
    log_warn "Swappiness=${swappiness} is high for SSD systems (recommend 10-20)"
  fi
  if [[ $SWAP_TOTAL_MB -gt 0 && $SWAP_USED_MB -gt $(( SWAP_TOTAL_MB * 80 / 100 )) ]]; then
    log_warn "Swap is >80% used — consider increasing swap size"
  fi
  if [[ $FREE_MB -lt 200 ]]; then
    log_warn "Available memory is low (${FREE_MB}MB) — check top processes"
  fi
  if [[ $SWAP_TOTAL_MB -gt 0 && $swappiness -le 30 && $FREE_MB -ge 200 ]]; then
    log_ok "Memory and swap look healthy"
  fi
}

cmd_create() {
  local size_mb
  size_mb=$(parse_size "${SIZE:-2G}")
  
  if [[ -f "$SWAP_FILE" ]] && swapon --show 2>/dev/null | grep -q "$SWAP_FILE"; then
    log_err "Swap file already exists and is active at $SWAP_FILE"
    log_info "Use 'resize' to change size, or 'remove' first"
    exit 1
  fi

  log_info "Creating ${size_mb}MB swap file at ${SWAP_FILE}..."
  
  # Try fallocate first, fall back to dd
  if fallocate -l "${size_mb}M" "$SWAP_FILE" 2>/dev/null; then
    log_ok "Created swap file with fallocate"
  else
    log_warn "fallocate not supported, using dd (slower)..."
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$size_mb" status=progress 2>&1
    log_ok "Created swap file with dd"
  fi

  chmod 600 "$SWAP_FILE"
  log_ok "Set permissions (600)"

  mkswap "$SWAP_FILE" >/dev/null
  log_ok "Formatted as swap"

  swapon "$SWAP_FILE"
  log_ok "Enabled swap"

  # Add to fstab if not already there
  if ! grep -q "$SWAP_FILE" /etc/fstab 2>/dev/null; then
    echo "${SWAP_FILE} none swap sw 0 0" >> /etc/fstab
    log_ok "Added to /etc/fstab for persistence"
  fi

  log_ok "Swap file active!"
  echo ""
  get_swap_info
  echo "Swap: Total: ${SWAP_TOTAL_MB}MB  Used: ${SWAP_USED_MB}MB  Free: ${SWAP_FREE_MB}MB"
}

cmd_remove() {
  if swapon --show 2>/dev/null | grep -q "$SWAP_FILE"; then
    swapoff "$SWAP_FILE"
    log_ok "Disabled swap"
  fi

  if [[ -f "$SWAP_FILE" ]]; then
    rm -f "$SWAP_FILE"
    log_ok "Removed swap file"
  fi

  # Remove from fstab
  if grep -q "$SWAP_FILE" /etc/fstab 2>/dev/null; then
    sed -i "\|${SWAP_FILE}|d" /etc/fstab
    log_ok "Removed from /etc/fstab"
  fi

  log_ok "Swap removed"
}

cmd_resize() {
  local size_mb
  size_mb=$(parse_size "${SIZE:-2G}")
  
  log_info "Resizing swap to ${size_mb}MB..."

  # Disable old swap
  if swapon --show 2>/dev/null | grep -q "$SWAP_FILE"; then
    log_info "Disabling current swap..."
    swapoff "$SWAP_FILE" 2>/dev/null || true
  fi

  # Remove old file
  rm -f "$SWAP_FILE" 2>/dev/null || true

  # Create new
  SIZE="${size_mb}M"
  cmd_create
}

cmd_tune() {
  local changed=false

  if [[ -n "${SWAPPINESS:-}" ]]; then
    sysctl -w vm.swappiness="$SWAPPINESS" >/dev/null
    log_ok "Set swappiness to $SWAPPINESS (runtime)"
    changed=true
  fi

  if [[ -n "${VFS_CACHE:-}" ]]; then
    sysctl -w vm.vfs_cache_pressure="$VFS_CACHE" >/dev/null
    log_ok "Set vfs_cache_pressure to $VFS_CACHE (runtime)"
    changed=true
  fi

  if [[ "$changed" == "true" ]]; then
    # Persist
    mkdir -p "$(dirname "$SYSCTL_CONF")"
    {
      echo "# Swap Manager tuning"
      [[ -n "${SWAPPINESS:-}" ]] && echo "vm.swappiness = $SWAPPINESS"
      [[ -n "${VFS_CACHE:-}" ]] && echo "vm.vfs_cache_pressure = $VFS_CACHE"
    } > "$SYSCTL_CONF"
    log_ok "Persisted to $SYSCTL_CONF"
  else
    log_err "Specify --swappiness N and/or --vfs-cache N"
    exit 1
  fi
}

cmd_setup_optimal() {
  get_mem_info
  local swap_mb swappiness=10

  # Calculate optimal swap size
  if [[ $TOTAL_MB -le 2048 ]]; then
    swap_mb=$(( TOTAL_MB * 2 ))
  elif [[ $TOTAL_MB -le 8192 ]]; then
    swap_mb=$TOTAL_MB
  else
    swap_mb=4096
  fi

  log_info "RAM: ${TOTAL_MB}MB → Creating ${swap_mb}MB swap, swappiness=${swappiness}"

  # Create swap
  SIZE="${swap_mb}M"
  cmd_create

  # Tune
  SWAPPINESS=$swappiness
  VFS_CACHE=50
  cmd_tune

  echo ""
  log_ok "Optimal setup complete!"
  cmd_status
}

cmd_zram() {
  if [[ "${ZRAM_DISABLE:-false}" == "true" ]]; then
    # Disable zram
    for dev in /dev/zram*; do
      [[ -b "$dev" ]] || continue
      swapoff "$dev" 2>/dev/null || true
    done
    modprobe -r zram 2>/dev/null || true
    log_ok "Zram disabled"
    return
  fi

  local pct="${ZRAM_SIZE:-50}"
  get_mem_info
  local zram_mb=$(( TOTAL_MB * pct / 100 ))

  # Load module
  if ! lsmod | grep -q zram; then
    modprobe zram num_devices=1 2>/dev/null || {
      log_err "zram module not available on this kernel"
      exit 1
    }
  fi

  # Configure
  echo "${zram_mb}M" > /sys/block/zram0/disksize 2>/dev/null || {
    # Reset and retry
    echo 1 > /sys/block/zram0/reset 2>/dev/null || true
    echo "${zram_mb}M" > /sys/block/zram0/disksize
  }
  mkswap /dev/zram0 >/dev/null
  swapon -p 100 /dev/zram0
  
  log_ok "Zram enabled: ${zram_mb}MB (${pct}% of RAM, priority 100)"
  log_info "Effective capacity with compression: ~$((zram_mb * 2))-$((zram_mb * 3))MB"
}

cmd_monitor() {
  local threshold="${THRESHOLD:-200}"
  local interval="${INTERVAL:-30}"
  local alert_cmd="${ALERT_CMD:-}"
  local alerted=false

  log_info "Monitoring memory — alert below ${threshold}MB, checking every ${interval}s"
  log_info "Press Ctrl+C to stop"

  while true; do
    get_mem_info
    
    if [[ $FREE_MB -lt $threshold ]]; then
      if [[ "$alerted" == "false" ]]; then
        echo ""
        echo -e "${RED}🚨 LOW MEMORY ALERT — Available: ${FREE_MB}MB (threshold: ${threshold}MB)${NC}"
        echo "  Top consumers:"
        ps aux --sort=-%mem | head -4 | tail -3 | awk '{printf "    PID %-7s %-15s — %sMB\n", $2, $11, int($6/1024)}'
        
        if [[ -n "$alert_cmd" ]]; then
          AVAILABLE_MB=$FREE_MB eval "$alert_cmd" 2>/dev/null || true
        fi
        alerted=true
      fi
    else
      alerted=false
    fi
    
    sleep "$interval"
  done
}

cmd_check() {
  # One-shot check (for cron)
  local threshold="${THRESHOLD:-200}"
  get_mem_info

  if [[ $FREE_MB -lt $threshold ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚨 LOW MEMORY: ${FREE_MB}MB available (threshold: ${threshold}MB)"
    ps aux --sort=-%mem | head -4 | tail -3 | awk '{printf "  PID %-7s %-15s — %sMB\n", $2, $11, int($6/1024)}'
    
    if [[ -n "${ALERT_CMD:-}" ]]; then
      AVAILABLE_MB=$FREE_MB eval "$ALERT_CMD" 2>/dev/null || true
    fi
    exit 1
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Memory OK: ${FREE_MB}MB available"
  fi
}

cmd_report() {
  get_mem_info
  get_swap_info

  echo ""
  echo "═══ Memory Report ═══"
  echo "RAM:  ${TOTAL_MB}MB total — ${USED_MB}MB used (${USED_PCT}%)"
  echo "Swap: ${SWAP_TOTAL_MB}MB total — ${SWAP_USED_MB}MB used"
  echo ""

  echo "Top 10 Memory Consumers:"
  printf "  %-8s %-10s %s\n" "PID" "RSS(MB)" "Command"
  ps aux --sort=-%mem | head -11 | tail -10 | awk '{printf "  %-8s %-10s %s\n", $2, int($6/1024), $11}'
  echo ""

  # Swap usage by process (if swap is used)
  if [[ $SWAP_USED_MB -gt 0 ]]; then
    echo "Swap Usage by Process:"
    printf "  %-8s %-10s %s\n" "PID" "Swap(MB)" "Command"
    for pid in /proc/[0-9]*; do
      pid_num=$(basename "$pid")
      swap_kb=$(awk '/^VmSwap:/ {print $2}' "$pid/status" 2>/dev/null || echo 0)
      if [[ ${swap_kb:-0} -gt 1024 ]]; then
        cmd=$(cat "$pid/comm" 2>/dev/null || echo "?")
        printf "  %-8s %-10s %s\n" "$pid_num" "$(( swap_kb / 1024 ))" "$cmd"
      fi
    done | sort -t' ' -k3 -rn | head -10
    echo ""
  fi

  echo "Kernel Memory:"
  awk '
    /^Buffers:/    {printf "  Buffers:    %dMB\n", $2/1024}
    /^Cached:/     {printf "  Cached:     %dMB\n", $2/1024}
    /^Slab:/       {printf "  Slab:       %dMB\n", $2/1024}
    /^PageTables:/ {printf "  PageTables: %dMB\n", $2/1024}
  ' /proc/meminfo
}

# ─── Argument Parsing ───

CMD=""
SIZE=""
SWAPPINESS=""
VFS_CACHE=""
THRESHOLD=""
INTERVAL=""
ALERT_CMD="${SWAP_ALERT_CMD:-}"
ZRAM_SIZE=""
ZRAM_DISABLE="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    status|create|remove|resize|tune|setup-optimal|zram|monitor|check|report)
      CMD="$1"; shift ;;
    --size)       SIZE="$2"; shift 2 ;;
    --swappiness) SWAPPINESS="$2"; shift 2 ;;
    --vfs-cache)  VFS_CACHE="$2"; shift 2 ;;
    --threshold)  THRESHOLD="$2"; shift 2 ;;
    --interval)   INTERVAL="$2"; shift 2 ;;
    --on-alert)   ALERT_CMD="$2"; shift 2 ;;
    --enable)     shift ;;
    --disable)    ZRAM_DISABLE="true"; shift ;;
    --version)    echo "swap-manager v${VERSION}"; exit 0 ;;
    --help|-h)    CMD="help"; shift ;;
    *)            log_err "Unknown option: $1"; exit 1 ;;
  esac
done

# Handle --size for zram
[[ -n "${SIZE:-}" && "$CMD" == "zram" ]] && ZRAM_SIZE="$SIZE"

case "${CMD:-help}" in
  status)        cmd_status ;;
  create)        cmd_create ;;
  remove)        cmd_remove ;;
  resize)        cmd_resize ;;
  tune)          cmd_tune ;;
  setup-optimal) cmd_setup_optimal ;;
  zram)          cmd_zram ;;
  monitor)       cmd_monitor ;;
  check)         cmd_check ;;
  report)        cmd_report ;;
  help)
    echo "Swap & Memory Manager v${VERSION}"
    echo ""
    echo "Usage: swap-manager.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status          Show memory & swap status with recommendations"
    echo "  create          Create a new swap file (--size 2G)"
    echo "  remove          Remove swap file and fstab entry"
    echo "  resize          Resize existing swap (--size 4G)"
    echo "  tune            Set swappiness/vfs_cache (--swappiness 10 --vfs-cache 50)"
    echo "  setup-optimal   Auto-configure optimal swap for this server"
    echo "  zram            Enable/disable zram (--enable/--disable --size 50)"
    echo "  monitor         Continuous monitoring (--threshold 200 --interval 30)"
    echo "  check           One-shot check for cron (--threshold 200)"
    echo "  report          Detailed memory usage report"
    echo ""
    echo "Options:"
    echo "  --size N        Swap size (e.g. 2G, 4G, 512M)"
    echo "  --swappiness N  Set vm.swappiness (0-200)"
    echo "  --vfs-cache N   Set vm.vfs_cache_pressure"
    echo "  --threshold N   Alert threshold in MB"
    echo "  --interval N    Check interval in seconds"
    echo "  --on-alert CMD  Command to run on alert (\$AVAILABLE_MB available)"
    echo ""
    echo "Environment:"
    echo "  SWAP_FILE       Override swap file path (default: /swapfile)"
    echo "  SWAP_ALERT_CMD  Default alert command"
    ;;
  *)
    log_err "Unknown command: $CMD"
    exit 1 ;;
esac
