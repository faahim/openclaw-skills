#!/bin/bash
# NFS Manager — Setup, manage, and monitor NFS shares
# Usage: bash nfs-manager.sh <command> [args...]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
err()  { echo -e "${RED}❌ $*${NC}" >&2; }

need_root() {
  if [[ $EUID -ne 0 ]]; then
    err "This command requires root. Run with sudo."
    exit 1
  fi
}

# ─── INSTALL ───────────────────────────────────────────────

cmd_install_server() {
  need_root
  echo "Installing NFS server..."
  
  if command -v apt-get &>/dev/null; then
    apt-get update -qq
    apt-get install -y -qq nfs-kernel-server nfs-common rpcbind
  elif command -v dnf &>/dev/null; then
    dnf install -y -q nfs-utils rpcbind
  elif command -v yum &>/dev/null; then
    yum install -y -q nfs-utils rpcbind
  elif command -v pacman &>/dev/null; then
    pacman -S --noconfirm nfs-utils rpcbind
  else
    err "Unsupported package manager. Install nfs-kernel-server manually."
    exit 1
  fi

  systemctl enable --now nfs-server rpcbind 2>/dev/null || \
  systemctl enable --now nfs-kernel-server rpcbind 2>/dev/null || true
  
  ok "NFS server installed and running"
}

cmd_install_client() {
  need_root
  echo "Installing NFS client..."
  
  if command -v apt-get &>/dev/null; then
    apt-get update -qq
    apt-get install -y -qq nfs-common rpcbind
  elif command -v dnf &>/dev/null; then
    dnf install -y -q nfs-utils rpcbind
  elif command -v yum &>/dev/null; then
    yum install -y -q nfs-utils rpcbind
  elif command -v pacman &>/dev/null; then
    pacman -S --noconfirm nfs-utils rpcbind
  else
    err "Unsupported package manager. Install nfs-common manually."
    exit 1
  fi

  systemctl enable --now rpcbind 2>/dev/null || true
  ok "NFS client installed and ready"
}

# ─── EXPORTS ───────────────────────────────────────────────

cmd_export() {
  need_root
  local path="${1:?Usage: nfs-manager.sh export <path> <network> [options]}"
  local network="${2:?Specify network, e.g. 192.168.1.0/24}"
  local opts="${3:-rw,sync,no_subtree_check}"

  # Create directory if it doesn't exist
  if [[ ! -d "$path" ]]; then
    mkdir -p "$path"
    ok "Created directory: $path"
  fi

  # Check if export already exists
  if grep -q "^${path}[[:space:]]" /etc/exports 2>/dev/null; then
    warn "Export for $path already exists. Updating..."
    sed -i "\|^${path}[[:space:]]|d" /etc/exports
  fi

  # Add export
  echo "${path} ${network}(${opts})" >> /etc/exports
  
  # Reload exports
  exportfs -ra
  
  ok "Created export: ${path} → ${network} (${opts})"
  ok "NFS exports reloaded"
}

cmd_unexport() {
  need_root
  local path="${1:?Usage: nfs-manager.sh unexport <path>}"

  if ! grep -q "^${path}[[:space:]]" /etc/exports 2>/dev/null; then
    err "No export found for $path"
    exit 1
  fi

  sed -i "\|^${path}[[:space:]]|d" /etc/exports
  exportfs -ra
  
  ok "Removed export: $path"
  ok "NFS exports reloaded"
}

cmd_list_exports() {
  echo "NFS Exports:"
  echo "────────────"
  
  if [[ ! -f /etc/exports ]] || [[ ! -s /etc/exports ]]; then
    echo "  (none configured)"
    return
  fi

  grep -v '^#' /etc/exports | grep -v '^$' | while IFS= read -r line; do
    local path=$(echo "$line" | awk '{print $1}')
    local rest=$(echo "$line" | cut -d' ' -f2-)
    printf "  %-20s → %s\n" "$path" "$rest"
  done
  
  echo ""
  
  # Show active exports from exportfs
  if command -v exportfs &>/dev/null; then
    echo "Active exports (exportfs):"
    exportfs -v 2>/dev/null | sed 's/^/  /' || echo "  (unable to query)"
  fi
}

# ─── MOUNTS ────────────────────────────────────────────────

cmd_mount() {
  need_root
  local remote="${1:?Usage: nfs-manager.sh mount <server:/path> <mountpoint> [options]}"
  local mountpoint="${2:?Specify local mount point}"
  local opts="${3:-rw,hard,timeo=600,retrans=2}"
  local persist=true

  # Check for --no-persist flag
  for arg in "$@"; do
    [[ "$arg" == "--no-persist" ]] && persist=false
  done

  # Create mount point
  mkdir -p "$mountpoint"

  # Mount
  mount -t nfs -o "$opts" "$remote" "$mountpoint"
  ok "Mounted $remote → $mountpoint"

  # Add to fstab for persistence
  if $persist; then
    if ! grep -q "$remote" /etc/fstab 2>/dev/null; then
      echo "${remote} ${mountpoint} nfs ${opts} 0 0" >> /etc/fstab
      ok "Added to /etc/fstab for persistence"
    else
      warn "Already in /etc/fstab"
    fi
  fi
}

cmd_unmount() {
  need_root
  local mountpoint="${1:?Usage: nfs-manager.sh unmount <mountpoint> [--permanent]}"
  local permanent=false

  [[ "${2:-}" == "--permanent" ]] && permanent=true

  if mountpoint -q "$mountpoint" 2>/dev/null; then
    umount "$mountpoint"
    ok "Unmounted $mountpoint"
  else
    warn "$mountpoint is not currently mounted"
  fi

  if $permanent; then
    if grep -q "$mountpoint" /etc/fstab 2>/dev/null; then
      sed -i "\|${mountpoint}|d" /etc/fstab
      ok "Removed from /etc/fstab"
    fi
  fi
}

cmd_list_mounts() {
  echo "NFS Mounts:"
  echo "───────────"
  
  local found=false
  mount -t nfs,nfs4 2>/dev/null | while IFS= read -r line; do
    found=true
    local remote=$(echo "$line" | awk '{print $1}')
    local local_path=$(echo "$line" | awk '{print $3}')
    local type=$(echo "$line" | awk '{print $5}')
    printf "  %s → %s (%s)\n" "$remote" "$local_path" "$type"
  done

  if ! mount -t nfs,nfs4 2>/dev/null | grep -q .; then
    echo "  (no NFS mounts active)"
  fi

  echo ""
  echo "Persistent mounts (fstab):"
  grep -E '\bnfs[4]?\b' /etc/fstab 2>/dev/null | sed 's/^/  /' || echo "  (none)"
}

# ─── HEALTH & DIAGNOSTICS ─────────────────────────────────

cmd_health() {
  echo "NFS Health Report"
  echo "─────────────────"
  
  # Check NFS server service
  local nfs_svc=""
  for svc in nfs-server nfs-kernel-server; do
    if systemctl is-active "$svc" &>/dev/null; then
      nfs_svc="$svc"
      break
    fi
  done

  if [[ -n "$nfs_svc" ]]; then
    echo -e "Service:    ${GREEN}✅ $nfs_svc active${NC}"
  else
    echo -e "Service:    ${RED}❌ NFS server not running${NC}"
  fi

  # Check rpcbind
  if systemctl is-active rpcbind &>/dev/null; then
    echo -e "RPC:        ${GREEN}✅ rpcbind active${NC}"
  else
    echo -e "RPC:        ${RED}❌ rpcbind not running${NC}"
  fi

  # Count exports
  local export_count=0
  if [[ -f /etc/exports ]]; then
    export_count=$(grep -cv '^#\|^$' /etc/exports 2>/dev/null || echo 0)
  fi
  echo "Exports:    ${export_count} configured"

  # Check active exports
  if command -v exportfs &>/dev/null; then
    local active_exports=$(exportfs -s 2>/dev/null | wc -l || echo 0)
    echo "Active:     ${active_exports} active exports"
  fi

  # Connected clients (from /proc/fs/nfsd/clients or ss)
  if [[ -d /proc/fs/nfsd ]]; then
    local threads=$(cat /proc/fs/nfsd/threads 2>/dev/null || echo "?")
    echo "Threads:    ${threads} NFS threads"
  fi

  # NFS port check
  if ss -tlnp 2>/dev/null | grep -q ':2049'; then
    echo -e "Port 2049:  ${GREEN}✅ listening${NC}"
  else
    echo -e "Port 2049:  ${YELLOW}⚠️  not listening (server may not be running)${NC}"
  fi
}

cmd_diagnose() {
  local server="${1:?Usage: nfs-manager.sh diagnose <server-ip>}"
  
  echo "Diagnosing NFS connectivity to $server..."
  echo "──────────────────────────────────────────"

  # Ping
  if ping -c 1 -W 2 "$server" &>/dev/null; then
    ok "Host reachable (ping)"
  else
    err "Host unreachable (ping failed)"
  fi

  # RPC
  if command -v rpcinfo &>/dev/null; then
    if rpcinfo -p "$server" &>/dev/null; then
      ok "RPC services available"
      echo "  NFS services:"
      rpcinfo -p "$server" 2>/dev/null | grep nfs | sed 's/^/    /'
    else
      err "RPC services unavailable (firewall? rpcbind not running?)"
    fi
  fi

  # Show exports
  if command -v showmount &>/dev/null; then
    echo ""
    echo "Available exports:"
    showmount -e "$server" 2>/dev/null | sed 's/^/  /' || err "Cannot query exports (showmount failed)"
  fi

  # Port check
  echo ""
  for port in 111 2049 20048; do
    if timeout 2 bash -c "echo >/dev/tcp/$server/$port" 2>/dev/null; then
      ok "Port $port open"
    else
      err "Port $port closed/filtered"
    fi
  done
}

cmd_stats() {
  echo "NFS Statistics"
  echo "──────────────"
  
  if command -v nfsstat &>/dev/null; then
    echo ""
    echo "Server stats:"
    nfsstat -s 2>/dev/null | head -20 | sed 's/^/  /' || echo "  (no server stats)"
    
    echo ""
    echo "Client stats:"
    nfsstat -c 2>/dev/null | head -20 | sed 's/^/  /' || echo "  (no client stats)"
  else
    warn "nfsstat not found. Install nfs-common or nfs-utils."
  fi
}

# ─── FIREWALL ──────────────────────────────────────────────

cmd_firewall_setup() {
  need_root
  local network="${1:?Usage: nfs-manager.sh firewall-setup <network>}"

  if command -v ufw &>/dev/null; then
    ufw allow from "$network" to any port 2049 proto tcp comment "NFS"
    ufw allow from "$network" to any port 20048 proto tcp comment "NFS mountd"
    ufw allow from "$network" to any port 111 proto tcp comment "NFS rpcbind"
    ufw allow from "$network" to any port 111 proto udp comment "NFS rpcbind UDP"
    ok "UFW rules added for NFS from $network"
  elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-service=nfs
    firewall-cmd --permanent --add-service=mountd
    firewall-cmd --permanent --add-service=rpc-bind
    firewall-cmd --reload
    ok "firewalld rules added for NFS"
  elif command -v iptables &>/dev/null; then
    iptables -A INPUT -s "$network" -p tcp --dport 2049 -j ACCEPT
    iptables -A INPUT -s "$network" -p tcp --dport 20048 -j ACCEPT
    iptables -A INPUT -s "$network" -p tcp --dport 111 -j ACCEPT
    iptables -A INPUT -s "$network" -p udp --dport 111 -j ACCEPT
    ok "iptables rules added for NFS from $network"
    warn "Remember to save iptables rules (iptables-save)"
  else
    err "No supported firewall found (ufw, firewalld, iptables)"
    exit 1
  fi
}

# ─── MAIN ──────────────────────────────────────────────────

usage() {
  cat <<EOF
NFS Manager — Setup, manage, and monitor NFS shares

USAGE:
  nfs-manager.sh <command> [args...]

SERVER COMMANDS:
  install-server              Install NFS server packages
  export <path> <net> [opts]  Add NFS export
  unexport <path>             Remove NFS export
  list-exports                List configured exports

CLIENT COMMANDS:
  install-client              Install NFS client packages
  mount <srv:/path> <mnt>     Mount remote NFS share
  unmount <mnt> [--permanent] Unmount NFS share
  list-mounts                 List active NFS mounts

MONITORING:
  health                      NFS server health check
  diagnose <server-ip>        Diagnose connectivity to NFS server
  stats                       Show NFS I/O statistics

FIREWALL:
  firewall-setup <network>    Configure firewall for NFS access

EOF
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  install-server)   cmd_install_server "$@" ;;
  install-client)   cmd_install_client "$@" ;;
  export)           cmd_export "$@" ;;
  unexport)         cmd_unexport "$@" ;;
  list-exports)     cmd_list_exports "$@" ;;
  mount)            cmd_mount "$@" ;;
  unmount)          cmd_unmount "$@" ;;
  list-mounts)      cmd_list_mounts "$@" ;;
  health)           cmd_health "$@" ;;
  diagnose)         cmd_diagnose "$@" ;;
  stats)            cmd_stats "$@" ;;
  firewall-setup)   cmd_firewall_setup "$@" ;;
  help|--help|-h)   usage ;;
  *)                err "Unknown command: $cmd"; usage; exit 1 ;;
esac
