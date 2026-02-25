#!/bin/bash
set -euo pipefail

# Authelia User Management Script
# Add, remove, list, and reset passwords for Authelia users

USERS_DB="authelia-data/users_database.yml"
ACTION=""
USERNAME=""
EMAIL=""
GROUPS=""
DISPLAY_NAME=""

usage() {
  cat <<EOF
Usage: bash scripts/manage-users.sh <action> [options]

Actions:
  add               Add a new user
  remove            Remove a user
  list              List all users
  reset-password    Reset a user's password

Options:
  --username <name>   Username (required for add/remove/reset-password)
  --email <email>     Email (required for add)
  --groups <groups>   Comma-separated groups (optional, e.g., admins,devs)
  --display <name>    Display name (optional)
  --db <path>         Users database path (default: authelia-data/users_database.yml)
  -h, --help          Show this help
EOF
  exit 1
}

hash_password() {
  local password="$1"
  # Try using docker to hash with argon2id (Authelia's format)
  if command -v docker &>/dev/null; then
    docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "$password" 2>/dev/null | grep "Digest:" | awk '{print $2}'
  elif command -v argon2 &>/dev/null; then
    # Fallback to local argon2
    local salt=$(openssl rand -hex 16)
    echo -n "$password" | argon2 "$salt" -id -t 3 -m 16 -p 4 -l 32 -e
  else
    echo "Error: Need docker or argon2 CLI to hash passwords" >&2
    exit 1
  fi
}

if [[ $# -lt 1 ]]; then usage; fi

ACTION="$1"; shift

while [[ $# -gt 0 ]]; do
  case $1 in
    --username) USERNAME="$2"; shift 2 ;;
    --email) EMAIL="$2"; shift 2 ;;
    --groups) GROUPS="$2"; shift 2 ;;
    --display) DISPLAY_NAME="$2"; shift 2 ;;
    --db) USERS_DB="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

case "$ACTION" in
  add)
    if [[ -z "$USERNAME" || -z "$EMAIL" ]]; then
      echo "Error: --username and --email required for add"
      exit 1
    fi

    # Check if user exists
    if grep -q "^  $USERNAME:" "$USERS_DB" 2>/dev/null; then
      echo "Error: User '$USERNAME' already exists"
      exit 1
    fi

    # Prompt for password
    echo -n "Enter password for $USERNAME: "
    read -s PASSWORD
    echo
    echo -n "Confirm password: "
    read -s PASSWORD2
    echo

    if [[ "$PASSWORD" != "$PASSWORD2" ]]; then
      echo "Error: Passwords don't match"
      exit 1
    fi

    if [[ ${#PASSWORD} -lt 8 ]]; then
      echo "Error: Password must be at least 8 characters"
      exit 1
    fi

    echo "🔐 Hashing password (this may take a moment)..."
    HASHED=$(hash_password "$PASSWORD")

    if [[ -z "$HASHED" ]]; then
      echo "Error: Failed to hash password"
      exit 1
    fi

    DISPLAY="${DISPLAY_NAME:-$USERNAME}"

    # Build groups array
    GROUPS_YAML=""
    if [[ -n "$GROUPS" ]]; then
      GROUPS_YAML="    groups:"
      IFS=',' read -ra GROUP_ARRAY <<< "$GROUPS"
      for g in "${GROUP_ARRAY[@]}"; do
        GROUPS_YAML="$GROUPS_YAML
      - $(echo "$g" | xargs)"
      done
    else
      GROUPS_YAML="    groups: []"
    fi

    # Append user to database
    # Remove trailing "users: {}" if empty
    if grep -q "^users: {}$" "$USERS_DB"; then
      sed -i 's/^users: {}$/users:/' "$USERS_DB"
    fi

    cat >> "$USERS_DB" <<YAML
  $USERNAME:
    disabled: false
    displayname: "$DISPLAY"
    password: "$HASHED"
    email: $EMAIL
$GROUPS_YAML
YAML

    echo "✅ User '$USERNAME' added successfully"
    echo "   Email: $EMAIL"
    [[ -n "$GROUPS" ]] && echo "   Groups: $GROUPS"
    ;;

  remove)
    if [[ -z "$USERNAME" ]]; then
      echo "Error: --username required for remove"
      exit 1
    fi

    if ! grep -q "^  $USERNAME:" "$USERS_DB" 2>/dev/null; then
      echo "Error: User '$USERNAME' not found"
      exit 1
    fi

    # Remove user block (from username line to next user or end)
    sed -i "/^  $USERNAME:/,/^  [a-zA-Z]/{/^  [a-zA-Z]/!d}" "$USERS_DB"
    sed -i "/^  $USERNAME:/d" "$USERS_DB"

    echo "✅ User '$USERNAME' removed"
    ;;

  list)
    echo "📋 Authelia Users:"
    echo "---"
    if grep -q "^users: {}$" "$USERS_DB" 2>/dev/null; then
      echo "(no users)"
    else
      grep -E "^  [a-zA-Z]|displayname|email|groups|disabled" "$USERS_DB" | \
        sed 's/^  //' | sed 's/:$//'
    fi
    ;;

  reset-password)
    if [[ -z "$USERNAME" ]]; then
      echo "Error: --username required for reset-password"
      exit 1
    fi

    if ! grep -q "^  $USERNAME:" "$USERS_DB" 2>/dev/null; then
      echo "Error: User '$USERNAME' not found"
      exit 1
    fi

    echo -n "Enter new password for $USERNAME: "
    read -s PASSWORD
    echo
    echo -n "Confirm password: "
    read -s PASSWORD2
    echo

    if [[ "$PASSWORD" != "$PASSWORD2" ]]; then
      echo "Error: Passwords don't match"
      exit 1
    fi

    echo "🔐 Hashing password..."
    HASHED=$(hash_password "$PASSWORD")

    # Replace password line
    sed -i "/^  $USERNAME:/,/^  [a-zA-Z]/{s|password: \".*\"|password: \"$HASHED\"|}" "$USERS_DB"

    echo "✅ Password reset for '$USERNAME'"
    echo "⚠️  User will need to re-register TOTP if 2FA was enabled"
    ;;

  *)
    echo "Unknown action: $ACTION"
    usage
    ;;
esac
