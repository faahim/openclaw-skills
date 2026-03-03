#!/bin/bash
# Mise Version Manager — Install Script
# Installs mise and configures shell activation

set -euo pipefail

MISE_BIN="$HOME/.local/bin/mise"
SHELL_RC=""

# Detect shell
detect_shell() {
  local current_shell
  current_shell="$(basename "$SHELL")"
  case "$current_shell" in
    bash) SHELL_RC="$HOME/.bashrc" ;;
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
    *)    SHELL_RC="$HOME/.bashrc" ;;
  esac
  echo "Detected shell: $current_shell (rc: $SHELL_RC)"
}

# Install mise
install_mise() {
  if command -v mise &>/dev/null; then
    echo "✅ mise already installed: $(mise --version)"
    return 0
  fi

  echo "📦 Installing mise..."
  curl -fsSL https://mise.run | sh

  if [ ! -f "$MISE_BIN" ]; then
    echo "❌ Installation failed — $MISE_BIN not found"
    exit 1
  fi

  echo "✅ mise installed: $($MISE_BIN --version)"
}

# Configure shell activation
configure_shell() {
  local activation_line

  case "$(basename "$SHELL")" in
    fish) activation_line="$MISE_BIN activate fish | source" ;;
    zsh)  activation_line="eval \"\$($MISE_BIN activate zsh)\"" ;;
    *)    activation_line="eval \"\$($MISE_BIN activate bash)\"" ;;
  esac

  if grep -qF "mise activate" "$SHELL_RC" 2>/dev/null; then
    echo "✅ Shell activation already configured in $SHELL_RC"
    return 0
  fi

  echo "" >> "$SHELL_RC"
  echo "# mise version manager" >> "$SHELL_RC"
  echo "$activation_line" >> "$SHELL_RC"
  echo "✅ Added mise activation to $SHELL_RC"
  echo "   Run: source $SHELL_RC"
}

# Install shell completions
install_completions() {
  case "$(basename "$SHELL")" in
    bash)
      local comp_dir="/etc/bash_completion.d"
      if [ -w "$comp_dir" ]; then
        $MISE_BIN completion bash > "$comp_dir/mise" 2>/dev/null && \
          echo "✅ Bash completions installed" || true
      fi
      ;;
    zsh)
      local zfunc_dir="$HOME/.zfunc"
      mkdir -p "$zfunc_dir"
      $MISE_BIN completion zsh > "$zfunc_dir/_mise" 2>/dev/null && \
        echo "✅ Zsh completions installed" || true
      ;;
    fish)
      local fish_comp="$HOME/.config/fish/completions"
      mkdir -p "$fish_comp"
      $MISE_BIN completion fish > "$fish_comp/mise.fish" 2>/dev/null && \
        echo "✅ Fish completions installed" || true
      ;;
  esac
}

# Main
main() {
  echo "=== Mise Version Manager Setup ==="
  echo ""
  detect_shell
  install_mise
  configure_shell
  install_completions
  echo ""
  echo "🎉 Done! Run 'source $SHELL_RC' then try:"
  echo "   mise use --global node@lts"
  echo "   mise use --global python@3.12"
}

main "$@"
