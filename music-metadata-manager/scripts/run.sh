#!/bin/bash
# Music Metadata Manager — Main entry point
# Commands: info, tag, art, rename, export, scan, strip, autotag, fix-encoding, dupes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSIONS="${MUSIC_EXTENSIONS:-mp3,flac,ogg,m4a,wma,aac}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  echo "Usage: bash scripts/run.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  info <file>                    Show metadata for a file"
  echo "  tag <file|dir> [--title ...] Set tags on file(s)"
  echo "  art <file|dir> --set|--extract|--remove  Manage album art"
  echo "  rename <dir> --pattern <pat>   Rename files by metadata pattern"
  echo "  export <dir> --output <csv>    Export tags to CSV"
  echo "  scan <dir>                     Find files with missing tags"
  echo "  strip <file|dir>               Remove all metadata"
  echo "  autotag <dir> --from-filename <pat>  Extract tags from filename"
  echo "  dupes <dir>                    Find duplicate tracks by metadata"
  echo ""
  echo "Pattern variables: {artist}, {title}, {album}, {year}, {track}, {genre}, {disc}"
  exit 1
}

# ---- Helper: get metadata via Python/mutagen (supports all formats) ----
get_meta() {
  local file="$1"
  python3 "$SCRIPT_DIR/metadata.py" info "$file"
}

# ---- Helper: find audio files ----
find_audio_files() {
  local dir="$1"
  local ext_list=""
  IFS=',' read -ra EXTS <<< "$EXTENSIONS"
  for ext in "${EXTS[@]}"; do
    if [ -n "$ext_list" ]; then ext_list="$ext_list -o "; fi
    ext_list="$ext_list-iname '*.${ext}'"
  done
  eval "find '$dir' -type f \( $ext_list \) | sort"
}

# ---- Commands ----

cmd_info() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo -e "${RED}Error: File not found: $file${NC}"
    exit 1
  fi
  python3 "$SCRIPT_DIR/metadata.py" info "$file"
}

cmd_tag() {
  local target="$1"
  shift
  python3 "$SCRIPT_DIR/metadata.py" tag "$target" "$@"
}

cmd_art() {
  local target="$1"
  shift
  python3 "$SCRIPT_DIR/metadata.py" art "$target" "$@"
}

cmd_rename() {
  local dir="$1"
  shift
  python3 "$SCRIPT_DIR/metadata.py" rename "$dir" "$@"
}

cmd_export() {
  local dir="$1"
  shift
  python3 "$SCRIPT_DIR/metadata.py" export "$dir" "$@"
}

cmd_scan() {
  local dir="$1"
  python3 "$SCRIPT_DIR/metadata.py" scan "$dir"
}

cmd_strip() {
  local target="$1"
  shift
  python3 "$SCRIPT_DIR/metadata.py" strip "$target" "$@"
}

cmd_autotag() {
  local dir="$1"
  shift
  python3 "$SCRIPT_DIR/metadata.py" autotag "$dir" "$@"
}

cmd_dupes() {
  local dir="$1"
  python3 "$SCRIPT_DIR/metadata.py" dupes "$dir"
}

# ---- Main ----

if [ $# -lt 1 ]; then usage; fi

COMMAND="$1"
shift

case "$COMMAND" in
  info)     cmd_info "$@" ;;
  tag)      cmd_tag "$@" ;;
  art)      cmd_art "$@" ;;
  rename)   cmd_rename "$@" ;;
  export)   cmd_export "$@" ;;
  scan)     cmd_scan "$@" ;;
  strip)    cmd_strip "$@" ;;
  autotag)  cmd_autotag "$@" ;;
  dupes)    cmd_dupes "$@" ;;
  *)        echo -e "${RED}Unknown command: $COMMAND${NC}"; usage ;;
esac
