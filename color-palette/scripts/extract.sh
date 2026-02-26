#!/usr/bin/env bash
# Color Palette Extractor — Extract dominant colors from images
# Requires: imagemagick, jq, bc

set -euo pipefail

# ─── Defaults ───────────────────────────────────────────────
NUM_COLORS="${PALETTE_DEFAULT_COLORS:-5}"
EXPORT_FORMAT="${PALETTE_DEFAULT_FORMAT:-text}"
OUTPUT_DIR="${PALETTE_OUTPUT_DIR:-.}"
OUTPUT_FILE=""
IMAGE=""
DIR=""
SORT_BY="frequency"
HARMONY=""
CONTRAST=false
NAMES=false
COMPARE_MODE=false
COMPARE_IMAGES=()
STDIN_MODE=false
COLORSPACE="sRGB"
DEPTH=8

# ─── Color name database (nearest match) ───────────────────
declare -A COLOR_NAMES=(
  ["#000000"]="Black" ["#FFFFFF"]="White" ["#FF0000"]="Red"
  ["#00FF00"]="Lime" ["#0000FF"]="Blue" ["#FFFF00"]="Yellow"
  ["#FF00FF"]="Magenta" ["#00FFFF"]="Cyan" ["#808080"]="Gray"
  ["#800000"]="Maroon" ["#808000"]="Olive" ["#008000"]="Green"
  ["#800080"]="Purple" ["#008080"]="Teal" ["#000080"]="Navy"
  ["#C0C0C0"]="Silver" ["#FF6347"]="Tomato" ["#FF4500"]="OrangeRed"
  ["#FFD700"]="Gold" ["#ADFF2F"]="GreenYellow" ["#7FFFD4"]="Aquamarine"
  ["#F0E68C"]="Khaki" ["#DDA0DD"]="Plum" ["#FA8072"]="Salmon"
  ["#E6E6FA"]="Lavender" ["#FFF0F5"]="LavenderBlush" ["#F5F5DC"]="Beige"
  ["#FFE4C4"]="Bisque" ["#FFDEAD"]="NavajoWhite" ["#D2691E"]="Chocolate"
  ["#B22222"]="Firebrick" ["#DC143C"]="Crimson" ["#FF69B4"]="HotPink"
  ["#FF1493"]="DeepPink" ["#4B0082"]="Indigo" ["#6A5ACD"]="SlateBlue"
  ["#7B68EE"]="MediumSlateBlue" ["#4169E1"]="RoyalBlue" ["#1E90FF"]="DodgerBlue"
  ["#87CEEB"]="SkyBlue" ["#20B2AA"]="LightSeaGreen" ["#2E8B57"]="SeaGreen"
  ["#228B22"]="ForestGreen" ["#32CD32"]="LimeGreen" ["#9ACD32"]="YellowGreen"
  ["#DAA520"]="Goldenrod" ["#CD853F"]="Peru" ["#D2B48C"]="Tan"
  ["#BC8F8F"]="RosyBrown" ["#F4A460"]="SandyBrown" ["#A0522D"]="Sienna"
  ["#8B4513"]="SaddleBrown" ["#2F4F4F"]="DarkSlateGray" ["#696969"]="DimGray"
  ["#778899"]="LightSlateGray" ["#708090"]="SlateGray" ["#A9A9A9"]="DarkGray"
)

# ─── Usage ──────────────────────────────────────────────────
usage() {
  cat <<EOF
🎨 Color Palette Extractor

Usage:
  $(basename "$0") --image <file> [options]
  $(basename "$0") --dir <directory> [options]
  $(basename "$0") --compare <img1> <img2> [options]
  ... | $(basename "$0") --stdin [options]

Options:
  --image FILE          Input image file
  --dir DIR             Process all images in directory
  --stdin               Read image from stdin pipe
  --compare IMG1 IMG2   Compare palettes of two images
  --colors N            Number of colors to extract (1-20, default: 5)
  --sort MODE           Sort: frequency (default) | luminance
  --harmony MODE        Generate harmony: complementary | analogous | triadic | split-complementary | all
  --contrast            Check WCAG contrast ratios between colors
  --names               Show nearest CSS color names
  --export FORMAT       Export: text (default) | css | json | tailwind | scss
  --output FILE         Output file path
  --colorspace CS       Color space: sRGB (default) | LAB | HSL
  --depth N             Color depth: 8 (default) | 16

Examples:
  $(basename "$0") --image photo.jpg --colors 5
  $(basename "$0") --image logo.png --colors 8 --export css --output palette.css
  $(basename "$0") --image hero.jpg --harmony all --contrast
  curl -sL url/photo.jpg | $(basename "$0") --stdin --colors 3 --export json
EOF
  exit 0
}

# ─── Argument Parsing ───────────────────────────────────────
[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    --stdin) STDIN_MODE=true; shift ;;
    --compare) COMPARE_MODE=true; COMPARE_IMAGES+=("$2" "$3"); shift 3 ;;
    --colors) NUM_COLORS="$2"; shift 2 ;;
    --sort) SORT_BY="$2"; shift 2 ;;
    --harmony) HARMONY="$2"; shift 2 ;;
    --contrast) CONTRAST=true; shift ;;
    --names) NAMES=true; shift ;;
    --export) EXPORT_FORMAT="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --colorspace) COLORSPACE="$2"; shift 2 ;;
    --depth) DEPTH="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Dependency Check ───────────────────────────────────────
check_deps() {
  local missing=()
  command -v convert &>/dev/null || missing+=("imagemagick")
  command -v jq &>/dev/null || missing+=("jq")
  command -v bc &>/dev/null || missing+=("bc")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ Missing dependencies: ${missing[*]}"
    echo "Install with: sudo apt-get install -y ${missing[*]}"
    exit 1
  fi
}

check_deps

# ─── Core: Extract Colors ──────────────────────────────────
extract_colors() {
  local img="$1"
  local n="$2"

  if [[ ! -f "$img" && "$STDIN_MODE" != true ]]; then
    echo "❌ File not found: $img"
    return 1
  fi

  # Use ImageMagick to quantize and extract dominant colors
  local raw
  raw=$(convert "$img" -colorspace "$COLORSPACE" -depth "$DEPTH" \
    +dither -colors "$n" -format "%c" histogram:info:- 2>/dev/null)

  # Parse histogram output: "  12345: (R,G,B) #HEXHEX srgb(...)"
  local -a hexes=()
  local -a counts=()
  local total=0

  while IFS= read -r line; do
    local count hex
    count=$(echo "$line" | sed -E 's/^ *([0-9]+):.*/\1/')
    hex=$(echo "$line" | grep -oE '#[0-9A-Fa-f]{6}' | head -1)
    if [[ -n "$hex" && -n "$count" ]]; then
      hexes+=("${hex^^}")
      counts+=("$count")
      total=$((total + count))
    fi
  done <<< "$raw"

  # Sort by frequency (default) or luminance
  if [[ "$SORT_BY" == "luminance" ]]; then
    # Sort by luminance (brightness)
    local -a sorted_indices=()
    for i in "${!hexes[@]}"; do
      local h="${hexes[$i]}"
      local r=$((16#${h:1:2}))
      local g=$((16#${h:3:2}))
      local b=$((16#${h:5:2}))
      local lum=$(echo "0.299*$r + 0.587*$g + 0.114*$b" | bc)
      echo "$i $lum"
    done | sort -k2 -rn | while read idx _; do echo "$idx"; done | {
      local -a new_hexes=() new_counts=()
      while read idx; do
        new_hexes+=("${hexes[$idx]}")
        new_counts+=("${counts[$idx]}")
      done
      hexes=("${new_hexes[@]}")
      counts=("${new_counts[@]}")
    }
  fi

  # Output based on format
  case "$EXPORT_FORMAT" in
    text) output_text "$img" "$total" "${hexes[@]}" -- "${counts[@]}" ;;
    css)  output_css "${hexes[@]}" ;;
    json) output_json "$img" "$total" "${hexes[@]}" -- "${counts[@]}" ;;
    tailwind) output_tailwind "${hexes[@]}" ;;
    scss) output_scss "${hexes[@]}" ;;
    *) echo "Unknown format: $EXPORT_FORMAT"; exit 1 ;;
  esac

  # Additional features
  if [[ "$CONTRAST" == true ]]; then
    check_contrast "${hexes[@]}"
  fi

  if [[ -n "$HARMONY" ]]; then
    generate_harmony "$HARMONY" "${hexes[0]}"
  fi
}

# ─── Output: Text ──────────────────────────────────────────
output_text() {
  local img="$1" total="$2"
  shift 2
  local -a hexes=() counts=()
  local sep=false
  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then sep=true; continue; fi
    if $sep; then counts+=("$arg"); else hexes+=("$arg"); fi
  done

  echo ""
  echo "🎨 Dominant Colors from $(basename "$img")"
  echo "─────────────────────────────────"

  for i in "${!hexes[@]}"; do
    local hex="${hexes[$i]}"
    local pct
    if [[ $total -gt 0 ]]; then
      pct=$(echo "scale=1; ${counts[$i]} * 100 / $total" | bc)
    else
      pct="0.0"
    fi

    local name_str=""
    if [[ "$NAMES" == true ]]; then
      name_str=" $(nearest_color_name "$hex")"
    fi

    printf "  %d. %s  ██████  (%s%%)%s\n" $((i+1)) "$hex" "$pct" "$name_str"
  done
  echo ""
}

# ─── Output: CSS ────────────────────────────────────────────
output_css() {
  local -a hexes=("$@")
  local labels=("primary" "secondary" "accent" "background" "success" "warning" "info" "muted")
  local out=":root {\n"

  for i in "${!hexes[@]}"; do
    local label="${labels[$i]:-color-$((i+1))}"
    out+="  --color-${label}: ${hexes[$i]};\n"
  done
  out+="}\n"

  if [[ -n "$OUTPUT_FILE" ]]; then
    echo -e "$out" > "$OUTPUT_FILE"
    echo "✅ CSS palette written to $OUTPUT_FILE"
  else
    echo -e "$out"
  fi
}

# ─── Output: JSON ───────────────────────────────────────────
output_json() {
  local img="$1" total="$2"
  shift 2
  local -a hexes=() counts=()
  local sep=false
  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then sep=true; continue; fi
    if $sep; then counts+=("$arg"); else hexes+=("$arg"); fi
  done

  local json='{"source":"'"$(basename "$img")"'","extracted_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","palette":['

  for i in "${!hexes[@]}"; do
    local hex="${hexes[$i]}"
    local r=$((16#${hex:1:2}))
    local g=$((16#${hex:3:2}))
    local b=$((16#${hex:5:2}))
    local pct="0.0"
    [[ $total -gt 0 ]] && pct=$(echo "scale=1; ${counts[$i]} * 100 / $total" | bc)

    [[ $i -gt 0 ]] && json+=','
    json+='{"hex":"'"$hex"'","rgb":['"$r"','"$g"','"$b"'],"percentage":'"$pct"'}'
  done

  json+=']}'

  if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$json" | jq . > "$OUTPUT_FILE"
    echo "✅ JSON palette written to $OUTPUT_FILE"
  else
    echo "$json" | jq .
  fi
}

# ─── Output: Tailwind ──────────────────────────────────────
output_tailwind() {
  local -a hexes=("$@")
  local labels=("primary" "secondary" "accent" "background" "success" "warning" "info" "muted")
  local out="/** @type {import('tailwindcss').Config} */\nmodule.exports = {\n  theme: {\n    extend: {\n      colors: {\n"

  for i in "${!hexes[@]}"; do
    local label="${labels[$i]:-color$((i+1))}"
    out+="        '${label}': '${hexes[$i]}',\n"
  done

  out+="      },\n    },\n  },\n};\n"

  if [[ -n "$OUTPUT_FILE" ]]; then
    echo -e "$out" > "$OUTPUT_FILE"
    echo "✅ Tailwind config written to $OUTPUT_FILE"
  else
    echo -e "$out"
  fi
}

# ─── Output: SCSS ───────────────────────────────────────────
output_scss() {
  local -a hexes=("$@")
  local labels=("primary" "secondary" "accent" "background" "success" "warning" "info" "muted")
  local out=""

  for i in "${!hexes[@]}"; do
    local label="${labels[$i]:-color-$((i+1))}"
    out+="\$${label}: ${hexes[$i]};\n"
  done

  if [[ -n "$OUTPUT_FILE" ]]; then
    echo -e "$out" > "$OUTPUT_FILE"
    echo "✅ SCSS variables written to $OUTPUT_FILE"
  else
    echo -e "$out"
  fi
}

# ─── Contrast Check (WCAG 2.1) ─────────────────────────────
hex_to_luminance() {
  local hex="$1"
  local r=$((16#${hex:1:2}))
  local g=$((16#${hex:3:2}))
  local b=$((16#${hex:5:2}))

  # sRGB to linear
  local rl=$(echo "scale=6; r=$r/255; if(r<=0.03928) r/12.92 else e(2.4*l((r+0.055)/1.055))" | bc -l)
  local gl=$(echo "scale=6; g=$g/255; if(g<=0.03928) g/12.92 else e(2.4*l((g+0.055)/1.055))" | bc -l)
  local bl=$(echo "scale=6; b=$b/255; if(b<=0.03928) b/12.92 else e(2.4*l((b+0.055)/1.055))" | bc -l)

  echo "scale=6; 0.2126*$rl + 0.7152*$gl + 0.0722*$bl" | bc -l
}

check_contrast() {
  local -a hexes=("$@")
  echo ""
  echo "Contrast Ratios (WCAG 2.1)"
  echo "──────────────────────────"

  for i in "${!hexes[@]}"; do
    for j in "${!hexes[@]}"; do
      [[ $j -le $i ]] && continue
      local l1 l2 ratio
      l1=$(hex_to_luminance "${hexes[$i]}")
      l2=$(hex_to_luminance "${hexes[$j]}")

      # Ensure l1 >= l2
      if (( $(echo "$l2 > $l1" | bc -l) )); then
        local tmp="$l1"; l1="$l2"; l2="$tmp"
      fi

      ratio=$(echo "scale=1; ($l1 + 0.05) / ($l2 + 0.05)" | bc -l)

      local grade
      if (( $(echo "$ratio >= 7" | bc -l) )); then
        grade="✅ AAA"
      elif (( $(echo "$ratio >= 4.5" | bc -l) )); then
        grade="✅ AA"
      elif (( $(echo "$ratio >= 3" | bc -l) )); then
        grade="⚠️  AA large text only"
      else
        grade="❌ Fail"
      fi

      printf "  %s vs %s  →  %s:1 %s\n" "${hexes[$i]}" "${hexes[$j]}" "$ratio" "$grade"
    done
  done
  echo ""
}

# ─── Color Harmony ──────────────────────────────────────────
hex_to_hsl() {
  local hex="$1"
  local r=$((16#${hex:1:2}))
  local g=$((16#${hex:3:2}))
  local b=$((16#${hex:5:2}))

  python3 -c "
import colorsys
r,g,b = $r/255, $g/255, $b/255
h,l,s = colorsys.rgb_to_hls(r,g,b)
print(f'{h*360:.1f} {s*100:.1f} {l*100:.1f}')
" 2>/dev/null || echo "0 0 50"
}

hsl_to_hex() {
  local h="$1" s="$2" l="$3"
  python3 -c "
import colorsys
h,s,l = $h/360, $s/100, $l/100
r,g,b = colorsys.hls_to_rgb(h,l,s)
print(f'#{int(r*255):02X}{int(g*255):02X}{int(b*255):02X}')
" 2>/dev/null || echo "#808080"
}

generate_harmony() {
  local mode="$1" base_hex="$2"
  local hsl
  hsl=$(hex_to_hsl "$base_hex")
  local h s l
  read h s l <<< "$hsl"

  echo "🎨 Color Harmonies (base: $base_hex)"
  echo "────────────────────────────────────"

  if [[ "$mode" == "complementary" || "$mode" == "all" ]]; then
    local comp_h=$(echo "scale=1; ($h + 180) % 360" | bc)
    local comp=$(hsl_to_hex "$comp_h" "$s" "$l")
    echo "  Complementary: $base_hex ↔ $comp"
  fi

  if [[ "$mode" == "analogous" || "$mode" == "all" ]]; then
    local a1_h=$(echo "scale=1; ($h + 30) % 360" | bc)
    local a2_h=$(echo "scale=1; ($h + 330) % 360" | bc)
    local a1=$(hsl_to_hex "$a1_h" "$s" "$l")
    local a2=$(hsl_to_hex "$a2_h" "$s" "$l")
    echo "  Analogous: $a2 ← $base_hex → $a1"
  fi

  if [[ "$mode" == "triadic" || "$mode" == "all" ]]; then
    local t1_h=$(echo "scale=1; ($h + 120) % 360" | bc)
    local t2_h=$(echo "scale=1; ($h + 240) % 360" | bc)
    local t1=$(hsl_to_hex "$t1_h" "$s" "$l")
    local t2=$(hsl_to_hex "$t2_h" "$s" "$l")
    echo "  Triadic: $base_hex ↔ $t1 ↔ $t2"
  fi

  if [[ "$mode" == "split-complementary" || "$mode" == "all" ]]; then
    local sc1_h=$(echo "scale=1; ($h + 150) % 360" | bc)
    local sc2_h=$(echo "scale=1; ($h + 210) % 360" | bc)
    local sc1=$(hsl_to_hex "$sc1_h" "$s" "$l")
    local sc2=$(hsl_to_hex "$sc2_h" "$s" "$l")
    echo "  Split-complementary: $base_hex ↔ $sc1 / $sc2"
  fi

  echo ""
}

# ─── Nearest Color Name ────────────────────────────────────
nearest_color_name() {
  local hex="$1"
  local r=$((16#${hex:1:2}))
  local g=$((16#${hex:3:2}))
  local b=$((16#${hex:5:2}))

  local best_name="Unknown" best_dist=999999

  for ref_hex in "${!COLOR_NAMES[@]}"; do
    local rr=$((16#${ref_hex:1:2}))
    local rg=$((16#${ref_hex:3:2}))
    local rb=$((16#${ref_hex:5:2}))
    local dist=$(( (r-rr)*(r-rr) + (g-rg)*(g-rg) + (b-rb)*(b-rb) ))
    if [[ $dist -lt $best_dist ]]; then
      best_dist=$dist
      best_name="${COLOR_NAMES[$ref_hex]}"
    fi
  done

  echo "($best_name)"
}

# ─── Main Execution ────────────────────────────────────────
if [[ "$STDIN_MODE" == true ]]; then
  TMP=$(mktemp /tmp/palette-XXXXXX.png)
  cat > "$TMP"
  extract_colors "$TMP" "$NUM_COLORS"
  rm -f "$TMP"
elif [[ -n "$DIR" ]]; then
  for img in $(find "$DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.tiff' \) 2>/dev/null); do
    [[ -f "$img" ]] || continue
    extract_colors "$img" "$NUM_COLORS"
  done
elif [[ "$COMPARE_MODE" == true ]]; then
  echo "📊 Palette Comparison"
  echo "═══════════════════════"
  for img in "${COMPARE_IMAGES[@]}"; do
    extract_colors "$img" "$NUM_COLORS"
  done
elif [[ -n "$IMAGE" ]]; then
  extract_colors "$IMAGE" "$NUM_COLORS"
else
  echo "❌ No input specified. Use --image, --dir, --stdin, or --compare."
  exit 1
fi
