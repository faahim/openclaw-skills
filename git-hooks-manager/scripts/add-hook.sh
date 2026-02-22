#!/bin/bash
# Add a hook to existing .pre-commit-config.yaml
set -e

REPO_PATH="${1:-.}"
HOOK_REPO=""
HOOK_REV=""
HOOK_ID=""

shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo) HOOK_REPO="$2"; shift 2 ;;
    --rev) HOOK_REV="$2"; shift 2 ;;
    --hook) HOOK_ID="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

CONFIG="$REPO_PATH/.pre-commit-config.yaml"

if [ ! -f "$CONFIG" ]; then
  echo "❌ No config found. Run init.sh first."
  exit 1
fi

if [ -z "$HOOK_REPO" ] || [ -z "$HOOK_REV" ] || [ -z "$HOOK_ID" ]; then
  echo "Usage: add-hook.sh /path/to/repo --repo <url> --rev <version> --hook <id>"
  echo ""
  echo "Example:"
  echo "  bash scripts/add-hook.sh . \\"
  echo "    --repo https://github.com/pre-commit/mirrors-prettier \\"
  echo "    --rev v3.1.0 \\"
  echo "    --hook prettier"
  exit 1
fi

# Append to config
cat >> "$CONFIG" <<EOF

  - repo: $HOOK_REPO
    rev: $HOOK_REV
    hooks:
      - id: $HOOK_ID
EOF

echo "✅ Added hook '$HOOK_ID' from $HOOK_REPO@$HOOK_REV"
echo "   Run 'pre-commit install --install-hooks' to download it."
