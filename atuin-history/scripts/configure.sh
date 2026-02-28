#!/bin/bash
# Configure Atuin settings
set -e

CONFDIR="${XDG_CONFIG_HOME:-$HOME/.config}/atuin"
CONF="$CONFDIR/config.toml"

if [[ "$1" == "init" ]]; then
    mkdir -p "$CONFDIR"
    if [[ -f "$CONF" ]]; then
        echo "⚠️  Config already exists at $CONF"
        read -p "Overwrite with defaults? (y/N): " REPLY
        [[ "$REPLY" =~ ^[Yy]$ ]] || exit 0
    fi
    cat > "$CONF" << 'EOF'
## Atuin Configuration
## Full reference: https://docs.atuin.sh/configuration/config/

# How to search: fuzzy, prefix, fulltext, skim
search_mode = "fuzzy"

# Default filter: global, host, session, directory
filter_mode = "global"

# UI style: auto, full, compact
style = "compact"

# Number of rows for inline search
inline_height = 20

# Show command preview
show_preview = true
max_preview_height = 4

# Sync frequency (set to "" to disable auto-sync)
sync_frequency = "10m"

# Patterns to never record (regex)
history_filter = [
    "^export.*TOKEN",
    "^export.*SECRET",
    "^export.*KEY",
    "^export.*PASSWORD",
]

# Record timestamps in UTC
timestamps_enabled = true

# Enter accepts immediately (false = shows preview first)
enter_accept = true
EOF
    echo "✅ Default config written to $CONF"
    exit 0
fi

KEY="$1"
VALUE="$2"

if [[ -z "$KEY" ]]; then
    echo "Usage:"
    echo "  $0 init                    # Generate default config"
    echo "  $0 <key> <value>           # Set a config value"
    echo ""
    echo "Common keys:"
    echo "  search_mode    fuzzy|prefix|fulltext|skim"
    echo "  filter_mode    global|host|session|directory"
    echo "  style          auto|full|compact"
    echo "  sync_address   URL or empty string"
    echo "  sync_frequency Duration (e.g. 10m, 1h)"
    echo "  history_filter JSON array of regex patterns"
    echo "  inline_height  Number of rows"
    echo "  show_preview   true|false"
    exit 0
fi

if [[ -z "$VALUE" ]]; then
    echo "❌ No value provided for key: $KEY"
    exit 1
fi

mkdir -p "$CONFDIR"

# Determine if value needs quoting
if [[ "$VALUE" =~ ^[0-9]+$ ]] || [[ "$VALUE" == "true" ]] || [[ "$VALUE" == "false" ]] || [[ "$VALUE" =~ ^\[.*\]$ ]]; then
    FORMATTED="$KEY = $VALUE"
else
    FORMATTED="$KEY = \"$VALUE\""
fi

if [[ -f "$CONF" ]] && grep -q "^$KEY " "$CONF"; then
    sed -i "s|^$KEY .*|$FORMATTED|" "$CONF"
    echo "✅ Updated: $FORMATTED"
else
    echo "$FORMATTED" >> "$CONF"
    echo "✅ Added: $FORMATTED"
fi
