#!/bin/bash
# Webfont Generator — Convert TTF/OTF to WOFF/WOFF2 with CSS generation
set -euo pipefail

PYTHON_BIN="${PYTHON_BIN:-python3}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Defaults
INPUT=""
OUTPUT="./webfonts"
FORMATS="woff2,woff"
GENERATE_CSS=true
GENERATE_SPECIMEN=false
SUBSET=""
FONT_DISPLAY="swap"
URL_PREFIX="./"
INFO_ONLY=false

usage() {
  cat <<EOF
Webfont Generator — Convert desktop fonts to optimized web formats

Usage: bash $0 [OPTIONS]

Options:
  --input PATH        Input font file or directory (required)
  --output DIR        Output directory (default: ./webfonts)
  --formats LIST      Comma-separated: woff2,woff (default: woff2,woff)
  --css               Generate @font-face CSS (default: on)
  --no-css            Skip CSS generation
  --specimen          Generate HTML specimen page
  --subset RANGE      Subset fonts (latin, latin-ext, cyrillic, greek, custom:U+XXXX-XXXX)
  --font-display VAL  CSS font-display value (default: swap)
  --prefix URL        URL prefix for CSS font paths (default: ./)
  --info              Show font metadata only
  --help              Show this help
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --input) INPUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --formats) FORMATS="$2"; shift 2 ;;
    --css) GENERATE_CSS=true; shift ;;
    --no-css) GENERATE_CSS=false; shift ;;
    --specimen) GENERATE_SPECIMEN=true; shift ;;
    --subset) SUBSET="$2"; shift 2 ;;
    --font-display) FONT_DISPLAY="$2"; shift 2 ;;
    --prefix) URL_PREFIX="$2"; shift 2 ;;
    --info) INFO_ONLY=true; shift ;;
    --help) usage ;;
    *) echo "[webfont] ❌ Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$INPUT" ]]; then
  echo "[webfont] ❌ --input is required"
  usage
fi

# Check dependencies
check_deps() {
  if ! command -v "$PYTHON_BIN" &>/dev/null; then
    echo "[webfont] ❌ python3 not found. Install Python 3.8+"
    exit 1
  fi
  if ! "$PYTHON_BIN" -c "from fontTools.ttLib import TTFont" 2>/dev/null; then
    echo "[webfont] ❌ fonttools not installed. Run: pip3 install fonttools brotli zopfli"
    exit 1
  fi
}

check_deps

# Collect font files
FONT_FILES=()
if [[ -d "$INPUT" ]]; then
  while IFS= read -r -d '' f; do
    FONT_FILES+=("$f")
  done < <(find "$INPUT" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -print0 | sort -z)
elif [[ -f "$INPUT" ]]; then
  FONT_FILES=("$INPUT")
else
  echo "[webfont] ❌ Input not found: $INPUT"
  exit 1
fi

if [[ ${#FONT_FILES[@]} -eq 0 ]]; then
  echo "[webfont] ❌ No .ttf or .otf files found in $INPUT"
  exit 1
fi

echo "[webfont] Found ${#FONT_FILES[@]} font file(s)"

# Info mode
if $INFO_ONLY; then
  "$PYTHON_BIN" - "${FONT_FILES[@]}" <<'PYEOF'
import sys
from fontTools.ttLib import TTFont

for path in sys.argv[1:]:
    try:
        font = TTFont(path)
        name = font['name']
        def get_name(nid):
            rec = name.getName(nid, 3, 1, 0x0409) or name.getName(nid, 1, 0, 0)
            return str(rec) if rec else "Unknown"

        import os
        size = os.path.getsize(path)
        glyph_count = len(font.getGlyphOrder())

        # Detect weight from OS/2 table
        weight = 400
        if 'OS/2' in font:
            weight = font['OS/2'].usWeightClass

        print(f"\n{'='*50}")
        print(f"File: {os.path.basename(path)}")
        print(f"Family: {get_name(1)}")
        print(f"Style: {get_name(2)}")
        print(f"Full Name: {get_name(4)}")
        print(f"Weight: {weight}")
        print(f"Version: {get_name(5)}")
        print(f"Glyphs: {glyph_count}")
        print(f"File size: {size:,} bytes")

        # Unicode ranges
        if 'cmap' in font:
            cmap = font.getBestCmap()
            if cmap:
                codes = sorted(cmap.keys())
                print(f"Unicode codepoints: {len(codes)} (U+{codes[0]:04X}..U+{codes[-1]:04X})")

        font.close()
    except Exception as e:
        print(f"[webfont] ❌ Error reading {path}: {e}")
PYEOF
  exit 0
fi

# Create output directory
mkdir -p "$OUTPUT"

# Build subset arg for Python
SUBSET_ARG=""
if [[ -n "$SUBSET" ]]; then
  case "$SUBSET" in
    latin) SUBSET_ARG="U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+2000-206F,U+2074,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD" ;;
    latin-ext) SUBSET_ARG="U+0100-024F,U+0259,U+1E00-1EFF,U+2020,U+20A0-20AB,U+20AD-20CF,U+2113,U+2C60-2C7F,U+A720-A7FF" ;;
    cyrillic) SUBSET_ARG="U+0301,U+0400-045F,U+0490-0491,U+04B0-04B1,U+2116" ;;
    greek) SUBSET_ARG="U+0370-03FF" ;;
    custom:*) SUBSET_ARG="${SUBSET#custom:}" ;;
    *) echo "[webfont] ❌ Unknown subset: $SUBSET (use: latin, latin-ext, cyrillic, greek, custom:U+XXXX-XXXX)"; exit 1 ;;
  esac
fi

# Convert fonts
"$PYTHON_BIN" - "$OUTPUT" "$FORMATS" "$SUBSET_ARG" "${FONT_FILES[@]}" <<'PYEOF'
import sys, os, json

output_dir = sys.argv[1]
formats = sys.argv[2].split(",")
subset_ranges = sys.argv[3]
font_paths = sys.argv[4:]

from fontTools.ttLib import TTFont
from fontTools import subset as ft_subset

results = []

for path in font_paths:
    try:
        basename = os.path.splitext(os.path.basename(path))[0]
        original_size = os.path.getsize(path)

        # Load font
        font = TTFont(path)

        # Get metadata
        name_table = font['name']
        def get_name(nid):
            rec = name_table.getName(nid, 3, 1, 0x0409) or name_table.getName(nid, 1, 0, 0)
            return str(rec) if rec else ""

        family = get_name(1) or basename
        style = get_name(2) or "Regular"
        weight = font['OS/2'].usWeightClass if 'OS/2' in font else 400

        # Determine italic
        is_italic = 'italic' in style.lower() or 'oblique' in style.lower()

        # Apply subsetting if requested
        if subset_ranges:
            subsetter = ft_subset.Subsetter()
            # Parse unicode ranges
            codepoints = set()
            for r in subset_ranges.split(","):
                r = r.strip().replace("U+", "").replace("u+", "")
                if "-" in r:
                    start, end = r.split("-")
                    for cp in range(int(start, 16), int(end, 16) + 1):
                        codepoints.add(cp)
                else:
                    codepoints.add(int(r, 16))
            subsetter.populate(unicodes=codepoints)
            subsetter.subset(font)

        generated = []
        for fmt in formats:
            fmt = fmt.strip()
            if fmt == "woff2":
                out_path = os.path.join(output_dir, f"{basename}.woff2")
                font.flavor = "woff2"
                font.save(out_path)
                font.flavor = None  # Reset for next format
                out_size = os.path.getsize(out_path)
                reduction = round((1 - out_size / original_size) * 100)
                print(f"[webfont] ✅ {basename}.woff2 — {out_size:,} bytes ({reduction}% reduction)")
                generated.append({"format": "woff2", "file": f"{basename}.woff2", "size": out_size})

            elif fmt == "woff":
                out_path = os.path.join(output_dir, f"{basename}.woff")
                font.flavor = "woff"
                font.save(out_path)
                font.flavor = None
                out_size = os.path.getsize(out_path)
                reduction = round((1 - out_size / original_size) * 100)
                print(f"[webfont] ✅ {basename}.woff — {out_size:,} bytes ({reduction}% reduction)")
                generated.append({"format": "woff", "file": f"{basename}.woff", "size": out_size})

        font.close()

        results.append({
            "basename": basename,
            "family": family,
            "style": style,
            "weight": weight,
            "italic": is_italic,
            "generated": generated
        })

    except Exception as e:
        print(f"[webfont] ❌ Error converting {path}: {e}")

# Write results for CSS generation
with open(os.path.join(output_dir, ".fontmeta.json"), "w") as f:
    json.dump(results, f, indent=2)

print(f"\n[webfont] Converted {len(results)} font(s)")
PYEOF

# Generate CSS
if $GENERATE_CSS && [[ -f "$OUTPUT/.fontmeta.json" ]]; then
  "$PYTHON_BIN" - "$OUTPUT" "$FONT_DISPLAY" "$URL_PREFIX" <<'PYEOF'
import sys, os, json

output_dir = sys.argv[1]
font_display = sys.argv[2]
url_prefix = sys.argv[3]

with open(os.path.join(output_dir, ".fontmeta.json")) as f:
    results = json.load(f)

css_lines = ["/* Generated by Webfont Generator */", ""]

for entry in results:
    family = entry["family"]
    weight = entry["weight"]
    style = "italic" if entry["italic"] else "normal"
    sources = []
    for gen in entry["generated"]:
        sources.append(f"url('{url_prefix}{gen['file']}') format('{gen['format']}')")

    if not sources:
        continue

    src = ",\n       ".join(sources)
    css_lines.append(f"""@font-face {{
  font-family: '{family}';
  font-style: {style};
  font-weight: {weight};
  font-display: {font_display};
  src: {src};
}}
""")

css_path = os.path.join(output_dir, "fonts.css")
with open(css_path, "w") as f:
    f.write("\n".join(css_lines))

print(f"[webfont] ✅ CSS written to {css_path}")
PYEOF
fi

# Generate specimen page
if $GENERATE_SPECIMEN && [[ -f "$OUTPUT/.fontmeta.json" ]]; then
  "$PYTHON_BIN" - "$OUTPUT" <<'PYEOF'
import sys, os, json

output_dir = sys.argv[1]

with open(os.path.join(output_dir, ".fontmeta.json")) as f:
    results = json.load(f)

families = sorted(set(r["family"] for r in results))

html = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Font Specimen</title>
<link rel="stylesheet" href="fonts.css">
<style>
  body { max-width: 800px; margin: 2rem auto; padding: 0 1rem; background: #fafafa; color: #333; font-family: system-ui; }
  h1 { border-bottom: 2px solid #333; padding-bottom: 0.5rem; }
  .specimen { margin: 2rem 0; padding: 1.5rem; background: white; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
  .specimen h2 { margin-top: 0; color: #666; font-family: system-ui; font-size: 0.9rem; text-transform: uppercase; letter-spacing: 0.05em; }
  .sample { margin: 0.5rem 0; }
  .s-xl { font-size: 3rem; line-height: 1.2; }
  .s-lg { font-size: 1.5rem; line-height: 1.4; }
  .s-md { font-size: 1rem; line-height: 1.6; }
  .s-sm { font-size: 0.875rem; line-height: 1.6; color: #555; }
  .chars { font-size: 1.25rem; letter-spacing: 0.05em; word-break: break-all; color: #444; }
</style>
</head>
<body>
<h1>Font Specimen</h1>
"""

pangram = "The quick brown fox jumps over the lazy dog"
chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%&*().,;:?/"

for family in families:
    weights = sorted(set((r["weight"], r["style"]) for r in results if r["family"] == family))
    html += f"""<div class="specimen">
<h2>{family}</h2>
"""
    for weight, style in weights:
        italic = "italic" if "italic" in style.lower() else "normal"
        html += f"""<div class="sample s-xl" style="font-family:'{family}';font-weight:{weight};font-style:{italic}">{pangram}</div>
<div class="sample s-lg" style="font-family:'{family}';font-weight:{weight};font-style:{italic}">{pangram}</div>
<div class="sample s-md" style="font-family:'{family}';font-weight:{weight};font-style:{italic}">Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump!</div>
<div class="sample chars" style="font-family:'{family}';font-weight:{weight};font-style:{italic}">{chars}</div>
<hr style="border:none;border-top:1px solid #eee;margin:1rem 0">
"""
    html += "</div>\n"

html += """</body>
</html>"""

spec_path = os.path.join(output_dir, "specimen.html")
with open(spec_path, "w") as f:
    f.write(html)

print(f"[webfont] ✅ Specimen page written to {spec_path}")
PYEOF
fi

# Cleanup metadata file
rm -f "$OUTPUT/.fontmeta.json"

echo "[webfont] Done!"
