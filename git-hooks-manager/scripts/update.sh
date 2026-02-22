#!/bin/bash
# Update all hook versions to latest
set -e

REPO_PATH="${1:-.}"

if [ ! -f "$REPO_PATH/.pre-commit-config.yaml" ]; then
  echo "❌ No config found in: $REPO_PATH"
  exit 1
fi

cd "$REPO_PATH"
export PATH="$HOME/.local/bin:$PATH"

echo "📦 Updating all hooks to latest versions..."
echo ""
echo "Before:"
grep 'rev:' .pre-commit-config.yaml

pre-commit autoupdate

echo ""
echo "After:"
grep 'rev:' .pre-commit-config.yaml

echo ""
echo "✅ All hooks updated. Run 'pre-commit run --all-files' to verify."
