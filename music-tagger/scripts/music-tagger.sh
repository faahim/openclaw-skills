#!/bin/bash
# Music Metadata Tagger — read, write, batch-edit music file tags
# Requires: python3, mutagen (pip3 install mutagen)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check dependencies
check_deps() {
  if ! command -v python3 &>/dev/null; then
    echo "❌ python3 not found. Install Python 3.8+."
    exit 1
  fi
  if ! python3 -c "import mutagen" 2>/dev/null; then
    echo "❌ mutagen not found. Run: pip3 install --user mutagen"
    exit 1
  fi
}

# Dispatch to Python backend
run_python() {
  python3 "$SCRIPT_DIR/tagger.py" "$@"
}

usage() {
  cat <<'EOF'
Music Metadata Tagger — Read, write & batch-edit music file metadata

USAGE:
  music-tagger.sh <command> <path> [options]

COMMANDS:
  info <file>              Show all tags for a single file
  scan <dir>               List tags for all music files in directory
  tag <file|dir> [opts]    Write tags to file(s)
  rename <dir> [opts]      Rename files based on tags
  organize <dir> [opts]    Move files into Artist/Album folder structure
  art-extract <path>       Extract embedded album art
  art-embed <path>         Embed album art into file(s)
  strip <file|dir>         Remove all tags
  auto-tag <dir>           Parse tags from filenames

TAG OPTIONS:
  --artist TEXT             Artist name
  --album TEXT              Album name
  --title TEXT              Track title
  --track NUM               Track number
  --year NUM                Year
  --genre TEXT              Genre
  --albumartist TEXT        Album artist
  --disc NUM                Disc number
  --composer TEXT           Composer
  --comment TEXT            Comment

RENAME OPTIONS:
  --pattern TEXT            Rename pattern (default: "{track:02d} - {title}")
                            Variables: {artist} {album} {title} {track} {track:02d} {year} {genre} {disc}

ORGANIZE OPTIONS:
  --dest DIR                Destination directory (default: ./sorted)
  --structure TEXT          Folder pattern (default: "{artist}/{album}")

ART OPTIONS:
  --image FILE              Image file to embed
  --output FILE             Output file for extraction
  --output-dir DIR          Output directory for batch extraction

AUTO-TAG OPTIONS:
  --from-pattern TEXT       Filename pattern to parse (e.g. "{track} - {artist} - {title}")

EXAMPLES:
  music-tagger.sh info song.mp3
  music-tagger.sh scan ~/Music/album/
  music-tagger.sh tag ~/Music/album/ --artist "Mogwai" --album "Young Team" --year 1997
  music-tagger.sh rename ~/Music/album/ --pattern "{track:02d} - {title}"
  music-tagger.sh organize ~/Music/unsorted/ --dest ~/Music/sorted/
  music-tagger.sh art-extract song.mp3 --output cover.jpg
  music-tagger.sh art-embed ~/Music/album/ --image cover.jpg
  music-tagger.sh strip ~/Music/album/
  music-tagger.sh auto-tag ~/Music/ --from-pattern "{track} - {artist} - {title}"
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

check_deps
run_python "$@"
