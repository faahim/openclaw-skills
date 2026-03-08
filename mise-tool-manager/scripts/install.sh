#!/bin/bash
# Mise Tool Manager — Install & Configure
set -euo pipefail

SHELL_NAME="${SHELL##*/}"
MISE_BIN="$HOME/.local/bin/mise"

echo "🔧 Mise Tool Manager — Install & Configure"
echo "============================================"
echo ""

# Check if already installed
if command -v mise &>/dev/null; then
    CURRENT_VERSION=$(mise --version 2>/dev/null | head -1)
    echo "✅ Mise already installed: $CURRENT_VERSION"
    echo ""
    read -rp "Upgrade to latest? [y/N] " UPGRADE
    if [[ "${UPGRADE,,}" == "y" ]]; then
        echo "⬆️  Upgrading mise..."
        mise self-update 2>/dev/null || curl https://mise.run | sh
        echo "✅ Upgraded to $(mise --version | head -1)"
    fi
else
    echo "📦 Installing mise..."
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
    echo "✅ Installed mise $(mise --version | head -1)"
fi

echo ""

# Configure shell integration
configure_shell() {
    local shell_name="$1"
    local rc_file=""
    local activate_cmd=""

    case "$shell_name" in
        bash)
            rc_file="$HOME/.bashrc"
            activate_cmd='eval "$(~/.local/bin/mise activate bash)"'
            ;;
        zsh)
            rc_file="$HOME/.zshrc"
            activate_cmd='eval "$(~/.local/bin/mise activate zsh)"'
            ;;
        fish)
            rc_file="$HOME/.config/fish/config.fish"
            activate_cmd='~/.local/bin/mise activate fish | source'
            ;;
        *)
            echo "⚠️  Unsupported shell: $shell_name"
            echo "   Add manually: eval \"\$(mise activate $shell_name)\""
            return 1
            ;;
    esac

    if [ -f "$rc_file" ] && grep -q "mise activate" "$rc_file" 2>/dev/null; then
        echo "✅ Shell integration already configured in $rc_file"
    else
        echo "$activate_cmd" >> "$rc_file"
        echo "✅ Added mise activation to $rc_file"
    fi
}

echo "🐚 Configuring shell integration for $SHELL_NAME..."
configure_shell "$SHELL_NAME"

echo ""

# Create global config if missing
MISE_CONFIG="$HOME/.config/mise/config.toml"
if [ ! -f "$MISE_CONFIG" ]; then
    mkdir -p "$(dirname "$MISE_CONFIG")"
    cat > "$MISE_CONFIG" << 'EOF'
# Mise Global Configuration
# Docs: https://mise.jdx.dev/configuration.html

[settings]
# Read .nvmrc, .python-version, .ruby-version files
legacy_version_file = true
# Auto-install missing tools when entering a directory
auto_install = true
# Show status message when switching versions
status.missing_tools = "always"
status.show_env = false

[tools]
# Uncomment to set global defaults:
# node = "lts"
# python = "3.12"
# go = "latest"
EOF
    echo "✅ Created global config at $MISE_CONFIG"
else
    echo "✅ Global config exists at $MISE_CONFIG"
fi

echo ""

# Run doctor
echo "🏥 Running mise doctor..."
"$MISE_BIN" doctor 2>&1 | head -20

echo ""
echo "============================================"
echo "✅ Mise is ready!"
echo ""
echo "Quick start:"
echo "  mise use --global node@lts     # Install Node.js LTS"
echo "  mise use --global python@3.12  # Install Python 3.12"
echo "  mise ls                        # List installed tools"
echo "  mise ls-remote node            # List available Node versions"
echo ""
echo "💡 Restart your shell or run: source ~/.${SHELL_NAME}rc"
