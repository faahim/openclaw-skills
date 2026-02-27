#!/bin/bash
# Manage Mosquitto MQTT broker users
set -euo pipefail

PASSWD_FILE="/etc/mosquitto/passwd"
ACTION="${1:-help}"
USERNAME="${2:-}"
PASSWORD="${3:-}"

case "$ACTION" in
  add)
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
      echo "Usage: $0 add <username> <password>"
      exit 1
    fi
    if [ ! -f "$PASSWD_FILE" ]; then
      sudo mosquitto_passwd -c -b "$PASSWD_FILE" "$USERNAME" "$PASSWORD"
    else
      sudo mosquitto_passwd -b "$PASSWD_FILE" "$USERNAME" "$PASSWORD"
    fi
    echo "✅ User '$USERNAME' added/updated"
    echo "   Restart broker: sudo systemctl restart mosquitto"
    ;;

  delete|remove)
    if [ -z "$USERNAME" ]; then
      echo "Usage: $0 delete <username>"
      exit 1
    fi
    sudo mosquitto_passwd -D "$PASSWD_FILE" "$USERNAME"
    echo "✅ User '$USERNAME' removed"
    echo "   Restart broker: sudo systemctl restart mosquitto"
    ;;

  list)
    if [ ! -f "$PASSWD_FILE" ]; then
      echo "No password file found. No users configured."
      exit 0
    fi
    echo "📋 Configured users:"
    sudo cut -d: -f1 "$PASSWD_FILE" | sort
    ;;

  help|*)
    echo "Mosquitto User Manager"
    echo ""
    echo "Usage:"
    echo "  $0 add <username> <password>   — Add or update a user"
    echo "  $0 delete <username>            — Remove a user"
    echo "  $0 list                         — List all users"
    ;;
esac
