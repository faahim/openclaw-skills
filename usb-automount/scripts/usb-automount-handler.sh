#!/bin/bash
set -euo pipefail

# USB Auto-Mount Handler
# Called by udev/systemd when USB devices are added/removed

CONFIG="/etc/usb-automount/config.yaml"
LOG_TAG="usb-automount"
HISTORY_LOG="/var/log/usb-automount/history.log"

# Simple YAML parser (reads key: value pairs)
yaml_get() {
    local file="$1" key="$2" default="${3:-}"
    local val
    val=$(grep -oP "^\s*${key}:\s*\K.*" "$file" 2>/dev/null | head -1 | sed 's/^["'\'']\|["'\'']\s*$//g' | xargs)
    echo "${val:-$default}"
}

log_msg() {
    logger -t "$LOG_TAG" "$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$HISTORY_LOG" 2>/dev/null || true
}

notify_user() {
    local msg="$1"
    # Try desktop notification
    if command -v notify-send &>/dev/null; then
        sudo -u "#$(yaml_get "$CONFIG" default_owner 1000)" \
            DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(yaml_get "$CONFIG" default_owner 1000)/bus" \
            notify-send "USB Auto-Mount" "$msg" 2>/dev/null || true
    fi
}

get_device_info() {
    local dev="/dev/$1"
    LABEL=$(lsblk -no LABEL "$dev" 2>/dev/null | head -1 | xargs)
    FSTYPE=$(lsblk -no FSTYPE "$dev" 2>/dev/null | head -1 | xargs)
    UUID=$(lsblk -no UUID "$dev" 2>/dev/null | head -1 | xargs)
    SIZE=$(lsblk -no SIZE "$dev" 2>/dev/null | head -1 | xargs)
    MOUNT_NAME="${LABEL:-${UUID:-$1}}"
}

get_mount_options() {
    local fstype="$1"
    local owner
    owner=$(yaml_get "$CONFIG" default_owner 1000)
    local group
    group=$(yaml_get "$CONFIG" default_group 1000)

    # Read fs-specific options from config
    local opts
    opts=$(yaml_get "$CONFIG" "$fstype" "defaults")

    # Replace placeholders
    opts="${opts//\{owner\}/$owner}"
    opts="${opts//\{group\}/$group}"

    echo "$opts"
}

check_ignore() {
    local label="$1" uuid="$2"
    # Check if device is in ignore list
    if grep -q "label:.*${label}" "$CONFIG" 2>/dev/null; then
        return 0
    fi
    if grep -q "uuid:.*${uuid}" "$CONFIG" 2>/dev/null; then
        return 0
    fi
    return 1
}

get_custom_mount() {
    local label="$1"
    # Check for per-device mount path in config
    # Simple grep-based — looks for label match in mounts section
    local custom_path
    custom_path=$(awk "/label:.*\"?${label}\"?/{found=1} found && /path:/{print \$2; exit}" "$CONFIG" 2>/dev/null)
    echo "$custom_path"
}

do_mount() {
    local devname="$1"
    local dev="/dev/$devname"

    # Wait briefly for device to settle
    sleep 1

    # Verify device exists
    [[ ! -b "$dev" ]] && { log_msg "Device $dev not found"; exit 1; }

    # Get device info
    get_device_info "$devname"

    # Check if already mounted
    if findmnt -rn "$dev" &>/dev/null; then
        local existing_mount
        existing_mount=$(findmnt -rno TARGET "$dev")
        log_msg "Already mounted: $dev → $existing_mount"
        exit 0
    fi

    # Check ignore list
    if check_ignore "${LABEL:-}" "${UUID:-}"; then
        log_msg "Ignored: $dev ($LABEL)"
        exit 0
    fi

    # Determine mount point
    local mount_base
    mount_base=$(yaml_get "$CONFIG" mount_base "/media/usb")
    local custom_path
    custom_path=$(get_custom_mount "${LABEL:-}")
    local mount_point="${custom_path:-$mount_base/$MOUNT_NAME}"

    # Create mount point
    mkdir -p "$mount_point"

    # Get mount options
    local opts
    opts=$(get_mount_options "${FSTYPE:-auto}")

    # Mount
    if mount -t "${FSTYPE:-auto}" -o "$opts" "$dev" "$mount_point" 2>/dev/null; then
        # Set ownership for native Linux filesystems
        if [[ "$FSTYPE" == "ext4" || "$FSTYPE" == "btrfs" || "$FSTYPE" == "xfs" ]]; then
            local owner group mode
            owner=$(yaml_get "$CONFIG" default_owner 1000)
            group=$(yaml_get "$CONFIG" default_group 1000)
            mode=$(yaml_get "$CONFIG" default_mode "0755")
            chown "$owner:$group" "$mount_point"
            chmod "$mode" "$mount_point"
        fi

        log_msg "MOUNT   $MOUNT_NAME ($devname, $FSTYPE, $SIZE) → $mount_point"
        notify_user "Mounted: $MOUNT_NAME → $mount_point"

        # Run on_mount hook if configured
        local hook
        hook=$(awk "/label:.*\"?${LABEL}\"?/{found=1} found && /on_mount:/{gsub(/.*on_mount:\s*\"?/,\"\"); gsub(/\"?\s*$/,\"\"); print; exit}" "$CONFIG" 2>/dev/null)
        if [[ -n "$hook" ]]; then
            hook="${hook//\{path\}/$mount_point}"
            hook="${hook//\{label\}/$MOUNT_NAME}"
            hook="${hook//\{device\}/$dev}"
            bash -c "$hook" &
            log_msg "Hook executed: $hook"
        fi
    else
        log_msg "FAILED  Could not mount $dev ($FSTYPE) → $mount_point"
        rmdir "$mount_point" 2>/dev/null || true
        exit 1
    fi
}

do_unmount() {
    local devname="$1"
    local dev="/dev/$devname"

    # Find where it's mounted
    local mount_point
    mount_point=$(findmnt -rno TARGET "$dev" 2>/dev/null || true)

    if [[ -z "$mount_point" ]]; then
        # Device already unmounted or never was
        exit 0
    fi

    get_device_info "$devname" 2>/dev/null || MOUNT_NAME="$devname"

    # Run on_unmount hook if configured
    local hook
    hook=$(awk "/label:.*\"?${LABEL:-}\"?/{found=1} found && /on_unmount:/{gsub(/.*on_unmount:\s*\"?/,\"\"); gsub(/\"?\s*$/,\"\"); print; exit}" "$CONFIG" 2>/dev/null || true)
    if [[ -n "$hook" ]]; then
        hook="${hook//\{path\}/$mount_point}"
        hook="${hook//\{label\}/$MOUNT_NAME}"
        bash -c "$hook" 2>/dev/null || true
    fi

    # Unmount
    umount "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null || true

    # Clean up mount point
    rmdir "$mount_point" 2>/dev/null || true

    log_msg "UNMOUNT $MOUNT_NAME ($devname) from $mount_point"
    notify_user "Unmounted: $MOUNT_NAME"
}

# Main
ACTION="${1:-}"
DEVICE="${2:-}"

case "$ACTION" in
    mount)
        [[ -z "$DEVICE" ]] && { echo "Usage: $0 mount <device>"; exit 1; }
        do_mount "$DEVICE"
        ;;
    unmount|remove)
        [[ -z "$DEVICE" ]] && { echo "Usage: $0 unmount <device>"; exit 1; }
        do_unmount "$DEVICE"
        ;;
    *)
        echo "Usage: $0 {mount|unmount} <device-name>"
        echo "  Example: $0 mount sdb1"
        exit 1
        ;;
esac
