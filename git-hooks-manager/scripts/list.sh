#!/bin/bash
# List all configured hooks
set -e

REPO_PATH="${1:-.}"
CONFIG="$REPO_PATH/.pre-commit-config.yaml"

if [ ! -f "$CONFIG" ]; then
  echo "❌ No config found in: $REPO_PATH"
  exit 1
fi

echo "📋 Configured hooks in: $REPO_PATH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Parse YAML to show hooks
current_repo=""
current_rev=""
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*repo:[[:space:]]*(.*) ]]; then
    current_repo="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]*rev:[[:space:]]*(.*) ]]; then
    current_rev="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*id:[[:space:]]*(.*) ]]; then
    hook_id="${BASH_REMATCH[1]}"
    # Extract short repo name
    repo_name=$(echo "$current_repo" | sed 's|.*/||')
    printf "  %-30s %-20s %s\n" "$hook_id" "$current_rev" "$repo_name"
  fi
done < "$CONFIG"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total: $(grep -c 'id:' "$CONFIG") hooks"
