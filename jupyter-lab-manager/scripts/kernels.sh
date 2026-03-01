#!/bin/bash
# JupyterLab Kernel Manager — Add, remove, and list Jupyter kernels
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

VENV_PATH="${JUPYTER_VENV:-$HOME/.jupyter-venv}"

activate_venv() {
  if [ -d "$VENV_PATH" ]; then
    # shellcheck disable=SC1091
    source "$VENV_PATH/bin/activate"
  fi
}

cmd_list() {
  activate_venv
  echo "📋 Installed Jupyter Kernels"
  echo "============================"
  jupyter kernelspec list 2>/dev/null || echo "No kernels found. Run install.sh first."
}

cmd_add() {
  local kernel="${1:-}"
  local force=false
  shift || true
  [[ "${1:-}" == "--force" ]] && force=true

  activate_venv

  case "$kernel" in
    python|python3)
      echo "📥 Installing Python 3 kernel..."
      pip install --quiet ipykernel
      if [ "$force" = true ]; then
        python3 -m ipykernel install --user --name python3 --display-name "Python 3" --force
      else
        python3 -m ipykernel install --user --name python3 --display-name "Python 3"
      fi
      echo "✅ Python 3 kernel installed"
      ;;
    nodejs|node|javascript)
      echo "📥 Installing Node.js kernel..."
      if ! command -v node &>/dev/null; then
        echo "❌ Node.js not found. Install it first:"
        echo "   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
        echo "   sudo apt-get install -y nodejs"
        exit 1
      fi
      npm install -g ijavascript 2>/dev/null || sudo npm install -g ijavascript
      ijsinstall --install=local 2>/dev/null || npx ijavascript --install=local
      echo "✅ Node.js (JavaScript) kernel installed"
      ;;
    r)
      echo "📥 Installing R kernel..."
      if ! command -v R &>/dev/null; then
        echo "❌ R not found. Install it first:"
        echo "   sudo apt-get install -y r-base"
        exit 1
      fi
      R -e "install.packages('IRkernel', repos='https://cloud.r-project.org'); IRkernel::installspec(user = TRUE)" 2>/dev/null
      echo "✅ R kernel installed"
      ;;
    bash)
      echo "📥 Installing Bash kernel..."
      pip install --quiet bash_kernel
      python3 -m bash_kernel.install
      echo "✅ Bash kernel installed"
      ;;
    rust)
      echo "📥 Installing Rust kernel..."
      if ! command -v cargo &>/dev/null; then
        echo "❌ Rust not found. Install: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        exit 1
      fi
      cargo install evcxr_jupyter
      evcxr_jupyter --install
      echo "✅ Rust kernel installed"
      ;;
    go|golang)
      echo "📥 Installing Go kernel..."
      if ! command -v go &>/dev/null; then
        echo "❌ Go not found. Install it first: https://go.dev/dl/"
        exit 1
      fi
      go install github.com/gopherdata/gophernotes@latest
      mkdir -p "$HOME/.local/share/jupyter/kernels/gophernotes"
      cat > "$HOME/.local/share/jupyter/kernels/gophernotes/kernel.json" << EOF
{
  "argv": ["$(go env GOPATH)/bin/gophernotes", "{connection_file}"],
  "display_name": "Go",
  "language": "go"
}
EOF
      echo "✅ Go kernel installed"
      ;;
    *)
      echo "Available kernels: python, nodejs, r, bash, rust, go"
      echo "Usage: bash kernels.sh add <kernel> [--force]"
      exit 1
      ;;
  esac
}

cmd_remove() {
  local kernel="${1:-}"
  if [ -z "$kernel" ]; then
    echo "Usage: bash kernels.sh remove <kernel-name>"
    echo "Run 'bash kernels.sh list' to see installed kernels"
    exit 1
  fi
  activate_venv
  jupyter kernelspec remove "$kernel" -y
  echo "✅ Kernel '$kernel' removed"
}

# Main
ACTION="${1:-help}"
shift || true

case "$ACTION" in
  list) cmd_list ;;
  add) cmd_add "$@" ;;
  remove) cmd_remove "$@" ;;
  *)
    echo "Jupyter Kernel Manager"
    echo ""
    echo "Usage: bash kernels.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  list                  List installed kernels"
    echo "  add <kernel> [--force] Add a kernel (python, nodejs, r, bash, rust, go)"
    echo "  remove <name>         Remove a kernel"
    ;;
esac
