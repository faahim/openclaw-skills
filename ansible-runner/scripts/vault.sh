#!/bin/bash
# Ansible Playbook Runner — Vault Manager
set -e

if ! command -v ansible-vault &>/dev/null; then
  echo "❌ ansible-vault not found. Run: bash scripts/install.sh"
  exit 1
fi

usage() {
  echo "Usage:"
  echo "  $0 encrypt <file>"
  echo "  $0 decrypt <file>"
  echo "  $0 edit <file>"
  echo "  $0 view <file>"
  echo "  $0 create <file>"
}

VAULT_ARGS=""
if [ -n "$ANSIBLE_VAULT_PASSWORD" ]; then
  TMPFILE=$(mktemp)
  echo "$ANSIBLE_VAULT_PASSWORD" > "$TMPFILE"
  VAULT_ARGS="--vault-password-file $TMPFILE"
  trap "rm -f $TMPFILE" EXIT
fi

case "${1:-}" in
  encrypt)
    ansible-vault encrypt "$2" $VAULT_ARGS
    echo "✅ Encrypted: $2"
    ;;
  decrypt)
    ansible-vault decrypt "$2" $VAULT_ARGS
    echo "✅ Decrypted: $2"
    ;;
  edit)
    ansible-vault edit "$2" $VAULT_ARGS
    ;;
  view)
    ansible-vault view "$2" $VAULT_ARGS
    ;;
  create)
    ansible-vault create "$2" $VAULT_ARGS
    echo "✅ Created encrypted file: $2"
    ;;
  *)
    usage
    ;;
esac
