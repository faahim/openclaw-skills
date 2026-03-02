#!/bin/bash
# One-shot container resource report
set -euo pipefail

if ! docker info &>/dev/null 2>&1; then
  echo "❌ Cannot connect to Docker daemon."
  exit 1
fi

TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
echo "=== Container Resource Report ($TIMESTAMP) ==="
echo ""

# Get stats
STATS=$(docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}' 2>/dev/null)

if [[ -z "$STATS" ]]; then
  echo "ℹ️  No running containers found."
  exit 0
fi

echo "$STATS"
echo ""

# Summary
TOTAL=$(docker ps -q | wc -l)
RUNNING=$(docker ps --filter "status=running" -q | wc -l)
STOPPED=$(docker ps --filter "status=exited" -q | wc -l)

echo "--- Summary ---"
echo "Running: $RUNNING | Stopped: $STOPPED | Total: $((RUNNING + STOPPED))"

# Check for high usage
echo ""
docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}' 2>/dev/null | while IFS=$'\t' read -r name cpu mem; do
  cpu_val=${cpu//%/}
  mem_val=${mem//%/}
  cpu_val=$(echo "$cpu_val" | tr -d ' ')
  mem_val=$(echo "$mem_val" | tr -d ' ')

  if (( $(echo "$cpu_val >= 80" | bc -l 2>/dev/null || echo 0) )); then
    echo "⚠️  $name: CPU at ${cpu_val}% (high)"
  fi
  if (( $(echo "$mem_val >= 80" | bc -l 2>/dev/null || echo 0) )); then
    echo "⚠️  $name: Memory at ${mem_val}% (high)"
  fi
done

echo ""
echo "✅ Report complete"
