#!/bin/bash
set -euo pipefail

TRIGGER="${1:-}"
REPLACEMENT="${2:-}"
FILE="${3:-base}"

if [ -z "$TRIGGER" ] || [ -z "$REPLACEMENT" ]; then
    echo "Usage: bash scripts/add-snippet.sh <trigger> <replacement> [file]"
    echo ""
    echo "Examples:"
    echo "  bash scripts/add-snippet.sh ':email' 'you@example.com'"
    echo "  bash scripts/add-snippet.sh ':sig' 'Best regards, John' personal"
    exit 1
fi

# Find espanso config dir
CONFIG_DIR="${ESPANSO_CONFIG:-}"
if [ -z "$CONFIG_DIR" ]; then
    if command -v espanso &>/dev/null; then
        CONFIG_DIR="$(espanso path config 2>/dev/null || echo "")"
    fi
fi

if [ -z "$CONFIG_DIR" ]; then
    # Default locations
    if [ -d "$HOME/.config/espanso" ]; then
        CONFIG_DIR="$HOME/.config/espanso"
    elif [ -d "$HOME/Library/Application Support/espanso" ]; then
        CONFIG_DIR="$HOME/Library/Application Support/espanso"
    else
        CONFIG_DIR="$HOME/.config/espanso"
        mkdir -p "$CONFIG_DIR/match" "$CONFIG_DIR/config"
    fi
fi

MATCH_DIR="$CONFIG_DIR/match"
mkdir -p "$MATCH_DIR"

MATCH_FILE="$MATCH_DIR/${FILE}.yml"

# Create file with header if it doesn't exist
if [ ! -f "$MATCH_FILE" ]; then
    echo "matches:" > "$MATCH_FILE"
fi

# Check if trigger already exists
if grep -q "trigger: \"$TRIGGER\"" "$MATCH_FILE" 2>/dev/null; then
    echo "⚠️  Trigger '$TRIGGER' already exists in $FILE.yml"
    read -p "Overwrite? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash "$(dirname "$0")/remove-snippet.sh" "$TRIGGER" "$FILE"
    else
        exit 0
    fi
fi

# Check if replacement is multi-line
if [[ "$REPLACEMENT" == *$'\n'* ]]; then
    # Multi-line: use YAML block scalar
    cat >> "$MATCH_FILE" << EOF

  - trigger: "$TRIGGER"
    replace: |
$(echo "$REPLACEMENT" | sed 's/^/      /')
EOF
else
    # Single line
    # Escape special YAML characters
    ESCAPED=$(echo "$REPLACEMENT" | sed 's/"/\\"/g')
    cat >> "$MATCH_FILE" << EOF

  - trigger: "$TRIGGER"
    replace: "$ESCAPED"
EOF
fi

echo "✅ Added snippet: $TRIGGER → ${REPLACEMENT:0:50}$([ ${#REPLACEMENT} -gt 50 ] && echo '...' || echo '')"
echo "   File: $MATCH_FILE"

# Restart espanso if running
if command -v espanso &>/dev/null && espanso status 2>/dev/null | grep -q "running"; then
    espanso restart 2>/dev/null && echo "🔄 Espanso restarted" || true
fi
