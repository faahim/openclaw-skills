#!/bin/bash
# System Benchmark Tool — Main Runner
set -euo pipefail

# Defaults
RUN_CPU=false
RUN_MEMORY=false
RUN_DISK=false
RUN_NETWORK=false
CPU_THREADS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
CPU_MAX_PRIME=${BENCH_CPU_MAX_PRIME:-20000}
DISK_SIZE=${BENCH_DISK_SIZE:-1G}
DISK_RUNTIME=${BENCH_DISK_RUNTIME:-60}
IPERF_SERVER=${BENCH_IPERF_SERVER:-""}
OUTPUT_FILE=""
QUIET=false
JSON_ONLY=false
FIO_PROFILE="mixed"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --all) RUN_CPU=true; RUN_MEMORY=true; RUN_DISK=true; shift ;;
    --cpu) RUN_CPU=true; shift ;;
    --memory) RUN_MEMORY=true; shift ;;
    --disk) RUN_DISK=true; shift ;;
    --network) RUN_NETWORK=true; shift ;;
    --server) IPERF_SERVER="$2"; shift 2 ;;
    --threads) CPU_THREADS="$2"; shift 2 ;;
    --disk-size) DISK_SIZE="$2"; shift 2 ;;
    --disk-runtime) DISK_RUNTIME="$2"; shift 2 ;;
    --fio-profile) FIO_PROFILE="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --quiet) QUIET=true; shift ;;
    --json) JSON_ONLY=true; shift ;;
    -h|--help) echo "Usage: $0 [--all|--cpu|--memory|--disk|--network] [options]"; exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# If nothing selected, show help
if ! $RUN_CPU && ! $RUN_MEMORY && ! $RUN_DISK && ! $RUN_NETWORK; then
  echo "Usage: $0 [--all|--cpu|--memory|--disk|--network] [options]"
  echo "Run '$0 --help' for details"
  exit 1
fi

# Check dependencies
check_tool() {
  if ! command -v "$1" &>/dev/null; then
    echo "❌ $1 not found. Run: bash scripts/install.sh"
    exit 1
  fi
}

$RUN_CPU && check_tool sysbench
$RUN_MEMORY && check_tool sysbench
$RUN_DISK && check_tool fio
$RUN_NETWORK && check_tool iperf3
check_tool jq

HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RESULTS="{\"host\": \"$HOSTNAME\", \"date\": \"$DATE\", \"benchmarks\": {}}"

log() {
  $QUIET || $JSON_ONLY || echo "$@"
}

rate() {
  local val=$1 thresholds=("${@:2}")
  if (( $(echo "$val >= ${thresholds[0]}" | bc -l 2>/dev/null || echo 0) )); then echo "★★★★★ Excellent"
  elif (( $(echo "$val >= ${thresholds[1]}" | bc -l 2>/dev/null || echo 0) )); then echo "★★★★☆ Good"
  elif (( $(echo "$val >= ${thresholds[2]}" | bc -l 2>/dev/null || echo 0) )); then echo "★★★☆☆ Average"
  elif (( $(echo "$val >= ${thresholds[3]}" | bc -l 2>/dev/null || echo 0) )); then echo "★★☆☆☆ Below Average"
  else echo "★☆☆☆☆ Poor"; fi
}

# ─── CPU Benchmark ───
if $RUN_CPU; then
  log ""
  log "🔧 CPU Benchmark (sysbench, $CPU_THREADS threads, max_prime=$CPU_MAX_PRIME)..."
  
  CPU_OUT=$(sysbench cpu --threads="$CPU_THREADS" --cpu-max-prime="$CPU_MAX_PRIME" --time=30 run 2>/dev/null)
  
  CPU_EPS=$(echo "$CPU_OUT" | grep "events per second" | awk '{print $NF}')
  CPU_LAT=$(echo "$CPU_OUT" | grep "avg:" | tail -1 | awk '{print $NF}')
  CPU_TOTAL=$(echo "$CPU_OUT" | grep "total number of events" | awk '{print $NF}')
  CPU_RATING=$(rate "$CPU_EPS" 10000 5000 2000 1000)
  
  RESULTS=$(echo "$RESULTS" | jq --arg eps "$CPU_EPS" --arg lat "$CPU_LAT" --arg total "$CPU_TOTAL" --arg threads "$CPU_THREADS" --arg rating "$CPU_RATING" \
    '.benchmarks.cpu = {events_per_sec: ($eps|tonumber), avg_latency_ms: ($lat|tonumber), total_events: ($total|tonumber), threads: ($threads|tonumber), rating: $rating}')
  
  log "  Events/sec: $CPU_EPS"
  log "  Avg latency: ${CPU_LAT}ms"
  log "  Rating: $CPU_RATING"
fi

# ─── Memory Benchmark ───
if $RUN_MEMORY; then
  log ""
  log "🧠 Memory Benchmark (sysbench, 1MB blocks)..."
  
  MEM_OUT=$(sysbench memory --threads="$CPU_THREADS" --memory-block-size=1M --memory-total-size=100G --time=30 run 2>/dev/null)
  
  MEM_OPS=$(echo "$MEM_OUT" | grep "transferred" | grep -oP '[\d.]+\s+MiB/sec' | awk '{print $1}')
  MEM_TOTAL=$(echo "$MEM_OUT" | grep "total number of events" | awk '{print $NF}')
  MEM_RATING=$(rate "$MEM_OPS" 15000 8000 4000 2000)
  
  RESULTS=$(echo "$RESULTS" | jq --arg ops "$MEM_OPS" --arg total "$MEM_TOTAL" --arg rating "$MEM_RATING" \
    '.benchmarks.memory = {throughput_mib_sec: ($ops|tonumber), total_operations: ($total|tonumber), block_size: "1MB", rating: $rating}')
  
  log "  Throughput: $MEM_OPS MiB/sec"
  log "  Rating: $MEM_RATING"
fi

# ─── Disk Benchmark ───
if $RUN_DISK; then
  log ""
  log "💾 Disk I/O Benchmark (fio, size=$DISK_SIZE, runtime=${DISK_RUNTIME}s)..."
  
  FIO_DIR="$WORK_DIR/fio-test"
  mkdir -p "$FIO_DIR"
  
  # Sequential read
  SEQ_READ=$(fio --name=seq-read --directory="$FIO_DIR" --rw=read --bs=1M --size="$DISK_SIZE" \
    --numjobs=1 --runtime="$DISK_RUNTIME" --time_based --group_reporting --output-format=json 2>/dev/null)
  SR_BW=$(echo "$SEQ_READ" | jq '.jobs[0].read.bw_bytes / 1048576 | floor')
  
  # Sequential write
  SEQ_WRITE=$(fio --name=seq-write --directory="$FIO_DIR" --rw=write --bs=1M --size="$DISK_SIZE" \
    --numjobs=1 --runtime="$DISK_RUNTIME" --time_based --group_reporting --output-format=json 2>/dev/null)
  SW_BW=$(echo "$SEQ_WRITE" | jq '.jobs[0].write.bw_bytes / 1048576 | floor')
  
  # Random read (4K)
  RAND_READ=$(fio --name=rand-read --directory="$FIO_DIR" --rw=randread --bs=4k --size="$DISK_SIZE" \
    --numjobs=4 --runtime="$DISK_RUNTIME" --time_based --group_reporting --output-format=json 2>/dev/null)
  RR_IOPS=$(echo "$RAND_READ" | jq '.jobs[0].read.iops | floor')
  
  # Random write (4K)
  RAND_WRITE=$(fio --name=rand-write --directory="$FIO_DIR" --rw=randwrite --bs=4k --size="$DISK_SIZE" \
    --numjobs=4 --runtime="$DISK_RUNTIME" --time_based --group_reporting --output-format=json 2>/dev/null)
  RW_IOPS=$(echo "$RAND_WRITE" | jq '.jobs[0].write.iops | floor')
  
  DISK_RATING=$(rate "$RR_IOPS" 100000 30000 10000 3000)
  
  RESULTS=$(echo "$RESULTS" | jq --arg sr "$SR_BW" --arg sw "$SW_BW" --arg rr "$RR_IOPS" --arg rw "$RW_IOPS" --arg rating "$DISK_RATING" --arg size "$DISK_SIZE" \
    '.benchmarks.disk = {seq_read_mbps: ($sr|tonumber), seq_write_mbps: ($sw|tonumber), random_read_iops: ($rr|tonumber), random_write_iops: ($rw|tonumber), test_size: $size, rating: $rating}')
  
  log "  Sequential Read:  ${SR_BW} MB/s"
  log "  Sequential Write: ${SW_BW} MB/s"
  log "  Random Read IOPS: $RR_IOPS"
  log "  Random Write IOPS: $RW_IOPS"
  log "  Rating: $DISK_RATING"
  
  rm -rf "$FIO_DIR"
fi

# ─── Network Benchmark ───
if $RUN_NETWORK; then
  if [ -z "$IPERF_SERVER" ]; then
    log ""
    log "🌐 Network: Skipped (no --server specified)"
    RESULTS=$(echo "$RESULTS" | jq '.benchmarks.network = {status: "skipped", reason: "no server specified"}')
  else
    log ""
    log "🌐 Network Benchmark (iperf3 → $IPERF_SERVER)..."
    
    NET_OUT=$(iperf3 -c "$IPERF_SERVER" -t 30 -J 2>/dev/null)
    NET_SEND=$(echo "$NET_OUT" | jq '.end.sum_sent.bits_per_second / 1000000 | floor')
    NET_RECV=$(echo "$NET_OUT" | jq '.end.sum_received.bits_per_second / 1000000 | floor')
    NET_RATING=$(rate "$NET_RECV" 1000 500 100 50)
    
    RESULTS=$(echo "$RESULTS" | jq --arg send "$NET_SEND" --arg recv "$NET_RECV" --arg rating "$NET_RATING" --arg server "$IPERF_SERVER" \
      '.benchmarks.network = {send_mbps: ($send|tonumber), receive_mbps: ($recv|tonumber), server: $server, rating: $rating}')
    
    log "  Send: ${NET_SEND} Mbps"
    log "  Receive: ${NET_RECV} Mbps"
    log "  Rating: $NET_RATING"
  fi
fi

# ─── Summary ───
log ""
log "════════════════════════════════════════════"
log "  BENCHMARK COMPLETE | $HOSTNAME | $(date +%Y-%m-%d)"
log "════════════════════════════════════════════"

# Save or output JSON
if [ -n "$OUTPUT_FILE" ]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  echo "$RESULTS" | jq . > "$OUTPUT_FILE"
  log "📄 Report saved: $OUTPUT_FILE"
fi

if $JSON_ONLY; then
  echo "$RESULTS" | jq .
fi
