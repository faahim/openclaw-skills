#!/bin/bash
# check-history.sh — Check cron execution history from system logs
set -eo pipefail

HOURS=24
FORMAT="summary"
GREP_FILTER=""
DATA_DIR="${CRON_MONITOR_DATA:-$HOME/.cron-monitor/data}"
mkdir -p "$DATA_DIR"

while [[ $# -gt 0 ]]; do
    case $1 in
        --hours) HOURS="$2"; shift 2 ;;
        --format) FORMAT="$2"; shift 2 ;;  # summary, detail, json, markdown
        --grep) GREP_FILTER="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

SINCE=$(date -d "$HOURS hours ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-${HOURS}H '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")

# Collect cron log entries
collect_logs() {
    local entries=""
    
    # Try journalctl first (systemd)
    if command -v journalctl &>/dev/null; then
        entries=$(journalctl -u cron --since "$HOURS hours ago" --no-pager 2>/dev/null || \
                  journalctl _COMM=cron --since "$HOURS hours ago" --no-pager 2>/dev/null || \
                  journalctl -t CRON --since "$HOURS hours ago" --no-pager 2>/dev/null || \
                  echo "")
    fi
    
    # Fallback to syslog
    if [[ -z "$entries" ]] && [[ -r /var/log/syslog ]]; then
        local cutoff
        cutoff=$(date -d "$HOURS hours ago" '+%b %d %H:%M' 2>/dev/null || echo "")
        entries=$(grep -i "cron" /var/log/syslog 2>/dev/null | tail -1000 || echo "")
    fi
    
    # Fallback to /var/log/cron
    if [[ -z "$entries" ]] && [[ -r /var/log/cron ]]; then
        entries=$(tail -1000 /var/log/cron 2>/dev/null || echo "")
    fi
    
    if [[ -n "$GREP_FILTER" ]]; then
        echo "$entries" | grep -i "$GREP_FILTER" || echo ""
    else
        echo "$entries"
    fi
}

# Parse log entries to extract job execution data
parse_executions() {
    local logs="$1"
    declare -A job_runs
    declare -A job_success
    declare -A job_fail
    
    # Count CMD entries (executed jobs)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        # Match CRON CMD lines
        if [[ "$line" =~ CMD[[:space:]]*\((.+)\) ]]; then
            local cmd="${BASH_REMATCH[1]}"
            # Extract base command name
            local base_cmd
            base_cmd=$(echo "$cmd" | awk '{print $1}' | xargs basename 2>/dev/null || echo "$cmd" | cut -c1-40)
            
            job_runs["$base_cmd"]=$(( ${job_runs["$base_cmd"]:-0} + 1 ))
            job_success["$base_cmd"]=$(( ${job_success["$base_cmd"]:-0} + 1 ))
        fi
        
        # Match error/failure lines
        if [[ "$line" =~ (ERROR|FAIL|error|failed) ]] && [[ "$line" =~ CMD ]]; then
            if [[ "$line" =~ CMD[[:space:]]*\((.+)\) ]]; then
                local cmd="${BASH_REMATCH[1]}"
                local base_cmd
                base_cmd=$(echo "$cmd" | awk '{print $1}' | xargs basename 2>/dev/null || echo "$cmd" | cut -c1-40)
                job_fail["$base_cmd"]=$(( ${job_fail["$base_cmd"]:-0} + 1 ))
                job_success["$base_cmd"]=$(( ${job_success["$base_cmd"]:-0} - 1 ))
            fi
        fi
    done <<< "$logs"
    
    # Output based on format
    local total_jobs=${#job_runs[@]}
    local total_runs=0
    local total_failures=0
    local healthy=0
    local failed=0
    
    for job in "${!job_runs[@]}"; do
        total_runs=$((total_runs + ${job_runs[$job]}))
        local fails=${job_fail[$job]:-0}
        total_failures=$((total_failures + fails))
        if [[ $fails -gt 0 ]]; then
            failed=$((failed + 1))
        else
            healthy=$((healthy + 1))
        fi
    done
    
    case "$FORMAT" in
        summary)
            echo "=== Cron Execution Report (last ${HOURS}h) ==="
            echo ""
            if [[ $total_jobs -eq 0 ]]; then
                echo "No cron executions found in logs."
                echo ""
                echo "Possible reasons:"
                echo "  - No cron jobs configured"
                echo "  - Insufficient permissions (try with sudo)"
                echo "  - Cron logging not enabled"
                return
            fi
            
            for job in $(echo "${!job_runs[@]}" | tr ' ' '\n' | sort); do
                local runs=${job_runs[$job]}
                local fails=${job_fail[$job]:-0}
                local success=$((runs - fails))
                local pct=0
                [[ $runs -gt 0 ]] && pct=$(( (success * 100) / runs ))
                
                if [[ $fails -gt 0 ]]; then
                    printf "❌ %-25s — %d/%d runs  (%d%% success, %d failures)\n" "$job" "$success" "$runs" "$pct" "$fails"
                else
                    printf "✅ %-25s — %d/%d runs  (100%% success)\n" "$job" "$runs" "$runs"
                fi
            done
            
            echo ""
            echo "Total: $total_jobs jobs, $total_runs executions, $total_failures failures"
            echo "Health: $healthy healthy, $failed with issues"
            ;;
        
        json)
            echo '{"report_period_hours":'$HOURS',"generated_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",'
            echo '"summary":{"total_jobs":'$total_jobs',"total_runs":'$total_runs',"total_failures":'$total_failures'},'
            echo '"jobs":['
            local first=true
            for job in "${!job_runs[@]}"; do
                local runs=${job_runs[$job]}
                local fails=${job_fail[$job]:-0}
                [[ "$first" = true ]] && first=false || echo ','
                echo '{"name":"'"$job"'","runs":'$runs',"failures":'$fails'}'
            done
            echo ']}'
            ;;
        
        markdown)
            echo "# Cron Job Report — Last ${HOURS}h"
            echo ""
            echo "| Job | Runs | Success Rate | Failures |"
            echo "|-----|------|-------------|----------|"
            for job in $(echo "${!job_runs[@]}" | tr ' ' '\n' | sort); do
                local runs=${job_runs[$job]}
                local fails=${job_fail[$job]:-0}
                local pct=0
                [[ $runs -gt 0 ]] && pct=$(( ((runs - fails) * 100) / runs ))
                echo "| $job | $runs | ${pct}% | $fails |"
            done
            echo ""
            echo "**Total:** $total_jobs jobs, $total_runs executions, $total_failures failures"
            ;;
    esac
}

# Save history
HISTORY_FILE="$DATA_DIR/history-$(date +%Y%m%d-%H%M%S).json"

echo "Collecting cron logs (last ${HOURS}h)..."
LOGS=$(collect_logs)

if [[ -z "$LOGS" || "$LOGS" == *"No journal files"* ]]; then
    echo ""
    echo "⚠️  No cron log entries found."
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check if cron is running: systemctl status cron"
    echo "  2. Check journal access: journalctl -u cron --since '1 hour ago'"
    echo "  3. Check syslog: grep CRON /var/log/syslog"
    echo "  4. Try with sudo: sudo bash $0 --hours $HOURS"
    exit 0
fi

parse_executions "$LOGS"

# Save JSON version for historical tracking
if [[ "$FORMAT" != "json" ]]; then
    FORMAT_BAK="$FORMAT"
    FORMAT="json"
    parse_executions "$LOGS" > "$HISTORY_FILE" 2>/dev/null || true
    FORMAT="$FORMAT_BAK"
fi
