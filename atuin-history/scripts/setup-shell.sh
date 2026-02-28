#!/bin/bash
# Set up Atuin shell integration
set -e

SHELL_NAME="${1:-$(basename $SHELL)}"

if ! command -v atuin &>/dev/null; then
    echo "❌ Atuin not found. Run install.sh first."
    exit 1
fi

setup_bash() {
    local RC="$HOME/.bashrc"
    local SNIPPET='[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
eval "$(atuin init bash)"'

    if grep -q "atuin init bash" "$RC" 2>/dev/null; then
        echo "✅ Atuin already configured in $RC"
        return
    fi

    # Install bash-preexec if needed
    if [[ ! -f "$HOME/.bash-preexec.sh" ]]; then
        echo "📦 Installing bash-preexec..."
        curl -fsSL https://raw.githubusercontent.com/rcaloras/bash-preexec/master/bash-preexec.sh -o "$HOME/.bash-preexec.sh"
    fi

    echo "" >> "$RC"
    echo "# Atuin shell history" >> "$RC"
    echo "$SNIPPET" >> "$RC"
    echo "✅ Added Atuin to $RC"
}

setup_zsh() {
    local RC="$HOME/.zshrc"
    local SNIPPET='eval "$(atuin init zsh)"'

    if grep -q "atuin init zsh" "$RC" 2>/dev/null; then
        echo "✅ Atuin already configured in $RC"
        return
    fi

    echo "" >> "$RC"
    echo "# Atuin shell history" >> "$RC"
    echo "$SNIPPET" >> "$RC"
    echo "✅ Added Atuin to $RC"
}

setup_fish() {
    local RC="$HOME/.config/fish/config.fish"
    local SNIPPET='atuin init fish | source'

    mkdir -p "$(dirname "$RC")"

    if grep -q "atuin init fish" "$RC" 2>/dev/null; then
        echo "✅ Atuin already configured in $RC"
        return
    fi

    echo "" >> "$RC"
    echo "# Atuin shell history" >> "$RC"
    echo "$SNIPPET" >> "$RC"
    echo "✅ Added Atuin to $RC"
}

case "$SHELL_NAME" in
    bash) setup_bash ;;
    zsh)  setup_zsh ;;
    fish) setup_fish ;;
    *)
        echo "❌ Unsupported shell: $SHELL_NAME"
        echo "Supported: bash, zsh, fish"
        exit 1
        ;;
esac

echo ""
echo "🔄 Reload your shell to activate:"
echo "   exec \$SHELL"
