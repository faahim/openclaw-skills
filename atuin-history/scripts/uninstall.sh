#!/bin/bash
# Uninstall Atuin
set -e

echo "🗑️  Atuin Uninstaller"
echo ""

# Stop daemon if running
systemctl --user stop atuin-daemon 2>/dev/null || true
systemctl --user disable atuin-daemon 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/atuin-daemon.service" 2>/dev/null

# Remove shell integration
for RC in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish"; do
    if [[ -f "$RC" ]]; then
        if grep -q "atuin" "$RC"; then
            sed -i '/# Atuin shell history/d' "$RC"
            sed -i '/atuin init/d' "$RC"
            sed -i '/bash-preexec/d' "$RC"
            echo "✅ Removed Atuin from $RC"
        fi
    fi
done

# Remove binary
ATUIN_BIN=$(which atuin 2>/dev/null || true)
if [[ -n "$ATUIN_BIN" ]]; then
    echo "Removing binary: $ATUIN_BIN"
    rm -f "$ATUIN_BIN" 2>/dev/null || sudo rm -f "$ATUIN_BIN"
    echo "✅ Binary removed"
fi

# Remove config
if [[ -d "$HOME/.config/atuin" ]]; then
    rm -rf "$HOME/.config/atuin"
    echo "✅ Config removed"
fi

# Ask about history database
if [[ -d "$HOME/.local/share/atuin" ]]; then
    echo ""
    echo "⚠️  History database found at ~/.local/share/atuin/"
    read -p "Delete history database? (y/N): " REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/.local/share/atuin"
        echo "✅ History database deleted"
    else
        echo "📁 History database kept at ~/.local/share/atuin/"
    fi
fi

echo ""
echo "✅ Atuin uninstalled. Restart your shell: exec \$SHELL"
