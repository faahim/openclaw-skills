#!/bin/bash
# Set up Atuin sync (register or login)
set -e

if ! command -v atuin &>/dev/null; then
    echo "❌ Atuin not found. Run install.sh first."
    exit 1
fi

echo "🔄 Atuin Sync Setup"
echo ""
echo "Options:"
echo "  1. Register new account (Atuin cloud — free)"
echo "  2. Login to existing account"
echo "  3. Use self-hosted server"
echo ""
read -p "Choose (1/2/3): " CHOICE

case "$CHOICE" in
    1)
        echo ""
        echo "📝 Registering new Atuin account..."
        echo "   Your history is E2E encrypted — the server cannot read it."
        echo ""
        atuin register
        echo ""
        echo "✅ Registered! Sync is now active."
        echo "⚠️  IMPORTANT: Back up your encryption key!"
        echo "   cat ~/.local/share/atuin/key"
        echo "   Store this key safely — you need it to sync on other machines."
        ;;
    2)
        echo ""
        atuin login
        echo ""
        echo "✅ Logged in! Running initial sync..."
        atuin sync
        ;;
    3)
        echo ""
        read -p "Enter your server URL (e.g. https://atuin.yourdomain.com): " SERVER_URL
        if [[ -z "$SERVER_URL" ]]; then
            echo "❌ No URL provided."
            exit 1
        fi

        # Update config
        CONFDIR="${XDG_CONFIG_HOME:-$HOME/.config}/atuin"
        mkdir -p "$CONFDIR"
        CONF="$CONFDIR/config.toml"

        if [[ -f "$CONF" ]]; then
            # Replace or add sync_address
            if grep -q "^sync_address" "$CONF"; then
                sed -i "s|^sync_address.*|sync_address = \"$SERVER_URL\"|" "$CONF"
            else
                echo "sync_address = \"$SERVER_URL\"" >> "$CONF"
            fi
        else
            echo "sync_address = \"$SERVER_URL\"" > "$CONF"
        fi

        echo "✅ Server set to: $SERVER_URL"
        echo ""
        echo "Now register or login:"
        echo "  atuin register  (new account)"
        echo "  atuin login     (existing account)"
        ;;
    *)
        echo "Invalid choice."
        exit 1
        ;;
esac
