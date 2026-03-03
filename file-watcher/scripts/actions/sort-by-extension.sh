#!/bin/bash
# Sort files by extension into categorized directories
set -euo pipefail

FILE="$1"
[[ -f "$FILE" ]] || exit 0

NAME=$(basename "$FILE")
EXT="${NAME##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
BASE_DIR=$(dirname "$FILE")

# Map extensions to directories
case "$EXT_LOWER" in
    pdf|doc|docx|txt|odt|rtf|xlsx|xls|csv|pptx|ppt)
        DEST="$HOME/Documents" ;;
    jpg|jpeg|png|gif|bmp|svg|webp|tiff|ico|heic)
        DEST="$HOME/Pictures" ;;
    mp4|mkv|avi|mov|wmv|flv|webm)
        DEST="$HOME/Videos" ;;
    mp3|wav|flac|aac|ogg|wma|m4a)
        DEST="$HOME/Music" ;;
    zip|tar|gz|bz2|xz|7z|rar|tgz)
        DEST="$HOME/Archives" ;;
    deb|rpm|AppImage|snap|flatpak)
        DEST="$HOME/Installers" ;;
    sh|py|js|ts|rb|go|rs|c|cpp|h|java)
        DEST="$HOME/Code" ;;
    iso|img|vmdk)
        DEST="$HOME/Disk-Images" ;;
    *)
        DEST="$HOME/Other" ;;
esac

mkdir -p "$DEST"

# Don't move if already in destination
[[ "$BASE_DIR" == "$DEST" ]] && exit 0

# Handle duplicate filenames
DEST_FILE="$DEST/$NAME"
if [[ -f "$DEST_FILE" ]]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BASENAME="${NAME%.*}"
    DEST_FILE="$DEST/${BASENAME}_${TIMESTAMP}.${EXT}"
fi

mv "$FILE" "$DEST_FILE"
echo "📁 $NAME → $DEST/"
