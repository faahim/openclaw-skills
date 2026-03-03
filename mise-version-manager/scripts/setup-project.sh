#!/bin/bash
# Mise — Initialize project with tool versions
# Usage: bash setup-project.sh [--node VERSION] [--python VERSION] [--go VERSION] [--ruby VERSION]

set -euo pipefail

if ! command -v mise &>/dev/null; then
  echo "❌ mise not found. Run install.sh first."
  exit 1
fi

NODE_VER=""
PYTHON_VER=""
GO_VER=""
RUBY_VER=""
JAVA_VER=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --node)    NODE_VER="$2"; shift 2 ;;
    --python)  PYTHON_VER="$2"; shift 2 ;;
    --go)      GO_VER="$2"; shift 2 ;;
    --ruby)    RUBY_VER="$2"; shift 2 ;;
    --java)    JAVA_VER="$2"; shift 2 ;;
    *)         echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$NODE_VER" && -z "$PYTHON_VER" && -z "$GO_VER" && -z "$RUBY_VER" && -z "$JAVA_VER" ]]; then
  echo "Usage: bash setup-project.sh --node 22 --python 3.12"
  echo ""
  echo "Options:"
  echo "  --node VERSION     Pin Node.js version"
  echo "  --python VERSION   Pin Python version"
  echo "  --go VERSION       Pin Go version"
  echo "  --ruby VERSION     Pin Ruby version"
  echo "  --java VERSION     Pin Java version"
  exit 0
fi

echo "=== Setting up project versions ==="

[[ -n "$NODE_VER" ]]   && mise use "node@$NODE_VER"
[[ -n "$PYTHON_VER" ]] && mise use "python@$PYTHON_VER"
[[ -n "$GO_VER" ]]     && mise use "go@$GO_VER"
[[ -n "$RUBY_VER" ]]   && mise use "ruby@$RUBY_VER"
[[ -n "$JAVA_VER" ]]   && mise use "java@$JAVA_VER"

echo ""
echo "✅ Project configured. Current versions:"
mise current
echo ""
echo "📄 Config file:"
cat .mise.toml 2>/dev/null || echo "(no .mise.toml found)"
