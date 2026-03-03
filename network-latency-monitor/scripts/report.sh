#!/usr/bin/env bash
# Network Latency Monitor — Report Generator
# Usage: bash report.sh --data-dir ./data --period 24h

set -euo pipefail

DATA_DIR="./data"
PERIOD="24h"
FORMAT="text"
COMPARE=false
TRENDS=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --data-dir DIR    Data directory (default: ./data)
  --period PERIOD   Report period: 1h, 6h, 24h, 7d, 30d (default: 24h)
  --format FORMAT   Output format: text, json, csv (default: text)
  --compare         Show host comparison table
  --trends          Show hourly trend analysis
  --help            Show this help
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    --period) PERIOD="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --compare) COMPARE=true; shift ;;
    --trends) TRENDS=true; shift ;;
    --help) usage ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# Convert period to seconds
period_to_seconds() {
  local p="$1"
  local num="${p%[hdm]}"
  local unit="${p: -1}"
  case "$unit" in
    h) echo $((num * 3600)) ;;
    d) echo $((num * 86400)) ;;
    m) echo $((num * 60)) ;;
    *) echo $((num * 3600)) ;;
  esac
}

PERIOD_SECS=$(period_to_seconds "$PERIOD")
NOW=$(date -u +%s)
CUTOFF=$((NOW - PERIOD_SECS))

if [[ ! -d "$DATA_DIR" ]]; then
  echo "Error: Data directory not found: $DATA_DIR"
  exit 1
fi

# Collect all host directories
HOSTS=()
for dir in "$DATA_DIR"/*/; do
  [[ -d "$dir" ]] && HOSTS+=("$(basename "$dir")")
done

if [[ ${#HOSTS[@]} -eq 0 ]]; then
  echo "No monitoring data found in $DATA_DIR"
  exit 0
fi

# Parse CSV data for a host within the time window
get_host_data() {
  local host="$1"
  local host_dir="$DATA_DIR/$host"

  # Concatenate all CSV files, filter by timestamp
  for csv in "$host_dir"/*.csv; do
    [[ -f "$csv" ]] || continue
    tail -n +2 "$csv"  # skip header
  done | awk -F',' -v cutoff="$CUTOFF" '
  {
    # Parse ISO timestamp to epoch (approximate)
    cmd = "date -u -d \"" $1 "\" +%s 2>/dev/null"
    cmd | getline epoch
    close(cmd)
    if (epoch >= cutoff) print $0
  }' 2>/dev/null
}

# Calculate stats from CSV data
calc_stats() {
  local data="$1"
  echo "$data" | awk -F',' '
  BEGIN {
    count=0; sum_avg=0; sum_loss=0;
    min_val=999999; max_val=0;
    # For P95 we collect all avg values
  }
  {
    avg=$3; min=$4; max=$5; loss=$6;
    if (avg+0 > 0 || loss+0 > 0) {
      count++;
      sum_avg += avg;
      sum_loss += loss;
      if (min+0 < min_val) min_val = min;
      if (max+0 > max_val) max_val = max;
      values[count] = avg;
    }
  }
  END {
    if (count == 0) {
      print "0|0|0|0|0|0|0"
      exit
    }
    overall_avg = sum_avg / count;
    avg_loss = sum_loss / count;

    # Sort for P95 (simple bubble sort for small datasets)
    for (i = 1; i <= count; i++) {
      for (j = i+1; j <= count; j++) {
        if (values[i] > values[j]) {
          tmp = values[i]; values[i] = values[j]; values[j] = tmp;
        }
      }
    }
    p95_idx = int(count * 0.95);
    if (p95_idx < 1) p95_idx = 1;
    p95 = values[p95_idx];

    printf "%.1f|%.1f|%.1f|%.1f|%.1f|%d|%.1f\n", overall_avg, min_val, max_val, p95, avg_loss, count, 0
  }'
}

# Text report
if [[ "$FORMAT" == "text" ]]; then
  echo "═══════════════════════════════════════════════════"
  echo " Network Latency Report — Last $PERIOD"
  echo " Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "═══════════════════════════════════════════════════"
  echo ""

  for host in "${HOSTS[@]}"; do
    data=$(get_host_data "$host")
    if [[ -z "$data" ]]; then
      echo " Host: $host"
      echo " └── No data in this period"
      echo ""
      continue
    fi

    stats=$(calc_stats "$data")
    IFS='|' read -r avg min max p95 loss checks _ <<< "$stats"

    # Determine status
    status="✅ Healthy"
    if (( $(echo "$loss > 5" | bc -l 2>/dev/null || echo 0) )); then
      status="❌ Unhealthy (high packet loss)"
    elif (( $(echo "$avg > 200" | bc -l 2>/dev/null || echo 0) )); then
      status="⚠️ Degraded (high latency)"
    elif (( $(echo "$p95 > 300" | bc -l 2>/dev/null || echo 0) )); then
      status="⚠️ Degraded (P95 spikes)"
    fi

    echo " Host: $host"
    echo " ├── Avg Latency:  ${avg}ms"
    echo " ├── Min/Max:      ${min}ms / ${max}ms"
    echo " ├── P95 Latency:  ${p95}ms"
    echo " ├── Packet Loss:  ${loss}%"
    echo " ├── Checks:       $checks"
    echo " └── Status:       $status"
    echo ""
  done

  # Comparison table
  if $COMPARE; then
    echo "═══════════════════════════════════════"
    echo " Host Comparison — Last $PERIOD"
    echo "═══════════════════════════════════════"
    printf " %-20s %8s %8s %8s\n" "Host" "Avg" "P95" "Loss"
    echo " ─────────────────────────────────────────────"
    for host in "${HOSTS[@]}"; do
      data=$(get_host_data "$host")
      [[ -z "$data" ]] && continue
      stats=$(calc_stats "$data")
      IFS='|' read -r avg min max p95 loss checks _ <<< "$stats"
      printf " %-20s %6sms %6sms %6s%%\n" "$host" "$avg" "$p95" "$loss"
    done
    echo ""
  fi
fi

# JSON report
if [[ "$FORMAT" == "json" ]]; then
  echo "{"
  echo "  \"period\": \"$PERIOD\","
  echo "  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"hosts\": ["

  first=true
  for host in "${HOSTS[@]}"; do
    data=$(get_host_data "$host")
    [[ -z "$data" ]] && continue
    stats=$(calc_stats "$data")
    IFS='|' read -r avg min max p95 loss checks _ <<< "$stats"

    $first || echo ","
    first=false
    cat <<JSONHOST
    {
      "host": "$host",
      "avg_ms": $avg,
      "min_ms": $min,
      "max_ms": $max,
      "p95_ms": $p95,
      "loss_pct": $loss,
      "checks": $checks
    }
JSONHOST
  done

  echo ""
  echo "  ]"
  echo "}"
fi
