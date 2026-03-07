#!/bin/bash
# User Manager — Linux user, group, SSH key, and sudo management
# Version: 1.0.0

set -euo pipefail

# --- Configuration ---
DEFAULT_SHELL="${USER_MGR_DEFAULT_SHELL:-/bin/bash}"
SSH_ONLY="${USER_MGR_SSH_ONLY:-true}"
MIN_UID="${USER_MGR_MIN_UID:-1000}"
HOME_BASE="${USER_MGR_HOME_BASE:-/home}"
LOG_FILE="/var/log/user-manager.log"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Helpers ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | sudo tee -a "$LOG_FILE" >/dev/null 2>/dev/null || true; }
ok()   { echo -e "${GREEN}✅ $*${NC}"; log "OK: $*"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; log "WARN: $*"; }
err()  { echo -e "${RED}❌ $*${NC}"; log "ERROR: $*"; }
die()  { err "$*"; exit 1; }

check_root() {
  [[ $EUID -eq 0 ]] || die "This script must be run as root (use sudo)"
}

user_exists() { id "$1" &>/dev/null; }
group_exists() { getent group "$1" &>/dev/null; }

# --- Commands ---

cmd_create() {
  local username="" fullname="" groups="" shell="$DEFAULT_SHELL" ssh_key=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username)  username="$2"; shift 2 ;;
      --fullname)  fullname="$2"; shift 2 ;;
      --groups)    groups="$2"; shift 2 ;;
      --shell)     shell="$2"; shift 2 ;;
      --ssh-key)   ssh_key="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -n "$username" ]] || die "Usage: create --username <name> [--fullname <name>] [--groups <g1,g2>] [--shell <path>] [--ssh-key <key>]"
  user_exists "$username" && die "User '$username' already exists"

  # Create groups if they don't exist
  if [[ -n "$groups" ]]; then
    IFS=',' read -ra GROUP_ARR <<< "$groups"
    for g in "${GROUP_ARR[@]}"; do
      if ! group_exists "$g"; then
        groupadd "$g"
        ok "Group '$g' created"
      fi
    done
  fi

  # Create user
  local cmd=(useradd -m -d "${HOME_BASE}/${username}" -s "$shell")
  [[ -n "$fullname" ]] && cmd+=(-c "$fullname")
  [[ -n "$groups" ]] && cmd+=(-G "$groups")
  "${cmd[@]}" "$username"
  ok "User '$username' created (UID: $(id -u "$username"))"
  ok "Home directory: ${HOME_BASE}/${username}"

  # Show groups
  local user_groups
  user_groups=$(id -nG "$username" | tr ' ' ', ')
  ok "Groups: $user_groups"

  # Set up SSH key
  if [[ -n "$ssh_key" ]]; then
    local ssh_dir="${HOME_BASE}/${username}/.ssh"
    mkdir -p "$ssh_dir"
    echo "$ssh_key" >> "$ssh_dir/authorized_keys"
    chmod 700 "$ssh_dir"
    chmod 600 "$ssh_dir/authorized_keys"
    chown -R "${username}:${username}" "$ssh_dir"
    ok "SSH key added to ${ssh_dir}/authorized_keys"
  fi

  # Disable password login if SSH-only mode
  if [[ "$SSH_ONLY" == "true" ]]; then
    passwd -l "$username" &>/dev/null
    ok "Password login disabled (SSH key only)"
  fi
}

cmd_sudo() {
  local username="" grant=false revoke=false nopasswd=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username) username="$2"; shift 2 ;;
      --grant)    grant=true; shift ;;
      --revoke)   revoke=true; shift ;;
      --nopasswd) nopasswd=true; shift ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -n "$username" ]] || die "Usage: sudo --username <name> --grant|--revoke [--nopasswd]"
  user_exists "$username" || die "User '$username' does not exist"

  local sudoers_file="/etc/sudoers.d/${username}"

  if $grant; then
    if $nopasswd; then
      echo "${username} ALL=(ALL:ALL) NOPASSWD:ALL" > "$sudoers_file"
      ok "Passwordless sudo granted to '${username}'"
      echo "   Rule: ${username} ALL=(ALL:ALL) NOPASSWD:ALL"
    else
      echo "${username} ALL=(ALL:ALL) ALL" > "$sudoers_file"
      ok "Sudo granted to '${username}' (password required)"
      echo "   Rule: ${username} ALL=(ALL:ALL) ALL"
    fi
    chmod 440 "$sudoers_file"
  elif $revoke; then
    rm -f "$sudoers_file"
    # Also remove from sudo group
    gpasswd -d "$username" sudo &>/dev/null || true
    ok "Sudo revoked for '${username}'"
  else
    die "Specify --grant or --revoke"
  fi
}

cmd_ssh_key() {
  local username="" add="" remove="" list=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username) username="$2"; shift 2 ;;
      --add)      add="$2"; shift 2 ;;
      --remove)   remove="$2"; shift 2 ;;
      --list)     list=true; shift ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -n "$username" ]] || die "Usage: ssh-key --username <name> --add <key>|--remove <comment>|--list"
  user_exists "$username" || die "User '$username' does not exist"

  local auth_keys="${HOME_BASE}/${username}/.ssh/authorized_keys"

  if [[ -n "$add" ]]; then
    local ssh_dir="${HOME_BASE}/${username}/.ssh"
    mkdir -p "$ssh_dir"
    echo "$add" >> "$auth_keys"
    chmod 700 "$ssh_dir"
    chmod 600 "$auth_keys"
    chown -R "${username}:${username}" "$ssh_dir"
    ok "SSH key added for '${username}'"

  elif [[ -n "$remove" ]]; then
    if [[ ! -f "$auth_keys" ]]; then
      die "No authorized_keys file for '${username}'"
    fi
    local before after
    before=$(wc -l < "$auth_keys")
    grep -v "$remove" "$auth_keys" > "${auth_keys}.tmp" || true
    mv "${auth_keys}.tmp" "$auth_keys"
    chmod 600 "$auth_keys"
    after=$(wc -l < "$auth_keys")
    ok "Removed $((before - after)) key(s) matching '${remove}'"

  elif $list; then
    if [[ ! -f "$auth_keys" ]] || [[ ! -s "$auth_keys" ]]; then
      echo "No SSH keys for '${username}'"
      return
    fi
    echo "SSH keys for '${username}':"
    local i=1
    while IFS= read -r line; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      local fp
      fp=$(echo "$line" | ssh-keygen -l -f - 2>/dev/null || echo "unknown fingerprint")
      echo "  ${i}. $fp"
      ((i++))
    done < "$auth_keys"
  fi
}

cmd_audit() {
  echo "=== User Account Audit ==="
  echo "Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo ""

  echo "Human Users (UID >= ${MIN_UID}):"
  local found=false
  while IFS=: read -r uname _ uid _ fullname home shell; do
    [[ $uid -lt $MIN_UID ]] && continue
    [[ "$uname" == "nobody" || "$uname" == "nfsnobody" ]] && continue
    found=true

    local groups_str
    groups_str=$(id -nG "$uname" 2>/dev/null | tr ' ' ', ')

    # Check sudo
    local sudo_status="no"
    if [[ -f "/etc/sudoers.d/${uname}" ]] || id -nG "$uname" 2>/dev/null | grep -qw sudo; then
      sudo_status="yes"
      if [[ -f "/etc/sudoers.d/${uname}" ]] && grep -q "NOPASSWD" "/etc/sudoers.d/${uname}" 2>/dev/null; then
        sudo_status="yes (NOPASSWD)"
      fi
    fi

    # Last login
    local last_login
    last_login=$(lastlog -u "$uname" 2>/dev/null | tail -1 | awk '{if ($2 == "**Never") print "Never"; else print $4" "$5" "$6" "$7}' || echo "unknown")

    # SSH key count
    local key_count=0
    local auth_keys="${home}/.ssh/authorized_keys"
    if [[ -f "$auth_keys" ]]; then
      key_count=$(grep -c "^ssh-" "$auth_keys" 2>/dev/null || echo 0)
    fi

    printf "  %-12s | Groups: %-25s | Sudo: %-16s | Last: %-15s | SSH keys: %s\n" \
      "$uname" "$groups_str" "$sudo_status" "$last_login" "$key_count"
  done < /etc/passwd

  $found || echo "  (none)"

  echo ""

  # Warnings
  echo "Security Checks:"

  # Users with empty passwords
  local empty_pw
  empty_pw=$(awk -F: '($2 == "" || $2 == "!") && $3 >= '"$MIN_UID"' {print $1}' /etc/shadow 2>/dev/null || true)
  if [[ -n "$empty_pw" ]]; then
    warn "Users with empty/locked passwords: $empty_pw"
  else
    ok "No users with empty passwords"
  fi

  # Users with login shell that shouldn't have one
  local sys_with_shell
  sys_with_shell=$(awk -F: '$3 < '"$MIN_UID"' && $3 != 0 && $7 !~ /nologin|false|sync|halt|shutdown/ {print $1}' /etc/passwd 2>/dev/null || true)
  if [[ -n "$sys_with_shell" ]]; then
    warn "System users with login shells: $sys_with_shell"
  else
    ok "No system users with login shells"
  fi

  # Passwordless sudo users
  local nopasswd_users=""
  for f in /etc/sudoers.d/*; do
    [[ -f "$f" ]] || continue
    if grep -q "NOPASSWD" "$f" 2>/dev/null; then
      nopasswd_users+="$(basename "$f") "
    fi
  done
  if [[ -n "$nopasswd_users" ]]; then
    warn "Users with passwordless sudo: $nopasswd_users"
  else
    ok "No passwordless sudo users"
  fi
}

cmd_lock() {
  local username=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username) username="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -n "$username" ]] || die "Usage: lock --username <name>"
  user_exists "$username" || die "User '$username' does not exist"

  usermod -L "$username"
  usermod -s /usr/sbin/nologin "$username" 2>/dev/null || usermod -s /sbin/nologin "$username"
  ok "User '$username' locked (account disabled, shell set to nologin)"
}

cmd_unlock() {
  local username="" shell="$DEFAULT_SHELL"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username) username="$2"; shift 2 ;;
      --shell)    shell="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -n "$username" ]] || die "Usage: unlock --username <name> [--shell <path>]"
  user_exists "$username" || die "User '$username' does not exist"

  usermod -U "$username"
  usermod -s "$shell" "$username"
  ok "User '$username' unlocked (shell: $shell)"
}

cmd_remove() {
  local username="" purge=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username) username="$2"; shift 2 ;;
      --purge)    purge=true; shift ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -n "$username" ]] || die "Usage: remove --username <name> [--purge]"
  user_exists "$username" || die "User '$username' does not exist"

  # Remove sudoers entry
  rm -f "/etc/sudoers.d/${username}"

  if $purge; then
    userdel -r "$username" 2>/dev/null || userdel "$username"
    ok "User '$username' removed (home directory purged)"
  else
    userdel "$username"
    ok "User '$username' removed (home directory preserved)"
  fi
}

cmd_group_create() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -n "$name" ]] || die "Usage: group-create --name <name>"
  group_exists "$name" && die "Group '$name' already exists"
  groupadd "$name"
  ok "Group '$name' created (GID: $(getent group "$name" | cut -d: -f3))"
}

cmd_group_add() {
  local username="" group=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username) username="$2"; shift 2 ;;
      --group)    group="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -n "$username" && -n "$group" ]] || die "Usage: group-add --username <name> --group <group>"
  user_exists "$username" || die "User '$username' does not exist"
  group_exists "$group" || die "Group '$group' does not exist"
  usermod -aG "$group" "$username"
  ok "User '$username' added to group '$group'"
}

cmd_group_remove() {
  local username="" group=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username) username="$2"; shift 2 ;;
      --group)    group="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -n "$username" && -n "$group" ]] || die "Usage: group-remove --username <name> --group <group>"
  gpasswd -d "$username" "$group"
  ok "User '$username' removed from group '$group'"
}

cmd_group_list() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -n "$name" ]] || die "Usage: group-list --name <name>"
  group_exists "$name" || die "Group '$name' does not exist"
  local members
  members=$(getent group "$name" | cut -d: -f4)
  echo "Group '$name' members: ${members:-<none>}"
}

cmd_bulk_create() {
  local file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -n "$file" && -f "$file" ]] || die "Usage: bulk-create --file <csv>"

  local count=0
  while IFS=, read -r username fullname groups shell ssh_key; do
    [[ "$username" == "username" || -z "$username" ]] && continue  # skip header
    local args=(--username "$username")
    [[ -n "$fullname" ]] && args+=(--fullname "$fullname")
    [[ -n "$groups" ]] && args+=(--groups "$groups")
    [[ -n "$shell" ]] && args+=(--shell "$shell")
    [[ -n "$ssh_key" ]] && args+=(--ssh-key "$ssh_key")
    echo "--- Creating user: $username ---"
    cmd_create "${args[@]}"
    ((count++))
    echo ""
  done < "$file"
  ok "Bulk create complete: $count users created"
}

cmd_export() {
  local format="json"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format) format="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  if [[ "$format" == "csv" ]]; then
    echo "username,uid,groups,shell,home,sudo,ssh_keys"
    while IFS=: read -r uname _ uid _ _ home shell; do
      [[ $uid -lt $MIN_UID ]] && continue
      [[ "$uname" == "nobody" ]] && continue
      local groups_str
      groups_str=$(id -nG "$uname" 2>/dev/null | tr ' ' ',')
      local sudo_yn="no"
      [[ -f "/etc/sudoers.d/${uname}" ]] && sudo_yn="yes"
      local keys=0
      [[ -f "${home}/.ssh/authorized_keys" ]] && keys=$(grep -c "^ssh-" "${home}/.ssh/authorized_keys" 2>/dev/null || echo 0)
      echo "${uname},${uid},${groups_str},${shell},${home},${sudo_yn},${keys}"
    done < /etc/passwd
  else
    echo "["
    local first=true
    while IFS=: read -r uname _ uid _ fullname home shell; do
      [[ $uid -lt $MIN_UID ]] && continue
      [[ "$uname" == "nobody" ]] && continue
      $first || echo ","
      first=false
      local groups_str
      groups_str=$(id -nG "$uname" 2>/dev/null | tr ' ' '", "')
      local sudo_yn="false"
      [[ -f "/etc/sudoers.d/${uname}" ]] && sudo_yn="true"
      local keys=0
      [[ -f "${home}/.ssh/authorized_keys" ]] && keys=$(grep -c "^ssh-" "${home}/.ssh/authorized_keys" 2>/dev/null || echo 0)
      cat <<EOF
  {
    "username": "$uname",
    "uid": $uid,
    "fullname": "$fullname",
    "home": "$home",
    "shell": "$shell",
    "groups": ["$groups_str"],
    "sudo": $sudo_yn,
    "ssh_keys": $keys
  }
EOF
    done < /etc/passwd
    echo ""
    echo "]"
  fi
}

cmd_enforce_ssh() {
  local username=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username) username="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -n "$username" ]] || die "Usage: enforce-ssh --username <name>"
  user_exists "$username" || die "User '$username' does not exist"

  local auth_keys="${HOME_BASE}/${username}/.ssh/authorized_keys"
  [[ -f "$auth_keys" && -s "$auth_keys" ]] || die "No SSH keys found for '${username}' — add a key first!"

  passwd -l "$username" &>/dev/null
  ok "Password login disabled for '${username}' (SSH key only)"
}

cmd_password_policy() {
  local username="" max_days="" warn_days=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username)  username="$2"; shift 2 ;;
      --max-days)  max_days="$2"; shift 2 ;;
      --warn-days) warn_days="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -n "$username" ]] || die "Usage: password-policy --username <name> --max-days <N> [--warn-days <N>]"
  user_exists "$username" || die "User '$username' does not exist"

  local cmd=(chage)
  [[ -n "$max_days" ]] && cmd+=(-M "$max_days")
  [[ -n "$warn_days" ]] && cmd+=(-W "$warn_days")
  "${cmd[@]}" "$username"
  ok "Password policy updated for '${username}'"
  chage -l "$username"
}

cmd_password_status() {
  local username=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username) username="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -n "$username" ]] || die "Usage: password-status --username <name>"
  user_exists "$username" || die "User '$username' does not exist"
  chage -l "$username"
}

# --- Usage ---
usage() {
  cat <<EOF
User Manager — Linux user, group, SSH key, and sudo management

Usage: $(basename "$0") <command> [options]

Commands:
  create          Create a new user
  sudo            Grant or revoke sudo access
  ssh-key         Manage SSH keys
  audit           Security audit of all users
  lock            Lock a user account
  unlock          Unlock a user account
  remove          Remove a user account
  group-create    Create a new group
  group-add       Add user to group
  group-remove    Remove user from group
  group-list      List group members
  bulk-create     Create users from CSV file
  export          Export user list (json/csv)
  enforce-ssh     Enforce SSH-key-only login
  password-policy Set password expiry policy
  password-status Check password status

Run '$(basename "$0") <command> --help' for details.
EOF
}

# --- Main ---
check_root

COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
  create)          cmd_create "$@" ;;
  sudo)            cmd_sudo "$@" ;;
  ssh-key)         cmd_ssh_key "$@" ;;
  audit)           cmd_audit ;;
  lock)            cmd_lock "$@" ;;
  unlock)          cmd_unlock "$@" ;;
  remove)          cmd_remove "$@" ;;
  group-create)    cmd_group_create "$@" ;;
  group-add)       cmd_group_add "$@" ;;
  group-remove)    cmd_group_remove "$@" ;;
  group-list)      cmd_group_list "$@" ;;
  bulk-create)     cmd_bulk_create "$@" ;;
  export)          cmd_export "$@" ;;
  enforce-ssh)     cmd_enforce_ssh "$@" ;;
  password-policy) cmd_password_policy "$@" ;;
  password-status) cmd_password_status "$@" ;;
  -h|--help|help|"") usage ;;
  *) die "Unknown command: $COMMAND. Run '$(basename "$0") --help'" ;;
esac
