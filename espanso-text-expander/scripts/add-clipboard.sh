#!/bin/bash
set -euo pipefail

TRIGGER="${1:-}"
TEMPLATE="${2:-}"
FILE="${3:-base}"

if [ -z "$TRIGGER" ] || [ -z "$TEMPLATE" ]; then
    echo "Usage: bash scripts/add-clipboard.sh <trigger> <template> [file]"
    echo ""
    echo "Use {{clipboard}} in template for clipboard content."
    echo ""
    echo "Examples:"
    echo "  bash scripts/add-clipboard.sh ':code' '\`\`\`\n{{clipboard}}\n\`\`\`'"
    echo "  bash scripts/add-clipboard.sh ':link' '[link]({{clipboard}})'"
    exit 1
fi

CONFIG_DIR="${ESPANSO_CONFIG:-}"
if [ -z "$CONFIG_DIR" ]; then
    if command -v espanso &>/dev/null; then
        CONFIG_DIR="$(espanso path config 2>/dev/null || echo "")"
    fi
fi
[ -z "$CONFIG_DIR" ] && CONFIG_DIR="$HOME/.config/espanso"

MATCH_DIR="$CONFIG_DIR/match"
mkdir -p "$MATCH_DIR"
MATCH_FILE="$MATCH_DIR/${FILE}.yml"

[ ! -f "$MATCH_FILE" ] && echo "matches:" > "$MATCH_FILE"

ESCAPED_TEMPLATE=$(echo "$TEMPLATE" | sed 's/"/\\"/g')

cat >> "$MATCH_FILE" << EOF

  - trigger: "$TRIGGER"
    replace: "$ESCAPED_TEMPLATE"
    vars:
      - name: clipboard
        type: clipboard
EOF

echo "✅ Added clipboard snippet: $TRIGGER"
echo "   Template: $TEMPLATE"

if command -v espanso &>/dev/null && espanso status 2>/dev/null | grep -q "running"; then
    espanso restart 2>/dev/null && echo "🔄 Espanso restarted" || true
fi
