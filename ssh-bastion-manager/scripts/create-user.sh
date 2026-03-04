#!/usr/bin/env bash
set -euo pipefail

USER_NAME=""
PUBKEY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) USER_NAME="$2"; shift 2;;
    --pubkey) PUBKEY_FILE="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

if [[ -z "$USER_NAME" || -z "$PUBKEY_FILE" ]]; then
  echo "Usage: sudo bash scripts/create-user.sh --user <name> --pubkey <file>" >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

id "$USER_NAME" >/dev/null 2>&1 || useradd -m -s /bin/bash "$USER_NAME"
install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"
install -m 600 -o "$USER_NAME" -g "$USER_NAME" "$PUBKEY_FILE" "/home/$USER_NAME/.ssh/authorized_keys"

usermod -aG sudo "$USER_NAME" || true

echo "User $USER_NAME provisioned with SSH key auth"
