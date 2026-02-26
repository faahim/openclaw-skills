#!/bin/bash
# Compare two benchmark results
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <result-a.json> <result-b.json>"
  exit 1
fi

FILE_A="$1"
FILE_B="$2"

HOST_A=$(jq -r '.host' "$FILE_A")
HOST_B=$(jq -r '.host' "$FILE_B")

printf "\n%-24s %-14s %-14s %s\n" "" "$HOST_A" "$HOST_B" "Winner"
printf "%-24s %-14s %-14s %s\n" "────────────────────────" "──────────────" "──────────────" "────────────"

compare_val() {
  local label="$1" val_a="$2" val_b="$3"
  if [ "$val_a" = "null" ] || [ "$val_b" = "null" ]; then return; fi
  
  local winner=""
  local pct=""
  if (( $(echo "$val_b > $val_a" | bc -l) )); then
    pct=$(echo "scale=0; ($val_b - $val_a) * 100 / $val_a" | bc)
    winner="$HOST_B (+${pct}%)"
  elif (( $(echo "$val_a > $val_b" | bc -l) )); then
    pct=$(echo "scale=0; ($val_a - $val_b) * 100 / $val_b" | bc)
    winner="$HOST_A (+${pct}%)"
  else
    winner="Tie"
  fi
  
  printf "%-24s %-14s %-14s %s\n" "$label" "$val_a" "$val_b" "$winner"
}

# CPU
A_CPU=$(jq -r '.benchmarks.cpu.events_per_sec // "null"' "$FILE_A")
B_CPU=$(jq -r '.benchmarks.cpu.events_per_sec // "null"' "$FILE_B")
compare_val "CPU events/sec" "$A_CPU" "$B_CPU"

# Memory
A_MEM=$(jq -r '.benchmarks.memory.throughput_mib_sec // "null"' "$FILE_A")
B_MEM=$(jq -r '.benchmarks.memory.throughput_mib_sec // "null"' "$FILE_B")
compare_val "Memory MiB/sec" "$A_MEM" "$B_MEM"

# Disk
A_SR=$(jq -r '.benchmarks.disk.seq_read_mbps // "null"' "$FILE_A")
B_SR=$(jq -r '.benchmarks.disk.seq_read_mbps // "null"' "$FILE_B")
compare_val "Seq Read MB/s" "$A_SR" "$B_SR"

A_SW=$(jq -r '.benchmarks.disk.seq_write_mbps // "null"' "$FILE_A")
B_SW=$(jq -r '.benchmarks.disk.seq_write_mbps // "null"' "$FILE_B")
compare_val "Seq Write MB/s" "$A_SW" "$B_SW"

A_RR=$(jq -r '.benchmarks.disk.random_read_iops // "null"' "$FILE_A")
B_RR=$(jq -r '.benchmarks.disk.random_read_iops // "null"' "$FILE_B")
compare_val "Random Read IOPS" "$A_RR" "$B_RR"

A_RW=$(jq -r '.benchmarks.disk.random_write_iops // "null"' "$FILE_A")
B_RW=$(jq -r '.benchmarks.disk.random_write_iops // "null"' "$FILE_B")
compare_val "Random Write IOPS" "$A_RW" "$B_RW"

# Network
A_NET=$(jq -r '.benchmarks.network.receive_mbps // "null"' "$FILE_A")
B_NET=$(jq -r '.benchmarks.network.receive_mbps // "null"' "$FILE_B")
compare_val "Network Recv Mbps" "$A_NET" "$B_NET"

echo ""
