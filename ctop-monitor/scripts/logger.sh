#!/bin/bash
# Log container stats to CSV for historical analysis
set -euo pipefail

INTERVAL=300
OUTPUT="logs/container-stats.csv"
RETENTION_DAYS=30

while [[ $# -gt 0 ]]; do
  case $1 in
    --interval) INTERVAL="$2"; shift 2 ;;
    --output)   OUTPUT="$2"; shift 2 ;;
    --retention) RETENTION_DAYS="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--interval SECS] [--output FILE] [--retention DAYS]"
      exit 0
      ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# Create output directory
mkdir -p "$(dirname "$OUTPUT")"

# Write CSV header if file doesn't exist
if [[ ! -f "$OUTPUT" ]]; then
  echo "timestamp,container,cpu_pct,mem_usage_mb,mem_limit_mb,mem_pct,net_rx_mb,net_tx_mb,block_read_mb,block_write_mb" > "$OUTPUT"
fi

parse_size() {
  # Convert Docker size string to MB (e.g., "384MiB" -> 384, "1.2GiB" -> 1228.8)
  local val="$1"
  val=$(echo "$val" | tr -d ' ')
  if echo "$val" | grep -qi "gib\|gb"; then
    echo "$val" | grep -oP '[\d.]+' | head -1 | awk '{printf "%.1f", $1 * 1024}'
  elif echo "$val" | grep -qi "mib\|mb"; then
    echo "$val" | grep -oP '[\d.]+' | head -1
  elif echo "$val" | grep -qi "kib\|kb"; then
    echo "$val" | grep -oP '[\d.]+' | head -1 | awk '{printf "%.1f", $1 / 1024}'
  else
    echo "0"
  fi
}

log_stats() {
  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%S')

  docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}' 2>/dev/null | while IFS=$'\t' read -r name cpu mem_usage mem_pct net_io block_io; do
    cpu=$(echo "${cpu//%/}" | tr -d ' ')
    mem_pct=$(echo "${mem_pct//%/}" | tr -d ' ')

    # Parse memory usage/limit
    local mem_used mem_limit
    mem_used=$(parse_size "$(echo "$mem_usage" | cut -d'/' -f1)")
    mem_limit=$(parse_size "$(echo "$mem_usage" | cut -d'/' -f2)")

    # Parse network I/O
    local net_rx net_tx
    net_rx=$(parse_size "$(echo "$net_io" | cut -d'/' -f1)")
    net_tx=$(parse_size "$(echo "$net_io" | cut -d'/' -f2)")

    # Parse block I/O
    local blk_r blk_w
    blk_r=$(parse_size "$(echo "$block_io" | cut -d'/' -f1)")
    blk_w=$(parse_size "$(echo "$block_io" | cut -d'/' -f2)")

    echo "${ts},${name},${cpu},${mem_used},${mem_limit},${mem_pct},${net_rx},${net_tx},${blk_r},${blk_w}" >> "$OUTPUT"
  done
}

prune_old() {
  if [[ -f "$OUTPUT" && "$RETENTION_DAYS" -gt 0 ]]; then
    local cutoff
    cutoff=$(date -u -d "$RETENTION_DAYS days ago" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -v-${RETENTION_DAYS}d '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "")
    if [[ -n "$cutoff" ]]; then
      local header
      header=$(head -1 "$OUTPUT")
      awk -v cutoff="$cutoff" -F',' 'NR==1 || $1 >= cutoff' "$OUTPUT" > "${OUTPUT}.tmp"
      mv "${OUTPUT}.tmp" "$OUTPUT"
    fi
  fi
}

echo "=== Container Stats Logger ==="
echo "Interval: ${INTERVAL}s | Output: $OUTPUT | Retention: ${RETENTION_DAYS} days"
echo "---"

trap 'echo ""; echo "Logger stopped."; exit 0' INT TERM

while true; do
  log_stats
  echo "[$(date -u '+%Y-%m-%d %H:%M:%S')] Logged $(docker ps -q | wc -l) containers → $OUTPUT"

  # Prune old data once per hour
  if (( $(date +%M) == 0 )); then
    prune_old
  fi

  sleep "$INTERVAL"
done
