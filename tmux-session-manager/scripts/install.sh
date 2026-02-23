#!/usr/bin/env bash
# Install tmux and set up session manager
set -euo pipefail

echo "🔧 Tmux Session Manager — Setup"

# Install tmux
if command -v tmux >/dev/null 2>&1; then
  echo "✅ tmux $(tmux -V) already installed"
else
  echo "📦 Installing tmux..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y tmux
  elif command -v brew >/dev/null 2>&1; then
    brew install tmux
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y tmux
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm tmux
  else
    echo "❌ Could not detect package manager. Install tmux manually."
    exit 1
  fi
  echo "✅ tmux $(tmux -V) installed"
fi

# Create directories
SESSIONS_DIR="${TMUX_SESSIONS_DIR:-$HOME/.tmux-sessions}"
mkdir -p "$SESSIONS_DIR/profiles" "$SESSIONS_DIR/saved"
echo "✅ Session directory: $SESSIONS_DIR"

# Create example profile
cat > "$SESSIONS_DIR/profiles/example-dev.yaml" <<'YAML'
# Example dev workspace profile
name: my-project
root: ~/projects/my-app
windows:
  - name: editor
    command: vim .
  - name: server
    command: npm run dev
  - name: logs
    command: tail -f logs/*.log
  - name: shell
    command: bash
YAML
echo "✅ Example profile: $SESSIONS_DIR/profiles/example-dev.yaml"

echo ""
echo "🎉 Setup complete! Try:"
echo "  bash scripts/tmux-manager.sh template dev ."
echo "  bash scripts/tmux-manager.sh list"
