#!/bin/bash
# Run pre-commit hooks against all files
set -e

REPO_PATH="${1:-.}"
HOOK_ID=""

shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --hook) HOOK_ID="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ ! -f "$REPO_PATH/.pre-commit-config.yaml" ]; then
  echo "❌ No .pre-commit-config.yaml found in: $REPO_PATH"
  echo "   Run: bash scripts/init.sh $REPO_PATH"
  exit 1
fi

cd "$REPO_PATH"
export PATH="$HOME/.local/bin:$PATH"

if [ -n "$HOOK_ID" ]; then
  echo "🔍 Running hook '$HOOK_ID' on all files..."
  pre-commit run "$HOOK_ID" --all-files
else
  echo "🔍 Running all hooks on all files..."
  pre-commit run --all-files
fi
