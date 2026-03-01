#!/bin/bash
# Postfix SMTP Relay — Uninstall

set -euo pipefail

PURGE=false
[[ "${1:-}" == "--purge" ]] && PURGE=true

SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

echo "🗑️  Removing Postfix SMTP Relay configuration..."

# Remove SASL credentials
$SUDO rm -f /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
echo "✅ Removed SASL credentials"

# Remove sender canonical
$SUDO rm -f /etc/postfix/sender_canonical
echo "✅ Removed sender canonical maps"

# Restore backup if exists
LATEST_BACKUP=$(ls -t /etc/postfix/main.cf.bak.* 2>/dev/null | head -1)
if [[ -n "$LATEST_BACKUP" ]]; then
    $SUDO cp "$LATEST_BACKUP" /etc/postfix/main.cf
    echo "✅ Restored config from $LATEST_BACKUP"
else
    # Just strip our additions
    $SUDO sed -i '/# SMTP Relay Config/,/^$/d' /etc/postfix/main.cf
    echo "✅ Removed relay config from main.cf"
fi

$SUDO systemctl reload postfix 2>/dev/null || true

if [[ "$PURGE" == true ]]; then
    echo "Purging postfix package..."
    if command -v apt-get &>/dev/null; then
        $SUDO apt-get purge -y postfix libsasl2-modules 2>/dev/null
    elif command -v dnf &>/dev/null; then
        $SUDO dnf remove -y postfix cyrus-sasl-plain 2>/dev/null
    fi
    echo "✅ Postfix purged"
fi

echo "🎉 Uninstall complete"
