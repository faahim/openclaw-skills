#!/bin/bash
# Latency Report — One-shot network quality report using mtr
set -euo pipefail

HOST=""
CYCLES=100

while [[ $# -gt 0 ]]; do
    case $1 in
        --host) HOST="$2"; shift 2 ;;
        --cycles) CYCLES="$2"; shift 2 ;;
        -h|--help) echo "Usage: $(basename "$0") --host HOST [--cycles N]"; exit 0 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [[ -z "$HOST" ]]; then
    echo "Error: --host required"
    exit 1
fi

command -v mtr >/dev/null 2>&1 || { echo "Error: mtr not found. Install with: sudo apt-get install -y mtr-tiny"; exit 1; }

echo "=== Network Quality Report ==="
echo "Target: $HOST"
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Cycles: $CYCLES"
echo ""

# Run mtr in report mode
mtr --report --report-cycles "$CYCLES" --no-dns "$HOST" 2>/dev/null || \
    mtr -r -c "$CYCLES" -n "$HOST" 2>/dev/null

echo ""

# Quick summary using fping
if command -v fping >/dev/null 2>&1; then
    RESULT=$(fping -C 20 -q -p 100 "$HOST" 2>&1 || true)
    TIMES=$(echo "$RESULT" | grep -oP ':\s+\K.*' | head -1)
    
    TOTAL=0 LOST=0 SUM=0
    for val in $TIMES; do
        ((TOTAL++))
        if [[ "$val" == "-" ]]; then
            ((LOST++))
        else
            SUM=$(echo "$SUM + $val" | bc)
        fi
    done
    
    RECV=$((TOTAL - LOST))
    if [[ $RECV -gt 0 ]]; then
        AVG=$(echo "scale=1; $SUM / $RECV" | bc)
        LOSS_PCT=$(echo "scale=1; $LOST * 100 / $TOTAL" | bc)
        
        echo "Summary (20 pings):"
        echo "  Average latency: ${AVG}ms"
        echo "  Packet loss: ${LOSS_PCT}%"
        
        # Grade
        if (( $(echo "$AVG < 20" | bc -l) )); then
            echo "  Grade: ★★★★★ Excellent"
        elif (( $(echo "$AVG < 50" | bc -l) )); then
            echo "  Grade: ★★★★ Good"
        elif (( $(echo "$AVG < 100" | bc -l) )); then
            echo "  Grade: ★★★ Fair"
        elif (( $(echo "$AVG < 200" | bc -l) )); then
            echo "  Grade: ★★ Poor"
        else
            echo "  Grade: ★ Bad"
        fi
    else
        echo "Summary: Host unreachable (100% packet loss)"
    fi
fi
