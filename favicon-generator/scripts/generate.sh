#!/bin/bash
# Favicon Generator — Generate all favicon sizes from a single source image
# Requires: ImageMagick (convert/magick), optionally librsvg2 for SVG
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
INPUT=""
OUTPUT="./favicons"
BG="transparent"
MINIMAL=false
PWA_ONLY=false
NO_MANIFEST=false
NO_BROWSERCONFIG=false
SITE_NAME="My Website"
THEME_COLOR="#ffffff"
PREFIX="/"
MAGICK="${MAGICK_BIN:-}"

# ── Parse Arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --input)           INPUT="$2"; shift 2 ;;
    --output)          OUTPUT="$2"; shift 2 ;;
    --bg)              BG="$2"; shift 2 ;;
    --minimal)         MINIMAL=true; shift ;;
    --pwa-only)        PWA_ONLY=true; shift ;;
    --no-manifest)     NO_MANIFEST=true; shift ;;
    --no-browserconfig) NO_BROWSERCONFIG=true; shift ;;
    --site-name)       SITE_NAME="$2"; shift 2 ;;
    --theme-color)     THEME_COLOR="$2"; shift 2 ;;
    --prefix)          PREFIX="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: generate.sh --input <file> [--output <dir>] [options]"
      echo ""
      echo "Options:"
      echo "  --input FILE        Source image (PNG, JPG, SVG)"
      echo "  --output DIR        Output directory (default: ./favicons)"
      echo "  --bg COLOR          Background color for tiles (default: transparent)"
      echo "  --minimal           ICO + Apple Touch + 32x32 only"
      echo "  --pwa-only          Android Chrome icons + manifest only"
      echo "  --no-manifest       Skip site.webmanifest"
      echo "  --no-browserconfig  Skip browserconfig.xml"
      echo "  --site-name NAME    Name for manifest (default: My Website)"
      echo "  --theme-color HEX   Theme color (default: #ffffff)"
      echo "  --prefix PATH       URL prefix for HTML snippet (default: /)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Validate ──────────────────────────────────────────────────────────────────
if [[ -z "$INPUT" ]]; then
  echo "❌ Error: --input is required"
  echo "Usage: generate.sh --input <file> [--output <dir>]"
  exit 1
fi

if [[ ! -f "$INPUT" ]]; then
  echo "❌ Error: File not found: $INPUT"
  exit 1
fi

# Find ImageMagick binary
if [[ -z "$MAGICK" ]]; then
  if command -v magick &>/dev/null; then
    MAGICK="magick"
  elif command -v convert &>/dev/null; then
    MAGICK="convert"
  else
    echo "❌ Error: ImageMagick not found. Install with:"
    echo "  Ubuntu/Debian: sudo apt install imagemagick"
    echo "  macOS: brew install imagemagick"
    exit 1
  fi
fi

# ── Setup ─────────────────────────────────────────────────────────────────────
mkdir -p "$OUTPUT"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "🎨 Favicon Generator"
echo "   Input:  $INPUT"
echo "   Output: $OUTPUT"
echo ""

# ── Helper: Rasterize SVG ────────────────────────────────────────────────────
rasterize_svg() {
  local input="$1" width="$2" height="$3" output="$4"
  if command -v rsvg-convert &>/dev/null; then
    rsvg-convert -w "$width" -h "$height" "$input" > "$output"
  else
    $MAGICK "$input" -resize "${width}x${height}!" -background "$BG" -flatten "$output"
  fi
}

# ── Helper: Resize Image ─────────────────────────────────────────────────────
resize_image() {
  local input="$1" width="$2" height="$3" output="$4" sharpen="${5:-false}"
  local ext="${input##*.}"

  if [[ "${ext,,}" == "svg" ]]; then
    rasterize_svg "$input" "$width" "$height" "$output"
  else
    if [[ "$sharpen" == "true" && "$width" -le 32 ]]; then
      # Apply unsharp mask for small sizes to prevent blur
      $MAGICK "$input" -resize "${width}x${height}" -unsharp 0.5x0.5+0.7+0 \
        -background "$BG" -gravity center -extent "${width}x${height}" "$output"
    else
      $MAGICK "$input" -resize "${width}x${height}" \
        -background "$BG" -gravity center -extent "${width}x${height}" "$output"
    fi
  fi
}

# ── Check Source Dimensions ───────────────────────────────────────────────────
EXT="${INPUT##*.}"
if [[ "${EXT,,}" != "svg" ]]; then
  SRC_SIZE=$(identify -format "%wx%h" "$INPUT" 2>/dev/null || echo "unknown")
  SRC_W=$(echo "$SRC_SIZE" | cut -dx -f1)
  if [[ "$SRC_W" =~ ^[0-9]+$ ]] && [[ "$SRC_W" -lt 512 ]]; then
    echo "⚠️  Warning: Source image is ${SRC_SIZE}. 512x512+ recommended for best quality."
    echo ""
  fi
fi

# ── Generate Standard PNGs ───────────────────────────────────────────────────
generate_png() {
  local name="$1" size="$2"
  echo "  📐 ${name} (${size}x${size})"
  resize_image "$INPUT" "$size" "$size" "$OUTPUT/$name" "true"
}

if [[ "$PWA_ONLY" == "false" ]]; then
  echo "📦 Generating PNG favicons..."
  generate_png "favicon-16x16.png" 16
  generate_png "favicon-32x32.png" 32

  if [[ "$MINIMAL" == "false" ]]; then
    generate_png "favicon-48x48.png" 48
  fi
  echo ""
fi

# ── Generate Apple Touch Icons ────────────────────────────────────────────────
if [[ "$PWA_ONLY" == "false" ]]; then
  echo "🍎 Generating Apple Touch Icons..."
  generate_png "apple-touch-icon.png" 180

  if [[ "$MINIMAL" == "false" ]]; then
    generate_png "apple-touch-icon-120x120.png" 120
    generate_png "apple-touch-icon-152x152.png" 152
    generate_png "apple-touch-icon-167x167.png" 167
  fi
  echo ""
fi

# ── Generate Android Chrome Icons ─────────────────────────────────────────────
if [[ "$MINIMAL" == "false" ]] || [[ "$PWA_ONLY" == "true" ]]; then
  echo "🤖 Generating Android Chrome icons..."
  generate_png "android-chrome-192x192.png" 192
  generate_png "android-chrome-512x512.png" 512

  # Maskable icon (with 20% safe zone padding)
  echo "  📐 android-chrome-maskable-192x192.png (with safe zone)"
  resize_image "$INPUT" 154 154 "$TMPDIR/maskable-inner.png" "false"
  $MAGICK -size 192x192 "xc:$THEME_COLOR" "$TMPDIR/maskable-inner.png" \
    -gravity center -composite "$OUTPUT/android-chrome-maskable-192x192.png"

  echo "  📐 android-chrome-maskable-512x512.png (with safe zone)"
  resize_image "$INPUT" 410 410 "$TMPDIR/maskable-inner-lg.png" "false"
  $MAGICK -size 512x512 "xc:$THEME_COLOR" "$TMPDIR/maskable-inner-lg.png" \
    -gravity center -composite "$OUTPUT/android-chrome-maskable-512x512.png"
  echo ""
fi

# ── Generate MS Tile Images ──────────────────────────────────────────────────
if [[ "$MINIMAL" == "false" ]] && [[ "$PWA_ONLY" == "false" ]]; then
  echo "🪟 Generating MS tile images..."
  MS_BG="${BG}"
  [[ "$MS_BG" == "transparent" ]] && MS_BG="$THEME_COLOR"

  for tile_size in 70 150 310; do
    echo "  📐 mstile-${tile_size}x${tile_size}.png"
    resize_image "$INPUT" "$tile_size" "$tile_size" "$OUTPUT/mstile-${tile_size}x${tile_size}.png" "false"
  done

  # Wide tile (310x150)
  echo "  📐 mstile-310x150.png (wide)"
  resize_image "$INPUT" 150 150 "$TMPDIR/wide-inner.png" "false"
  $MAGICK -size 310x150 "xc:$MS_BG" "$TMPDIR/wide-inner.png" \
    -gravity center -composite "$OUTPUT/mstile-310x150.png"
  echo ""
fi

# ── Generate ICO ──────────────────────────────────────────────────────────────
if [[ "$PWA_ONLY" == "false" ]]; then
  echo "🔷 Generating favicon.ico (multi-resolution)..."
  # Create temporary PNGs for ICO
  for ico_size in 16 32 48; do
    resize_image "$INPUT" "$ico_size" "$ico_size" "$TMPDIR/ico-${ico_size}.png" "true"
  done
  $MAGICK "$TMPDIR/ico-16.png" "$TMPDIR/ico-32.png" "$TMPDIR/ico-48.png" "$OUTPUT/favicon.ico"
  echo ""
fi

# ── Generate site.webmanifest ─────────────────────────────────────────────────
if [[ "$NO_MANIFEST" == "false" ]] && ([[ "$MINIMAL" == "false" ]] || [[ "$PWA_ONLY" == "true" ]]); then
  echo "📋 Generating site.webmanifest..."
  cat > "$OUTPUT/site.webmanifest" << MANIFEST
{
  "name": "$SITE_NAME",
  "short_name": "$SITE_NAME",
  "icons": [
    {
      "src": "${PREFIX}android-chrome-192x192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "${PREFIX}android-chrome-512x512.png",
      "sizes": "512x512",
      "type": "image/png"
    },
    {
      "src": "${PREFIX}android-chrome-maskable-192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "maskable"
    },
    {
      "src": "${PREFIX}android-chrome-maskable-512x512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable"
    }
  ],
  "theme_color": "$THEME_COLOR",
  "background_color": "$THEME_COLOR",
  "display": "standalone"
}
MANIFEST
  echo ""
fi

# ── Generate browserconfig.xml ────────────────────────────────────────────────
if [[ "$NO_BROWSERCONFIG" == "false" ]] && [[ "$MINIMAL" == "false" ]] && [[ "$PWA_ONLY" == "false" ]]; then
  echo "📋 Generating browserconfig.xml..."
  MS_TILE_COLOR="${BG}"
  [[ "$MS_TILE_COLOR" == "transparent" ]] && MS_TILE_COLOR="$THEME_COLOR"
  cat > "$OUTPUT/browserconfig.xml" << BCONFIG
<?xml version="1.0" encoding="utf-8"?>
<browserconfig>
  <msapplication>
    <tile>
      <square70x70logo src="${PREFIX}mstile-70x70.png"/>
      <square150x150logo src="${PREFIX}mstile-150x150.png"/>
      <square310x310logo src="${PREFIX}mstile-310x310.png"/>
      <wide310x150logo src="${PREFIX}mstile-310x150.png"/>
      <TileColor>${MS_TILE_COLOR}</TileColor>
    </tile>
  </msapplication>
</browserconfig>
BCONFIG
  echo ""
fi

# ── Generate HTML Snippet ─────────────────────────────────────────────────────
echo "📝 Generating HEAD-SNIPPET.html..."

{
  echo "<!-- Favicon — generated by favicon-generator -->"
  echo "<link rel=\"icon\" type=\"image/x-icon\" href=\"${PREFIX}favicon.ico\">"
  echo "<link rel=\"icon\" type=\"image/png\" sizes=\"32x32\" href=\"${PREFIX}favicon-32x32.png\">"
  echo "<link rel=\"icon\" type=\"image/png\" sizes=\"16x16\" href=\"${PREFIX}favicon-16x16.png\">"
  echo "<link rel=\"apple-touch-icon\" sizes=\"180x180\" href=\"${PREFIX}apple-touch-icon.png\">"

  if [[ "$MINIMAL" == "false" ]] || [[ "$PWA_ONLY" == "true" ]]; then
    echo "<link rel=\"manifest\" href=\"${PREFIX}site.webmanifest\">"
  fi

  if [[ "$MINIMAL" == "false" ]] && [[ "$PWA_ONLY" == "false" ]]; then
    echo "<meta name=\"msapplication-config\" content=\"${PREFIX}browserconfig.xml\">"
  fi

  echo "<meta name=\"theme-color\" content=\"${THEME_COLOR}\">"
} > "$OUTPUT/HEAD-SNIPPET.html"

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
FILE_COUNT=$(find "$OUTPUT" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$OUTPUT" | cut -f1)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Done! Generated $FILE_COUNT files ($TOTAL_SIZE)"
echo "   Output: $OUTPUT/"
echo ""
echo "📋 Next steps:"
echo "   1. Copy files to your project's public/ directory"
echo "   2. Paste contents of HEAD-SNIPPET.html into your <head>"
echo "   3. Test: https://realfavicongenerator.net/favicon_checker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
