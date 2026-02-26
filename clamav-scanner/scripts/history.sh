#!/bin/bash
# ClamAV — View scan history
SCAN_LOG="${CLAMAV_SCAN_LOG:-/var/log/clamav/scan.log}"

if [[ ! -f "$SCAN_LOG" ]]; then
    echo "No scan history yet. Run your first scan with: bash scripts/scan.sh --path /home"
    exit 0
fi

LIMIT="${1:-20}"

echo "📊 Scan History (last $LIMIT scans)"
echo ""
printf "%-20s %-25s %-8s %-8s %s\n" "Date" "Path" "Files" "Threats" "Duration"
printf "%-20s %-25s %-8s %-8s %s\n" "----" "----" "-----" "-------" "--------"

tail -n "$LIMIT" "$SCAN_LOG" | while IFS='|' read -r timestamp path files threats duration; do
    printf "%-20s %-25s %-8s %-8s %s\n" "$timestamp" "$path" "$files" "$threats" "$duration"
done
