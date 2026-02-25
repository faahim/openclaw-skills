#!/bin/bash
# Ansible Playbook Runner — Inventory Manager
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INV_FILE="${ANSIBLE_INVENTORY:-$SCRIPT_DIR/inventory.ini}"

# Ensure inventory exists
if [ ! -f "$INV_FILE" ]; then
  echo "[all]" > "$INV_FILE"
fi

usage() {
  echo "Usage:"
  echo "  $0 add <name> <host> [--user USER] [--port PORT] [--key KEY] [--group GROUP]"
  echo "  $0 remove <name>"
  echo "  $0 group <groupname> <host1,host2,...>"
  echo "  $0 list"
  echo ""
  echo "Examples:"
  echo "  $0 add web1 10.0.0.1 --user deploy --key ~/.ssh/id_ed25519"
  echo "  $0 add db1 10.0.0.2 --user root --group databases"
  echo "  $0 group webservers web1,web2"
  echo "  $0 list"
}

cmd_add() {
  local name="$1"
  local host="$2"
  shift 2

  local user="" port="" key="" group="all"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --user) user="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --key) key="$2"; shift 2 ;;
      --group) group="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  # Build host line
  local line="$name ansible_host=$host"
  [ -n "$user" ] && line="$line ansible_user=$user"
  [ -n "$port" ] && line="$line ansible_port=$port"
  [ -n "$key" ] && line="$line ansible_ssh_private_key_file=$key"

  # Remove existing entry for this name
  sed -i "/^${name} /d" "$INV_FILE"

  # Ensure group exists
  if ! grep -q "^\[$group\]" "$INV_FILE"; then
    echo "" >> "$INV_FILE"
    echo "[$group]" >> "$INV_FILE"
  fi

  # Add host under group
  sed -i "/^\[$group\]/a $line" "$INV_FILE"

  echo "✅ Added $name ($host) to [$group]"
}

cmd_remove() {
  local name="$1"
  if grep -q "^${name} " "$INV_FILE"; then
    sed -i "/^${name} /d" "$INV_FILE"
    echo "✅ Removed $name"
  else
    echo "⚠️  Host $name not found"
  fi
}

cmd_group() {
  local groupname="$1"
  local hosts="$2"

  if ! grep -q "^\[$groupname\]" "$INV_FILE"; then
    echo "" >> "$INV_FILE"
    echo "[$groupname]" >> "$INV_FILE"
  fi

  IFS=',' read -ra HOST_ARRAY <<< "$hosts"
  for h in "${HOST_ARRAY[@]}"; do
    # Check if host exists in inventory
    if grep -q "^${h} " "$INV_FILE"; then
      # Add host reference under group if not already there
      if ! sed -n "/^\[$groupname\]/,/^\[/p" "$INV_FILE" | grep -q "^${h}$"; then
        sed -i "/^\[$groupname\]/a $h" "$INV_FILE"
        echo "✅ Added $h to [$groupname]"
      else
        echo "ℹ️  $h already in [$groupname]"
      fi
    else
      echo "⚠️  Host $h not found in inventory. Add it first."
    fi
  done
}

cmd_list() {
  echo "📋 Inventory: $INV_FILE"
  echo "---"
  cat "$INV_FILE"
  echo "---"
  local count=$(grep -c "ansible_host=" "$INV_FILE" 2>/dev/null || echo 0)
  echo "Total hosts: $count"
}

# Main
case "${1:-}" in
  add)
    shift
    if [ $# -lt 2 ]; then usage; exit 1; fi
    cmd_add "$@"
    ;;
  remove)
    shift
    if [ $# -lt 1 ]; then usage; exit 1; fi
    cmd_remove "$@"
    ;;
  group)
    shift
    if [ $# -lt 2 ]; then usage; exit 1; fi
    cmd_group "$@"
    ;;
  list)
    cmd_list
    ;;
  *)
    usage
    ;;
esac
