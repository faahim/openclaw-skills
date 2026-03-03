#!/bin/bash
# BTRFS Snapshot Manager — Create, list, cleanup, rollback BTRFS snapshots
# Requires: btrfs-progs, bash 4.0+, root access

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${BTRFS_SNAP_LOG:-/var/log/btrfs-snap.log}"
DATE_FMT="+%Y-%m-%d_%H-%M-%S"
TIMESTAMP_FMT="+%Y-%m-%d %H:%M:%S"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "[$(date "$TIMESTAMP_FMT")] $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "[$(date "$TIMESTAMP_FMT")] $*"; }
err() { log "${RED}❌ $*${NC}" >&2; }
ok()  { log "${GREEN}✅ $*${NC}"; }
warn(){ log "${YELLOW}⚠️  $*${NC}"; }
info(){ log "${BLUE}ℹ️  $*${NC}"; }

# Check prerequisites
check_btrfs() {
    if ! command -v btrfs &>/dev/null; then
        err "btrfs-progs not installed. Install: sudo apt install btrfs-progs"
        exit 1
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "This script must be run as root (sudo)"
        exit 1
    fi
}

# Verify path is on a BTRFS filesystem
verify_btrfs_path() {
    local path="$1"
    local fstype
    fstype=$(df -T "$path" 2>/dev/null | awk 'NR==2 {print $2}')
    if [[ "$fstype" != "btrfs" ]]; then
        err "$path is not on a BTRFS filesystem (detected: ${fstype:-unknown})"
        exit 1
    fi
}

# Get or create snapshot directory
get_snap_dir() {
    local subvol="$1"
    local snap_dir="${BTRFS_SNAP_DIR:-${subvol}/.snapshots}"
    mkdir -p "$snap_dir"
    echo "$snap_dir"
}

# ─── SNAP: Create a snapshot ────────────────────────────────────────
cmd_snap() {
    local subvol="${1:?Usage: btrfs-snap.sh snap <subvolume> [--label <label>]}"
    shift
    local label=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --label|-l) label="_${2:?--label requires a value}"; shift 2 ;;
            *) err "Unknown option: $1"; exit 1 ;;
        esac
    done

    check_root
    verify_btrfs_path "$subvol"

    local snap_dir
    snap_dir=$(get_snap_dir "$subvol")
    local snap_name
    snap_name="$(date "$DATE_FMT")${label}"
    local snap_path="${snap_dir}/${snap_name}"

    if [[ -d "$snap_path" ]]; then
        warn "Snapshot already exists: $snap_path"
        return 0
    fi

    btrfs subvolume snapshot -r "$subvol" "$snap_path" >/dev/null 2>&1
    ok "Snapshot created: ${snap_path}"
}

# ─── LIST: Show snapshots ───────────────────────────────────────────
cmd_list() {
    local subvol="${1:?Usage: btrfs-snap.sh list <subvolume>}"
    local snap_dir
    snap_dir=$(get_snap_dir "$subvol")

    if [[ ! -d "$snap_dir" ]] || [[ -z "$(ls -A "$snap_dir" 2>/dev/null)" ]]; then
        info "No snapshots found for $subvol"
        return 0
    fi

    echo ""
    echo "BTRFS Snapshots for $subvol"
    echo "─────────────────────────────────────────────"
    printf " %-3s %-45s %-8s %s\n" "#" "Snapshot" "Type" "Label"
    echo "─────────────────────────────────────────────"

    local i=1
    for snap in $(ls -1d "$snap_dir"/*/ 2>/dev/null | sort -r); do
        local name
        name=$(basename "$snap")
        local snap_label=""
        local snap_type="manual"

        # Extract label from name (after datetime)
        if [[ "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}_(.*) ]]; then
            snap_label="${BASH_REMATCH[1]}"
            if [[ "$snap_label" =~ ^(hourly|daily|weekly|monthly)$ ]]; then
                snap_type="$snap_label"
                snap_label=""
            fi
        fi

        printf " %-3d %-45s %-8s %s\n" "$i" "$name" "$snap_type" "$snap_label"
        ((i++))
    done
    echo ""
    echo "Total: $((i-1)) snapshots"
}

# ─── CLEANUP: Apply retention policy ────────────────────────────────
cmd_cleanup() {
    local subvol="${1:?Usage: btrfs-snap.sh cleanup <subvolume> [--hourly N] [--daily N] [--weekly N] [--monthly N]}"
    shift

    local keep_hourly=24 keep_daily=7 keep_weekly=4 keep_monthly=6

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --hourly)  keep_hourly="${2:?}"; shift 2 ;;
            --daily)   keep_daily="${2:?}"; shift 2 ;;
            --weekly)  keep_weekly="${2:?}"; shift 2 ;;
            --monthly) keep_monthly="${2:?}"; shift 2 ;;
            *) err "Unknown option: $1"; exit 1 ;;
        esac
    done

    check_root
    verify_btrfs_path "$subvol"

    local snap_dir
    snap_dir=$(get_snap_dir "$subvol")
    local deleted=0
    local retained=0

    # Collect all snapshots sorted oldest first
    local all_snaps=()
    while IFS= read -r snap; do
        [[ -n "$snap" ]] && all_snaps+=("$snap")
    done < <(ls -1d "$snap_dir"/*/ 2>/dev/null | sort)

    if [[ ${#all_snaps[@]} -eq 0 ]]; then
        info "No snapshots to clean up"
        return 0
    fi

    # Categorize snapshots by type based on label suffix
    local hourly=() daily=() weekly=() monthly=() other=()
    for snap in "${all_snaps[@]}"; do
        local name
        name=$(basename "$snap")
        case "$name" in
            *_hourly)  hourly+=("$snap") ;;
            *_daily)   daily+=("$snap") ;;
            *_weekly)  weekly+=("$snap") ;;
            *_monthly) monthly+=("$snap") ;;
            *)         other+=("$snap") ;;
        esac
    done

    # Delete excess snapshots (keep newest N)
    delete_excess() {
        local -n arr=$1
        local keep=$2
        local count=${#arr[@]}
        if [[ $count -gt $keep ]]; then
            local to_delete=$((count - keep))
            for ((i=0; i<to_delete; i++)); do
                local snap="${arr[$i]}"
                if btrfs subvolume delete "$snap" >/dev/null 2>&1; then
                    ((deleted++))
                else
                    warn "Failed to delete: $snap"
                fi
            done
        fi
        retained=$((retained + (count > keep ? keep : count)))
    }

    delete_excess hourly "$keep_hourly"
    delete_excess daily "$keep_daily"
    delete_excess weekly "$keep_weekly"
    delete_excess monthly "$keep_monthly"
    # Keep all manually-labeled snapshots
    retained=$((retained + ${#other[@]}))

    ok "Deleted $deleted expired snapshots"
    info "Retained: $retained snapshots"

    # Estimate freed space
    if command -v btrfs &>/dev/null; then
        local usage
        usage=$(btrfs filesystem usage -b "$subvol" 2>/dev/null | grep "Free (estimated)" | awk '{print $3}' || echo "unknown")
        info "Free space: $usage"
    fi
}

# ─── ROLLBACK: Restore from snapshot ────────────────────────────────
cmd_rollback() {
    local subvol="${1:?Usage: btrfs-snap.sh rollback <subvolume> <snapshot-name>}"
    local snap_name="${2:?Specify snapshot name (use 'list' to see available)}"

    check_root
    verify_btrfs_path "$subvol"

    local snap_dir
    snap_dir=$(get_snap_dir "$subvol")
    local snap_path="${snap_dir}/${snap_name}"

    if [[ ! -d "$snap_path" ]]; then
        err "Snapshot not found: $snap_path"
        echo "Available snapshots:"
        cmd_list "$subvol"
        exit 1
    fi

    # Create safety snapshot first
    local safety_name
    safety_name="$(date "$DATE_FMT")_pre-rollback"
    local safety_path="${snap_dir}/${safety_name}"

    warn "Rolling back $subvol to snapshot: $snap_name"
    btrfs subvolume snapshot -r "$subvol" "$safety_path" >/dev/null 2>&1
    ok "Safety snapshot created: $safety_path"

    # Create a writable snapshot from the target, then swap
    local restore_path="${snap_dir}/_restore_tmp"
    rm -rf "$restore_path" 2>/dev/null || true

    btrfs subvolume snapshot "$snap_path" "$restore_path" >/dev/null 2>&1

    # For non-root: we can replace contents
    # For root: need to update fstab subvol= or use a bootloader entry
    local mount_point
    mount_point=$(df "$subvol" | awk 'NR==2 {print $6}')

    if [[ "$mount_point" == "/" ]]; then
        warn "Root filesystem rollback detected."
        warn "The restore snapshot is at: $restore_path"
        warn "To complete: update /etc/fstab subvol= to point to $restore_path, then reboot."
        info "Or use: btrfs subvolume set-default <id> <mount>"
        local subvol_id
        subvol_id=$(btrfs subvolume show "$restore_path" 2>/dev/null | grep "Subvolume ID" | awk '{print $3}')
        if [[ -n "$subvol_id" ]]; then
            info "Subvolume ID: $subvol_id"
            info "Run: sudo btrfs subvolume set-default $subvol_id /"
        fi
    else
        ok "Rollback prepared at: $restore_path"
        info "To finalize: unmount $subvol, rename $restore_path to $subvol"
    fi

    ok "Rollback complete. Reboot recommended for root subvolumes."
}

# ─── DIFF: Show changes between snapshots ───────────────────────────
cmd_diff() {
    local subvol="${1:?Usage: btrfs-snap.sh diff <subvolume> <snap1> <snap2>}"
    local snap1="${2:?Specify first snapshot name}"
    local snap2="${3:?Specify second snapshot name}"

    check_root

    local snap_dir
    snap_dir=$(get_snap_dir "$subvol")
    local path1="${snap_dir}/${snap1}"
    local path2="${snap_dir}/${snap2}"

    [[ ! -d "$path1" ]] && { err "Snapshot not found: $path1"; exit 1; }
    [[ ! -d "$path2" ]] && { err "Snapshot not found: $path2"; exit 1; }

    echo ""
    echo "Changes between $snap1 → $snap2"
    echo "─────────────────────────────────────────────"

    # Use btrfs send to detect changes (dry-run)
    local added=0 modified=0 deleted=0

    # Find new generation info
    btrfs subvolume find-new "$path2" 9999999 2>/dev/null | head -50 | while read -r line; do
        if [[ "$line" =~ ^inode ]]; then
            local file
            file=$(echo "$line" | awk '{print $NF}')
            if [[ -e "${path1}/${file}" ]]; then
                echo "~  ${file}  (modified)"
                ((modified++)) || true
            else
                echo "+  ${file}  (added)"
                ((added++)) || true
            fi
        fi
    done

    echo ""
    info "Use 'btrfs send --no-data -p $path1 $path2' for detailed binary diff"
}

# ─── STATUS: Show snapshot disk usage ────────────────────────────────
cmd_status() {
    local subvol="${1:?Usage: btrfs-snap.sh status <subvolume>}"

    check_root
    verify_btrfs_path "$subvol"

    local snap_dir
    snap_dir=$(get_snap_dir "$subvol")

    echo ""
    echo "BTRFS Snapshot Status for $subvol"
    echo "────────────────────────────────"

    # Filesystem info
    local device
    device=$(df "$subvol" | awk 'NR==2 {print $1}')
    echo "Filesystem:    $device"

    btrfs filesystem usage "$subvol" 2>/dev/null | grep -E "^(Device size|Used|Free)" | while read -r line; do
        echo "$line"
    done

    # Snapshot count
    local count=0 oldest="" newest=""
    if [[ -d "$snap_dir" ]]; then
        count=$(ls -1d "$snap_dir"/*/ 2>/dev/null | wc -l)
        oldest=$(ls -1d "$snap_dir"/*/ 2>/dev/null | sort | head -1 | xargs basename 2>/dev/null || echo "none")
        newest=$(ls -1d "$snap_dir"/*/ 2>/dev/null | sort | tail -1 | xargs basename 2>/dev/null || echo "none")
    fi

    echo "Snapshots:     $count"
    [[ -n "$oldest" ]] && echo "Oldest:        $oldest"
    [[ -n "$newest" ]] && echo "Newest:        $newest"
    echo ""
}

# ─── SEND: Send snapshot to remote ──────────────────────────────────
cmd_send() {
    local subvol="${1:?Usage: btrfs-snap.sh send <subvolume> <snapshot> [--parent <parent-snap>] --remote <user@host:/path>}"
    local snap_name="${2:?Specify snapshot name}"
    shift 2

    local parent="" remote=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --parent|-p) parent="$2"; shift 2 ;;
            --remote|-r) remote="$2"; shift 2 ;;
            *) err "Unknown option: $1"; exit 1 ;;
        esac
    done

    [[ -z "$remote" ]] && { err "--remote is required"; exit 1; }

    check_root

    local snap_dir
    snap_dir=$(get_snap_dir "$subvol")
    local snap_path="${snap_dir}/${snap_name}"

    [[ ! -d "$snap_path" ]] && { err "Snapshot not found: $snap_path"; exit 1; }

    local remote_host="${remote%%:*}"
    local remote_path="${remote#*:}"

    info "Sending snapshot to $remote_host:$remote_path"

    if [[ -n "$parent" ]]; then
        local parent_path="${snap_dir}/${parent}"
        [[ ! -d "$parent_path" ]] && { err "Parent snapshot not found: $parent_path"; exit 1; }
        btrfs send -p "$parent_path" "$snap_path" | ssh "$remote_host" "btrfs receive $remote_path"
        ok "Incremental send complete (parent: $parent)"
    else
        btrfs send "$snap_path" | ssh "$remote_host" "btrfs receive $remote_path"
        ok "Full send complete"
    fi
}

# ─── INSTALL-CRON: Set up automated snapshots ───────────────────────
cmd_install_cron() {
    local config="${1:-config.yaml}"

    check_root

    if [[ ! -f "$config" ]]; then
        err "Config file not found: $config"
        info "Copy the template: cp scripts/config-template.yaml config.yaml"
        exit 1
    fi

    local script_path
    script_path="$(realpath "$SCRIPT_DIR/btrfs-snap.sh")"

    # Parse YAML config (basic parser — handles our simple format)
    local subvols=()
    local current_path=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*path:[[:space:]]*(.+) ]]; then
            current_path="${BASH_REMATCH[1]}"
            subvols+=("$current_path")
        fi
    done < "$config"

    if [[ ${#subvols[@]} -eq 0 ]]; then
        err "No subvolumes found in config"
        exit 1
    fi

    # Install cron jobs
    local crontab_tmp
    crontab_tmp=$(mktemp)
    crontab -l > "$crontab_tmp" 2>/dev/null || true

    # Remove existing btrfs-snap entries
    grep -v "btrfs-snap" "$crontab_tmp" > "${crontab_tmp}.clean" || true
    mv "${crontab_tmp}.clean" "$crontab_tmp"

    for subvol in "${subvols[@]}"; do
        # Hourly snapshot
        echo "0 * * * * $script_path snap $subvol --label hourly >> $LOG_FILE 2>&1" >> "$crontab_tmp"
        ok "Cron installed: hourly snapshots for $subvol"

        # Daily cleanup at midnight
        echo "0 0 * * * $script_path cleanup $subvol --hourly 24 --daily 7 --weekly 4 --monthly 6 >> $LOG_FILE 2>&1" >> "$crontab_tmp"
        ok "Cron installed: daily cleanup for $subvol"

        # Daily labeled snapshot
        echo "0 0 * * * $script_path snap $subvol --label daily >> $LOG_FILE 2>&1" >> "$crontab_tmp"

        # Weekly labeled snapshot (Sunday)
        echo "0 0 * * 0 $script_path snap $subvol --label weekly >> $LOG_FILE 2>&1" >> "$crontab_tmp"

        # Monthly labeled snapshot (1st of month)
        echo "0 0 1 * * $script_path snap $subvol --label monthly >> $LOG_FILE 2>&1" >> "$crontab_tmp"
    done

    crontab "$crontab_tmp"
    rm -f "$crontab_tmp"

    ok "All cron jobs installed. View with: sudo crontab -l | grep btrfs-snap"
}

# ─── ALERT: Send notification on failure ─────────────────────────────
send_alert() {
    local message="$1"
    local token="${TELEGRAM_BOT_TOKEN:-}"
    local chat_id="${TELEGRAM_CHAT_ID:-}"

    if [[ -n "$token" && -n "$chat_id" ]]; then
        curl -s "https://api.telegram.org/bot${token}/sendMessage" \
            -d "chat_id=${chat_id}" \
            -d "text=🔴 BTRFS Snapshot Alert: ${message}" \
            -d "parse_mode=Markdown" >/dev/null 2>&1 || true
    fi
}

# ─── MAIN ────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
BTRFS Snapshot Manager v${VERSION}

Usage: btrfs-snap.sh <command> [options]

Commands:
  snap <subvol> [--label <name>]           Create a read-only snapshot
  list <subvol>                            List all snapshots
  cleanup <subvol> [--hourly N] ...        Apply retention policy
  rollback <subvol> <snapshot-name>        Rollback to a snapshot
  diff <subvol> <snap1> <snap2>            Show changes between snapshots
  status <subvol>                          Show snapshot disk usage
  send <subvol> <snap> --remote <dest>     Send snapshot to remote
  install-cron <config.yaml>               Install scheduled snapshots

Options:
  --label, -l     Label for the snapshot (e.g., "before-upgrade")
  --hourly N      Keep N hourly snapshots (default: 24)
  --daily N       Keep N daily snapshots (default: 7)
  --weekly N      Keep N weekly snapshots (default: 4)
  --monthly N     Keep N monthly snapshots (default: 6)
  --parent, -p    Parent snapshot for incremental send
  --remote, -r    Remote destination (user@host:/path)

Examples:
  sudo btrfs-snap.sh snap /home --label before-upgrade
  sudo btrfs-snap.sh list /home
  sudo btrfs-snap.sh cleanup /home --hourly 24 --daily 7
  sudo btrfs-snap.sh rollback /home 2026-03-03_23-00-00
  sudo btrfs-snap.sh send /home 2026-03-03_23-00-00 --remote user@backup:/mnt/backups
EOF
}

main() {
    check_btrfs

    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        snap)         cmd_snap "$@" ;;
        list)         cmd_list "$@" ;;
        cleanup)      cmd_cleanup "$@" ;;
        rollback)     cmd_rollback "$@" ;;
        diff)         cmd_diff "$@" ;;
        status)       cmd_status "$@" ;;
        send)         cmd_send "$@" ;;
        install-cron) cmd_install_cron "$@" ;;
        help|--help|-h) usage ;;
        version|--version|-v) echo "btrfs-snap v${VERSION}" ;;
        *)
            err "Unknown command: $cmd"
            usage
            exit 1
            ;;
    esac
}

# Trap errors and send alerts
trap 'send_alert "Command failed: $BASH_COMMAND (exit code: $?)"' ERR

main "$@"
