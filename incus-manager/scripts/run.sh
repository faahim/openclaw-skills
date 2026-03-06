#!/bin/bash
# Incus Manager — Helper Script
# Batch operations, status reports, backups

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[incus-mgr]${NC} $1"; }
warn() { echo -e "${YELLOW}[incus-mgr]${NC} $1"; }
err() { echo -e "${RED}[incus-mgr]${NC} $1" >&2; }

# Show status of all instances
cmd_status() {
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Incus Instance Status Report${NC}"
    echo -e "${CYAN}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""

    # Instance list
    incus list -f compact

    echo ""
    echo -e "${CYAN}── Storage Pools ──${NC}"
    incus storage list -f compact 2>/dev/null || echo "  No storage pools configured"

    echo ""
    echo -e "${CYAN}── Networks ──${NC}"
    incus network list -f compact 2>/dev/null || echo "  No custom networks"

    echo ""
    echo -e "${CYAN}── Resource Usage ──${NC}"
    local RUNNING=$(incus list status=running -f csv -c n 2>/dev/null | wc -l)
    local STOPPED=$(incus list status=stopped -f csv -c n 2>/dev/null | wc -l)
    local TOTAL=$((RUNNING + STOPPED))
    echo "  Running: $RUNNING / $TOTAL instances"

    # Per-instance CPU/memory if running
    if [ "$RUNNING" -gt 0 ]; then
        echo ""
        echo -e "${CYAN}── Instance Resources ──${NC}"
        printf "  %-20s %-10s %-10s %-10s\n" "NAME" "STATE" "CPU" "MEMORY"
        printf "  %-20s %-10s %-10s %-10s\n" "----" "-----" "---" "------"
        for name in $(incus list status=running -f csv -c n 2>/dev/null); do
            local cpu_limit=$(incus config get "$name" limits.cpu 2>/dev/null || echo "-")
            local mem_limit=$(incus config get "$name" limits.memory 2>/dev/null || echo "-")
            [ -z "$cpu_limit" ] && cpu_limit="-"
            [ -z "$mem_limit" ] && mem_limit="-"
            printf "  %-20s %-10s %-10s %-10s\n" "$name" "RUNNING" "$cpu_limit" "$mem_limit"
        done
    fi
}

# Execute command on all running containers
cmd_batch_exec() {
    local CMD="${1:?Usage: run.sh batch-exec '<command>'}"

    local INSTANCES=$(incus list status=running -f csv -c n 2>/dev/null)
    if [ -z "$INSTANCES" ]; then
        warn "No running instances found."
        return 0
    fi

    for name in $INSTANCES; do
        echo -e "\n${CYAN}── $name ──${NC}"
        incus exec "$name" -- bash -c "$CMD" 2>&1 || warn "Failed on $name"
    done
}

# Snapshot all instances
cmd_batch_snapshot() {
    local SNAP_NAME="${1:-snap-$(date +%Y%m%d-%H%M%S)}"

    local INSTANCES=$(incus list -f csv -c n 2>/dev/null)
    if [ -z "$INSTANCES" ]; then
        warn "No instances found."
        return 0
    fi

    for name in $INSTANCES; do
        log "Snapshotting $name → $SNAP_NAME"
        incus snapshot create "$name" "$SNAP_NAME" 2>&1 || warn "Failed to snapshot $name"
    done

    log "Done. Created snapshot '$SNAP_NAME' on $(echo "$INSTANCES" | wc -w) instances."
}

# Backup all instances to directory
cmd_backup() {
    local BACKUP_DIR="${1:?Usage: run.sh backup /path/to/backups/}"

    mkdir -p "$BACKUP_DIR"

    local INSTANCES=$(incus list -f csv -c n 2>/dev/null)
    if [ -z "$INSTANCES" ]; then
        warn "No instances found."
        return 0
    fi

    for name in $INSTANCES; do
        local BACKUP_FILE="$BACKUP_DIR/${name}-$(date +%Y%m%d-%H%M%S).tar.gz"
        log "Backing up $name → $BACKUP_FILE"
        incus export "$name" "$BACKUP_FILE" 2>&1 || warn "Failed to backup $name"
    done

    log "Backups saved to $BACKUP_DIR"
    ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null
}

# Cleanup old snapshots
cmd_cleanup_snapshots() {
    local MAX_AGE_DAYS="${1:-7}"

    local INSTANCES=$(incus list -f csv -c n 2>/dev/null)
    if [ -z "$INSTANCES" ]; then
        warn "No instances found."
        return 0
    fi

    local CUTOFF=$(date -d "$MAX_AGE_DAYS days ago" +%Y%m%d 2>/dev/null || date -v-${MAX_AGE_DAYS}d +%Y%m%d)

    for name in $INSTANCES; do
        local SNAPS=$(incus snapshot list "$name" -f csv -c n 2>/dev/null)
        for snap in $SNAPS; do
            # Try to extract date from snapshot name (format: *-YYYYMMDD*)
            local SNAP_DATE=$(echo "$snap" | grep -oE '[0-9]{8}' | head -1)
            if [ -n "$SNAP_DATE" ] && [ "$SNAP_DATE" -lt "$CUTOFF" ] 2>/dev/null; then
                log "Deleting old snapshot: $name/$snap"
                incus snapshot delete "$name" "$snap"
            fi
        done
    done
}

# Main dispatcher
case "${1:-help}" in
    status)
        cmd_status
        ;;
    batch-exec)
        cmd_batch_exec "${2:-}"
        ;;
    batch-snapshot)
        cmd_batch_snapshot "${2:-}"
        ;;
    backup)
        cmd_backup "${2:-}"
        ;;
    cleanup-snapshots)
        cmd_cleanup_snapshots "${2:-7}"
        ;;
    help|*)
        echo "Incus Manager — Helper Commands"
        echo ""
        echo "Usage: bash scripts/run.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  status                    Show all instances, resources, networks"
        echo "  batch-exec '<cmd>'        Run command on all running instances"
        echo "  batch-snapshot [name]     Snapshot all instances"
        echo "  backup /path/             Export all instances to backup files"
        echo "  cleanup-snapshots [days]  Remove snapshots older than N days (default: 7)"
        echo ""
        ;;
esac
