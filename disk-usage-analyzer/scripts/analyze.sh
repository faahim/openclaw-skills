#!/bin/bash
# Disk Usage Analyzer — Main Analysis Script
set -e

REPORTS_DIR="${DISK_ANALYZER_REPORTS:-/tmp/disk-reports}"
SNAPSHOTS_DIR="${DISK_ANALYZER_SNAPSHOTS:-/tmp/disk-analyzer-snapshots}"
ALERT_THRESHOLD="${DISK_ALERT_THRESHOLD:-85}"

mkdir -p "$REPORTS_DIR" "$SNAPSHOTS_DIR"

usage() {
    cat <<EOF
Disk Usage Analyzer

Usage: bash analyze.sh <command> [options]

Commands:
  overview                       Show disk usage overview (all filesystems)
  hogs <path> [count]            Find largest files/dirs (default: 20)
  find-large <path> <min-size>   Find files larger than min-size (e.g. 100M, 1G)
  find-stale <path> <min-size> <days>  Find large files older than N days
  tree <path> [depth]            Directory size treemap (default depth: 3)
  report                         Generate full disk report
  snapshot <path>                Save disk usage snapshot for later comparison
  compare <path>                 Compare current usage with last snapshot
  schedule <weekly|daily-report> Set up automated cron jobs
  alert                          Check if any filesystem exceeds threshold

Examples:
  bash analyze.sh overview
  bash analyze.sh hogs /home 20
  bash analyze.sh find-large / 1G
  bash analyze.sh tree /var 5
  bash analyze.sh report
EOF
}

cmd_overview() {
    echo "╭──────────────────────────────────────────────╮"
    echo "│  DISK USAGE OVERVIEW — $(date +%Y-%m-%d)          │"
    echo "╰──────────────────────────────────────────────╯"
    echo ""
    if command -v duf &>/dev/null; then
        duf --only local
    else
        df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs 2>/dev/null || df -h
    fi
}

cmd_hogs() {
    local path="${1:-/}"
    local count="${2:-20}"
    
    echo "🔍 Top $count space hogs in $path"
    echo "─────────────────────────────────────────"
    
    if command -v dust &>/dev/null; then
        dust -n "$count" -d 1 "$path" 2>/dev/null
    else
        du -ah "$path" 2>/dev/null | sort -rh | head -n "$count"
    fi
}

cmd_find_large() {
    local path="${1:-/}"
    local min_size="${2:-100M}"
    
    echo "🔍 Files larger than $min_size in $path"
    echo "─────────────────────────────────────────"
    
    find "$path" -type f -size +"$min_size" -exec ls -lhS {} \; 2>/dev/null | \
        awk '{print $5, $9}' | sort -rh | head -50
}

cmd_find_stale() {
    local path="${1:-/}"
    local min_size="${2:-100M}"
    local days="${3:-30}"
    
    echo "🔍 Files >$min_size older than $days days in $path"
    echo "─────────────────────────────────────────"
    
    find "$path" -type f -size +"$min_size" -mtime +"$days" -exec ls -lhS {} \; 2>/dev/null | \
        awk '{print $5, $6, $7, $8, $9}' | sort -rh | head -50
}

cmd_tree() {
    local path="${1:-/}"
    local depth="${2:-3}"
    
    echo "🌳 Directory size tree: $path (depth: $depth)"
    echo "─────────────────────────────────────────"
    
    if command -v dust &>/dev/null; then
        dust -d "$depth" "$path" 2>/dev/null
    else
        du -h --max-depth="$depth" "$path" 2>/dev/null | sort -rh | head -30
    fi
}

cmd_report() {
    local report_file="$REPORTS_DIR/disk-report-$(date +%Y-%m-%d_%H%M%S).txt"
    
    echo "📊 Generating full disk report..."
    
    {
        echo "═══════════════════════════════════════════════"
        echo "  DISK USAGE REPORT — $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Host: $(hostname)"
        echo "═══════════════════════════════════════════════"
        echo ""
        
        echo "== FILESYSTEM OVERVIEW =="
        echo ""
        if command -v duf &>/dev/null; then
            duf --only local 2>/dev/null
        else
            df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs 2>/dev/null || df -h
        fi
        echo ""
        
        echo "== TOP 20 LARGEST DIRECTORIES =="
        echo ""
        du -h --max-depth=2 / 2>/dev/null | sort -rh | head -20
        echo ""
        
        echo "== TOP 20 LARGEST FILES =="
        echo ""
        find / -type f -size +50M -exec ls -lhS {} \; 2>/dev/null | \
            awk '{print $5, $9}' | sort -rh | head -20
        echo ""
        
        echo "== CACHE SIZES =="
        echo ""
        for cache_dir in ~/.cache ~/.npm ~/.local/share/Trash /var/cache/apt; do
            if [ -d "$cache_dir" ]; then
                size=$(du -sh "$cache_dir" 2>/dev/null | awk '{print $1}')
                echo "  $size  $cache_dir"
            fi
        done
        echo ""
        
        echo "== LOG SIZES =="
        echo ""
        du -sh /var/log 2>/dev/null || echo "  (no access to /var/log)"
        if command -v journalctl &>/dev/null; then
            echo "  Journal: $(journalctl --disk-usage 2>/dev/null | awk '{print $NF}')"
        fi
        echo ""
        
        echo "== DOCKER (if available) =="
        echo ""
        if command -v docker &>/dev/null; then
            docker system df 2>/dev/null || echo "  Docker not running"
        else
            echo "  Docker not installed"
        fi
        echo ""
        
        echo "== ALERT CHECK =="
        echo ""
        df -h --output=source,pcent,target -x tmpfs -x devtmpfs 2>/dev/null | \
            tail -n +2 | while read -r src pct mount; do
                pct_num="${pct%\%}"
                if [ "$pct_num" -ge "$ALERT_THRESHOLD" ] 2>/dev/null; then
                    echo "  ⚠️  $mount is at $pct ($src)"
                fi
            done
        echo ""
        echo "═══════════════════════════════════════════════"
        echo "  Report saved: $report_file"
        echo "═══════════════════════════════════════════════"
        
    } | tee "$report_file"
    
    echo ""
    echo "📄 Report saved to: $report_file"
}

cmd_snapshot() {
    local path="${1:-/}"
    local snap_file="$SNAPSHOTS_DIR/snapshot-$(echo "$path" | tr '/' '_')-$(date +%Y-%m-%d).txt"
    
    echo "📸 Taking snapshot of $path..."
    du -a --max-depth=3 "$path" 2>/dev/null | sort -rn > "$snap_file"
    echo "✅ Snapshot saved: $snap_file ($(wc -l < "$snap_file") entries)"
}

cmd_compare() {
    local path="${1:-/}"
    local snap_pattern="$SNAPSHOTS_DIR/snapshot-$(echo "$path" | tr '/' '_')-*.txt"
    local latest_snap=$(ls -t $snap_pattern 2>/dev/null | head -1)
    
    if [ -z "$latest_snap" ]; then
        echo "❌ No previous snapshot found for $path"
        echo "   Run: bash analyze.sh snapshot $path"
        return 1
    fi
    
    echo "📊 Comparing current $path with snapshot: $(basename "$latest_snap")"
    echo "─────────────────────────────────────────"
    
    local tmp_current="/tmp/disk-current-$$.txt"
    du -a --max-depth=3 "$path" 2>/dev/null | sort -rn > "$tmp_current"
    
    # Compare top directories
    echo ""
    echo "Directory Growth Report:"
    echo ""
    
    # Get top 15 dirs from current
    head -15 "$tmp_current" | while read -r cur_size cur_path; do
        old_size=$(grep -w "$cur_path" "$latest_snap" 2>/dev/null | awk '{print $1}')
        if [ -n "$old_size" ]; then
            diff_kb=$((cur_size - old_size))
            if [ "$diff_kb" -gt 102400 ]; then  # >100MB change
                diff_human=$(numfmt --to=iec-i --suffix=B $((diff_kb * 1024)) 2>/dev/null || echo "${diff_kb}K")
                cur_human=$(numfmt --to=iec-i --suffix=B $((cur_size * 1024)) 2>/dev/null || echo "${cur_size}K")
                if [ "$diff_kb" -gt 0 ]; then
                    echo "  +$diff_human  $cur_path (now $cur_human)"
                else
                    echo "  $diff_human  $cur_path (now $cur_human) ✅"
                fi
            fi
        fi
    done
    
    rm -f "$tmp_current"
}

cmd_alert() {
    local alerts=0
    echo "🔔 Checking disk usage thresholds (alert at ${ALERT_THRESHOLD}%)..."
    echo ""
    
    df --output=source,pcent,target -x tmpfs -x devtmpfs 2>/dev/null | \
        tail -n +2 | while read -r src pct mount; do
            pct_num="${pct%\%}"
            if [ "$pct_num" -ge "$ALERT_THRESHOLD" ] 2>/dev/null; then
                echo "  ⚠️  ALERT: $mount is at $pct ($src)"
                alerts=$((alerts + 1))
            else
                echo "  ✅ $mount: $pct"
            fi
        done
    
    if [ "$alerts" -eq 0 ]; then
        echo ""
        echo "✅ All filesystems below ${ALERT_THRESHOLD}% threshold"
    fi
}

cmd_schedule() {
    local schedule_type="${1:-weekly}"
    local script_path="$(cd "$(dirname "$0")" && pwd)"
    
    case "$schedule_type" in
        weekly)
            local cron_line="0 3 * * 0 cd $script_path && bash cleanup.sh --execute >> /var/log/disk-cleanup.log 2>&1"
            echo "📅 Adding weekly cleanup cron (Sunday 3am)..."
            (crontab -l 2>/dev/null | grep -v "disk-cleanup"; echo "$cron_line") | crontab -
            echo "✅ Weekly cleanup scheduled"
            ;;
        daily-report)
            local cron_line="0 8 * * * cd $script_path && bash analyze.sh report >> /dev/null 2>&1"
            echo "📅 Adding daily report cron (8am)..."
            (crontab -l 2>/dev/null | grep -v "disk-report"; echo "$cron_line") | crontab -
            echo "✅ Daily report scheduled"
            ;;
        *)
            echo "❌ Unknown schedule type: $schedule_type"
            echo "   Use: weekly | daily-report"
            return 1
            ;;
    esac
}

# Main dispatcher
case "${1:-}" in
    overview)    cmd_overview ;;
    hogs)        cmd_hogs "$2" "$3" ;;
    find-large)  cmd_find_large "$2" "$3" ;;
    find-stale)  cmd_find_stale "$2" "$3" "$4" ;;
    tree)        cmd_tree "$2" "$3" ;;
    report)      cmd_report ;;
    snapshot)    cmd_snapshot "$2" ;;
    compare)     cmd_compare "$2" ;;
    schedule)    cmd_schedule "$2" ;;
    alert)       cmd_alert ;;
    *)           usage ;;
esac
