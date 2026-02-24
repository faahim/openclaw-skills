#!/bin/bash
# Samba File Share Manager
# Install, configure, and manage SMB/CIFS shares on Linux

set -euo pipefail

SAMBA_CONF="/etc/samba/smb.conf"
SCRIPT_NAME="$(basename "$0")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This command requires root privileges. Run with sudo."
        exit 1
    fi
}

backup_config() {
    if [[ -f "$SAMBA_CONF" ]]; then
        local backup="${SAMBA_CONF}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$SAMBA_CONF" "$backup"
        log_info "Config backed up to $backup"
    fi
}

cmd_install() {
    check_root
    log_info "Installing Samba..."

    if command -v apt-get &>/dev/null; then
        apt-get update -qq
        apt-get install -y -qq samba samba-common-bin
    elif command -v dnf &>/dev/null; then
        dnf install -y -q samba samba-common
    elif command -v yum &>/dev/null; then
        yum install -y -q samba samba-common
    elif command -v pacman &>/dev/null; then
        pacman -Sy --noconfirm samba
    elif command -v apk &>/dev/null; then
        apk add samba
    else
        log_error "Unsupported package manager. Install samba manually."
        exit 1
    fi

    # Backup original config
    backup_config

    # Enable and start services
    systemctl enable smbd nmbd 2>/dev/null || true
    systemctl start smbd nmbd 2>/dev/null || true

    # Open firewall ports if ufw is available
    if command -v ufw &>/dev/null; then
        ufw allow 139/tcp >/dev/null 2>&1 || true
        ufw allow 445/tcp >/dev/null 2>&1 || true
        ufw allow 137/udp >/dev/null 2>&1 || true
        ufw allow 138/udp >/dev/null 2>&1 || true
        log_info "Firewall ports opened (139, 445, 137, 138)"
    fi

    log_info "Samba installed and running."
    smbd --version 2>/dev/null || true
}

cmd_create_share() {
    check_root
    local name="" path="" public="no" writable="yes" valid_users="" browseable="yes"
    local read_only="no" create_mask="0664" directory_mask="0775"
    local vfs_objects="" fruit_time_machine="no"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift 2 ;;
            --path) path="$2"; shift 2 ;;
            --public) public="$2"; shift 2 ;;
            --writable) writable="$2"; shift 2 ;;
            --valid-users) valid_users="$2"; shift 2 ;;
            --browseable) browseable="$2"; shift 2 ;;
            --read-only) read_only="$2"; shift 2 ;;
            --create-mask) create_mask="$2"; shift 2 ;;
            --directory-mask) directory_mask="$2"; shift 2 ;;
            --vfs-objects) vfs_objects="$2"; shift 2 ;;
            --fruit-time-machine) fruit_time_machine="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$name" || -z "$path" ]]; then
        log_error "Usage: $SCRIPT_NAME create-share --name <name> --path <path> [options]"
        exit 1
    fi

    # Create directory if it doesn't exist
    mkdir -p "$path"
    if [[ "$public" == "yes" ]]; then
        chmod 777 "$path"
    else
        chmod 775 "$path"
    fi

    backup_config

    # Check if share already exists
    if grep -q "^\[$name\]" "$SAMBA_CONF" 2>/dev/null; then
        log_warn "Share [$name] already exists. Removing old definition..."
        # Remove existing share block
        sed -i "/^\[$name\]/,/^\[/{ /^\[${name}\]/d; /^\[/!d; }" "$SAMBA_CONF"
    fi

    # Append share definition
    {
        echo ""
        echo "[$name]"
        echo "   path = $path"
        echo "   browseable = $browseable"
        echo "   public = $public"
        if [[ "$read_only" == "yes" ]]; then
            echo "   read only = yes"
        else
            echo "   writable = $writable"
        fi
        if [[ -n "$valid_users" ]]; then
            echo "   valid users = $valid_users"
        fi
        echo "   create mask = $create_mask"
        echo "   directory mask = $directory_mask"
        if [[ -n "$vfs_objects" ]]; then
            echo "   vfs objects = $vfs_objects"
        fi
        if [[ "$fruit_time_machine" == "yes" ]]; then
            echo "   fruit:time machine = yes"
            echo "   fruit:time machine max size = 1T"
        fi
    } >> "$SAMBA_CONF"

    # Reload samba
    systemctl reload smbd 2>/dev/null || systemctl restart smbd 2>/dev/null || true

    log_info "Share [$name] created at $path"
    log_info "Access: \\\\$(hostname -I | awk '{print $1}')\\$name"
}

cmd_remove_share() {
    check_root
    local name=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$name" ]]; then
        log_error "Usage: $SCRIPT_NAME remove-share --name <name>"
        exit 1
    fi

    if ! grep -q "^\[$name\]" "$SAMBA_CONF" 2>/dev/null; then
        log_error "Share [$name] not found in config."
        exit 1
    fi

    backup_config

    # Remove share block (from [name] to next [section] or EOF)
    python3 -c "
import re, sys
with open('$SAMBA_CONF', 'r') as f:
    content = f.read()
pattern = r'\n?\[$name\][^\[]*'
content = re.sub(pattern, '', content)
with open('$SAMBA_CONF', 'w') as f:
    f.write(content)
" 2>/dev/null || {
    # Fallback: use awk
    awk -v name="[$name]" '
        $0 == name { skip=1; next }
        /^\[/ { skip=0 }
        !skip { print }
    ' "$SAMBA_CONF" > "${SAMBA_CONF}.tmp" && mv "${SAMBA_CONF}.tmp" "$SAMBA_CONF"
}

    systemctl reload smbd 2>/dev/null || true
    log_info "Share [$name] removed."
}

cmd_list_shares() {
    echo "Active Samba Shares:"
    if [[ -f "$SAMBA_CONF" ]]; then
        awk '/^\[/{section=$0} /^\[/{if(section!="[global]") print ""; if(section!="[global]") print "  " section} !/^\[/{if(section!="[global]" && section!="") print "    " $0}' "$SAMBA_CONF" | grep -v "^$" | head -100
    else
        echo "  No Samba config found at $SAMBA_CONF"
    fi
}

cmd_add_user() {
    check_root
    local username=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --username) username="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$username" ]]; then
        log_error "Usage: $SCRIPT_NAME add-user --username <user>"
        exit 1
    fi

    # Check if Linux user exists
    if ! id "$username" &>/dev/null; then
        log_info "Creating Linux user $username..."
        useradd -M -s /usr/sbin/nologin "$username" 2>/dev/null || true
    fi

    log_info "Set Samba password for $username:"
    smbpasswd -a "$username"
    smbpasswd -e "$username"
    log_info "Samba user $username added and enabled."
}

cmd_remove_user() {
    check_root
    local username=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --username) username="$2"; shift 2 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$username" ]]; then
        log_error "Usage: $SCRIPT_NAME remove-user --username <user>"
        exit 1
    fi

    smbpasswd -x "$username" 2>/dev/null || true
    log_info "Samba user $username removed."
}

cmd_list_users() {
    echo "Samba Users:"
    pdbedit -L 2>/dev/null || {
        log_warn "pdbedit not available. Trying alternative..."
        cat /etc/samba/smbpasswd 2>/dev/null || echo "  No users found"
    }
}

cmd_status() {
    echo "=== Samba Status ==="

    # Service status
    if systemctl is-active smbd &>/dev/null; then
        echo -e "Samba Service: ${GREEN}active (running)${NC}"
    else
        echo -e "Samba Service: ${RED}inactive${NC}"
    fi

    # Active connections
    local connections
    connections=$(smbstatus -b 2>/dev/null | grep -c "^[0-9]" || echo "0")
    echo "Active connections: $connections"

    # Share count
    local shares
    shares=$(grep -c "^\[" "$SAMBA_CONF" 2>/dev/null || echo "0")
    shares=$((shares - 1))  # Subtract [global]
    [[ $shares -lt 0 ]] && shares=0
    echo "Shares configured: $shares"

    # Firewall
    if command -v ufw &>/dev/null; then
        if ufw status 2>/dev/null | grep -q "445.*ALLOW"; then
            echo -e "Firewall: ${GREEN}ports 139,445 open${NC}"
        else
            echo -e "Firewall: ${YELLOW}ports may be blocked${NC}"
        fi
    else
        echo "Firewall: ufw not installed (check manually)"
    fi

    # Version
    echo ""
    smbd --version 2>/dev/null || true
}

cmd_test_config() {
    log_info "Testing Samba configuration..."
    testparm -s 2>&1
}

cmd_restart() {
    check_root
    systemctl restart smbd nmbd 2>/dev/null || {
        service smbd restart 2>/dev/null
        service nmbd restart 2>/dev/null
    }
    log_info "Samba services restarted."
}

usage() {
    cat <<EOF
Samba File Share Manager

Usage: $SCRIPT_NAME <command> [options]

Commands:
  install                  Install Samba and enable services
  create-share [opts]      Create a new file share
  remove-share --name X    Remove a share
  list-shares              List all configured shares
  add-user --username X    Add a Samba user
  remove-user --username X Remove a Samba user
  list-users               List Samba users
  status                   Show Samba service status
  test-config              Validate smb.conf syntax
  restart                  Restart Samba services

Create-share options:
  --name <name>            Share name (required)
  --path <path>            Directory path (required)
  --public yes|no          Allow anonymous access (default: no)
  --writable yes|no        Allow writes (default: yes)
  --valid-users "u1 u2"    Restrict to specific users
  --browseable yes|no      Show in network browse (default: yes)
  --create-mask 0664       File permission mask
  --directory-mask 0775    Directory permission mask
  --vfs-objects "..."      VFS objects (for Time Machine, etc.)
  --fruit-time-machine yes Enable macOS Time Machine support

Examples:
  $SCRIPT_NAME install
  $SCRIPT_NAME create-share --name media --path /srv/media --public yes --writable no
  $SCRIPT_NAME create-share --name docs --path /srv/docs --valid-users "alice bob"
  $SCRIPT_NAME add-user --username alice
  $SCRIPT_NAME status
EOF
}

# Main dispatcher
case "${1:-}" in
    install)        shift; cmd_install "$@" ;;
    create-share)   shift; cmd_create_share "$@" ;;
    remove-share)   shift; cmd_remove_share "$@" ;;
    list-shares)    shift; cmd_list_shares "$@" ;;
    add-user)       shift; cmd_add_user "$@" ;;
    remove-user)    shift; cmd_remove_user "$@" ;;
    list-users)     shift; cmd_list_users "$@" ;;
    status)         shift; cmd_status "$@" ;;
    test-config)    shift; cmd_test_config "$@" ;;
    restart)        shift; cmd_restart "$@" ;;
    -h|--help|help) usage ;;
    *)              usage; exit 1 ;;
esac
