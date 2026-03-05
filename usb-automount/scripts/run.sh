#!/bin/bash
set -euo pipefail

# USB Auto-Mount CLI — list, mount, unmount, eject, history

CONFIG="/etc/usb-automount/config.yaml"
HANDLER="/usr/local/bin/usb-automount.sh"
HISTORY_LOG="/var/log/usb-automount/history.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

cmd_list() {
    echo -e "${CYAN}USB Devices:${NC}"
    echo ""
    
    local found=0
    while IFS= read -r line; do
        local name size fstype mountpoint label
        name=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        fstype=$(echo "$line" | awk '{print $3}')
        mountpoint=$(echo "$line" | awk '{print $4}')
        label=$(echo "$line" | awk '{print $5}')
        
        # Check if it's a USB device
        if udevadm info --query=property "/dev/$name" 2>/dev/null | grep -q "ID_USB_DRIVER=usb-storage"; then
            found=1
            local status
            if [[ -n "$mountpoint" && "$mountpoint" != "" ]]; then
                status="${GREEN}[mounted]${NC}"
            else
                status="${YELLOW}[not mounted]${NC}"
                mountpoint="—"
            fi
            printf "  /dev/%-6s %-15s %-6s %-6s %-30s %b\n" \
                "$name" "${label:-<no label>}" "${fstype:-?}" "$size" "$mountpoint" "$status"
        fi
    done < <(lsblk -rno NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL 2>/dev/null | grep -v "^$")
    
    if [[ $found -eq 0 ]]; then
        echo "  No USB storage devices found."
    fi
    echo ""
}

cmd_mount() {
    local dev="$1"
    # Strip /dev/ prefix if given
    dev="${dev#/dev/}"
    
    if [[ $EUID -ne 0 ]]; then
        echo "Mount requires root. Trying with sudo..."
        sudo "$HANDLER" mount "$dev"
    else
        "$HANDLER" mount "$dev"
    fi
}

cmd_unmount() {
    local dev="$1"
    dev="${dev#/dev/}"
    
    if [[ $EUID -ne 0 ]]; then
        sudo "$HANDLER" unmount "$dev"
    else
        "$HANDLER" unmount "$dev"
    fi
}

cmd_eject() {
    local dev="$1"
    dev="${dev#/dev/}"
    # Get parent device (e.g., sdb from sdb1)
    local parent
    parent=$(lsblk -rno PKNAME "/dev/$dev" 2>/dev/null | head -1)
    parent="${parent:-$dev}"
    
    # Unmount all partitions
    for part in $(lsblk -rno NAME "/dev/$parent" 2>/dev/null | tail -n +2); do
        if findmnt -rn "/dev/$part" &>/dev/null; then
            echo "Unmounting /dev/$part..."
            cmd_unmount "$part"
        fi
    done
    
    # Power off device
    if command -v udisksctl &>/dev/null; then
        udisksctl power-off -b "/dev/$parent" 2>/dev/null && \
            echo -e "${GREEN}✓${NC} Device /dev/$parent safely ejected" || \
            echo -e "${YELLOW}!${NC} Unmounted but could not power off (safe to remove)"
    else
        echo -e "${GREEN}✓${NC} Unmounted. Safe to remove /dev/$parent"
    fi
}

cmd_history() {
    local lines="${1:-20}"
    if [[ -f "$HISTORY_LOG" ]]; then
        echo -e "${CYAN}Mount History (last $lines events):${NC}"
        echo ""
        tail -n "$lines" "$HISTORY_LOG"
    else
        echo "No history yet. Plug in a USB drive to start logging."
    fi
    echo ""
}

cmd_status() {
    echo -e "${CYAN}USB Auto-Mount Status:${NC}"
    echo ""
    
    # Check udev rule
    if [[ -f "/etc/udev/rules.d/99-usb-automount.rules" ]]; then
        echo -e "  udev rule:     ${GREEN}installed${NC}"
    else
        echo -e "  udev rule:     ${RED}not installed${NC}"
    fi
    
    # Check handler script
    if [[ -x "$HANDLER" ]]; then
        echo -e "  mount handler: ${GREEN}installed${NC}"
    else
        echo -e "  mount handler: ${RED}not installed${NC}"
    fi
    
    # Check systemd service
    if [[ -f "/etc/systemd/system/usb-automount@.service" ]]; then
        echo -e "  systemd unit:  ${GREEN}installed${NC}"
    else
        echo -e "  systemd unit:  ${RED}not installed${NC}"
    fi
    
    # Check config
    if [[ -f "$CONFIG" ]]; then
        echo -e "  config:        ${GREEN}$CONFIG${NC}"
    else
        echo -e "  config:        ${RED}not found${NC}"
    fi
    
    echo ""
}

# Main
case "${1:-help}" in
    list|ls)
        cmd_list
        ;;
    mount)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 mount <device>"; exit 1; }
        cmd_mount "$2"
        ;;
    unmount|umount)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 unmount <device>"; exit 1; }
        cmd_unmount "$2"
        ;;
    eject)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 eject <device>"; exit 1; }
        cmd_eject "$2"
        ;;
    history|log)
        cmd_history "${2:-20}"
        ;;
    status)
        cmd_status
        ;;
    help|--help|-h)
        echo "USB Auto-Mount Manager"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  list              List connected USB devices"
        echo "  mount <device>    Mount a USB device"
        echo "  unmount <device>  Unmount a USB device"
        echo "  eject <device>    Safely eject a USB device"
        echo "  history [N]       Show last N mount events (default: 20)"
        echo "  status            Check installation status"
        echo "  help              Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 list"
        echo "  $0 mount sdb1"
        echo "  $0 eject sdb"
        echo "  $0 history 50"
        ;;
    *)
        echo "Unknown command: $1 (try '$0 help')"
        exit 1
        ;;
esac
