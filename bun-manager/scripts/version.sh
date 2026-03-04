#!/bin/bash
# Bun version manager — list, install, and switch versions
set -euo pipefail

ACTION="${1:-current}"
BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"

case "$ACTION" in
  current)
    if command -v bun &>/dev/null; then
      echo "Bun $(bun --version)"
      echo "Path: $(which bun)"
    else
      echo "Bun is not installed"
      exit 1
    fi
    ;;

  list)
    echo "📋 Available Bun versions (latest 15):"
    echo ""
    curl -fsSL "https://api.github.com/repos/oven-sh/bun/releases?per_page=15" 2>/dev/null | \
      jq -r '.[].tag_name' | sed 's/bun-v//' | while read -r v; do
        if command -v bun &>/dev/null && [[ "$(bun --version 2>/dev/null)" == "$v" ]]; then
          echo "  ✅ $v (current)"
        else
          echo "     $v"
        fi
      done
    ;;

  use)
    VERSION="${2:-}"
    if [[ -z "$VERSION" ]]; then
      echo "Usage: $0 use <version>"
      echo "Example: $0 use 1.2.0"
      exit 1
    fi
    echo "📥 Switching to Bun v$VERSION..."
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    bash "$SCRIPT_DIR/install.sh" --version "$VERSION"
    ;;

  *)
    echo "Usage: $0 {current|list|use <version>}"
    exit 1
    ;;
esac
