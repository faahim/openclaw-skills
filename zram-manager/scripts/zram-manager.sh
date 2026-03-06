#!/bin/bash
# ZRAM Manager — Configure and manage compressed swap in RAM
# Requires: bash 4+, zramctl, modprobe, root/sudo for write operations

set -euo pipefail

VERSION="1.0.0"
ZRAM_CONF="/etc/systemd/zram-generator.conf"
ZRAM_SERVICE="/etc/systemd/system/zram-swap.service"
ZRAM_UDEV="/etc/udev/rules.d/99-zram.rules"

# Defaults
DEFAULT_ALGO="zstd"
DEFAULT_SIZE_PERCENT=50
DEFAULT_PRIORITY=100
DEFAULT_STREAMS=$(nproc 2>/dev/null || echo 2)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
error() { echo -e "${RED}❌${NC} $*" >&2; }

get_total_ram_mb() {
    awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo
}

get_used_ram_mb() {
    awk '/MemAvailable/ {avail=$2} /MemTotal/ {total=$2} END {printf "%d", (total-avail)/1024}' /proc/meminfo
}

get_swap_total_mb() {
    awk '/SwapTotal/ {printf "%d", $2/1024}' /proc/meminfo
}

get_swap_used_mb() {
    awk '/SwapFree/ {free=$2} /SwapTotal/ {total=$2} END {printf "%d", (total-free)/1024}' /proc/meminfo
}

parse_size() {
    local size_str="$1"
    local total_ram_mb
    total_ram_mb=$(get_total_ram_mb)

    if [[ "$size_str" == *"%" ]]; then
        local pct="${size_str%\%}"
        echo $(( total_ram_mb * pct / 100 ))
    elif [[ "$size_str" == *"G" || "$size_str" == *"g" ]]; then
        local num="${size_str%[Gg]}"
        echo $(( num * 1024 ))
    elif [[ "$size_str" == *"M" || "$size_str" == *"m" ]]; then
        echo "${size_str%[Mm]}"
    else
        echo "$size_str"
    fi
}

cmd_status() {
    local total_ram used_ram swap_total swap_used
    total_ram=$(get_total_ram_mb)
    used_ram=$(get_used_ram_mb)
    swap_total=$(get_swap_total_mb)
    swap_used=$(get_swap_used_mb)

    echo -e "${BLUE}=== Memory Status ===${NC}"
    echo "Total RAM:  ${total_ram} MB"
    echo "Used RAM:   ${used_ram} MB ($((used_ram * 100 / total_ram))%)"
    echo "Swap Total: ${swap_total} MB"
    echo "Swap Used:  ${swap_used} MB"
    echo ""

    # Check ZRAM
    if lsmod 2>/dev/null | grep -q zram; then
        echo -e "${BLUE}=== ZRAM Devices ===${NC}"
        if command -v zramctl &>/dev/null; then
            zramctl 2>/dev/null || echo "No ZRAM devices configured"
        else
            echo "zramctl not found — install util-linux"
        fi
    else
        echo "ZRAM: Not loaded (kernel module not active)"
        echo ""
        echo "Recommendation: Enable ZRAM with $((total_ram / 2)) MB (50% of RAM)"
    fi

    # Check persistence
    echo ""
    if [ -f "$ZRAM_SERVICE" ] || [ -f "$ZRAM_CONF" ]; then
        echo "Persistence: ✅ Configured (survives reboot)"
    else
        echo "Persistence: ❌ Not configured (lost on reboot)"
    fi
}

cmd_enable() {
    local size_mb algo streams priority num_devices
    algo="${ZRAM_ALGO:-$DEFAULT_ALGO}"
    streams="${ZRAM_STREAMS:-$DEFAULT_STREAMS}"
    priority="${ZRAM_PRIORITY:-$DEFAULT_PRIORITY}"
    num_devices=1

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --size)    size_mb=$(parse_size "$2"); shift 2 ;;
            --algo)    algo="$2"; shift 2 ;;
            --streams) streams="$2"; shift 2 ;;
            --priority) priority="$2"; shift 2 ;;
            --devices) num_devices="$2"; shift 2 ;;
            *) error "Unknown option: $1"; exit 1 ;;
        esac
    done

    # Default size: 50% of RAM
    if [ -z "${size_mb:-}" ]; then
        local total_ram
        total_ram=$(get_total_ram_mb)
        size_mb=$(( total_ram * DEFAULT_SIZE_PERCENT / 100 ))
    fi

    # Validate algorithm
    local valid_algos
    valid_algos=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null || echo "lzo lz4 zstd lzo-rle")
    # Load module if not loaded
    if ! lsmod | grep -q zram; then
        modprobe zram num_devices="$num_devices" 2>/dev/null || {
            error "Failed to load zram module. Install: sudo apt install linux-modules-extra-\$(uname -r)"
            exit 1
        }
        info "ZRAM kernel module loaded"
    fi

    local per_device_mb=$(( size_mb / num_devices ))

    for i in $(seq 0 $((num_devices - 1))); do
        local dev="/dev/zram${i}"

        # Reset if exists
        if [ -e "$dev" ]; then
            swapoff "$dev" 2>/dev/null || true
            echo 1 > "/sys/block/zram${i}/reset" 2>/dev/null || true
        fi

        # If device doesn't exist, create via hot_add
        if [ ! -e "$dev" ] && [ "$i" -gt 0 ]; then
            cat /sys/class/zram-control/hot_add >/dev/null 2>&1 || true
        fi

        # Configure
        echo "$algo" > "/sys/block/zram${i}/comp_algorithm" 2>/dev/null || {
            warn "Algorithm '$algo' not available, falling back to lzo-rle"
            algo="lzo-rle"
            echo "$algo" > "/sys/block/zram${i}/comp_algorithm"
        }
        echo "$streams" > "/sys/block/zram${i}/max_comp_streams" 2>/dev/null || true
        echo "${per_device_mb}M" > "/sys/block/zram${i}/disksize" 2>/dev/null || \
            echo $((per_device_mb * 1024 * 1024)) > "/sys/block/zram${i}/disksize"

        # Setup swap
        mkswap "$dev" >/dev/null 2>&1
        swapon -p "$priority" "$dev"

        info "ZRAM device created: $dev"
        echo "   Size: ${per_device_mb} MB"
        echo "   Algorithm: ${algo}"
        echo "   Streams: ${streams}"
        echo "   Priority: ${priority}"
    done

    info "ZRAM swap active. Run 'zramctl' to verify."
}

cmd_disable() {
    local purge=false
    [[ "${1:-}" == "--purge" ]] && purge=true

    # Disable all ZRAM swap devices
    for dev in /dev/zram*; do
        [ -b "$dev" ] || continue
        if swapon --show=NAME --noheadings | grep -q "$(basename "$dev")"; then
            swapoff "$dev" 2>/dev/null && info "Disabled swap on $dev" || warn "Could not swapoff $dev"
        fi
    done

    # Reset devices
    for zram_dir in /sys/block/zram*; do
        [ -d "$zram_dir" ] || continue
        echo 1 > "$zram_dir/reset" 2>/dev/null || true
    done

    # Remove module
    rmmod zram 2>/dev/null && info "ZRAM module unloaded" || warn "Could not unload zram module (may be in use)"

    if $purge; then
        rm -f "$ZRAM_SERVICE" "$ZRAM_CONF" "$ZRAM_UDEV"
        systemctl daemon-reload 2>/dev/null || true
        info "Persistence files removed"
    fi
}

cmd_persist() {
    # Create systemd service for persistence
    cat > "$ZRAM_SERVICE" << 'UNIT'
[Unit]
Description=ZRAM Compressed Swap
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '\
    modprobe zram; \
    ALGO="${ZRAM_ALGO:-zstd}"; \
    SIZE_PCT="${ZRAM_SIZE_PERCENT:-50}"; \
    TOTAL_KB=$(awk "/MemTotal/ {print \\$2}" /proc/meminfo); \
    SIZE_BYTES=$((TOTAL_KB * 1024 * SIZE_PCT / 100)); \
    echo "$ALGO" > /sys/block/zram0/comp_algorithm 2>/dev/null || true; \
    echo $SIZE_BYTES > /sys/block/zram0/disksize; \
    mkswap /dev/zram0; \
    swapon -p 100 /dev/zram0'
ExecStop=/bin/bash -c 'swapoff /dev/zram0 2>/dev/null; echo 1 > /sys/block/zram0/reset 2>/dev/null; rmmod zram 2>/dev/null'

[Install]
WantedBy=multi-user.target
UNIT

    systemctl daemon-reload
    systemctl enable zram-swap.service
    info "ZRAM persistence configured (systemd service)"
    echo "   Service: zram-swap.service"
    echo "   Will activate on boot automatically"
}

cmd_stats() {
    if ! lsmod | grep -q zram; then
        error "ZRAM is not loaded"
        exit 1
    fi

    echo -e "${BLUE}=== ZRAM Statistics ===${NC}"

    for zram_dir in /sys/block/zram*; do
        [ -d "$zram_dir" ] || continue
        local dev=$(basename "$zram_dir")
        local disksize algo

        disksize=$(cat "$zram_dir/disksize" 2>/dev/null || echo 0)
        [ "$disksize" -eq 0 ] && continue

        algo=$(cat "$zram_dir/comp_algorithm" 2>/dev/null | sed 's/.*\[\(.*\)\].*/\1/' || echo "unknown")

        echo ""
        echo "Device: /dev/$dev"
        echo "Algorithm: $algo"
        echo "Disk Size: $((disksize / 1024 / 1024)) MB"

        # Parse mm_stat if available
        if [ -f "$zram_dir/mm_stat" ]; then
            read -r orig_size compr_size mem_used limit max_used same_pages pages_compacted huge_pages < "$zram_dir/mm_stat"
            local orig_mb=$((orig_size / 1024 / 1024))
            local compr_mb=$((compr_size / 1024 / 1024))
            local mem_mb=$((mem_used / 1024 / 1024))

            if [ "$compr_size" -gt 0 ]; then
                # Calculate ratio (avoid floating point)
                local ratio_x100=$((orig_size * 100 / compr_size))
                local ratio_int=$((ratio_x100 / 100))
                local ratio_frac=$((ratio_x100 % 100))
                echo "Compressed: ${orig_mb} MB → ${compr_mb} MB (${ratio_int}.${ratio_frac}:1 ratio)"
            else
                echo "Compressed: ${orig_mb} MB → ${compr_mb} MB (no data yet)"
            fi
            echo "Memory Used: ${mem_mb} MB"
            echo "Same/Zero Pages: ${same_pages}"
        fi

        # IO stats
        if [ -f "$zram_dir/stat" ]; then
            read -r reads _ _ _ writes _ _ _ _ _ _ < "$zram_dir/stat" 2>/dev/null || true
            echo "Read ops: ${reads:-0}"
            echo "Write ops: ${writes:-0}"
        fi
    done
}

cmd_replace_swap() {
    echo -e "${BLUE}=== Replacing Disk Swap with ZRAM ===${NC}"

    # Find and disable disk swap
    local disk_swaps
    disk_swaps=$(swapon --show=NAME,TYPE --noheadings 2>/dev/null | grep -v zram | awk '{print $1}')

    if [ -n "$disk_swaps" ]; then
        for swap in $disk_swaps; do
            swapoff "$swap" 2>/dev/null && info "Disabled disk swap: $swap" || warn "Could not disable: $swap"
        done
    else
        info "No disk swap found"
    fi

    # Enable ZRAM
    cmd_enable "$@"

    info "Disk swap replaced with ZRAM"
    echo "   Note: Disk swap entries in /etc/fstab are NOT removed"
    echo "   To permanently remove, comment them out in /etc/fstab"
}

cmd_tune() {
    echo -e "${BLUE}=== Applying ZRAM-Optimized Kernel Parameters ===${NC}"

    # swappiness: 180 is fine for ZRAM since it's in RAM (not disk)
    sysctl -w vm.swappiness=180 2>/dev/null && info "vm.swappiness = 180" || warn "Could not set swappiness"

    # Disable watermark boosting (not needed with ZRAM)
    sysctl -w vm.watermark_boost_factor=0 2>/dev/null && info "vm.watermark_boost_factor = 0" || true

    # Increase watermark scale factor
    sysctl -w vm.watermark_scale_factor=125 2>/dev/null && info "vm.watermark_scale_factor = 125" || true

    # Disable swap readahead (not useful for ZRAM)
    sysctl -w vm.page-cluster=0 2>/dev/null && info "vm.page-cluster = 0" || true

    echo ""
    echo "To make persistent, add to /etc/sysctl.d/99-zram.conf:"
    echo "  vm.swappiness=180"
    echo "  vm.watermark_boost_factor=0"
    echo "  vm.watermark_scale_factor=125"
    echo "  vm.page-cluster=0"
}

cmd_check() {
    local min_ratio=0
    local alert=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --min-ratio) min_ratio="$2"; shift 2 ;;
            --alert) alert=true; shift ;;
            *) shift ;;
        esac
    done

    if ! lsmod | grep -q zram; then
        if $alert; then
            echo "ALERT: ZRAM is not loaded!"
        fi
        exit 1
    fi

    # Check compression ratio
    for zram_dir in /sys/block/zram*; do
        [ -f "$zram_dir/mm_stat" ] || continue
        read -r orig_size compr_size _ < "$zram_dir/mm_stat"
        [ "$compr_size" -eq 0 ] && continue

        local ratio_x100=$((orig_size * 100 / compr_size))
        local min_x100=$((${min_ratio%.*} * 100))

        if [ "$ratio_x100" -lt "$min_x100" ] && $alert; then
            echo "ALERT: ZRAM compression ratio ($((ratio_x100/100)).$((ratio_x100%100)):1) below minimum (${min_ratio}:1)"
            exit 2
        fi
    done

    echo "OK"
}

cmd_help() {
    cat << EOF
ZRAM Manager v${VERSION} — Compressed swap in RAM

Usage: $(basename "$0") <command> [options]

Commands:
  status          Show memory and ZRAM status
  enable          Create and activate ZRAM swap
  disable         Deactivate ZRAM swap (--purge to remove persistence)
  persist         Make ZRAM survive reboots (systemd service)
  stats           Show ZRAM compression statistics
  replace-swap    Replace disk swap with ZRAM
  tune            Apply ZRAM-optimized kernel parameters
  check           Health check (for cron monitoring)
  help            Show this help

Enable Options:
  --size <SIZE>     Size (e.g., 1G, 512M, 50%)  [default: 50% of RAM]
  --algo <ALGO>     Compression: zstd|lz4|lzo|lzo-rle|zlib  [default: zstd]
  --streams <N>     Compression streams  [default: nproc]
  --priority <N>    Swap priority  [default: 100]
  --devices <N>     Number of ZRAM devices  [default: 1]

Check Options:
  --min-ratio <N>   Minimum acceptable compression ratio
  --alert           Print alert message if check fails

Environment:
  ZRAM_SIZE_PERCENT   Default size as % of RAM (default: 50)
  ZRAM_ALGO           Default compression algorithm (default: zstd)
  ZRAM_STREAMS        Default compression streams
  ZRAM_PRIORITY       Default swap priority (default: 100)

Examples:
  $(basename "$0") enable --size 1G --algo zstd
  $(basename "$0") enable --size 75% --algo lz4    # For Raspberry Pi
  $(basename "$0") replace-swap
  $(basename "$0") persist
  $(basename "$0") stats
EOF
}

# Main dispatch
case "${1:-help}" in
    status)       cmd_status ;;
    enable)       shift; cmd_enable "$@" ;;
    disable)      shift; cmd_disable "$@" ;;
    persist)      cmd_persist ;;
    stats)        cmd_stats ;;
    replace-swap) shift; cmd_replace_swap "$@" ;;
    tune)         cmd_tune ;;
    check)        shift; cmd_check "$@" ;;
    help|--help|-h) cmd_help ;;
    *)            error "Unknown command: $1"; cmd_help; exit 1 ;;
esac
