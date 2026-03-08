#!/bin/bash
# Mise Tool Manager — Initialize project with .mise.toml
set -euo pipefail

echo "📁 Mise Project Setup"
echo "====================="
echo ""

# Check mise installed
if ! command -v mise &>/dev/null; then
    echo "❌ Mise not installed. Run install.sh first."
    exit 1
fi

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

echo "Setting up mise in: $(pwd)"
echo ""

# Detect existing version files
DETECTED=""
if [ -f ".nvmrc" ]; then
    NODE_VER=$(cat .nvmrc | tr -d 'v \n')
    echo "📋 Found .nvmrc: Node $NODE_VER"
    DETECTED="$DETECTED node@$NODE_VER"
fi
if [ -f ".python-version" ]; then
    PY_VER=$(cat .python-version | tr -d ' \n')
    echo "📋 Found .python-version: Python $PY_VER"
    DETECTED="$DETECTED python@$PY_VER"
fi
if [ -f ".ruby-version" ]; then
    RB_VER=$(cat .ruby-version | tr -d ' \n')
    echo "📋 Found .ruby-version: Ruby $RB_VER"
    DETECTED="$DETECTED ruby@$RB_VER"
fi
if [ -f ".tool-versions" ]; then
    echo "📋 Found .tool-versions (asdf format)"
    DETECTED="asdf"
fi
if [ -f ".mise.toml" ]; then
    echo "✅ .mise.toml already exists"
    mise install
    echo ""
    echo "Installed tools:"
    mise current
    exit 0
fi

echo ""

# Create .mise.toml
if [ "$DETECTED" = "asdf" ]; then
    echo "Converting .tool-versions → .mise.toml..."
    mise use $(awk '{print $1"@"$2}' .tool-versions | tr '\n' ' ')
elif [ -n "$DETECTED" ]; then
    echo "Creating .mise.toml from detected versions..."
    mise use $DETECTED
else
    echo "No existing version files found."
    echo ""
    echo "Select runtimes to add (space-separated numbers):"
    echo "  1) Node.js (LTS)    5) Java (21)"
    echo "  2) Python (3.12)    6) Rust (latest)"
    echo "  3) Go (latest)      7) Deno (latest)"
    echo "  4) Ruby (3.3)       8) Bun (latest)"
    echo ""
    read -rp "Choices [e.g., 1 2]: " CHOICES

    TOOLS=""
    for choice in $CHOICES; do
        case $choice in
            1) TOOLS="$TOOLS node@lts" ;;
            2) TOOLS="$TOOLS python@3.12" ;;
            3) TOOLS="$TOOLS go@latest" ;;
            4) TOOLS="$TOOLS ruby@3.3" ;;
            5) TOOLS="$TOOLS java@21" ;;
            6) TOOLS="$TOOLS rust@latest" ;;
            7) TOOLS="$TOOLS deno@latest" ;;
            8) TOOLS="$TOOLS bun@latest" ;;
        esac
    done

    if [ -n "$TOOLS" ]; then
        mise use $TOOLS
    else
        echo "No tools selected. Creating empty .mise.toml..."
        cat > .mise.toml << 'EOF'
# .mise.toml — Project tool versions
# Docs: https://mise.jdx.dev/configuration.html

[tools]
# node = "22"
# python = "3.12"

[env]
# MY_VAR = "value"
EOF
    fi
fi

echo ""
echo "✅ Project configured!"
echo ""
echo "Active tools:"
mise current 2>/dev/null || echo "  (install tools with: mise install)"
echo ""
echo "📝 Edit .mise.toml to customize versions, env vars, and tasks."
