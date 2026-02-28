#!/bin/bash
# Font Installer — Download, install, and manage system fonts
# Supports Google Fonts API + local files

set -euo pipefail

FONT_DIR="${FONT_DIR:-$HOME/.local/share/fonts}"
GOOGLE_FONTS_API="https://fonts.google.com/download"
GOOGLE_FONTS_META="https://raw.githubusercontent.com/google/fonts/main/tags/all/families.csv"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/font-installer"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}ℹ${NC} $*"; }
ok()    { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
err()   { echo -e "${RED}❌${NC} $*" >&2; }

mkdir -p "$FONT_DIR" "$CACHE_DIR"

# Check dependencies
check_deps() {
  local missing=()
  for cmd in curl unzip fc-cache fc-list; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    err "Missing dependencies: ${missing[*]}"
    echo "Install with: sudo apt-get install curl unzip fontconfig"
    exit 1
  fi
}

# Refresh font cache
refresh_cache() {
  fc-cache -f "$FONT_DIR" 2>/dev/null
  ok "Font cache updated"
}

# Download and install a Google Font
install_google_font() {
  local family="$1"
  local dest="$FONT_DIR/${family// /}"
  local tmpdir
  tmpdir=$(mktemp -d)

  if [[ -d "$dest" ]] && [[ "$(ls -A "$dest" 2>/dev/null)" ]]; then
    warn "$family is already installed at $dest"
    return 0
  fi

  info "Downloading $family..."

  # Convert family name to google/fonts repo path format
  # e.g. "Fira Code" -> lowercase "firacode", then try ofl/firacode, apache/firacode
  local slug
  slug=$(echo "${family}" | tr '[:upper:]' '[:lower:]' | tr -d ' ')

  local downloaded=false

  # Try downloading from google/fonts GitHub repo (most reliable)
  for license_dir in ofl apache ufl; do
    local repo_url="https://github.com/google/fonts/raw/main/${license_dir}/${slug}"
    # First check if the directory exists by fetching a known file pattern
    local listing_url="https://api.github.com/repos/google/fonts/contents/${license_dir}/${slug}"
    local listing
    listing=$(curl -sL "$listing_url" 2>/dev/null)

    if echo "$listing" | grep -q '"name"'; then
      # Extract .ttf file URLs
      local ttf_files
      ttf_files=$(echo "$listing" | grep -o '"download_url": "[^"]*\.ttf"' | sed 's/"download_url": "//;s/"$//')

      if [[ -z "$ttf_files" ]]; then
        # Check for static directory
        local static_url="https://api.github.com/repos/google/fonts/contents/${license_dir}/${slug}/static"
        local static_listing
        static_listing=$(curl -sL "$static_url" 2>/dev/null)
        ttf_files=$(echo "$static_listing" | grep -o '"download_url": "[^"]*\.ttf"' | sed 's/"download_url": "//;s/"$//')
      fi

      if [[ -n "$ttf_files" ]]; then
        mkdir -p "$dest"
        local count=0
        while IFS= read -r url; do
          [[ -z "$url" ]] && continue
          local fname
          fname=$(basename "$url")
          if curl -sL "$url" -o "$dest/$fname" 2>/dev/null; then
            ((count++))
          fi
        done <<< "$ttf_files"

        if [[ $count -gt 0 ]]; then
          downloaded=true
          ok "Downloaded $family ($count variants)"
          ok "Installed to $dest/"
          break
        fi
      fi
    fi
  done

  rm -rf "$tmpdir"

  if [[ "$downloaded" == "false" ]]; then
    err "Failed to download $family — not found in Google Fonts repo"
    err "Try searching: font-installer.sh search \"$family\""
    return 1
  fi
}

# Install from local file
install_local_file() {
  local src="$1"
  if [[ ! -f "$src" ]]; then
    err "File not found: $src"
    return 1
  fi

  local ext="${src##*.}"
  local basename
  basename=$(basename "$src")
  local family="${basename%.*}"

  case "$ext" in
    ttf|otf|woff2)
      local dest="$FONT_DIR/$family"
      mkdir -p "$dest"
      cp "$src" "$dest/"
      ok "Installed $basename to $dest/"
      ;;
    zip)
      install_zip "$src"
      ;;
    *)
      err "Unsupported format: .$ext (use .ttf, .otf, .woff2, or .zip)"
      return 1
      ;;
  esac
}

# Install from zip
install_zip() {
  local src="$1"
  local tmpdir
  tmpdir=$(mktemp -d)

  if ! unzip -qo "$src" -d "$tmpdir" 2>/dev/null; then
    err "Failed to extract $src"
    rm -rf "$tmpdir"
    return 1
  fi

  local count=0
  while IFS= read -r -d '' font; do
    local basename
    basename=$(basename "$font")
    local family="${basename%.*}"
    local dest="$FONT_DIR/$family"
    mkdir -p "$dest"
    cp "$font" "$dest/"
    ((count++))
  done < <(find "$tmpdir" -type f \( -name "*.ttf" -o -name "*.otf" \) -print0)

  rm -rf "$tmpdir"
  ok "Installed $count fonts from $(basename "$src")"
}

# Install all fonts from a directory
install_dir() {
  local srcdir="$1"
  if [[ ! -d "$srcdir" ]]; then
    err "Directory not found: $srcdir"
    return 1
  fi

  local count=0
  while IFS= read -r -d '' font; do
    install_local_file "$font"
    ((count++))
  done < <(find "$srcdir" -type f \( -name "*.ttf" -o -name "*.otf" -o -name "*.woff2" \) -print0)

  if [[ $count -eq 0 ]]; then
    warn "No font files found in $srcdir"
  else
    ok "Installed $count fonts from $srcdir"
  fi
}

# Ensure we have a cached font list
ensure_font_list() {
  local cache_file="$CACHE_DIR/google-fonts-list.txt"
  local cache_age=604800  # 7 days

  if [[ ! -f "$cache_file" ]] || [[ $(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) )) -gt $cache_age ]]; then
    info "Fetching Google Fonts catalog..."
    # Use the Google Fonts GitHub metadata
    curl -sL "https://fonts.google.com/metadata/fonts" -o "$CACHE_DIR/google-fonts-meta.json" 2>/dev/null

    if command -v jq &>/dev/null && [[ -s "$CACHE_DIR/google-fonts-meta.json" ]]; then
      jq -r '.familyMetadataList[] | .family + "|" + .category + "|" + (.fonts // {} | keys | length | tostring)' \
        "$CACHE_DIR/google-fonts-meta.json" > "$cache_file" 2>/dev/null || true
    fi

    # Fallback: use a simple list if jq/API fails
    if [[ ! -s "$cache_file" ]]; then
      curl -sL "https://raw.githubusercontent.com/google/fonts/main/tags/all/families.csv" \
        -o "$cache_file" 2>/dev/null || true
    fi
  fi

  echo "$cache_file"
}

# Search Google Fonts
search_fonts() {
  local query="$1"
  local cache_file
  cache_file=$(ensure_font_list)

  if [[ ! -s "$cache_file" ]]; then
    err "Failed to fetch Google Fonts catalog"
    return 1
  fi

  echo -e "${BLUE}🔍 Results for \"$query\":${NC}"
  grep -i "$query" "$cache_file" | head -20 | while IFS='|' read -r family category styles _rest; do
    if [[ -n "$category" ]]; then
      echo "  $family ($styles variants) — $category"
    else
      echo "  $family"
    fi
  done
}

# Browse by category
browse_fonts() {
  local category="$1"
  local cache_file
  cache_file=$(ensure_font_list)

  echo -e "${BLUE}📂 Google Fonts — $category:${NC}"
  grep -i "|${category}|" "$cache_file" | head -30 | while IFS='|' read -r family cat styles _rest; do
    echo "  $family ($styles variants)"
  done
}

# Font info
font_info() {
  local family="$1"
  local cache_file
  cache_file=$(ensure_font_list)

  grep -i "^${family}" "$cache_file" | head -5 | while IFS='|' read -r fam category styles _rest; do
    echo -e "📝 $fam"
    echo "   Category: $category"
    echo "   Variants: $styles"
  done

  # Also check if locally installed
  echo ""
  check_font "$family" 2>/dev/null || true
}

# List installed user fonts
list_fonts() {
  echo -e "${BLUE}📋 Installed fonts (user — $FONT_DIR):${NC}"
  if [[ ! -d "$FONT_DIR" ]] || [[ -z "$(ls -A "$FONT_DIR" 2>/dev/null)" ]]; then
    warn "No user-installed fonts found"
    return 0
  fi

  for dir in "$FONT_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    local family
    family=$(basename "$dir")
    local count
    count=$(find "$dir" -type f \( -name "*.ttf" -o -name "*.otf" \) 2>/dev/null | wc -l)
    if [[ $count -gt 0 ]]; then
      local variants
      variants=$(find "$dir" -type f \( -name "*.ttf" -o -name "*.otf" \) -exec basename {} \; | sed 's/\.\(ttf\|otf\)$//' | tr '\n' ', ' | sed 's/,$//')
      echo "  $family ($count variants): $variants"
    fi
  done
}

# List all system fonts matching pattern
list_all() {
  local pattern="${1:-}"
  echo -e "${BLUE}📋 System fonts${pattern:+ matching \"$pattern\"}:${NC}"
  if [[ -n "$pattern" ]]; then
    fc-list | grep -i "$pattern" | sort | head -50
  else
    fc-list --format="%{family}\n" | sort -u | head -50
    echo "  ... (showing first 50, use 'list-all <pattern>' to filter)"
  fi
}

# Remove a font family
remove_font() {
  local family="$1"
  local dir="$FONT_DIR/${family// /}"

  if [[ ! -d "$dir" ]]; then
    # Try case-insensitive match
    local match
    match=$(find "$FONT_DIR" -maxdepth 1 -type d -iname "${family// /}" 2>/dev/null | head -1)
    if [[ -n "$match" ]]; then
      dir="$match"
    else
      err "Font not found: $family (looked in $FONT_DIR)"
      return 1
    fi
  fi

  rm -rf "$dir"
  refresh_cache
  ok "Removed $family"
}

# Check if font is installed
check_font() {
  local family="$1"
  local slug="${family// /}"
  if fc-list | grep -qi "$family"; then
    ok "$family is installed"
    fc-list | grep -i "$family" | head -5
  elif [[ -d "$FONT_DIR/$slug" ]] && [[ "$(ls -A "$FONT_DIR/$slug" 2>/dev/null)" ]]; then
    ok "$family is installed (user dir: $FONT_DIR/$slug)"
    ls "$FONT_DIR/$slug/"
  else
    warn "$family is NOT installed"
    return 1
  fi
}

# Install from list file
install_list() {
  local listfile="$1"
  if [[ ! -f "$listfile" ]]; then
    err "File not found: $listfile"
    return 1
  fi

  local count=0
  while IFS= read -r font || [[ -n "$font" ]]; do
    font=$(echo "$font" | xargs)  # trim whitespace
    [[ -z "$font" || "$font" == \#* ]] && continue
    install_google_font "$font" && ((count++)) || true
  done < "$listfile"

  refresh_cache
  ok "Installed $count fonts from $listfile"
}

# Font packs
install_pack() {
  local pack="$1"
  local fonts=()

  case "$pack" in
    dev|developer)
      fonts=("Fira Code" "JetBrains Mono" "Source Code Pro" "Cascadia Code" "Hack")
      ;;
    design|ui)
      fonts=("Inter" "Roboto" "Open Sans" "Lato" "Montserrat" "Poppins")
      ;;
    serif)
      fonts=("Merriweather" "Lora" "Playfair Display" "Crimson Text" "Libre Baskerville")
      ;;
    handwriting)
      fonts=("Caveat" "Dancing Script" "Pacifico" "Indie Flower" "Great Vibes")
      ;;
    *)
      err "Unknown pack: $pack"
      echo "Available packs: dev, design, serif, handwriting"
      return 1
      ;;
  esac

  info "Installing $pack font pack (${#fonts[@]} fonts)..."
  for font in "${fonts[@]}"; do
    install_google_font "$font" || true
  done
  refresh_cache
}

# Install by Google Fonts category
install_category() {
  local category="$1"
  local limit="${2:-10}"
  local cache_file
  cache_file=$(ensure_font_list)

  info "Installing top $limit $category fonts..."

  grep -i "|${category}|" "$cache_file" | head -"$limit" | while IFS='|' read -r family _rest; do
    [[ -n "$family" ]] && install_google_font "$family" || true
  done

  refresh_cache
}

# --- Main ---
usage() {
  cat << 'EOF'
Font Installer — Install and manage system fonts

USAGE:
  font-installer.sh <command> [args...]

COMMANDS:
  install <name> [name...]     Install Google Fonts by name
  install-file <path>          Install a local .ttf/.otf/.woff2 file
  install-dir <path>           Install all fonts from a directory
  install-zip <path>           Install fonts from a .zip archive
  install-list <file>          Install fonts listed in a text file (one per line)
  install-category <cat> [n]   Install top N fonts from a Google Fonts category
  pack <name>                  Install a curated font pack (dev, design, serif, handwriting)
  search <query>               Search Google Fonts catalog
  browse <category>            Browse Google Fonts by category
  info <name>                  Show font details
  list                         List user-installed fonts
  list-all [pattern]           List all system fonts (optionally filtered)
  check <name>                 Check if a font is installed
  remove <name>                Remove a user-installed font family

EXAMPLES:
  font-installer.sh install "Inter" "Fira Code"
  font-installer.sh pack dev
  font-installer.sh search "mono"
  font-installer.sh list
  font-installer.sh remove "Inter"
EOF
}

check_deps

case "${1:-}" in
  install)
    shift
    [[ $# -eq 0 ]] && { err "Usage: font-installer.sh install <name> [name...]"; exit 1; }
    for font in "$@"; do
      install_google_font "$font" || true
    done
    refresh_cache
    ;;
  install-file)    install_local_file "${2:?Usage: font-installer.sh install-file <path>}"; refresh_cache ;;
  install-dir)     install_dir "${2:?Usage: font-installer.sh install-dir <path>}"; refresh_cache ;;
  install-zip)     install_zip "${2:?Usage: font-installer.sh install-zip <path>}"; refresh_cache ;;
  install-list)    install_list "${2:?Usage: font-installer.sh install-list <file>}" ;;
  install-category) install_category "${2:?Usage: font-installer.sh install-category <category> [limit]}" "${3:-10}" ;;
  pack)            install_pack "${2:?Usage: font-installer.sh pack <dev|design|serif|handwriting>}" ;;
  search)          search_fonts "${2:?Usage: font-installer.sh search <query>}" ;;
  browse)          browse_fonts "${2:?Usage: font-installer.sh browse <category>}" ;;
  info)            font_info "${2:?Usage: font-installer.sh info <name>}" ;;
  list)            list_fonts ;;
  list-all)        list_all "${2:-}" ;;
  check)           check_font "${2:?Usage: font-installer.sh check <name>}" ;;
  remove)          remove_font "${2:?Usage: font-installer.sh remove <name>}" ;;
  -h|--help|help|"") usage ;;
  *)               err "Unknown command: $1"; usage; exit 1 ;;
esac
