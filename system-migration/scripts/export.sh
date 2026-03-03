#!/bin/bash
# System Migration Tool — Export Script
# Captures system configuration into a portable migration bundle

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
OUTPUT=""
INCLUDE_ALL=true
INCLUDE_COMPONENTS=()
EXCLUDE_COMPONENTS=()
CONFIG_FILE=""
QUIET=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { $QUIET || echo -e "[export] $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1" >&2; }
err() { echo -e "${RED}[error]${NC} $1" >&2; exit 1; }
ok() { $QUIET || echo -e "${GREEN}✅${NC} $1"; }

usage() {
  cat <<EOF
System Migration Tool — Export v${VERSION}

Usage: sudo bash $0 --output <path> [options]

Options:
  --output, -o <path>     Output path (without .tar.gz extension)
  --include <components>  Only export these (comma-separated)
  --exclude <components>  Skip these (comma-separated)
  --config <file>         Config file (YAML-like)
  --quiet, -q             Minimal output
  --help, -h              Show this help

Components: packages, services, crontabs, network, users, dotfiles, sysctl, firewall, etc-configs, docker

Examples:
  sudo bash $0 --output /tmp/migration
  sudo bash $0 --output /tmp/pkgs --include packages,services
  sudo bash $0 --output /tmp/full --exclude docker
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --output|-o) OUTPUT="$2"; shift 2 ;;
    --include) IFS=',' read -ra INCLUDE_COMPONENTS <<< "$2"; INCLUDE_ALL=false; shift 2 ;;
    --exclude) IFS=',' read -ra EXCLUDE_COMPONENTS <<< "$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --quiet|-q) QUIET=true; shift ;;
    --help|-h) usage ;;
    *) err "Unknown option: $1" ;;
  esac
done

[[ -z "$OUTPUT" ]] && err "Output path required. Use --output <path>"

# Create working directory
WORK_DIR=$(mktemp -d)
MIGRATION_DIR="$WORK_DIR/migration"
mkdir -p "$MIGRATION_DIR"

# Cleanup on exit
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# Check if component should be exported
should_export() {
  local component=$1
  # Check excludes
  for exc in "${EXCLUDE_COMPONENTS[@]+"${EXCLUDE_COMPONENTS[@]}"}"; do
    [[ "$exc" == "$component" ]] && return 1
  done
  # Check includes
  if ! $INCLUDE_ALL; then
    for inc in "${INCLUDE_COMPONENTS[@]}"; do
      [[ "$inc" == "$component" ]] && return 0
    done
    return 1
  fi
  return 0
}

# Detect package manager
detect_pkg_manager() {
  if command -v apt &>/dev/null; then echo "apt"
  elif command -v dnf &>/dev/null; then echo "dnf"
  elif command -v yum &>/dev/null; then echo "yum"
  elif command -v pacman &>/dev/null; then echo "pacman"
  else echo "unknown"
  fi
}

# Save metadata
cat > "$MIGRATION_DIR/metadata.json" <<EOF
{
  "version": "$VERSION",
  "exported_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "os": "$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || echo 'unknown')",
  "kernel": "$(uname -r)",
  "arch": "$(uname -m)",
  "pkg_manager": "$(detect_pkg_manager)"
}
EOF

# 1. PACKAGES
if should_export packages; then
  PKG_MGR=$(detect_pkg_manager)
  case $PKG_MGR in
    apt)
      dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | sort > "$MIGRATION_DIR/packages.txt"
      # Also save manually installed packages
      apt-mark showmanual 2>/dev/null | sort > "$MIGRATION_DIR/packages-manual.txt"
      ;;
    dnf|yum)
      rpm -qa --qf '%{NAME}\n' 2>/dev/null | sort > "$MIGRATION_DIR/packages.txt"
      ;;
    pacman)
      pacman -Qqe 2>/dev/null | sort > "$MIGRATION_DIR/packages.txt"
      pacman -Qqm 2>/dev/null | sort > "$MIGRATION_DIR/packages-aur.txt"
      ;;
    *)
      warn "Unknown package manager — skipping package export"
      ;;
  esac
  COUNT=$(wc -l < "$MIGRATION_DIR/packages.txt" 2>/dev/null || echo 0)
  log "Collecting package list... $COUNT packages"
fi

# 2. SERVICES
if should_export services; then
  mkdir -p "$MIGRATION_DIR/services"
  # Enabled services
  systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend 2>/dev/null | \
    awk '{print $1}' | sort > "$MIGRATION_DIR/services/enabled.txt"
  # Running services
  systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | \
    awk '{print $1}' | sort > "$MIGRATION_DIR/services/running.txt"
  # Enabled timers
  systemctl list-unit-files --type=timer --state=enabled --no-pager --no-legend 2>/dev/null | \
    awk '{print $1}' | sort > "$MIGRATION_DIR/services/timers.txt"
  COUNT=$(wc -l < "$MIGRATION_DIR/services/enabled.txt" 2>/dev/null || echo 0)
  log "Collecting service states... $COUNT enabled services"
fi

# 3. CRONTABS
if should_export crontabs; then
  mkdir -p "$MIGRATION_DIR/crontabs"
  CRON_COUNT=0
  # System crontab
  if [[ -f /etc/crontab ]]; then
    cp /etc/crontab "$MIGRATION_DIR/crontabs/system-crontab"
    CRON_COUNT=$((CRON_COUNT + 1))
  fi
  # Per-user crontabs
  for user in $(cut -d: -f1 /etc/passwd); do
    if crontab -l -u "$user" &>/dev/null; then
      crontab -l -u "$user" > "$MIGRATION_DIR/crontabs/user-${user}.cron" 2>/dev/null || true
      CRON_COUNT=$((CRON_COUNT + 1))
    fi
  done
  # Cron.d directory
  if [[ -d /etc/cron.d ]]; then
    cp -r /etc/cron.d "$MIGRATION_DIR/crontabs/cron.d" 2>/dev/null || true
  fi
  log "Collecting crontabs... $CRON_COUNT crontabs"
fi

# 4. NETWORK
if should_export network; then
  mkdir -p "$MIGRATION_DIR/network"
  # Netplan (Ubuntu 18+)
  if [[ -d /etc/netplan ]]; then
    cp -r /etc/netplan "$MIGRATION_DIR/network/netplan" 2>/dev/null || true
  fi
  # Traditional interfaces
  if [[ -f /etc/network/interfaces ]]; then
    cp /etc/network/interfaces "$MIGRATION_DIR/network/interfaces" 2>/dev/null || true
  fi
  # DNS
  if [[ -f /etc/resolv.conf ]]; then
    cp /etc/resolv.conf "$MIGRATION_DIR/network/resolv.conf" 2>/dev/null || true
  fi
  # Hosts
  cp /etc/hosts "$MIGRATION_DIR/network/hosts" 2>/dev/null || true
  # Current IP info
  ip addr show 2>/dev/null > "$MIGRATION_DIR/network/ip-addr.txt" || true
  ip route show 2>/dev/null > "$MIGRATION_DIR/network/ip-route.txt" || true
  log "Collecting network config..."
fi

# 5. USERS
if should_export users; then
  mkdir -p "$MIGRATION_DIR/users"
  # Non-system users (UID >= 1000, excluding nobody)
  awk -F: '$3 >= 1000 && $1 != "nobody" {print $1":"$3":"$4":"$6":"$7}' /etc/passwd > "$MIGRATION_DIR/users/users.txt"
  # Groups
  awk -F: '$3 >= 1000 {print $0}' /etc/group > "$MIGRATION_DIR/users/groups.txt"
  # User-group memberships
  for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    groups "$user" 2>/dev/null >> "$MIGRATION_DIR/users/memberships.txt" || true
  done
  # SSH authorized_keys
  for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    HOME_DIR=$(getent passwd "$user" | cut -d: -f6)
    if [[ -f "$HOME_DIR/.ssh/authorized_keys" ]]; then
      mkdir -p "$MIGRATION_DIR/users/ssh-keys"
      cp "$HOME_DIR/.ssh/authorized_keys" "$MIGRATION_DIR/users/ssh-keys/${user}_authorized_keys" 2>/dev/null || true
    fi
  done
  COUNT=$(wc -l < "$MIGRATION_DIR/users/users.txt" 2>/dev/null || echo 0)
  log "Collecting user accounts... $COUNT users"
fi

# 6. DOTFILES
if should_export dotfiles; then
  mkdir -p "$MIGRATION_DIR/dotfiles"
  DEFAULT_DOTFILES=(.bashrc .bash_profile .profile .gitconfig .ssh/config .tmux.conf .vimrc .zshrc .inputrc)
  for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    HOME_DIR=$(getent passwd "$user" | cut -d: -f6)
    USER_DOTS="$MIGRATION_DIR/dotfiles/$user"
    for dotfile in "${DEFAULT_DOTFILES[@]}"; do
      if [[ -f "$HOME_DIR/$dotfile" ]]; then
        mkdir -p "$USER_DOTS/$(dirname "$dotfile")"
        cp "$HOME_DIR/$dotfile" "$USER_DOTS/$dotfile" 2>/dev/null || true
      fi
    done
  done
  log "Collecting dotfiles..."
fi

# 7. SYSCTL
if should_export sysctl; then
  mkdir -p "$MIGRATION_DIR/sysctl"
  # Main sysctl.conf
  [[ -f /etc/sysctl.conf ]] && cp /etc/sysctl.conf "$MIGRATION_DIR/sysctl/sysctl.conf"
  # sysctl.d directory
  [[ -d /etc/sysctl.d ]] && cp -r /etc/sysctl.d "$MIGRATION_DIR/sysctl/sysctl.d" 2>/dev/null || true
  # Current runtime values (key ones)
  sysctl -a 2>/dev/null | grep -E '^(net\.|vm\.|kernel\.|fs\.)' | sort > "$MIGRATION_DIR/sysctl/runtime-values.txt" || true
  log "Collecting sysctl settings..."
fi

# 8. FIREWALL
if should_export firewall; then
  mkdir -p "$MIGRATION_DIR/firewall"
  # UFW
  if command -v ufw &>/dev/null; then
    timeout 5 ufw status verbose 2>/dev/null > "$MIGRATION_DIR/firewall/ufw-status.txt" || true
    # UFW rules files
    if [[ -d /etc/ufw ]]; then
      cp -r /etc/ufw "$MIGRATION_DIR/firewall/ufw-config" 2>/dev/null || true
    fi
  fi
  # iptables
  if command -v iptables &>/dev/null; then
    timeout 5 iptables-save 2>/dev/null > "$MIGRATION_DIR/firewall/iptables-rules.txt" || true
  fi
  # nftables
  if command -v nft &>/dev/null; then
    timeout 5 nft list ruleset 2>/dev/null > "$MIGRATION_DIR/firewall/nftables-rules.txt" || true
  fi
  log "Collecting firewall rules..."
fi

# 9. DOCKER (optional)
if should_export docker; then
  if command -v docker &>/dev/null; then
    mkdir -p "$MIGRATION_DIR/docker"
    # Running containers
    docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null > "$MIGRATION_DIR/docker/containers.txt" || true
    # All images
    docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null > "$MIGRATION_DIR/docker/images.txt" || true
    # Docker compose files (search common locations, max depth 4)
    timeout 10 find /opt /srv /home -maxdepth 4 \( -name "docker-compose.yml" -o -name "docker-compose.yaml" -o -name "compose.yml" -o -name "compose.yaml" \) 2>/dev/null | head -50 > "$MIGRATION_DIR/docker/compose-locations.txt" || true
    log "Collecting Docker info..."
  fi
fi

# 10. ETC CONFIGS (optional selective)
if should_export etc-configs; then
  mkdir -p "$MIGRATION_DIR/etc-configs"
  # Common config directories
  for dir in nginx redis postgresql mysql ssh fail2ban; do
    if [[ -d "/etc/$dir" ]]; then
      cp -r "/etc/$dir" "$MIGRATION_DIR/etc-configs/$dir" 2>/dev/null || true
    fi
  done
  log "Collecting /etc/ config directories..."
fi

# Create the bundle
cd "$WORK_DIR"
tar czf "${OUTPUT}.tar.gz" migration/

BUNDLE_SIZE=$(du -h "${OUTPUT}.tar.gz" | cut -f1)
ok "Migration bundle saved to ${OUTPUT}.tar.gz ($BUNDLE_SIZE)"
