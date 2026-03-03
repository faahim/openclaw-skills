#!/bin/bash
# Cockpit Web Console — Multi-Machine Manager

set -euo pipefail

ACTION="${1:-list}"
shift 2>/dev/null || true

MACHINES_FILE="/etc/cockpit/machines.d/99-agents.json"

ensure_machines_dir() {
  sudo mkdir -p /etc/cockpit/machines.d
  if [ ! -f "$MACHINES_FILE" ]; then
    echo '{}' | sudo tee "$MACHINES_FILE" > /dev/null
  fi
}

case "$ACTION" in
  list)
    echo "Connected Machines"
    echo "══════════════════"
    
    ensure_machines_dir
    
    if ! command -v jq &>/dev/null; then
      echo "⚠️ jq required for machine management. Install: sudo apt install jq"
      exit 1
    fi
    
    # Always show localhost
    echo "  ✅ localhost (this machine)"
    
    # Show configured remotes
    jq -r 'to_entries[] | "  \(.value.visible // true | if . then "✅" else "⬜" end) \(.key) — \(.value.address) (user: \(.value.user // "default"))"' "$MACHINES_FILE" 2>/dev/null || true
    ;;

  add)
    NAME="${1:-}"
    ADDRESS="${2:-}"
    USER=""
    
    shift 2 2>/dev/null || true
    while [[ $# -gt 0 ]]; do
      case $1 in
        --user) USER=$2; shift 2 ;;
        *) shift ;;
      esac
    done

    if [ -z "$NAME" ] || [ -z "$ADDRESS" ]; then
      echo "Usage: machines.sh add <name> <address> [--user username]"
      exit 1
    fi

    ensure_machines_dir
    
    if ! command -v jq &>/dev/null; then
      echo "⚠️ jq required. Install: sudo apt install jq"
      exit 1
    fi

    ENTRY=$(jq -n --arg addr "$ADDRESS" --arg user "$USER" '{
      address: $addr,
      visible: true,
      color: null
    } + (if $user != "" then {user: $user} else {} end)')

    jq --arg name "$NAME" --argjson entry "$ENTRY" '. + {($name): $entry}' "$MACHINES_FILE" | sudo tee "${MACHINES_FILE}.tmp" > /dev/null
    sudo mv "${MACHINES_FILE}.tmp" "$MACHINES_FILE"

    echo "✅ Added machine: $NAME ($ADDRESS)"
    echo ""
    echo "⚠️  Ensure SSH key access is set up:"
    echo "   ssh-copy-id ${USER:+${USER}@}${ADDRESS}"
    echo ""
    echo "   Then install cockpit on the remote:"
    echo "   ssh ${USER:+${USER}@}${ADDRESS} 'sudo apt install cockpit -y && sudo systemctl enable cockpit.socket'"
    ;;

  remove)
    NAME="${1:-}"
    if [ -z "$NAME" ]; then
      echo "Usage: machines.sh remove <name>"
      exit 1
    fi

    ensure_machines_dir
    jq --arg name "$NAME" 'del(.[$name])' "$MACHINES_FILE" | sudo tee "${MACHINES_FILE}.tmp" > /dev/null
    sudo mv "${MACHINES_FILE}.tmp" "$MACHINES_FILE"

    echo "✅ Removed machine: $NAME"
    ;;

  *)
    echo "Usage: machines.sh <list|add|remove>"
    echo ""
    echo "Examples:"
    echo "  machines.sh list"
    echo "  machines.sh add web-server 192.168.1.100 --user admin"
    echo "  machines.sh remove web-server"
    exit 1
    ;;
esac
