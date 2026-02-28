#!/bin/bash
# ASCII Art Generator — Main Script
# Usage: bash run.sh <command> [args] [options]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
WIDTH="${ASCII_WIDTH:-80}"
FONT="${ASCII_FONT:-standard}"
FILTER="${ASCII_FILTER:-crop}"
CHARS="${ASCII_CHARS:-}"
OUTPUT=""
INVERT=""
ENHANCE=""
GRAYSCALE=""

# --- Helpers ---

usage() {
    cat <<'EOF'
ASCII Art Generator

COMMANDS:
  banner <text>           Generate text banner with figlet
  style <text>            Generate styled text with toilet
  image <file|url>        Convert image to ASCII art
  fonts                   List available figlet fonts
  filters                 List available toilet filters
  batch-banner <file>     Generate banners for each line in file
  batch-image <dir>       Convert all images in directory
  random <text>           Random font banner
  random-style <text>     Random styled text

OPTIONS:
  --font <name>           Figlet/toilet font (default: standard)
  --filter <name>         Toilet filter: metal, gay, border, flip, etc.
  --width <N>             Image width in characters (default: 80)
  --chars <set>           Custom character ramp for jp2a
  --invert                Invert image colors
  --enhance               Enhance contrast before conversion
  --grayscale             Convert to grayscale first
  --output <path>         Save output to file (or directory for batch)

EXAMPLES:
  bash run.sh banner "Hello" --font slant
  bash run.sh style "WARNING" --filter metal
  bash run.sh image photo.jpg --width 100
  bash run.sh fonts | grep -i script
EOF
    exit 0
}

check_cmd() {
    if ! command -v "$1" &>/dev/null; then
        echo "❌ '$1' not found. Run: bash scripts/install.sh" >&2
        exit 1
    fi
}

# --- Parse args ---

COMMAND="${1:-}"
shift 2>/dev/null || true
TEXT=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --font)     FONT="$2"; shift 2 ;;
        --filter)   FILTER="$2"; shift 2 ;;
        --width)    WIDTH="$2"; shift 2 ;;
        --chars)    CHARS="$2"; shift 2 ;;
        --invert)   INVERT="--invert"; shift ;;
        --enhance)  ENHANCE="1"; shift ;;
        --grayscale) GRAYSCALE="1"; shift ;;
        --output)   OUTPUT="$2"; shift 2 ;;
        --help|-h)  usage ;;
        *)          POSITIONAL+=("$1"); shift ;;
    esac
done

TEXT="${POSITIONAL[0]:-}"

# Read from stdin if no text and command expects text
if [[ -z "$TEXT" && "$COMMAND" =~ ^(banner|style|random|random-style)$ ]] && [ ! -t 0 ]; then
    TEXT=$(cat)
fi

output_result() {
    if [ -n "$OUTPUT" ]; then
        cat > "$OUTPUT"
        echo "💾 Saved to: $OUTPUT" >&2
    else
        cat
    fi
}

# --- Commands ---

cmd_banner() {
    check_cmd figlet
    [ -z "$TEXT" ] && { echo "Usage: banner <text> [--font <name>]" >&2; exit 1; }
    figlet -f "$FONT" "$TEXT" | output_result
}

cmd_style() {
    check_cmd toilet
    [ -z "$TEXT" ] && { echo "Usage: style <text> [--font <name>] [--filter <name>]" >&2; exit 1; }
    toilet -f "$FONT" --filter "$FILTER" "$TEXT" | output_result
}

cmd_image() {
    check_cmd jp2a
    local SRC="${TEXT}"
    [ -z "$SRC" ] && { echo "Usage: image <file|url> [--width N] [--invert]" >&2; exit 1; }

    local TMPFILE=""
    local INPUT_FILE="$SRC"

    # Handle URLs
    if [[ "$SRC" =~ ^https?:// ]]; then
        check_cmd curl
        TMPFILE=$(mktemp /tmp/ascii-img-XXXXXX)
        curl -sL "$SRC" -o "$TMPFILE"
        INPUT_FILE="$TMPFILE"
    fi

    # Handle PNG → JPEG conversion (jp2a needs JPEG)
    if file "$INPUT_FILE" 2>/dev/null | grep -qi "png\|gif\|webp\|bmp\|tiff"; then
        check_cmd convert
        local JPEG_TMP=$(mktemp /tmp/ascii-jpg-XXXXXX.jpg)

        local CONVERT_OPTS=()
        [ -n "$ENHANCE" ] && CONVERT_OPTS+=(-contrast -contrast)
        [ -n "$GRAYSCALE" ] && CONVERT_OPTS+=(-colorspace Gray)

        convert "$INPUT_FILE" "${CONVERT_OPTS[@]}" "$JPEG_TMP"
        INPUT_FILE="$JPEG_TMP"
    elif [ -n "$ENHANCE" ] || [ -n "$GRAYSCALE" ]; then
        check_cmd convert
        local JPEG_TMP=$(mktemp /tmp/ascii-jpg-XXXXXX.jpg)
        local CONVERT_OPTS=()
        [ -n "$ENHANCE" ] && CONVERT_OPTS+=(-contrast -contrast)
        [ -n "$GRAYSCALE" ] && CONVERT_OPTS+=(-colorspace Gray)
        convert "$INPUT_FILE" "${CONVERT_OPTS[@]}" "$JPEG_TMP"
        INPUT_FILE="$JPEG_TMP"
    fi

    # Build jp2a args
    local JP2A_ARGS=(--width="$WIDTH")
    [ -n "$INVERT" ] && JP2A_ARGS+=(--invert)
    [ -n "$CHARS" ] && JP2A_ARGS+=(--chars="$CHARS")

    jp2a "${JP2A_ARGS[@]}" "$INPUT_FILE" | output_result

    # Cleanup temp files
    [ -n "$TMPFILE" ] && rm -f "$TMPFILE"
    [ -n "$JPEG_TMP" ] && rm -f "$JPEG_TMP" 2>/dev/null
}

cmd_fonts() {
    check_cmd figlet
    local FONTDIR
    FONTDIR=$(figlet -I 2 2>/dev/null)
    if [ -d "$FONTDIR" ]; then
        find "$FONTDIR" -name '*.flf' -exec basename {} .flf \; | sort
    else
        echo "Font directory not found. Try: figlet -I 2" >&2
    fi
}

cmd_filters() {
    echo "Available toilet filters:"
    echo "  crop    — Crop empty lines"
    echo "  gay     — Rainbow colors"
    echo "  metal   — Metallic gradient"
    echo "  flip    — Flip vertically"
    echo "  flop    — Flip horizontally"
    echo "  180     — Rotate 180°"
    echo "  left    — Rotate left"
    echo "  right   — Rotate right"
    echo "  border  — Add border"
}

cmd_batch_banner() {
    check_cmd figlet
    local FILE="${TEXT}"
    [ -z "$FILE" ] || [ ! -f "$FILE" ] && { echo "Usage: batch-banner <file> [--font <name>] [--output <dir>]" >&2; exit 1; }

    local OUTDIR="${OUTPUT:-.}"
    mkdir -p "$OUTDIR"

    local i=0
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        i=$((i + 1))
        local SLUG=$(echo "$line" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//;s/-$//')
        figlet -f "$FONT" "$line" > "$OUTDIR/${i}-${SLUG}.txt"
        echo "✅ $OUTDIR/${i}-${SLUG}.txt"
    done < "$FILE"
    echo "📁 Generated $i banners in $OUTDIR/"
}

cmd_batch_image() {
    check_cmd jp2a
    local DIR="${TEXT}"
    [ -z "$DIR" ] || [ ! -d "$DIR" ] && { echo "Usage: batch-image <dir> [--width N] [--output <dir>]" >&2; exit 1; }

    local OUTDIR="${OUTPUT:-.}"
    mkdir -p "$OUTDIR"

    local i=0
    for img in "$DIR"/*.{jpg,jpeg,png,gif,webp,bmp} ; do
        [ -f "$img" ] || continue
        i=$((i + 1))
        local BASE=$(basename "$img" | sed 's/\.[^.]*$//')
        TEXT="$img" cmd_image_inner > "$OUTDIR/${BASE}.txt"
        echo "✅ $OUTDIR/${BASE}.txt"
    done
    echo "📁 Converted $i images in $OUTDIR/"
}

cmd_random() {
    check_cmd figlet
    [ -z "$TEXT" ] && { echo "Usage: random <text>" >&2; exit 1; }
    local FONTDIR
    FONTDIR=$(figlet -I 2 2>/dev/null)
    if [ -d "$FONTDIR" ]; then
        FONT=$(find "$FONTDIR" -name '*.flf' -exec basename {} .flf \; | shuf -n 1)
        echo "🎲 Font: $FONT"
        figlet -f "$FONT" "$TEXT" | output_result
    else
        figlet "$TEXT" | output_result
    fi
}

cmd_random_style() {
    check_cmd toilet
    [ -z "$TEXT" ] && { echo "Usage: random-style <text>" >&2; exit 1; }
    local FILTERS=(crop gay metal flip border)
    local RAND_FILTER=${FILTERS[$RANDOM % ${#FILTERS[@]}]}
    echo "🎲 Filter: $RAND_FILTER"
    toilet --filter "$RAND_FILTER" "$TEXT" | output_result
}

# --- Dispatch ---

case "$COMMAND" in
    banner)         cmd_banner ;;
    style)          cmd_style ;;
    image)          cmd_image ;;
    fonts)          cmd_fonts ;;
    filters)        cmd_filters ;;
    batch-banner)   cmd_batch_banner ;;
    batch-image)    cmd_batch_image ;;
    random)         cmd_random ;;
    random-style)   cmd_random_style ;;
    ""|--help|-h)   usage ;;
    *)              echo "❌ Unknown command: $COMMAND" >&2; usage ;;
esac
