#!/bin/bash
set -euo pipefail

TRIGGER="${1:-}"
VAR_TYPE="${2:-}"
FORMAT="${3:-}"
FILE="${4:-base}"

if [ -z "$TRIGGER" ] || [ -z "$VAR_TYPE" ]; then
    echo "Usage: bash scripts/add-dynamic.sh <trigger> <type> [format] [file]"
    echo ""
    echo "Types:"
    echo "  {{date}}     — Current date (format: strftime, default %Y-%m-%d)"
    echo "  {{time}}     — Current time (format: strftime, default %H:%M)"
    echo "  {{shell}}    — Shell command output (format = command)"
    echo ""
    echo "Examples:"
    echo "  bash scripts/add-dynamic.sh ':today' '{{date}}' '%Y-%m-%d'"
    echo "  bash scripts/add-dynamic.sh ':ip' '{{shell}}' 'curl -s ifconfig.me'"
    exit 1
fi

# Find config dir
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

case "$VAR_TYPE" in
    "{{date}}")
        FMT="${FORMAT:-%Y-%m-%d}"
        cat >> "$MATCH_FILE" << EOF

  - trigger: "$TRIGGER"
    replace: "{{today}}"
    vars:
      - name: today
        type: date
        params:
          format: "$FMT"
EOF
        ;;
    "{{time}}")
        FMT="${FORMAT:-%H:%M}"
        cat >> "$MATCH_FILE" << EOF

  - trigger: "$TRIGGER"
    replace: "{{now}}"
    vars:
      - name: now
        type: date
        params:
          format: "$FMT"
EOF
        ;;
    "{{shell}}")
        CMD="${FORMAT:-echo 'no command specified'}"
        cat >> "$MATCH_FILE" << EOF

  - trigger: "$TRIGGER"
    replace: "{{output}}"
    vars:
      - name: output
        type: shell
        params:
          cmd: "$CMD"
EOF
        ;;
    *)
        echo "❌ Unknown type: $VAR_TYPE"
        echo "   Supported: {{date}}, {{time}}, {{shell}}"
        exit 1
        ;;
esac

echo "✅ Added dynamic snippet: $TRIGGER ($VAR_TYPE)"
echo "   File: $MATCH_FILE"

if command -v espanso &>/dev/null && espanso status 2>/dev/null | grep -q "running"; then
    espanso restart 2>/dev/null && echo "🔄 Espanso restarted" || true
fi
