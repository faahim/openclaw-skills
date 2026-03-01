#!/bin/bash
# JupyterLab Extension Manager
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"
VENV_PATH="${JUPYTER_VENV:-$HOME/.jupyter-venv}"

activate_venv() {
  [ -d "$VENV_PATH" ] && source "$VENV_PATH/bin/activate"
}

cmd_install() {
  local ext="${1:-}"
  [ -z "$ext" ] && { echo "Usage: bash extensions.sh install <extension-name>"; exit 1; }
  activate_venv
  pip install --quiet "$ext"
  echo "✅ Extension '$ext' installed"
}

cmd_list() {
  activate_venv
  echo "📋 Installed Extensions"
  echo "======================="
  jupyter labextension list 2>/dev/null || echo "No extensions found"
}

cmd_disable() {
  local ext="${1:-}"
  [ -z "$ext" ] && { echo "Usage: bash extensions.sh disable <extension-name>"; exit 1; }
  activate_venv
  jupyter labextension disable "$ext"
  echo "✅ Extension '$ext' disabled"
}

cmd_enable() {
  local ext="${1:-}"
  [ -z "$ext" ] && { echo "Usage: bash extensions.sh enable <extension-name>"; exit 1; }
  activate_venv
  jupyter labextension enable "$ext"
  echo "✅ Extension '$ext' enabled"
}

cmd_rebuild() {
  activate_venv
  echo "🔨 Rebuilding JupyterLab..."
  jupyter lab build 2>/dev/null || echo "⚠️  Build not needed (pre-built extensions)"
  echo "✅ Rebuild complete"
}

cmd_popular() {
  echo "🌟 Popular JupyterLab Extensions"
  echo "================================="
  echo ""
  echo "  jupyterlab-git          — Git integration (stage, commit, push)"
  echo "  jupyterlab-lsp          — Language Server Protocol (autocomplete, linting)"
  echo "  jupyterlab-drawio       — Draw.io diagrams in notebooks"
  echo "  jupyterlab-execute-time — Show cell execution time"
  echo "  jupyterlab-code-formatter — Auto-format code (black, isort)"
  echo "  jupyterlab-vim          — Vim keybindings"
  echo "  jupyterlab-spreadsheet  — View Excel/CSV files"
  echo ""
  echo "Install: bash extensions.sh install <name>"
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  install) cmd_install "$@" ;;
  list) cmd_list ;;
  disable) cmd_disable "$@" ;;
  enable) cmd_enable "$@" ;;
  rebuild) cmd_rebuild ;;
  popular) cmd_popular ;;
  *)
    echo "JupyterLab Extension Manager"
    echo ""
    echo "Commands:"
    echo "  install <name>   Install an extension"
    echo "  list             List installed extensions"
    echo "  disable <name>   Disable an extension"
    echo "  enable <name>    Enable an extension"
    echo "  rebuild          Rebuild JupyterLab"
    echo "  popular          Show popular extensions"
    ;;
esac
