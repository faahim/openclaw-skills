#!/bin/bash
# Radicale User Management
set -e

USERS_FILE="${RADICALE_CONFIG_DIR:-$HOME/.config/radicale}/users"

usage() {
  echo "Usage: bash manage-users.sh <command> [args]"
  echo ""
  echo "Commands:"
  echo "  add <username> <password>     Add a new user"
  echo "  remove <username>             Remove a user"
  echo "  passwd <username> <password>  Change password"
  echo "  list                          List all users"
  exit 1
}

ensure_file() {
  if [ ! -f "$USERS_FILE" ]; then
    mkdir -p "$(dirname "$USERS_FILE")"
    touch "$USERS_FILE"
    chmod 600 "$USERS_FILE"
  fi
}

add_user() {
  local user="$1" pass="$2"
  [ -z "$user" ] || [ -z "$pass" ] && { echo "❌ Usage: add <username> <password>"; exit 1; }
  ensure_file

  if grep -q "^${user}:" "$USERS_FILE" 2>/dev/null; then
    echo "❌ User '$user' already exists. Use 'passwd' to change password."
    exit 1
  fi

  HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw('${pass}'.encode(), bcrypt.gensalt()).decode())")
  echo "${user}:${HASH}" >> "$USERS_FILE"
  echo "✅ User '$user' added"
}

remove_user() {
  local user="$1"
  [ -z "$user" ] && { echo "❌ Usage: remove <username>"; exit 1; }
  ensure_file

  if ! grep -q "^${user}:" "$USERS_FILE" 2>/dev/null; then
    echo "❌ User '$user' not found"
    exit 1
  fi

  sed -i "/^${user}:/d" "$USERS_FILE"
  echo "✅ User '$user' removed"
}

change_password() {
  local user="$1" pass="$2"
  [ -z "$user" ] || [ -z "$pass" ] && { echo "❌ Usage: passwd <username> <password>"; exit 1; }
  ensure_file

  if ! grep -q "^${user}:" "$USERS_FILE" 2>/dev/null; then
    echo "❌ User '$user' not found"
    exit 1
  fi

  HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw('${pass}'.encode(), bcrypt.gensalt()).decode())")
  sed -i "s|^${user}:.*|${user}:${HASH}|" "$USERS_FILE"
  echo "✅ Password updated for '$user'"
}

list_users() {
  ensure_file
  if [ ! -s "$USERS_FILE" ]; then
    echo "No users configured. Add one with: bash manage-users.sh add <username> <password>"
    exit 0
  fi
  echo "Configured users:"
  awk -F: '{print "  • " $1}' "$USERS_FILE"
  echo ""
  echo "Total: $(wc -l < "$USERS_FILE") user(s)"
}

# Main
case "${1:-}" in
  add) add_user "$2" "$3" ;;
  remove) remove_user "$2" ;;
  passwd) change_password "$2" "$3" ;;
  list) list_users ;;
  *) usage ;;
esac
