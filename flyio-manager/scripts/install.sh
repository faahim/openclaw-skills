#!/bin/bash
# Fly.io Manager — Install Script
# Installs flyctl CLI and configures PATH

set -euo pipefail

echo "🚀 Fly.io Manager — Installing flyctl..."

# Check if already installed
if command -v fly &>/dev/null; then
    CURRENT_VERSION=$(fly version 2>/dev/null | head -1)
    echo "✅ flyctl already installed: $CURRENT_VERSION"
    read -p "Reinstall/update? (y/N): " REINSTALL
    if [[ "$REINSTALL" != "y" && "$REINSTALL" != "Y" ]]; then
        echo "Skipping installation."
        exit 0
    fi
fi

# Install flyctl
echo "📦 Downloading flyctl..."
curl -L https://fly.io/install.sh | sh

# Configure PATH
FLYCTL_INSTALL="${HOME}/.fly"
SHELL_RC=""

if [[ -f "$HOME/.bashrc" ]]; then
    SHELL_RC="$HOME/.bashrc"
elif [[ -f "$HOME/.zshrc" ]]; then
    SHELL_RC="$HOME/.zshrc"
fi

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -q "FLYCTL_INSTALL" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Fly.io CLI" >> "$SHELL_RC"
        echo "export FLYCTL_INSTALL=\"${FLYCTL_INSTALL}\"" >> "$SHELL_RC"
        echo "export PATH=\"\$FLYCTL_INSTALL/bin:\$PATH\"" >> "$SHELL_RC"
        echo "✅ Added flyctl to PATH in $SHELL_RC"
    else
        echo "✅ PATH already configured in $SHELL_RC"
    fi
fi

# Add to current session
export PATH="$FLYCTL_INSTALL/bin:$PATH"

# Verify
echo ""
echo "✅ flyctl installed successfully!"
fly version
echo ""
echo "Next steps:"
echo "  1. Run: fly auth login"
echo "  2. Or set: export FLY_API_TOKEN='your-token'"
echo "  3. Deploy: cd your-app && fly launch"
