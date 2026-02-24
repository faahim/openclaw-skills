#!/bin/bash
# Mermaid Diagram Renderer — Quick render with smart defaults
set -euo pipefail

THEME="default"
BATCH=false
WIDTH=1200
BG="white"

usage() {
    echo "Usage: render.sh [OPTIONS] <input.mmd> <output.png|svg|pdf>"
    echo "       render.sh --batch <input-dir/> <output-dir/>"
    echo ""
    echo "Options:"
    echo "  --theme <name>   Theme: default, dark, forest, neutral"
    echo "  --width <px>     Output width (default: 1200)"
    echo "  --bg <color>     Background: white, transparent, #hex"
    echo "  --batch          Render all .mmd files in directory"
    echo "  -h, --help       Show this help"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --theme) THEME="$2"; shift 2 ;;
        --width) WIDTH="$2"; shift 2 ;;
        --bg) BG="$2"; shift 2 ;;
        --batch) BATCH=true; shift ;;
        -h|--help) usage ;;
        *) break ;;
    esac
done

# Check mmdc is available
if ! command -v mmdc &>/dev/null; then
    echo "❌ mermaid-cli not found. Install with: npm install -g @mermaid-js/mermaid-cli"
    exit 1
fi

render_one() {
    local input="$1"
    local output="$2"

    if [[ ! -f "$input" ]]; then
        echo "❌ File not found: $input"
        return 1
    fi

    # Create puppeteer config for headless environments
    local puppet_cfg
    puppet_cfg=$(mktemp /tmp/puppeteer-XXXXXX.json)
    echo '{"args":["--no-sandbox","--disable-setuid-sandbox"]}' > "$puppet_cfg"

    # Detect Chromium path
    local chrome_path=""
    for candidate in \
        "$HOME/.cache/ms-playwright/chromium-*/chrome-linux/chrome" \
        "$HOME/.cache/puppeteer/chrome/*/chrome-linux64/chrome" \
        "$(which chromium-browser 2>/dev/null)" \
        "$(which chromium 2>/dev/null)" \
        "$(which google-chrome 2>/dev/null)"; do
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            chrome_path="$candidate"
            break
        fi
    done

    local extra_args=()
    if [[ -n "$chrome_path" ]]; then
        export PUPPETEER_EXECUTABLE_PATH="$chrome_path"
    fi

    echo "🔄 Rendering: $input → $output"
    mmdc \
        -i "$input" \
        -o "$output" \
        -t "$THEME" \
        -w "$WIDTH" \
        -b "$BG" \
        -p "$puppet_cfg" \
        2>&1

    local status=$?
    rm -f "$puppet_cfg"

    if [[ $status -eq 0 ]]; then
        local size
        size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null || echo "?")
        echo "✅ Done: $output ($size bytes)"
    else
        echo "❌ Failed to render: $input"
        return 1
    fi
}

if [[ "$BATCH" == true ]]; then
    INPUT_DIR="${1:-.}"
    OUTPUT_DIR="${2:-$INPUT_DIR}"
    mkdir -p "$OUTPUT_DIR"

    count=0
    failed=0
    for f in "$INPUT_DIR"/*.mmd; do
        [[ -f "$f" ]] || continue
        base=$(basename "${f%.mmd}")
        if render_one "$f" "$OUTPUT_DIR/$base.png"; then
            ((count++))
        else
            ((failed++))
        fi
    done

    echo ""
    echo "📊 Batch complete: $count rendered, $failed failed"
else
    if [[ $# -lt 2 ]]; then
        echo "❌ Missing arguments. Usage: render.sh <input.mmd> <output.png>"
        echo "   Run with --help for options."
        exit 1
    fi

    INPUT="$1"
    OUTPUT="$2"

    # If 3rd positional arg is a theme name (backwards compat)
    if [[ $# -ge 3 && "$THEME" == "default" ]]; then
        THEME="$3"
    fi

    render_one "$INPUT" "$OUTPUT"
fi
