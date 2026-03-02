#!/bin/bash
# Latency Analyze — Analyze CSV log files from latency-monitor
set -euo pipefail

CSVFILE="${1:-}"

if [[ -z "$CSVFILE" || ! -f "$CSVFILE" ]]; then
    echo "Usage: $(basename "$0") <latency-log.csv>"
    exit 1
fi

command -v bc >/dev/null 2>&1 || { echo "Error: bc not found"; exit 1; }

echo "=== Latency Analysis ==="

# Get time range
FIRST=$(tail -n +2 "$CSVFILE" | head -1 | cut -d',' -f1)
LAST=$(tail -1 "$CSVFILE" | cut -d',' -f1)
echo "Period: $FIRST — $LAST"
echo ""

# Get unique hosts
HOSTS=$(tail -n +2 "$CSVFILE" | cut -d',' -f2 | sort -u)

printf "%-25s %8s %8s %8s %8s %8s %6s\n" "Host" "Avg(ms)" "P50(ms)" "P95(ms)" "P99(ms)" "Jitter" "Loss%"
printf "%-25s %8s %8s %8s %8s %8s %6s\n" "-------------------------" "--------" "--------" "--------" "--------" "--------" "------"

BEST_HOST=""
BEST_AVG=999999

for host in $HOSTS; do
    # Extract latency values for this host (column 3 = avg latency)
    LATENCIES=$(tail -n +2 "$CSVFILE" | awk -F',' -v h="$host" '$2==h && $3>0 {print $3}')
    JITTERS=$(tail -n +2 "$CSVFILE" | awk -F',' -v h="$host" '$2==h && $6>0 {print $6}')
    LOSSES=$(tail -n +2 "$CSVFILE" | awk -F',' -v h="$host" '$2==h {print $7}')
    
    COUNT=$(echo "$LATENCIES" | wc -l)
    if [[ $COUNT -eq 0 || -z "$LATENCIES" ]]; then
        printf "%-25s %8s %8s %8s %8s %8s %6s\n" "$host" "N/A" "N/A" "N/A" "N/A" "N/A" "N/A"
        continue
    fi
    
    # Sort latencies for percentiles
    SORTED=$(echo "$LATENCIES" | sort -n)
    
    # Average
    SUM=$(echo "$LATENCIES" | paste -sd+ | bc)
    AVG=$(echo "scale=1; $SUM / $COUNT" | bc)
    
    # Percentiles
    P50_IDX=$(echo "($COUNT * 50 + 50) / 100" | bc)
    P95_IDX=$(echo "($COUNT * 95 + 50) / 100" | bc)
    P99_IDX=$(echo "($COUNT * 99 + 50) / 100" | bc)
    [[ $P50_IDX -lt 1 ]] && P50_IDX=1
    [[ $P95_IDX -lt 1 ]] && P95_IDX=1
    [[ $P99_IDX -lt 1 ]] && P99_IDX=1
    
    P50=$(echo "$SORTED" | sed -n "${P50_IDX}p")
    P95=$(echo "$SORTED" | sed -n "${P95_IDX}p")
    P99=$(echo "$SORTED" | sed -n "${P99_IDX}p")
    
    # Avg jitter
    if [[ -n "$JITTERS" ]]; then
        JSUM=$(echo "$JITTERS" | paste -sd+ | bc)
        JCOUNT=$(echo "$JITTERS" | wc -l)
        JAVG=$(echo "scale=1; $JSUM / $JCOUNT" | bc)
    else
        JAVG="0"
    fi
    
    # Avg loss
    if [[ -n "$LOSSES" ]]; then
        LSUM=$(echo "$LOSSES" | paste -sd+ | bc)
        LCOUNT=$(echo "$LOSSES" | wc -l)
        LAVG=$(echo "scale=1; $LSUM / $LCOUNT" | bc)
    else
        LAVG="0"
    fi
    
    printf "%-25s %8s %8s %8s %8s %8s %6s\n" "$host" "$AVG" "$P50" "$P95" "$P99" "$JAVG" "$LAVG"
    
    # Track best
    if (( $(echo "$AVG < $BEST_AVG" | bc -l) )); then
        BEST_AVG="$AVG"
        BEST_HOST="$host"
    fi
done

echo ""
if [[ -n "$BEST_HOST" ]]; then
    echo "Winner: $BEST_HOST — lowest average latency (${BEST_AVG}ms)"
fi
