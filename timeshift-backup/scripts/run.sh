#!/bin/bash
# Timeshift System Backup — Main Runner
# Usage: bash run.sh [--create|--list|--restore|--delete|--schedule|--status|--prune|--check-disk]
set -euo pipefail

# ─── Config ───
CONFIG_DIR="${TIMESHIFT_CONFIG_DIR:-/etc/timeshift}"
LOG_FILE="${TIMESHIFT_LOG:-/var/log/timeshift-skill.log}"

# ─── Helpers ───
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$(timestamp)] $1"; }
die() { log "❌ $1"; exit 1; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script requires root/sudo. Run: sudo bash $0 $*"
    fi
}

check_timeshift() {
    command -v timeshift &>/dev/null || die "Timeshift not installed. Run: bash scripts/install.sh"
}

# ─── Commands ───

cmd_create() {
    check_root
    check_timeshift
    local comment="${COMMENT:-Manual snapshot}"
    log "📸 Creating snapshot: $comment"
    timeshift --create --comments "$comment" --yes
    log "✅ Snapshot created successfully"
}

cmd_list() {
    check_timeshift
    sudo timeshift --list 2>/dev/null || timeshift --list
}

cmd_restore() {
    check_root
    check_timeshift
    [[ -z "${SNAPSHOT:-}" ]] && die "Specify snapshot: --snapshot <name>"
    echo ""
    echo "⚠️  WARNING: This will restore your system to snapshot: $SNAPSHOT"
    echo "   Files outside /home will be replaced."
    echo ""
    read -p "Type YES to confirm: " confirm
    [[ "$confirm" == "YES" ]] || { echo "Cancelled."; exit 0; }
    log "🔄 Restoring snapshot: $SNAPSHOT"
    timeshift --restore --snapshot "$SNAPSHOT" --yes
    log "✅ Restore complete. Reboot recommended."
}

cmd_delete() {
    check_root
    check_timeshift
    [[ -z "${SNAPSHOT:-}" ]] && die "Specify snapshot: --snapshot <name>"
    log "🗑️ Deleting snapshot: $SNAPSHOT"
    timeshift --delete --snapshot "$SNAPSHOT" --yes
    log "✅ Snapshot deleted"
}

cmd_schedule() {
    check_root
    check_timeshift

    if [[ "${DISABLE:-}" == "true" ]]; then
        log "⏸️ Disabling scheduled snapshots..."
        timeshift --schedule-disable 2>/dev/null || {
            # Fallback: edit config directly
            sed -i 's/"schedule_daily" : "true"/"schedule_daily" : "false"/' "$CONFIG_DIR/timeshift.json" 2>/dev/null
            sed -i 's/"schedule_weekly" : "true"/"schedule_weekly" : "false"/' "$CONFIG_DIR/timeshift.json" 2>/dev/null
            sed -i 's/"schedule_monthly" : "true"/"schedule_monthly" : "false"/' "$CONFIG_DIR/timeshift.json" 2>/dev/null
        }
        log "✅ Scheduled snapshots disabled"
        return
    fi

    local daily="${DAILY:-0}"
    local weekly="${WEEKLY:-0}"
    local monthly="${MONTHLY:-0}"

    log "📅 Configuring schedule: daily=$daily, weekly=$weekly, monthly=$monthly"

    # Timeshift config is JSON at /etc/timeshift/timeshift.json
    # Create or update config
    local config="$CONFIG_DIR/timeshift.json"
    if [[ -f "$config" ]]; then
        # Update existing config
        if [[ "$daily" -gt 0 ]]; then
            sed -i "s/\"schedule_daily\" : \"false\"/\"schedule_daily\" : \"true\"/" "$config"
            sed -i "s/\"count_daily\" : \"[0-9]*\"/\"count_daily\" : \"$daily\"/" "$config"
        fi
        if [[ "$weekly" -gt 0 ]]; then
            sed -i "s/\"schedule_weekly\" : \"false\"/\"schedule_weekly\" : \"true\"/" "$config"
            sed -i "s/\"count_weekly\" : \"[0-9]*\"/\"count_weekly\" : \"$weekly\"/" "$config"
        fi
        if [[ "$monthly" -gt 0 ]]; then
            sed -i "s/\"schedule_monthly\" : \"false\"/\"schedule_monthly\" : \"true\"/" "$config"
            sed -i "s/\"count_monthly\" : \"[0-9]*\"/\"count_monthly\" : \"$monthly\"/" "$config"
        fi
    else
        log "⚠️ Config not found at $config. Run 'timeshift --create' first to generate config."
        return 1
    fi

    log "✅ Schedule configured"
}

cmd_status() {
    check_timeshift

    echo "Timeshift Status"
    echo "================"

    # Detect mode
    local config="$CONFIG_DIR/timeshift.json"
    if [[ -f "$config" ]]; then
        local mode=$(grep -o '"backup_device_uuid"[^,]*' "$config" 2>/dev/null | head -1 || echo "unknown")
        local snap_type=$(grep -o '"btrfs_mode"[^,]*' "$config" 2>/dev/null | head -1 || echo "RSYNC")
        echo "Config:     $config"
    fi

    # Count snapshots
    local count=$(sudo timeshift --list 2>/dev/null | grep -c "^[0-9]" || echo "0")
    echo "Snapshots:  $count total"

    # Check schedule
    if [[ -f "$config" ]]; then
        local daily=$(grep '"schedule_daily"' "$config" 2>/dev/null | grep -o 'true\|false' || echo "false")
        local weekly=$(grep '"schedule_weekly"' "$config" 2>/dev/null | grep -o 'true\|false' || echo "false")
        local monthly=$(grep '"schedule_monthly"' "$config" 2>/dev/null | grep -o 'true\|false' || echo "false")
        echo "Daily:      $daily"
        echo "Weekly:     $weekly"
        echo "Monthly:    $monthly"
    fi

    # Disk usage
    local snap_dir="/timeshift"
    if [[ -d "$snap_dir" ]]; then
        local usage=$(du -sh "$snap_dir" 2>/dev/null | awk '{print $1}')
        local disk_free=$(df -h "$snap_dir" 2>/dev/null | awk 'NR==2 {print $4}')
        echo "Used:       ${usage:-unknown}"
        echo "Disk free:  ${disk_free:-unknown}"
    fi
}

cmd_prune() {
    check_root
    check_timeshift
    local older_than="${OLDER_THAN:-30}"
    local cutoff=$(date -d "-${older_than} days" '+%Y-%m-%d' 2>/dev/null || date -v-${older_than}d '+%Y-%m-%d')

    log "🧹 Pruning snapshots older than $older_than days (before $cutoff)..."

    local deleted=0
    while IFS= read -r line; do
        local snap_name=$(echo "$line" | awk '{print $3}')
        local snap_date=$(echo "$snap_name" | grep -oP '^\d{4}-\d{2}-\d{2}' || continue)
        if [[ "$snap_date" < "$cutoff" ]]; then
            log "  Deleting: $snap_name"
            timeshift --delete --snapshot "$snap_name" --yes 2>/dev/null && ((deleted++))
        fi
    done < <(sudo timeshift --list 2>/dev/null | grep "^[0-9]")

    log "✅ Pruned $deleted snapshot(s)"
}

cmd_check_disk() {
    local threshold="${THRESHOLD:-80}"
    local snap_dir="/timeshift"
    [[ -d "$snap_dir" ]] || snap_dir="/"

    local usage_pct=$(df "$snap_dir" 2>/dev/null | awk 'NR==2 {gsub(/%/,""); print $5}')

    if [[ "${usage_pct:-0}" -ge "$threshold" ]]; then
        log "⚠️ ALERT: Snapshot disk at ${usage_pct}% capacity (threshold: ${threshold}%)"
        log "   Consider pruning: bash scripts/run.sh --prune --older-than 14"
        exit 2
    else
        log "✅ Disk usage OK: ${usage_pct}% (threshold: ${threshold}%)"
    fi
}

cmd_exclude() {
    check_root
    local config="$CONFIG_DIR/timeshift.json"
    [[ -f "$config" ]] || die "Config not found. Run 'timeshift --create' first."

    if [[ -n "${EXCLUDES:-}" ]]; then
        log "Adding excludes: $EXCLUDES"
        IFS=',' read -ra DIRS <<< "$EXCLUDES"
        for dir in "${DIRS[@]}"; do
            dir=$(echo "$dir" | xargs)  # trim whitespace
            log "  + $dir"
            # Add to exclude list in config
            sed -i "s|\"exclude\" : \[|\"exclude\" : [\n    \"$dir\",|" "$config" 2>/dev/null
        done
        log "✅ Excludes updated"
    fi
}

cmd_show_excludes() {
    local config="$CONFIG_DIR/timeshift.json"
    [[ -f "$config" ]] || die "Config not found."
    echo "Current excludes:"
    grep -A 100 '"exclude"' "$config" | grep '"/' | sed 's/[",]//g' | sed 's/^/  /'
}

cmd_list_devices() {
    echo "Available devices for snapshots:"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | grep -E "part|disk"
}

# ─── Parse Args ───
ACTION=""
COMMENT=""
SNAPSHOT=""
DAILY=0
WEEKLY=0
MONTHLY=0
DISABLE=""
OLDER_THAN=30
THRESHOLD=80
EXCLUDES=""
MODE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --create) ACTION="create"; shift ;;
        --list) ACTION="list"; shift ;;
        --restore) ACTION="restore"; shift ;;
        --delete) ACTION="delete"; shift ;;
        --schedule) ACTION="schedule"; shift ;;
        --status) ACTION="status"; shift ;;
        --prune) ACTION="prune"; shift ;;
        --check-disk) ACTION="check_disk"; shift ;;
        --exclude) ACTION="exclude"; EXCLUDES="$2"; shift 2 ;;
        --show-excludes) ACTION="show_excludes"; shift ;;
        --list-devices) ACTION="list_devices"; shift ;;
        --comment) COMMENT="$2"; shift 2 ;;
        --snapshot) SNAPSHOT="$2"; shift 2 ;;
        --daily) DAILY="$2"; shift 2 ;;
        --weekly) WEEKLY="$2"; shift 2 ;;
        --monthly) MONTHLY="$2"; shift 2 ;;
        --disable) DISABLE="true"; shift ;;
        --older-than) OLDER_THAN="$2"; shift 2 ;;
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        --device) DEVICE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: bash run.sh [ACTION] [OPTIONS]"
            echo ""
            echo "Actions:"
            echo "  --create              Create a new snapshot"
            echo "  --list                List all snapshots"
            echo "  --restore             Restore a snapshot"
            echo "  --delete              Delete a snapshot"
            echo "  --schedule            Configure scheduled snapshots"
            echo "  --status              Show current status"
            echo "  --prune               Delete old snapshots"
            echo "  --check-disk          Check disk space usage"
            echo "  --exclude <dirs>      Add exclude directories (comma-separated)"
            echo "  --show-excludes       Show current excludes"
            echo "  --list-devices        List available devices"
            echo ""
            echo "Options:"
            echo "  --comment <text>      Comment for snapshot"
            echo "  --snapshot <name>     Snapshot name (for restore/delete)"
            echo "  --daily <N>           Keep N daily snapshots"
            echo "  --weekly <N>          Keep N weekly snapshots"
            echo "  --monthly <N>         Keep N monthly snapshots"
            echo "  --disable             Disable scheduled snapshots"
            echo "  --older-than <days>   Prune snapshots older than N days"
            echo "  --threshold <pct>     Disk usage alert threshold (%)"
            exit 0
            ;;
        *) die "Unknown option: $1. Use --help for usage." ;;
    esac
done

[[ -z "$ACTION" ]] && die "No action specified. Use --help for usage."

# Run the action
"cmd_$ACTION"
