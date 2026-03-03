#!/bin/bash
# System Migration Tool — Import Script
# Restores system configuration from a migration bundle

set -euo pipefail

VERSION="1.0.0"

# Defaults
BUNDLE=""
DRY_RUN=false
INCLUDE_ALL=true
INCLUDE_COMPONENTS=()
EXCLUDE_COMPONENTS=()
FORCE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "[import] $1"; }
dry() { echo -e "${BLUE}[dry-run]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1" >&2; }
err() { echo -e "${RED}[error]${NC} $1" >&2; exit 1; }
ok() { echo -e "${GREEN}✅${NC} $1"; }

usage() {
  cat <<EOF
System Migration Tool — Import v${VERSION}

Usage: sudo bash $0 --bundle <path.tar.gz> [options]

Options:
  --bundle, -b <path>     Migration bundle (.tar.gz)
  --dry-run, -n           Preview changes without applying
  --include <components>  Only import these (comma-separated)
  --exclude <components>  Skip these (comma-separated)
  --force, -f             Don't prompt for confirmation
  --help, -h              Show this help

Components: packages, services, crontabs, network, users, dotfiles, sysctl, firewall, docker

Examples:
  sudo bash $0 --bundle /tmp/migration-bundle.tar.gz --dry-run
  sudo bash $0 --bundle /tmp/migration-bundle.tar.gz
  sudo bash $0 --bundle /tmp/migration-bundle.tar.gz --include packages,services
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --bundle|-b) BUNDLE="$2"; shift 2 ;;
    --dry-run|-n) DRY_RUN=true; shift ;;
    --include) IFS=',' read -ra INCLUDE_COMPONENTS <<< "$2"; INCLUDE_ALL=false; shift 2 ;;
    --exclude) IFS=',' read -ra EXCLUDE_COMPONENTS <<< "$2"; shift 2 ;;
    --force|-f) FORCE=true; shift ;;
    --help|-h) usage ;;
    *) err "Unknown option: $1" ;;
  esac
done

[[ -z "$BUNDLE" ]] && err "Bundle path required. Use --bundle <path>"
[[ ! -f "$BUNDLE" ]] && err "Bundle not found: $BUNDLE"

# Extract bundle
WORK_DIR=$(mktemp -d)
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

tar xzf "$BUNDLE" -C "$WORK_DIR"
MIG="$WORK_DIR/migration"

[[ ! -d "$MIG" ]] && err "Invalid bundle — missing migration/ directory"

# Show metadata
if [[ -f "$MIG/metadata.json" ]]; then
  log "Bundle info:"
  log "  Source: $(cat "$MIG/metadata.json" | grep hostname | cut -d'"' -f4)"
  log "  OS: $(cat "$MIG/metadata.json" | grep '"os"' | cut -d'"' -f4)"
  log "  Exported: $(cat "$MIG/metadata.json" | grep exported_at | cut -d'"' -f4)"
  echo ""
fi

should_import() {
  local component=$1
  for exc in "${EXCLUDE_COMPONENTS[@]+"${EXCLUDE_COMPONENTS[@]}"}"; do
    [[ "$exc" == "$component" ]] && return 1
  done
  if ! $INCLUDE_ALL; then
    for inc in "${INCLUDE_COMPONENTS[@]}"; do
      [[ "$inc" == "$component" ]] && return 0
    done
    return 1
  fi
  return 0
}

detect_pkg_manager() {
  if command -v apt &>/dev/null; then echo "apt"
  elif command -v dnf &>/dev/null; then echo "dnf"
  elif command -v yum &>/dev/null; then echo "yum"
  elif command -v pacman &>/dev/null; then echo "pacman"
  else echo "unknown"
  fi
}

CHANGES=0

# 1. PACKAGES
if should_import packages && [[ -f "$MIG/packages.txt" ]]; then
  PKG_MGR=$(detect_pkg_manager)
  # Use manual packages if available (better — avoids auto-installed deps)
  PKG_FILE="$MIG/packages.txt"
  [[ -f "$MIG/packages-manual.txt" ]] && PKG_FILE="$MIG/packages-manual.txt"

  # Find missing packages
  case $PKG_MGR in
    apt) INSTALLED=$(dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | sort) ;;
    dnf|yum) INSTALLED=$(rpm -qa --qf '%{NAME}\n' 2>/dev/null | sort) ;;
    pacman) INSTALLED=$(pacman -Qqe 2>/dev/null | sort) ;;
    *) INSTALLED="" ;;
  esac

  MISSING=$(comm -23 <(sort "$PKG_FILE") <(echo "$INSTALLED") 2>/dev/null || true)
  MISSING_COUNT=$(echo "$MISSING" | grep -c . || echo 0)

  if [[ $MISSING_COUNT -gt 0 ]]; then
    if $DRY_RUN; then
      dry "Would install $MISSING_COUNT missing packages:"
      echo "$MISSING" | head -20 | sed 's/^/  /'
      [[ $MISSING_COUNT -gt 20 ]] && echo "  ... and $((MISSING_COUNT - 20)) more"
    else
      log "Installing $MISSING_COUNT packages..."
      case $PKG_MGR in
        apt) apt-get update -qq && echo "$MISSING" | xargs apt-get install -y -qq 2>/dev/null ;;
        dnf) echo "$MISSING" | xargs dnf install -y -q 2>/dev/null ;;
        yum) echo "$MISSING" | xargs yum install -y -q 2>/dev/null ;;
        pacman) echo "$MISSING" | xargs pacman -S --noconfirm 2>/dev/null ;;
      esac
      ok "Packages installed"
    fi
    CHANGES=$((CHANGES + 1))
  fi
fi

# 2. SERVICES
if should_import services && [[ -f "$MIG/services/enabled.txt" ]]; then
  # Find services to enable
  CURRENT_ENABLED=$(systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend 2>/dev/null | awk '{print $1}' | sort)
  TO_ENABLE=$(comm -23 <(sort "$MIG/services/enabled.txt") <(echo "$CURRENT_ENABLED") 2>/dev/null || true)
  ENABLE_COUNT=$(echo "$TO_ENABLE" | grep -c . 2>/dev/null || echo 0)
  ENABLE_COUNT=$(echo "$ENABLE_COUNT" | tr -d '[:space:]')

  if [[ $ENABLE_COUNT -gt 0 ]]; then
    if $DRY_RUN; then
      dry "Would enable $ENABLE_COUNT services:"
      echo "$TO_ENABLE" | sed 's/^/  /'
    else
      log "Enabling $ENABLE_COUNT services..."
      echo "$TO_ENABLE" | while read -r svc; do
        systemctl enable "$svc" 2>/dev/null || warn "Failed to enable $svc"
      done
      ok "Services enabled"
    fi
    CHANGES=$((CHANGES + 1))
  fi

  # Timers
  if [[ -f "$MIG/services/timers.txt" ]]; then
    TO_ENABLE_TIMERS=$(comm -23 <(sort "$MIG/services/timers.txt") <(systemctl list-unit-files --type=timer --state=enabled --no-pager --no-legend 2>/dev/null | awk '{print $1}' | sort) 2>/dev/null || true)
    TIMER_COUNT=$(echo "$TO_ENABLE_TIMERS" | grep -c . 2>/dev/null || echo 0)
    TIMER_COUNT=$(echo "$TIMER_COUNT" | tr -d '[:space:]')
    if [[ $TIMER_COUNT -gt 0 ]]; then
      if $DRY_RUN; then
        dry "Would enable $TIMER_COUNT timers:"
        echo "$TO_ENABLE_TIMERS" | sed 's/^/  /'
      else
        echo "$TO_ENABLE_TIMERS" | while read -r tmr; do
          systemctl enable "$tmr" 2>/dev/null || true
        done
      fi
      CHANGES=$((CHANGES + 1))
    fi
  fi
fi

# 3. CRONTABS
if should_import crontabs && [[ -d "$MIG/crontabs" ]]; then
  CRON_COUNT=0
  for cron_file in "$MIG/crontabs"/user-*.cron; do
    [[ ! -f "$cron_file" ]] && continue
    USERNAME=$(basename "$cron_file" | sed 's/^user-//;s/\.cron$//')
    if $DRY_RUN; then
      dry "Would restore crontab for user: $USERNAME"
    else
      if id "$USERNAME" &>/dev/null; then
        crontab -u "$USERNAME" "$cron_file" 2>/dev/null || warn "Failed to restore crontab for $USERNAME"
      else
        warn "User $USERNAME doesn't exist — skipping crontab"
      fi
    fi
    CRON_COUNT=$((CRON_COUNT + 1))
  done
  [[ $CRON_COUNT -gt 0 ]] && CHANGES=$((CHANGES + 1))
  if $DRY_RUN && [[ $CRON_COUNT -gt 0 ]]; then
    dry "Would restore $CRON_COUNT crontabs"
  fi
fi

# 4. SYSCTL
if should_import sysctl && [[ -d "$MIG/sysctl" ]]; then
  if [[ -f "$MIG/sysctl/sysctl.conf" ]]; then
    if $DRY_RUN; then
      # Count differing values
      DIFF_COUNT=$(diff "$MIG/sysctl/sysctl.conf" /etc/sysctl.conf 2>/dev/null | grep -c '^[<>]' || echo 0)
      dry "Would apply sysctl.conf ($DIFF_COUNT lines differ)"
    else
      cp "$MIG/sysctl/sysctl.conf" /etc/sysctl.conf
      sysctl -p 2>/dev/null || warn "Some sysctl values failed to apply"
      ok "Sysctl settings applied"
    fi
    CHANGES=$((CHANGES + 1))
  fi
  if [[ -d "$MIG/sysctl/sysctl.d" ]]; then
    if $DRY_RUN; then
      FILE_COUNT=$(find "$MIG/sysctl/sysctl.d" -type f | wc -l)
      dry "Would restore $FILE_COUNT sysctl.d config files"
    else
      cp -r "$MIG/sysctl/sysctl.d/"* /etc/sysctl.d/ 2>/dev/null || true
    fi
  fi
fi

# 5. FIREWALL
if should_import firewall && [[ -d "$MIG/firewall" ]]; then
  if [[ -d "$MIG/firewall/ufw-config" ]] && command -v ufw &>/dev/null; then
    if $DRY_RUN; then
      dry "Would restore UFW rules from bundle"
      [[ -f "$MIG/firewall/ufw-status.txt" ]] && cat "$MIG/firewall/ufw-status.txt" | head -10 | sed 's/^/  /'
    else
      cp -r "$MIG/firewall/ufw-config/"* /etc/ufw/ 2>/dev/null || true
      ufw --force enable 2>/dev/null || warn "Failed to enable UFW"
      ok "UFW rules restored"
    fi
    CHANGES=$((CHANGES + 1))
  elif [[ -f "$MIG/firewall/iptables-rules.txt" ]] && command -v iptables-restore &>/dev/null; then
    if $DRY_RUN; then
      RULE_COUNT=$(grep -c '^-A' "$MIG/firewall/iptables-rules.txt" || echo 0)
      dry "Would restore $RULE_COUNT iptables rules"
    else
      iptables-restore < "$MIG/firewall/iptables-rules.txt" 2>/dev/null || warn "Failed to restore iptables rules"
    fi
    CHANGES=$((CHANGES + 1))
  fi
fi

# 6. USERS
if should_import users && [[ -f "$MIG/users/users.txt" ]]; then
  while IFS=: read -r username uid gid homedir shell; do
    [[ -z "$username" ]] && continue
    if id "$username" &>/dev/null; then
      continue  # User already exists
    fi
    if $DRY_RUN; then
      dry "Would create user: $username (UID=$uid, home=$homedir, shell=$shell)"
    else
      useradd -m -u "$uid" -s "$shell" "$username" 2>/dev/null || warn "Failed to create user $username"
    fi
    CHANGES=$((CHANGES + 1))
  done < "$MIG/users/users.txt"

  # Restore SSH keys
  if [[ -d "$MIG/users/ssh-keys" ]]; then
    for keyfile in "$MIG/users/ssh-keys"/*_authorized_keys; do
      [[ ! -f "$keyfile" ]] && continue
      USERNAME=$(basename "$keyfile" | sed 's/_authorized_keys$//')
      if id "$USERNAME" &>/dev/null; then
        HOME_DIR=$(getent passwd "$USERNAME" | cut -d: -f6)
        if $DRY_RUN; then
          dry "Would restore SSH keys for $USERNAME"
        else
          mkdir -p "$HOME_DIR/.ssh"
          cp "$keyfile" "$HOME_DIR/.ssh/authorized_keys"
          chown -R "$USERNAME:" "$HOME_DIR/.ssh"
          chmod 700 "$HOME_DIR/.ssh"
          chmod 600 "$HOME_DIR/.ssh/authorized_keys"
        fi
      fi
    done
  fi
fi

# 7. DOTFILES
if should_import dotfiles && [[ -d "$MIG/dotfiles" ]]; then
  DOT_COUNT=0
  for user_dir in "$MIG/dotfiles"/*/; do
    [[ ! -d "$user_dir" ]] && continue
    USERNAME=$(basename "$user_dir")
    if ! id "$USERNAME" &>/dev/null; then
      warn "User $USERNAME doesn't exist — skipping dotfiles"
      continue
    fi
    HOME_DIR=$(getent passwd "$USERNAME" | cut -d: -f6)
    if $DRY_RUN; then
      FILE_COUNT=$(find "$user_dir" -type f | wc -l)
      dry "Would restore $FILE_COUNT dotfiles for $USERNAME"
    else
      # Copy dotfiles preserving relative paths
      cd "$user_dir"
      find . -type f | while read -r f; do
        dest="$HOME_DIR/$f"
        mkdir -p "$(dirname "$dest")"
        cp "$f" "$dest"
        chown "$USERNAME:" "$dest"
      done
      cd - >/dev/null
    fi
    DOT_COUNT=$((DOT_COUNT + 1))
  done
  [[ $DOT_COUNT -gt 0 ]] && CHANGES=$((CHANGES + 1))
fi

# Summary
echo ""
if $DRY_RUN; then
  if [[ $CHANGES -gt 0 ]]; then
    warn "No changes made. Remove --dry-run to apply."
  else
    ok "System already matches bundle — no changes needed."
  fi
else
  if [[ $CHANGES -gt 0 ]]; then
    ok "Migration complete! $CHANGES component(s) updated."
    log "Recommended: reboot to ensure all changes take effect."
  else
    ok "System already matches bundle — nothing to do."
  fi
fi
