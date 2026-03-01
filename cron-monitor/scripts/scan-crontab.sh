#!/bin/bash
# scan-crontab.sh — Parse and display all cron jobs
set -euo pipefail

DATA_DIR="${CRON_MONITOR_DATA:-$HOME/.cron-monitor/data}"
mkdir -p "$DATA_DIR"

echo "=== Scanning Cron Jobs ==="
echo ""

JOB_COUNT=0
OUTPUT_FILE="$DATA_DIR/crontab-entries.json"
echo '{"scanned_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","jobs":[' > "$OUTPUT_FILE"
FIRST=true

# Function: describe schedule in human terms
describe_schedule() {
    local min="$1" hour="$2" dom="$3" mon="$4" dow="$5"
    
    if [[ "$min" == "*" && "$hour" == "*" ]]; then
        echo "every minute"
    elif [[ "$min" == "*/5" && "$hour" == "*" ]]; then
        echo "every 5 min"
    elif [[ "$min" == "*/10" && "$hour" == "*" ]]; then
        echo "every 10 min"
    elif [[ "$min" == "*/15" && "$hour" == "*" ]]; then
        echo "every 15 min"
    elif [[ "$min" == "*/30" && "$hour" == "*" ]]; then
        echo "every 30 min"
    elif [[ "$min" == "0" && "$hour" == "*" ]]; then
        echo "hourly"
    elif [[ "$dom" == "*" && "$mon" == "*" && "$dow" == "*" ]]; then
        echo "daily at ${hour}:$(printf '%02d' "${min}")"
    elif [[ "$dow" != "*" ]]; then
        echo "weekly (dow=$dow) at ${hour}:$(printf '%02d' "${min}")"
    elif [[ "$dom" != "*" ]]; then
        echo "monthly (day $dom) at ${hour}:$(printf '%02d' "${min}")"
    else
        echo "$min $hour $dom $mon $dow"
    fi
}

# Parse user crontab
parse_crontab() {
    local source="$1"
    local label="$2"
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Skip variable assignments
        [[ "$line" =~ ^[A-Z_]+= ]] && continue
        
        # Parse cron fields
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
            local min="${BASH_REMATCH[1]}"
            local hour="${BASH_REMATCH[2]}"
            local dom="${BASH_REMATCH[3]}"
            local mon="${BASH_REMATCH[4]}"
            local dow="${BASH_REMATCH[5]}"
            local cmd="${BASH_REMATCH[6]}"
            local schedule="$min $hour $dom $mon $dow"
            local desc
            desc=$(describe_schedule "$min" "$hour" "$dom" "$mon" "$dow")
            
            JOB_COUNT=$((JOB_COUNT + 1))
            
            # Get short command name
            local short_cmd
            short_cmd=$(echo "$cmd" | awk '{print $1}' | xargs basename 2>/dev/null || echo "$cmd" | cut -c1-50)
            
            printf "[%d] %-20s %-40s (%s)\n" "$JOB_COUNT" "$schedule" "$short_cmd" "$desc"
            
            # Write JSON
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                echo ',' >> "$OUTPUT_FILE"
            fi
            
            # Escape command for JSON
            local escaped_cmd
            escaped_cmd=$(echo "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')
            
            cat >> "$OUTPUT_FILE" << JSONEOF
{"id":$JOB_COUNT,"schedule":"$schedule","command":"$escaped_cmd","description":"$desc","source":"$label"}
JSONEOF
        fi
    done <<< "$source"
}

# 1. User crontab
echo "--- User crontab ($(whoami)) ---"
USER_CRONTAB=$(crontab -l 2>/dev/null || echo "")
if [[ -n "$USER_CRONTAB" ]]; then
    parse_crontab "$USER_CRONTAB" "user:$(whoami)"
else
    echo "(no user crontab found)"
fi
echo ""

# 2. System crontab
if [[ -r /etc/crontab ]]; then
    echo "--- System crontab (/etc/crontab) ---"
    SYS_CRONTAB=$(cat /etc/crontab 2>/dev/null || echo "")
    if [[ -n "$SYS_CRONTAB" ]]; then
        parse_crontab "$SYS_CRONTAB" "system:/etc/crontab"
    fi
    echo ""
fi

# 3. /etc/cron.d/
if [[ -d /etc/cron.d ]]; then
    for f in /etc/cron.d/*; do
        [[ -f "$f" ]] || continue
        echo "--- $f ---"
        CRON_D=$(cat "$f" 2>/dev/null || echo "")
        if [[ -n "$CRON_D" ]]; then
            parse_crontab "$CRON_D" "cron.d:$(basename "$f")"
        fi
    done
    echo ""
fi

# Close JSON
echo ']}' >> "$OUTPUT_FILE"

echo "=== Found $JOB_COUNT cron jobs ==="
echo "Saved to: $OUTPUT_FILE"
