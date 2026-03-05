#!/bin/bash
set -euo pipefail

# USB Auto-Mount Installer
# Installs udev rules, mount script, and systemd service

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="/etc/usb-automount"
UDEV_RULE="/etc/udev/rules.d/99-usb-automount.rules"
MOUNT_SCRIPT="/usr/local/bin/usb-automount.sh"
SYSTEMD_DIR="/etc/systemd/system"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Check root
[[ $EUID -ne 0 ]] && error "This script must be run as root (use sudo)"

# Handle uninstall
if [[ "${1:-}" == "--uninstall" ]]; then
    echo "Uninstalling USB Auto-Mount..."
    rm -f "$UDEV_RULE"
    rm -f "$MOUNT_SCRIPT"
    rm -f "$SYSTEMD_DIR/usb-automount@.service"
    systemctl daemon-reload 2>/dev/null || true
    udevadm control --reload-rules 2>/dev/null || true
    echo ""
    read -p "Remove config ($CONFIG_DIR)? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && rm -rf "$CONFIG_DIR" && log "Config removed"
    log "USB Auto-Mount uninstalled"
    exit 0
fi

# Handle reload
if [[ "${1:-}" == "--reload" ]]; then
    udevadm control --reload-rules
    udevadm trigger
    log "Rules reloaded"
    exit 0
fi

echo "Installing USB Auto-Mount..."
echo ""

# 1. Create config directory
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/config.yaml" ]]; then
    cat > "$CONFIG_DIR/config.yaml" << 'CFGEOF'
# USB Auto-Mount Configuration
general:
  mount_base: /media/usb
  default_owner: 1000
  default_group: 1000
  default_mode: "0755"
  auto_unmount_on_remove: true
  log_to_journal: true
  notify: false

fs_options:
  vfat: "uid={owner},gid={group},umask=022,iocharset=utf8"
  ntfs: "uid={owner},gid={group},umask=022"
  ext4: "defaults"
  exfat: "uid={owner},gid={group},umask=022"
  btrfs: "defaults,compress=zstd"

mounts: []

ignore: []
CFGEOF
    log "Config created: $CONFIG_DIR/config.yaml"
else
    warn "Config already exists, skipping"
fi

# 2. Install mount script
cp "$SCRIPT_DIR/usb-automount-handler.sh" "$MOUNT_SCRIPT"
chmod +x "$MOUNT_SCRIPT"
log "Mount script installed: $MOUNT_SCRIPT"

# 3. Install udev rule
cat > "$UDEV_RULE" << 'UDEVEOF'
# USB Auto-Mount Rules
# Trigger on USB block device add/remove

# On USB storage device add
ACTION=="add", SUBSYSTEM=="block", ENV{ID_USB_DRIVER}=="usb-storage", ENV{ID_FS_USAGE}=="filesystem", TAG+="systemd", ENV{SYSTEMD_WANTS}+="usb-automount@%k.service"

# On USB storage device remove
ACTION=="remove", SUBSYSTEM=="block", ENV{ID_USB_DRIVER}=="usb-storage", RUN+="/usr/local/bin/usb-automount.sh unmount %k"
UDEVEOF
log "udev rule installed: $UDEV_RULE"

# 4. Install systemd service template
cat > "$SYSTEMD_DIR/usb-automount@.service" << 'SVCEOF'
[Unit]
Description=USB Auto-Mount for %i
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/usr/local/bin/usb-automount.sh mount %i
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
SVCEOF
log "systemd service installed: usb-automount@.service"

# 5. Create mount base directory
MOUNT_BASE=$(grep -oP 'mount_base:\s*\K\S+' "$CONFIG_DIR/config.yaml" 2>/dev/null || echo "/media/usb")
mkdir -p "$MOUNT_BASE"
log "Mount base created: $MOUNT_BASE"

# 6. Create log directory
mkdir -p /var/log/usb-automount
log "Log directory created"

# 7. Reload
systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger
log "Rules reloaded"

echo ""
log "USB Auto-Mount installed successfully!"
echo ""
echo "  Config: $CONFIG_DIR/config.yaml"
echo "  Logs:   journalctl -t usb-automount"
echo ""
echo "  Plug in a USB drive to test."
