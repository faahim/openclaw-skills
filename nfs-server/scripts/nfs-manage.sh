#!/bin/bash
# NFS Server Manager — Add/Remove/List/Status shares
set -euo pipefail

EXPORTS_FILE="/etc/exports"

# ─── Helpers ────────────────────────────────────────

usage() {
    cat <<EOF
NFS Server Manager

Usage: bash scripts/nfs-manage.sh <command> [options]

Commands:
  add         Add an NFS export
  remove      Remove an NFS export
  list        List all exports
  status      Full status report
  clients     Show connected clients
  stats       Show NFS statistics
  backup      Backup /etc/exports
  restore     Restore /etc/exports from backup
  mount-cmd   Generate mount command for clients
  firewall-check  Verify firewall rules

Options for 'add':
  --path <dir>        Directory to export (created if missing)
  --clients <spec>    Client IP/subnet (e.g., 192.168.1.0/24 or *)
  --options <opts>    Export options (default: rw,sync,no_subtree_check)

Options for 'remove':
  --path <dir>        Directory to unexport
  --clients <spec>    Specific client to remove (optional)
  --all               Remove all rules for path

Options for 'mount-cmd':
  --path <dir>        Exported directory
  --client-ip <ip>    Client IP to generate command for

Options for 'restore':
  --file <path>       Backup file to restore from
EOF
    exit 1
}

reload_exports() {
    sudo exportfs -ra 2>&1
}

get_server_ip() {
    # Get primary IP
    ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}'
}

# ─── Commands ───────────────────────────────────────

cmd_add() {
    local path="" clients="" options="rw,sync,no_subtree_check"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path) path="$2"; shift 2 ;;
            --clients) clients="$2"; shift 2 ;;
            --options) options="$2"; shift 2 ;;
            *) echo "❌ Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$path" || -z "$clients" ]]; then
        echo "❌ --path and --clients are required"
        echo "Example: bash scripts/nfs-manage.sh add --path /srv/shared --clients '192.168.1.0/24'"
        exit 1
    fi

    # Create directory if needed
    if [[ ! -d "$path" ]]; then
        sudo mkdir -p "$path"
        sudo chmod 755 "$path"
        echo "✅ Created directory $path"
    fi

    # Build export line
    local export_line="$path $clients($options)"

    # Check if exact line already exists
    if grep -qF "$export_line" "$EXPORTS_FILE" 2>/dev/null; then
        echo "ℹ️  Export already exists: $export_line"
        return 0
    fi

    # Append to exports
    echo "$export_line" | sudo tee -a "$EXPORTS_FILE" >/dev/null
    echo "✅ Added export: $export_line"

    # Reload
    reload_exports
    echo "✅ Exports reloaded"
}

cmd_remove() {
    local path="" clients="" all=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path) path="$2"; shift 2 ;;
            --clients) clients="$2"; shift 2 ;;
            --all) all=true; shift ;;
            *) echo "❌ Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$path" ]]; then
        echo "❌ --path is required"
        exit 1
    fi

    if $all; then
        # Remove all lines starting with this path
        sudo sed -i "\|^${path} |d" "$EXPORTS_FILE"
        echo "✅ Removed all exports for $path"
    elif [[ -n "$clients" ]]; then
        # Remove specific client rule
        sudo sed -i "\|^${path} ${clients}|d" "$EXPORTS_FILE"
        echo "✅ Removed export: $path → $clients"
    else
        echo "❌ Specify --clients or --all"
        exit 1
    fi

    reload_exports
    echo "✅ Exports reloaded"
}

cmd_list() {
    echo "Active NFS Exports"
    echo "══════════════════"

    if [[ ! -f "$EXPORTS_FILE" ]] || ! grep -v '^#' "$EXPORTS_FILE" | grep -q '[^[:space:]]'; then
        echo "(none configured)"
        return 0
    fi

    local current_path=""
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ || -z "${line// /}" ]] && continue

        local lpath
        lpath=$(echo "$line" | awk '{print $1}')
        local rest
        rest=$(echo "$line" | cut -d' ' -f2-)

        if [[ "$lpath" != "$current_path" ]]; then
            [[ -n "$current_path" ]] && echo ""
            printf "%-20s → %s\n" "$lpath" "$rest"
            current_path="$lpath"
        else
            printf "%-20s   %s\n" "" "$rest"
        fi
    done < "$EXPORTS_FILE"
    echo ""
}

cmd_status() {
    echo "NFS Server Status"
    echo "═════════════════"

    # Service status
    local svc_name="nfs-server"
    if systemctl is-active --quiet "$svc_name" 2>/dev/null; then
        echo "Service: ● active (running)"
    else
        echo "Service: ○ inactive"
    fi

    # Count exports
    local count=0
    if [[ -f "$EXPORTS_FILE" ]]; then
        count=$(grep -cv '^#\|^$' "$EXPORTS_FILE" 2>/dev/null || echo 0)
    fi
    echo "Exports: $count active"
    echo ""

    # Show exports
    cmd_list

    # Connected clients
    echo "Connected Clients"
    echo "─────────────────"
    if command -v showmount &>/dev/null; then
        local clients
        clients=$(showmount -a 2>/dev/null | tail -n +2)
        if [[ -n "$clients" ]]; then
            echo "$clients" | while IFS=: read -r ip mount; do
                printf "  %s → %s (mounted)\n" "$ip" "$mount"
            done
        else
            echo "  (none)"
        fi
    else
        echo "  (showmount not available)"
    fi
    echo ""
}

cmd_clients() {
    echo "Connected NFS Clients"
    echo "═════════════════════"

    if command -v showmount &>/dev/null; then
        local clients
        clients=$(showmount -a 2>/dev/null | tail -n +2)
        if [[ -n "$clients" ]]; then
            echo "$clients" | while IFS=: read -r ip mount; do
                printf "  %s → %s (mounted)\n" "$ip" "$mount"
            done
        else
            echo "  (none connected)"
        fi
    else
        # Fallback: check /proc/fs/nfsd
        if [[ -f /proc/fs/nfsd/clients/*/info ]]; then
            cat /proc/fs/nfsd/clients/*/info 2>/dev/null
        else
            echo "  (unable to determine — showmount not available)"
        fi
    fi
}

cmd_stats() {
    echo "NFS Server Statistics"
    echo "═════════════════════"

    if [[ -f /proc/net/rpc/nfsd ]]; then
        local stats
        stats=$(cat /proc/net/rpc/nfsd)

        # Parse RPC stats
        local rpc_line
        rpc_line=$(echo "$stats" | grep "^rpc ")
        if [[ -n "$rpc_line" ]]; then
            local total
            total=$(echo "$rpc_line" | awk '{print $2}')
            echo "Total RPCs: $total"
        fi

        # Parse IO stats
        local io_line
        io_line=$(echo "$stats" | grep "^io ")
        if [[ -n "$io_line" ]]; then
            local reads writes
            reads=$(echo "$io_line" | awk '{print $2}')
            writes=$(echo "$io_line" | awk '{print $3}')
            echo "  Bytes read:    $reads"
            echo "  Bytes written: $writes"
        fi

        # Thread info
        local th_line
        th_line=$(echo "$stats" | grep "^th ")
        if [[ -n "$th_line" ]]; then
            local threads
            threads=$(echo "$th_line" | awk '{print $2}')
            echo "  NFS threads:   $threads"
        fi
    else
        echo "  NFS stats not available (server may not be running)"
    fi
    echo ""

    # nfsstat if available
    if command -v nfsstat &>/dev/null; then
        echo "Detailed NFS v4 Stats:"
        echo "──────────────────────"
        nfsstat -s -4 2>/dev/null || echo "  (no NFSv4 stats available)"
    fi
}

cmd_backup() {
    local backup="/etc/exports.backup.$(date +%Y-%m-%d-%H%M%S)"
    sudo cp "$EXPORTS_FILE" "$backup"
    echo "✅ Backed up to $backup"
}

cmd_restore() {
    local file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file) file="$2"; shift 2 ;;
            *) echo "❌ Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$file" || ! -f "$file" ]]; then
        echo "❌ --file required and must exist"
        echo "Available backups:"
        ls -1 /etc/exports.backup.* 2>/dev/null || echo "  (none)"
        exit 1
    fi

    sudo cp "$file" "$EXPORTS_FILE"
    reload_exports
    echo "✅ Restored from $file and reloaded"
}

cmd_mount_cmd() {
    local path="" client_ip=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path) path="$2"; shift 2 ;;
            --client-ip) client_ip="$2"; shift 2 ;;
            *) echo "❌ Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "$path" ]]; then
        echo "❌ --path is required"
        exit 1
    fi

    local server_ip
    server_ip=$(get_server_ip)
    local mount_point="/mnt/$(basename "$path")"

    echo "Mount command for client${client_ip:+ $client_ip}:"
    echo ""
    echo "  sudo mkdir -p $mount_point"
    echo "  sudo mount -t nfs ${server_ip}:${path} ${mount_point}"
    echo ""
    echo "To persist across reboots, add to /etc/fstab:"
    echo ""
    echo "  ${server_ip}:${path} ${mount_point} nfs defaults,_netdev 0 0"
}

cmd_firewall_check() {
    echo "Firewall Check"
    echo "══════════════"

    local ok=true

    if command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
        echo "Firewall: UFW (active)"
        if sudo ufw status | grep -q "2049"; then
            echo "  ✅ Port 2049/tcp (NFS) — allowed"
        else
            echo "  ❌ Port 2049/tcp (NFS) — NOT allowed"
            ok=false
        fi
        if sudo ufw status | grep -q "111"; then
            echo "  ✅ Port 111/tcp (portmapper) — allowed"
        else
            echo "  ⚠️  Port 111/tcp (portmapper) — NOT allowed (may be needed for NFSv3)"
        fi
    elif command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
        echo "Firewall: firewalld (active)"
        if sudo firewall-cmd --list-services | grep -q "nfs"; then
            echo "  ✅ NFS service — allowed"
        else
            echo "  ❌ NFS service — NOT allowed"
            ok=false
        fi
    else
        echo "Firewall: none detected (or inactive)"
        echo "  ⚠️  Ensure ports 2049/tcp and 111/tcp are accessible"
    fi

    echo ""
    if $ok; then
        echo "✅ Firewall looks good"
    else
        echo "❌ Fix firewall issues above, then re-run"
    fi
}

# ─── Main ───────────────────────────────────────────

CMD="${1:-}"
shift || true

case "$CMD" in
    add)            cmd_add "$@" ;;
    remove)         cmd_remove "$@" ;;
    list)           cmd_list ;;
    status)         cmd_status ;;
    clients)        cmd_clients ;;
    stats)          cmd_stats ;;
    backup)         cmd_backup ;;
    restore)        cmd_restore "$@" ;;
    mount-cmd)      cmd_mount_cmd "$@" ;;
    firewall-check) cmd_firewall_check ;;
    *)              usage ;;
esac
