#!/bin/bash
# Linux User Manager — Manage users, groups, sudo, SSH keys, passwords
# Version: 1.0.0

set -euo pipefail

LOG_FILE="/var/log/user-manager.log"
SCRIPT_NAME="$(basename "$0")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

info() { echo -e "${GREEN}✅${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️${NC}  $*"; }
error() { echo -e "${RED}❌${NC} $*" >&2; }

usage() {
  cat <<EOF
Linux User Manager v1.0.0

Usage: $SCRIPT_NAME <command> [options]

Commands:
  create       Create a new user
  delete       Delete a user
  modify       Modify an existing user
  list         List all users
  sudo         Manage sudo access
  ssh-key      Manage SSH keys
  password     Manage password policies
  group        Manage groups
  audit        Security audit & reporting
  bulk-create  Create users from CSV file

Run '$SCRIPT_NAME <command> --help' for command-specific help.
EOF
}

# ── Helpers ──────────────────────────────────────────────

user_exists() { getent passwd "$1" &>/dev/null; }
group_exists() { getent group "$1" &>/dev/null; }

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This command requires root/sudo privileges"
    exit 1
  fi
}

# ── CREATE ───────────────────────────────────────────────

cmd_create() {
  local username="" fullname="" shell="/bin/bash" groups="" ssh_key=""
  local password_expire="" home="" dry_run=false lock_password=true

  while [[ $# -gt 0 ]]; do
    case $1 in
      --username) username="$2"; shift 2 ;;
      --fullname) fullname="$2"; shift 2 ;;
      --shell) shell="$2"; shift 2 ;;
      --groups) groups="$2"; shift 2 ;;
      --ssh-key) ssh_key="$2"; shift 2 ;;
      --password-expire) password_expire="$2"; shift 2 ;;
      --home) home="$2"; shift 2 ;;
      --set-password) lock_password=false; shift ;;
      --dry-run) dry_run=true; shift ;;
      --help) echo "Usage: $SCRIPT_NAME create --username <name> [--fullname <name>] [--shell <path>] [--groups <g1,g2>] [--ssh-key <key>] [--password-expire <days>] [--home <path>] [--set-password] [--dry-run]"; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  [[ -z "$username" ]] && { error "--username is required"; return 1; }

  if $dry_run; then
    echo "DRY RUN — Would create user '$username':"
    echo "  Shell: $shell"
    [[ -n "$fullname" ]] && echo "  Full name: $fullname"
    [[ -n "$groups" ]] && echo "  Groups: $groups"
    [[ -n "$ssh_key" ]] && echo "  SSH key: ${ssh_key:0:30}..."
    [[ -n "$password_expire" ]] && echo "  Password expires: ${password_expire} days"
    return 0
  fi

  ensure_root

  if user_exists "$username"; then
    error "User '$username' already exists. Use 'modify' instead."
    return 1
  fi

  # Create groups if they don't exist
  if [[ -n "$groups" ]]; then
    IFS=',' read -ra GROUP_LIST <<< "$groups"
    for g in "${GROUP_LIST[@]}"; do
      if ! group_exists "$g"; then
        groupadd "$g"
        info "Created group '$g'"
      fi
    done
  fi

  # Build useradd command
  local cmd="useradd -m -s $shell"
  [[ -n "$fullname" ]] && cmd+=" -c \"$fullname\""
  [[ -n "$home" ]] && cmd+=" -d $home"
  [[ -n "$groups" ]] && cmd+=" -G $groups"
  cmd+=" $username"

  eval $cmd
  log "Created user: $username (groups: ${groups:-none}, shell: $shell)"
  info "Created user '$username'"

  # Lock password by default (SSH-key-only)
  if $lock_password; then
    passwd -l "$username" &>/dev/null
    info "Password locked (SSH-key-only access)"
  else
    echo "Set password for $username:"
    passwd "$username"
  fi

  # Install SSH key
  if [[ -n "$ssh_key" ]]; then
    local ssh_dir
    ssh_dir="$(eval echo ~"$username")/.ssh"
    mkdir -p "$ssh_dir"
    echo "$ssh_key" >> "$ssh_dir/authorized_keys"
    chmod 700 "$ssh_dir"
    chmod 600 "$ssh_dir/authorized_keys"
    chown -R "$username:$(id -gn "$username")" "$ssh_dir"
    info "SSH key installed"
    log "SSH key added for $username"
  fi

  # Password expiry
  if [[ -n "$password_expire" ]]; then
    chage -M "$password_expire" "$username"
    info "Password expires in $password_expire days"
    log "Password expiry set: $username = $password_expire days"
  fi

  echo ""
  info "User '$username' created successfully"
}

# ── DELETE ───────────────────────────────────────────────

cmd_delete() {
  local username="" remove_home=false reassign=false dry_run=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --username) username="$2"; shift 2 ;;
      --remove-home) remove_home=true; shift ;;
      --reassign) reassign=true; shift ;;
      --dry-run) dry_run=true; shift ;;
      --help) echo "Usage: $SCRIPT_NAME delete --username <name> [--remove-home] [--reassign] [--dry-run]"; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  [[ -z "$username" ]] && { error "--username is required"; return 1; }
  ensure_root

  if ! user_exists "$username"; then
    error "User '$username' does not exist"
    return 1
  fi

  if $dry_run; then
    echo "DRY RUN — Would delete user '$username'"
    $remove_home && echo "  Would remove home directory"
    $reassign && echo "  Would reassign owned files to root"
    return 0
  fi

  # Reassign files
  if $reassign; then
    local uid
    uid=$(id -u "$username")
    find / -user "$uid" -not -path "/proc/*" -exec chown root:root {} \; 2>/dev/null || true
    info "Reassigned files to root"
  fi

  local cmd="userdel"
  $remove_home && cmd+=" -r"
  $cmd "$username"

  log "Deleted user: $username (remove_home=$remove_home)"
  info "User '$username' deleted"
}

# ── LIST ─────────────────────────────────────────────────

cmd_list() {
  local show_system=false json=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --all) show_system=true; shift ;;
      --json) json=true; shift ;;
      --help) echo "Usage: $SCRIPT_NAME list [--all] [--json]"; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  local min_uid=1000
  $show_system && min_uid=0

  printf "${BLUE}%-16s %-6s %-24s %-20s %-18s %-12s${NC}\n" \
    "USERNAME" "UID" "GROUPS" "SHELL" "LAST LOGIN" "PWD EXPIRES"
  echo "──────────────────────────────────────────────────────────────────────────────────────────────"

  while IFS=: read -r uname _ uid _ _ _ ushell; do
    [[ $uid -lt $min_uid && $uid -ne 0 ]] && continue

    local ugroups last_login pwd_expires
    ugroups=$(groups "$uname" 2>/dev/null | cut -d: -f2 | xargs | tr ' ' ',' || echo "N/A")
    last_login=$(lastlog -u "$uname" 2>/dev/null | tail -1 | awk '{if ($2 == "**Never") print "Never"; else print $4" "$5" "$6" "$9}' || echo "N/A")
    pwd_expires=$(chage -l "$uname" 2>/dev/null | grep "Password expires" | cut -d: -f2 | xargs || echo "N/A")

    # Truncate long fields
    [[ ${#ugroups} -gt 24 ]] && ugroups="${ugroups:0:21}..."
    [[ ${#last_login} -gt 18 ]] && last_login="${last_login:0:18}"

    printf "%-16s %-6s %-24s %-20s %-18s %-12s\n" \
      "$uname" "$uid" "$ugroups" "$ushell" "$last_login" "$pwd_expires"
  done < /etc/passwd
}

# ── SUDO ─────────────────────────────────────────────────

cmd_sudo() {
  local username="" grant=false revoke=false nopasswd=false list=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --username) username="$2"; shift 2 ;;
      --grant) grant=true; shift ;;
      --revoke) revoke=true; shift ;;
      --nopasswd) nopasswd=true; shift ;;
      --list) list=true; shift ;;
      --help) echo "Usage: $SCRIPT_NAME sudo --username <name> --grant|--revoke [--nopasswd] | --list"; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  if $list; then
    echo "Users with sudo access:"
    grep -Po '^[^#].*ALL.*' /etc/sudoers /etc/sudoers.d/* 2>/dev/null || true
    echo ""
    echo "Users in sudo/wheel group:"
    getent group sudo 2>/dev/null | cut -d: -f4 || \
    getent group wheel 2>/dev/null | cut -d: -f4 || echo "No sudo group found"
    return 0
  fi

  [[ -z "$username" ]] && { error "--username is required"; return 1; }
  ensure_root

  if ! user_exists "$username"; then
    error "User '$username' does not exist"
    return 1
  fi

  if $grant; then
    if $nopasswd; then
      echo "$username ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$username"
      chmod 440 "/etc/sudoers.d/$username"
      info "Granted passwordless sudo to '$username'"
    else
      # Add to sudo/wheel group
      if group_exists sudo; then
        usermod -aG sudo "$username"
      elif group_exists wheel; then
        usermod -aG wheel "$username"
      else
        echo "$username ALL=(ALL) ALL" > "/etc/sudoers.d/$username"
        chmod 440 "/etc/sudoers.d/$username"
      fi
      info "Granted sudo to '$username'"
    fi
    log "Sudo granted: $username (nopasswd=$nopasswd)"
  fi

  if $revoke; then
    # Remove from sudo/wheel group
    gpasswd -d "$username" sudo 2>/dev/null || true
    gpasswd -d "$username" wheel 2>/dev/null || true
    rm -f "/etc/sudoers.d/$username"
    info "Revoked sudo from '$username'"
    log "Sudo revoked: $username"
  fi
}

# ── SSH-KEY ──────────────────────────────────────────────

cmd_ssh_key() {
  local username="" add="" add_file="" remove="" list=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --username) username="$2"; shift 2 ;;
      --add) add="$2"; shift 2 ;;
      --add-file) add_file="$2"; shift 2 ;;
      --remove) remove="$2"; shift 2 ;;
      --list) list=true; shift ;;
      --help) echo "Usage: $SCRIPT_NAME ssh-key --username <name> --add <key>|--add-file <path>|--remove <comment>|--list"; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  [[ -z "$username" ]] && { error "--username is required"; return 1; }

  if ! user_exists "$username"; then
    error "User '$username' does not exist"
    return 1
  fi

  local ssh_dir auth_keys
  ssh_dir="$(eval echo ~"$username")/.ssh"
  auth_keys="$ssh_dir/authorized_keys"

  if $list; then
    if [[ -f "$auth_keys" ]]; then
      echo "SSH keys for $username:"
      cat "$auth_keys"
    else
      echo "No SSH keys found for $username"
    fi
    return 0
  fi

  ensure_root

  if [[ -n "$add" ]]; then
    mkdir -p "$ssh_dir"
    echo "$add" >> "$auth_keys"
    chmod 700 "$ssh_dir"
    chmod 600 "$auth_keys"
    chown -R "$username:$(id -gn "$username")" "$ssh_dir"
    info "SSH key added for '$username'"
    log "SSH key added: $username"
  fi

  if [[ -n "$add_file" ]]; then
    [[ ! -f "$add_file" ]] && { error "File not found: $add_file"; return 1; }
    mkdir -p "$ssh_dir"
    cat "$add_file" >> "$auth_keys"
    chmod 700 "$ssh_dir"
    chmod 600 "$auth_keys"
    chown -R "$username:$(id -gn "$username")" "$ssh_dir"
    info "SSH key added from file for '$username'"
    log "SSH key added from file: $username"
  fi

  if [[ -n "$remove" ]]; then
    if [[ -f "$auth_keys" ]]; then
      local count_before count_after
      count_before=$(wc -l < "$auth_keys")
      grep -v "$remove" "$auth_keys" > "${auth_keys}.tmp" || true
      mv "${auth_keys}.tmp" "$auth_keys"
      chmod 600 "$auth_keys"
      chown "$username:$(id -gn "$username")" "$auth_keys"
      count_after=$(wc -l < "$auth_keys")
      info "Removed $((count_before - count_after)) key(s) matching '$remove'"
      log "SSH key removed: $username (pattern: $remove)"
    else
      warn "No authorized_keys file found"
    fi
  fi
}

# ── PASSWORD ─────────────────────────────────────────────

cmd_password() {
  local username="" max_age="" min_age="" force_change=false lock=false unlock=false show_info=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --username) username="$2"; shift 2 ;;
      --max-age) max_age="$2"; shift 2 ;;
      --min-age) min_age="$2"; shift 2 ;;
      --force-change) force_change=true; shift ;;
      --lock) lock=true; shift ;;
      --unlock) unlock=true; shift ;;
      --info) show_info=true; shift ;;
      --help) echo "Usage: $SCRIPT_NAME password --username <name> [--max-age <days>] [--min-age <days>] [--force-change] [--lock] [--unlock] [--info]"; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  [[ -z "$username" ]] && { error "--username is required"; return 1; }

  if ! user_exists "$username"; then
    error "User '$username' does not exist"
    return 1
  fi

  if $show_info; then
    echo "Password Policy for $username:"
    chage -l "$username" | while IFS= read -r line; do
      echo "  $line"
    done
    echo ""
    local locked
    locked=$(passwd -S "$username" 2>/dev/null | awk '{print $2}')
    [[ "$locked" == "L" ]] && echo "  Account locked: Yes" || echo "  Account locked: No"
    return 0
  fi

  ensure_root

  [[ -n "$max_age" ]] && { chage -M "$max_age" "$username"; info "Max password age set to $max_age days"; }
  [[ -n "$min_age" ]] && { chage -m "$min_age" "$username"; info "Min password age set to $min_age days"; }
  $force_change && { chage -d 0 "$username"; info "Password change forced on next login"; }
  $lock && { passwd -l "$username" &>/dev/null; info "Account '$username' locked"; log "Account locked: $username"; }
  $unlock && { passwd -u "$username" &>/dev/null; info "Account '$username' unlocked"; log "Account unlocked: $username"; }
}

# ── GROUP ────────────────────────────────────────────────

cmd_group() {
  local create="" add_user="" to_group="" remove_user="" from_group="" members="" list=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --create) create="$2"; shift 2 ;;
      --add) add_user="$2"; shift 2 ;;
      --to) to_group="$2"; shift 2 ;;
      --remove) remove_user="$2"; shift 2 ;;
      --from) from_group="$2"; shift 2 ;;
      --members) members="$2"; shift 2 ;;
      --list) list=true; shift ;;
      --help) echo "Usage: $SCRIPT_NAME group --create <name> | --add <user> --to <group> | --remove <user> --from <group> | --members <group> | --list"; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  if $list; then
    echo "Groups with members:"
    while IFS=: read -r gname _ gid gmembers; do
      [[ -z "$gmembers" ]] && continue
      printf "  %-20s (GID: %-5s) → %s\n" "$gname" "$gid" "$gmembers"
    done < /etc/group
    return 0
  fi

  if [[ -n "$members" ]]; then
    if group_exists "$members"; then
      echo "Members of '$members':"
      getent group "$members" | cut -d: -f4 | tr ',' '\n' | while read -r m; do
        [[ -n "$m" ]] && echo "  - $m"
      done
    else
      error "Group '$members' does not exist"
      return 1
    fi
    return 0
  fi

  ensure_root

  if [[ -n "$create" ]]; then
    if group_exists "$create"; then
      warn "Group '$create' already exists"
    else
      groupadd "$create"
      info "Created group '$create'"
      log "Group created: $create"
    fi
  fi

  if [[ -n "$add_user" && -n "$to_group" ]]; then
    if ! group_exists "$to_group"; then
      groupadd "$to_group"
      info "Created group '$to_group'"
    fi
    usermod -aG "$to_group" "$add_user"
    info "Added '$add_user' to group '$to_group'"
    log "Group membership: $add_user added to $to_group"
  fi

  if [[ -n "$remove_user" && -n "$from_group" ]]; then
    gpasswd -d "$remove_user" "$from_group"
    info "Removed '$remove_user' from group '$from_group'"
    log "Group membership: $remove_user removed from $from_group"
  fi
}

# ── AUDIT ────────────────────────────────────────────────

cmd_audit() {
  local logins=false failed=false expiring="" inactive="" sudoers=false full=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --logins) logins=true; shift ;;
      --failed) failed=true; shift ;;
      --expiring) expiring="$2"; shift 2 ;;
      --inactive) inactive="$2"; shift 2 ;;
      --sudoers) sudoers=true; shift ;;
      --full) full=true; shift ;;
      --help) echo "Usage: $SCRIPT_NAME audit [--logins] [--failed] [--expiring <days>] [--inactive <days>] [--sudoers] [--full]"; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  if $logins; then
    echo "Recent login history:"
    last -20 2>/dev/null || echo "  'last' command not available"
    return 0
  fi

  if $failed; then
    echo "Failed login attempts:"
    lastb -20 2>/dev/null || { warn "'lastb' requires root"; return 1; }
    return 0
  fi

  if [[ -n "$expiring" ]]; then
    echo "Users with passwords expiring in the next $expiring days:"
    local today
    today=$(date +%s)
    while IFS=: read -r uname _ uid _ _ _ _; do
      [[ $uid -lt 1000 && $uid -ne 0 ]] && continue
      local exp_date
      exp_date=$(chage -l "$uname" 2>/dev/null | grep "Password expires" | cut -d: -f2 | xargs)
      [[ "$exp_date" == "never" || -z "$exp_date" ]] && continue
      local exp_ts
      exp_ts=$(date -d "$exp_date" +%s 2>/dev/null || continue)
      local days_left=$(( (exp_ts - today) / 86400 ))
      if [[ $days_left -ge 0 && $days_left -le $expiring ]]; then
        warn "$uname — expires $exp_date ($days_left days left)"
      fi
    done < /etc/passwd
    return 0
  fi

  if [[ -n "$inactive" ]]; then
    echo "Users with no login in $inactive+ days:"
    while IFS=: read -r uname _ uid _ _ _ _; do
      [[ $uid -lt 1000 && $uid -ne 0 ]] && continue
      local last_line
      last_line=$(lastlog -u "$uname" 2>/dev/null | tail -1)
      if echo "$last_line" | grep -q "Never logged in"; then
        warn "$uname — Never logged in"
      fi
    done < /etc/passwd
    return 0
  fi

  if $sudoers; then
    echo "Users with sudo access:"
    echo ""
    echo "Via sudo group:"
    getent group sudo 2>/dev/null | cut -d: -f4 | tr ',' '\n' | while read -r u; do
      [[ -n "$u" ]] && echo "  - $u"
    done
    echo ""
    echo "Via wheel group:"
    getent group wheel 2>/dev/null | cut -d: -f4 | tr ',' '\n' | while read -r u; do
      [[ -n "$u" ]] && echo "  - $u"
    done
    echo ""
    echo "Via sudoers.d:"
    ls /etc/sudoers.d/ 2>/dev/null | while read -r f; do
      [[ "$f" == "README" ]] && continue
      echo "  - $f"
    done
    return 0
  fi

  if $full; then
    echo "=== Linux User Security Audit ==="
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo ""

    local total_human=0 total_system=0 sudo_users=0 locked=0 no_pass=0 with_ssh=0
    local expiring_list="" inactive_list=""

    while IFS=: read -r uname _ uid _ _ uhome _; do
      if [[ $uid -ge 1000 || $uid -eq 0 ]]; then
        ((total_human++)) || true

        # Check sudo
        if groups "$uname" 2>/dev/null | grep -qE '\b(sudo|wheel)\b'; then
          ((sudo_users++)) || true
        elif [[ -f "/etc/sudoers.d/$uname" ]]; then
          ((sudo_users++)) || true
        fi

        # Check locked
        local pstatus
        pstatus=$(passwd -S "$uname" 2>/dev/null | awk '{print $2}' || echo "")
        [[ "$pstatus" == "L" ]] && ((locked++)) || true

        # Check SSH keys
        [[ -f "$uhome/.ssh/authorized_keys" ]] && ((with_ssh++)) || true

        # Check password expiry
        local exp_date
        exp_date=$(chage -l "$uname" 2>/dev/null | grep "Password expires" | cut -d: -f2 | xargs 2>/dev/null || echo "never")
        if [[ "$exp_date" != "never" && -n "$exp_date" ]]; then
          local exp_ts today_ts days_left
          exp_ts=$(date -d "$exp_date" +%s 2>/dev/null || echo 0)
          today_ts=$(date +%s)
          days_left=$(( (exp_ts - today_ts) / 86400 ))
          if [[ $days_left -ge 0 && $days_left -le 30 ]]; then
            expiring_list+="  ⚠️  $uname: Password expires in $days_left days ($exp_date)\n"
          fi
        fi
      else
        ((total_system++)) || true
      fi
    done < /etc/passwd

    echo "TOTAL USERS: $((total_human + total_system)) ($total_human human, $total_system system)"
    echo "SUDO USERS: $sudo_users"
    echo "LOCKED ACCOUNTS: $locked"
    echo "USERS WITH SSH KEYS: $with_ssh"
    echo ""

    if [[ -n "$expiring_list" ]]; then
      echo "EXPIRING PASSWORDS (next 30 days):"
      echo -e "$expiring_list"
    else
      echo "✅ No passwords expiring in the next 30 days"
    fi

    echo ""
    echo "RECOMMENDATIONS:"

    # Check for users with no password
    while IFS=: read -r uname pwhash _; do
      if [[ "$pwhash" == "" || "$pwhash" == "!" || "$pwhash" == "*" ]]; then
        continue  # System accounts or locked
      fi
    done < /etc/shadow 2>/dev/null || true

    echo "✅ Audit complete"
    return 0
  fi

  # Default: show summary
  echo "Usage: $SCRIPT_NAME audit [--logins] [--failed] [--expiring <days>] [--inactive <days>] [--sudoers] [--full]"
}

# ── MODIFY ───────────────────────────────────────────────

cmd_modify() {
  local username="" add_groups="" remove_groups="" shell="" fullname=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --username) username="$2"; shift 2 ;;
      --add-groups) add_groups="$2"; shift 2 ;;
      --remove-groups) remove_groups="$2"; shift 2 ;;
      --shell) shell="$2"; shift 2 ;;
      --fullname) fullname="$2"; shift 2 ;;
      --help) echo "Usage: $SCRIPT_NAME modify --username <name> [--add-groups <g1,g2>] [--remove-groups <g1,g2>] [--shell <path>] [--fullname <name>]"; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  [[ -z "$username" ]] && { error "--username is required"; return 1; }
  ensure_root

  if ! user_exists "$username"; then
    error "User '$username' does not exist"
    return 1
  fi

  if [[ -n "$add_groups" ]]; then
    IFS=',' read -ra GROUP_LIST <<< "$add_groups"
    for g in "${GROUP_LIST[@]}"; do
      group_exists "$g" || groupadd "$g"
    done
    usermod -aG "$add_groups" "$username"
    info "Added '$username' to groups: $add_groups"
  fi

  if [[ -n "$remove_groups" ]]; then
    IFS=',' read -ra GROUP_LIST <<< "$remove_groups"
    for g in "${GROUP_LIST[@]}"; do
      gpasswd -d "$username" "$g" 2>/dev/null || true
    done
    info "Removed '$username' from groups: $remove_groups"
  fi

  [[ -n "$shell" ]] && { usermod -s "$shell" "$username"; info "Shell changed to $shell"; }
  [[ -n "$fullname" ]] && { usermod -c "$fullname" "$username"; info "Full name set to '$fullname'"; }
}

# ── BULK CREATE ──────────────────────────────────────────

cmd_bulk_create() {
  local file=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --file) file="$2"; shift 2 ;;
      --help) echo "Usage: $SCRIPT_NAME bulk-create --file <csv>"; echo "CSV format: username,fullname,shell,groups,ssh_key"; return 0 ;;
      *) error "Unknown option: $1"; return 1 ;;
    esac
  done

  [[ -z "$file" ]] && { error "--file is required"; return 1; }
  [[ ! -f "$file" ]] && { error "File not found: $file"; return 1; }
  ensure_root

  local count=0
  while IFS=, read -r username fullname shell groups ssh_key; do
    [[ "$username" =~ ^#.*$ || -z "$username" ]] && continue
    groups="${groups//;/,}"  # Allow semicolons as group separator

    local args=(--username "$username")
    [[ -n "$fullname" ]] && args+=(--fullname "$fullname")
    [[ -n "$shell" ]] && args+=(--shell "$shell")
    [[ -n "$groups" ]] && args+=(--groups "$groups")
    [[ -n "$ssh_key" ]] && args+=(--ssh-key "$ssh_key")

    echo "Creating user: $username..."
    cmd_create "${args[@]}" || warn "Failed to create '$username'"
    ((count++)) || true
    echo ""
  done < "$file"

  info "Processed $count users from $file"
}

# ── MAIN ─────────────────────────────────────────────────

main() {
  [[ $# -eq 0 ]] && { usage; exit 0; }

  local command="$1"
  shift

  case "$command" in
    create)      cmd_create "$@" ;;
    delete)      cmd_delete "$@" ;;
    modify)      cmd_modify "$@" ;;
    list)        cmd_list "$@" ;;
    sudo)        cmd_sudo "$@" ;;
    ssh-key)     cmd_ssh_key "$@" ;;
    password)    cmd_password "$@" ;;
    group)       cmd_group "$@" ;;
    audit)       cmd_audit "$@" ;;
    bulk-create) cmd_bulk_create "$@" ;;
    --help|-h)   usage ;;
    *)           error "Unknown command: $command"; usage; exit 1 ;;
  esac
}

main "$@"
