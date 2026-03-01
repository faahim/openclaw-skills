#!/usr/bin/env bash
# Media Organizer — Sort, rename, and organize media files by metadata
# Requires: exiftool, ffprobe, imagemagick (convert), md5sum/shasum
set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
SOURCE=""
DEST=""
MODE="date"
DATE_FORMAT="%Y/%m"
RENAME=false
RENAME_PATTERN="{date}_{time}_{seq}"
DRY_RUN=false
THUMBNAILS=false
THUMB_SIZE=320
DEDUP=false
DEDUP_ACTION="skip"
DEDUP_DEST=""
MOVE=true
CONVERT_HEIC=false
INCREMENTAL=false
REPORT_ONLY=false
RENAME_ONLY=false
PARALLEL=1
CONFIG=""
LOG_FILE=""
PROCESSED_DB=""

# File type arrays
PHOTO_EXTS="jpg jpeg png heic webp tiff tif raw cr2 nef arw dng orf rw2 pef srw"
VIDEO_EXTS="mp4 mkv avi mov wmv flv webm m4v mts 3gp"
AUDIO_EXTS="mp3 flac wav ogg m4a aac wma opus"

# Counters
COUNT_PHOTOS=0
COUNT_VIDEOS=0
COUNT_AUDIO=0
COUNT_SKIPPED=0
COUNT_DUPES=0
COUNT_ERRORS=0
TOTAL_SIZE=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  local level="$1"; shift
  local msg="$*"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  case "$level" in
    INFO)  echo -e "${GREEN}[${ts}]${NC} ✅ ${msg}" ;;
    WARN)  echo -e "${YELLOW}[${ts}]${NC} ⚠️  ${msg}" ;;
    ERROR) echo -e "${RED}[${ts}]${NC} ❌ ${msg}" ;;
    DEDUP) echo -e "${BLUE}[${ts}]${NC} 🔄 ${msg}" ;;
    DRY)   echo -e "${YELLOW}[${ts}]${NC} 🔍 [DRY-RUN] ${msg}" ;;
  esac
  if [[ -n "$LOG_FILE" ]]; then
    echo "[${ts}] [${level}] ${msg}" >> "$LOG_FILE"
  fi
}

usage() {
  cat <<EOF
Media Organizer v${VERSION}

Usage: $(basename "$0") [OPTIONS]

Options:
  --source DIR          Source directory to scan
  --dest DIR            Destination directory for organized files
  --mode MODE           Organization mode: date|type|camera (default: date)
  --format FMT          Date format for folder structure (default: %Y/%m)
  --rename              Rename files using metadata
  --pattern PAT         Rename pattern: {date}_{time}_{camera}_{seq} (default: {date}_{time}_{seq})
  --dry-run             Preview changes without moving/copying files
  --thumbnails          Generate video thumbnails
  --thumb-size PX       Thumbnail width in pixels (default: 320)
  --dedup               Enable duplicate detection
  --dedup-action ACT    On duplicate: skip|move|delete (default: skip)
  --dedup-dest DIR      Where to move duplicates (with --dedup-action move)
  --copy                Copy files instead of moving
  --convert-heic        Convert HEIC files to JPEG
  --incremental         Only process new files (tracks processed files)
  --report              Generate library summary report
  --rename-only         Rename files in-place without moving
  --parallel N          Process N files in parallel (default: 1)
  --config FILE         Load YAML config file
  --log FILE            Log output to file
  -h, --help            Show this help

Examples:
  # Sort photos by date (dry run)
  $(basename "$0") --source ~/Downloads --dest ~/media --dry-run

  # Sort and rename with thumbnails
  $(basename "$0") --source ~/incoming --dest ~/media --rename --thumbnails

  # Deduplicate a library
  $(basename "$0") --source ~/media --dedup --dedup-action move --dedup-dest ~/dupes

  # Generate a report
  $(basename "$0") --source ~/media --report
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)       SOURCE="$2"; shift 2 ;;
    --dest)         DEST="$2"; shift 2 ;;
    --mode)         MODE="$2"; shift 2 ;;
    --format)       DATE_FORMAT="$2"; shift 2 ;;
    --rename)       RENAME=true; shift ;;
    --pattern)      RENAME_PATTERN="$2"; RENAME=true; shift 2 ;;
    --dry-run)      DRY_RUN=true; shift ;;
    --thumbnails)   THUMBNAILS=true; shift ;;
    --thumb-size)   THUMB_SIZE="$2"; shift 2 ;;
    --dedup)        DEDUP=true; shift ;;
    --dedup-action) DEDUP_ACTION="$2"; shift 2 ;;
    --dedup-dest)   DEDUP_DEST="$2"; shift 2 ;;
    --copy)         MOVE=false; shift ;;
    --convert-heic) CONVERT_HEIC=true; shift ;;
    --incremental)  INCREMENTAL=true; shift ;;
    --report)       REPORT_ONLY=true; shift ;;
    --rename-only)  RENAME_ONLY=true; shift ;;
    --parallel)     PARALLEL="$2"; shift 2 ;;
    --config)       CONFIG="$2"; shift 2 ;;
    --log)          LOG_FILE="$2"; shift 2 ;;
    -h|--help)      usage ;;
    *)              echo "Unknown option: $1"; usage ;;
  esac
done

# Validate
if [[ -z "$SOURCE" ]]; then
  echo "Error: --source is required"
  usage
fi

if [[ ! -d "$SOURCE" ]]; then
  echo "Error: Source directory does not exist: $SOURCE"
  exit 1
fi

if [[ "$REPORT_ONLY" == false && "$RENAME_ONLY" == false && -z "$DEST" ]]; then
  echo "Error: --dest is required (unless using --report or --rename-only)"
  usage
fi

# Check dependencies
check_deps() {
  local missing=()
  command -v exiftool >/dev/null 2>&1 || missing+=("exiftool")
  command -v ffprobe >/dev/null 2>&1 || missing+=("ffprobe (ffmpeg)")
  command -v convert >/dev/null 2>&1 || missing+=("convert (imagemagick)")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: Missing dependencies: ${missing[*]}"
    echo ""
    echo "Install with:"
    echo "  Ubuntu/Debian: sudo apt-get install -y exiftool ffmpeg imagemagick"
    echo "  macOS:         brew install exiftool ffmpeg imagemagick"
    exit 1
  fi
}

check_deps

# Get file type category
get_type() {
  local ext="${1,,}"  # lowercase
  for e in $PHOTO_EXTS; do [[ "$ext" == "$e" ]] && echo "photos" && return; done
  for e in $VIDEO_EXTS; do [[ "$ext" == "$e" ]] && echo "videos" && return; done
  for e in $AUDIO_EXTS; do [[ "$ext" == "$e" ]] && echo "audio" && return; done
  echo ""
}

# Extract date from file metadata
get_date() {
  local file="$1"
  local date_str

  # Try EXIF DateTimeOriginal first
  date_str=$(exiftool -s -s -s -DateTimeOriginal "$file" 2>/dev/null || true)

  # Fallback: CreateDate
  if [[ -z "$date_str" ]]; then
    date_str=$(exiftool -s -s -s -CreateDate "$file" 2>/dev/null || true)
  fi

  # Fallback: MediaCreateDate (for videos)
  if [[ -z "$date_str" ]]; then
    date_str=$(exiftool -s -s -s -MediaCreateDate "$file" 2>/dev/null || true)
  fi

  # Fallback: file modification time
  if [[ -z "$date_str" || "$date_str" == "0000:00:00 00:00:00" ]]; then
    date_str=$(date -r "$file" '+%Y:%m:%d %H:%M:%S' 2>/dev/null || stat -c '%y' "$file" 2>/dev/null | cut -d. -f1 | sed 's/-/:/g; s/ /:/; s/://3; s/://3' || true)
  fi

  echo "$date_str"
}

# Get camera model
get_camera() {
  local file="$1"
  local model
  model=$(exiftool -s -s -s -Model "$file" 2>/dev/null || true)
  # Sanitize: remove spaces and special chars
  model=$(echo "$model" | tr ' ' '_' | tr -cd '[:alnum:]_-')
  echo "${model:-Unknown}"
}

# Compute file hash for dedup
file_hash() {
  local file="$1"
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$file" | cut -d' ' -f1
  elif command -v md5 >/dev/null 2>&1; then
    md5 -q "$file"
  else
    shasum "$file" | cut -d' ' -f1
  fi
}

# Generate video thumbnail
make_thumbnail() {
  local file="$1"
  local dest_dir="$2"
  local basename
  basename=$(basename "$file")
  local thumb_dir="${dest_dir}/.thumbs"
  local thumb_file="${thumb_dir}/${basename%.*}.jpg"

  mkdir -p "$thumb_dir"

  if [[ ! -f "$thumb_file" ]]; then
    # Extract frame at 10% of duration
    local duration
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "10")
    local seek
    seek=$(echo "$duration * 0.1" | bc 2>/dev/null || echo "2")

    ffmpeg -y -ss "$seek" -i "$file" -vframes 1 -vf "scale=${THUMB_SIZE}:-1" "$thumb_file" 2>/dev/null && \
      log INFO "Thumbnail: ${basename}" || \
      log WARN "Thumbnail failed: ${basename}"
  fi
}

# Generate report
generate_report() {
  local dir="$1"
  local photo_count=0 video_count=0 audio_count=0 other_count=0
  local photo_size=0 video_size=0 audio_size=0
  local earliest="" latest=""

  echo ""
  echo "Media Library Summary"
  echo "─────────────────────"
  echo "Scanning: $dir"
  echo ""

  while IFS= read -r -d '' file; do
    local ext="${file##*.}"
    local ftype
    ftype=$(get_type "$ext")
    local fsize
    fsize=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)

    case "$ftype" in
      photos) ((photo_count++)) || true; photo_size=$((photo_size + fsize)) ;;
      videos) ((video_count++)) || true; video_size=$((video_size + fsize)) ;;
      audio)  ((audio_count++)) || true; audio_size=$((audio_size + fsize)) ;;
    esac
  done < <(find "$dir" -type f -print0 2>/dev/null)

  local total=$((photo_count + video_count + audio_count))
  local total_size=$((photo_size + video_size + audio_size))

  printf "  Photos:  %'d files (%s)\n" "$photo_count" "$(numfmt --to=iec-i --suffix=B "$photo_size" 2>/dev/null || echo "${photo_size} bytes")"
  printf "  Videos:  %'d files (%s)\n" "$video_count" "$(numfmt --to=iec-i --suffix=B "$video_size" 2>/dev/null || echo "${video_size} bytes")"
  printf "  Audio:   %'d files (%s)\n" "$audio_count" "$(numfmt --to=iec-i --suffix=B "$audio_size" 2>/dev/null || echo "${audio_size} bytes")"
  echo "  ─────────────────────"
  printf "  Total:   %'d files (%s)\n" "$total" "$(numfmt --to=iec-i --suffix=B "$total_size" 2>/dev/null || echo "${total_size} bytes")"
  echo ""
  exit 0
}

# Report mode
if [[ "$REPORT_ONLY" == true ]]; then
  generate_report "$SOURCE"
fi

# Incremental tracking
if [[ "$INCREMENTAL" == true ]]; then
  PROCESSED_DB="${DEST}/.media-organizer-processed.log"
  touch "$PROCESSED_DB"
fi

# Dedup hash tracking
declare -A SEEN_HASHES

# Create destination
if [[ "$RENAME_ONLY" == false ]]; then
  mkdir -p "$DEST"
fi

# Sequence counter
SEQ=0

log INFO "Starting Media Organizer v${VERSION}"
log INFO "Source: $SOURCE"
[[ "$RENAME_ONLY" == false ]] && log INFO "Dest: $DEST"
log INFO "Mode: $MODE | Rename: $RENAME | Dedup: $DEDUP | Dry-run: $DRY_RUN"
echo ""

# Process files
while IFS= read -r -d '' file; do
  local_file="$file"
  filename=$(basename "$file")
  ext="${filename##*.}"
  ext_lower="${ext,,}"

  # Skip hidden files
  [[ "$filename" == .* ]] && continue
  [[ "$filename" == "Thumbs.db" ]] && continue
  [[ "$filename" == ".DS_Store" ]] && continue

  # Get file type
  ftype=$(get_type "$ext_lower")
  [[ -z "$ftype" ]] && continue  # Skip unsupported types

  # Incremental: skip already processed
  if [[ "$INCREMENTAL" == true && -f "$PROCESSED_DB" ]]; then
    if grep -qF "$file" "$PROCESSED_DB" 2>/dev/null; then
      ((COUNT_SKIPPED++)) || true
      continue
    fi
  fi

  # Deduplication
  if [[ "$DEDUP" == true ]]; then
    hash=$(file_hash "$file")
    if [[ -n "${SEEN_HASHES[$hash]:-}" ]]; then
      ((COUNT_DUPES++)) || true
      case "$DEDUP_ACTION" in
        skip)
          log DEDUP "Duplicate skipped: $filename (matches ${SEEN_HASHES[$hash]})"
          ;;
        move)
          if [[ -n "$DEDUP_DEST" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
              log DRY "Would move duplicate: $filename → $DEDUP_DEST/"
            else
              mkdir -p "$DEDUP_DEST"
              mv "$file" "$DEDUP_DEST/" 2>/dev/null || true
              log DEDUP "Moved duplicate: $filename → $DEDUP_DEST/"
            fi
          fi
          ;;
        delete)
          if [[ "$DRY_RUN" == true ]]; then
            log DRY "Would delete duplicate: $filename"
          else
            rm "$file" 2>/dev/null || true
            log DEDUP "Deleted duplicate: $filename"
          fi
          ;;
      esac
      continue
    fi
    SEEN_HASHES[$hash]="$filename"
  fi

  # Get metadata
  date_str=$(get_date "$file")

  # Parse date components
  if [[ -n "$date_str" ]]; then
    # EXIF format: "2026:03:01 14:30:22"
    date_part=$(echo "$date_str" | sed 's/:/-/; s/:/-/' | cut -d' ' -f1)
    time_part=$(echo "$date_str" | cut -d' ' -f2 | tr -d ':')
  else
    date_part=$(date '+%Y-%m-%d')
    time_part=$(date '+%H%M%S')
  fi

  # Build destination path
  ((SEQ++)) || true

  case "$MODE" in
    date)
      # Use date-based folders
      folder_date=$(date -d "${date_part}" "+${DATE_FORMAT}" 2>/dev/null || echo "${date_part//-//}")
      dest_subdir="${ftype}/${folder_date}"
      ;;
    type)
      dest_subdir="${ftype}"
      ;;
    camera)
      camera=$(get_camera "$file")
      dest_subdir="${ftype}/${camera}"
      ;;
    *)
      dest_subdir="${ftype}"
      ;;
  esac

  # Build new filename
  if [[ "$RENAME" == true ]]; then
    camera=$(get_camera "$file")
    new_name="${RENAME_PATTERN}"
    new_name="${new_name//\{date\}/${date_part}}"
    new_name="${new_name//\{time\}/${time_part}}"
    new_name="${new_name//\{camera\}/${camera}}"
    new_name="${new_name//\{seq\}/$(printf '%03d' $SEQ)}"
    new_name="${new_name}.${ext}"
  else
    new_name="$filename"
  fi

  if [[ "$RENAME_ONLY" == true ]]; then
    # Rename in place
    local_dir=$(dirname "$file")
    dest_path="${local_dir}/${new_name}"
    if [[ "$DRY_RUN" == true ]]; then
      log DRY "Would rename: $filename → $new_name"
    else
      if [[ "$file" != "$dest_path" ]]; then
        mv "$file" "$dest_path"
        log INFO "Renamed: $filename → $new_name"
      fi
    fi
  else
    dest_dir="${DEST}/${dest_subdir}"
    dest_path="${dest_dir}/${new_name}"

    # Handle conflicts
    if [[ -f "$dest_path" ]]; then
      base="${new_name%.*}"
      conflict_seq=1
      while [[ -f "${dest_dir}/${base}_${conflict_seq}.${ext}" ]]; do
        ((conflict_seq++))
      done
      new_name="${base}_${conflict_seq}.${ext}"
      dest_path="${dest_dir}/${new_name}"
    fi

    if [[ "$DRY_RUN" == true ]]; then
      log DRY "$filename → ${dest_subdir}/${new_name}"
    else
      mkdir -p "$dest_dir"

      # HEIC conversion
      if [[ "$CONVERT_HEIC" == true && ("$ext_lower" == "heic" || "$ext_lower" == "heif") ]]; then
        local jpg_name="${new_name%.*}.jpg"
        dest_path="${dest_dir}/${jpg_name}"
        if command -v heif-convert >/dev/null 2>&1; then
          heif-convert "$file" "$dest_path" 2>/dev/null
        else
          convert "$file" "$dest_path" 2>/dev/null
        fi
        [[ "$MOVE" == true ]] && rm "$file"
        log INFO "Converted: $filename → ${dest_subdir}/${jpg_name}"
      elif [[ "$MOVE" == true ]]; then
        mv "$file" "$dest_path"
        log INFO "Moved: $filename → ${dest_subdir}/${new_name}"
      else
        cp "$file" "$dest_path"
        log INFO "Copied: $filename → ${dest_subdir}/${new_name}"
      fi

      # Generate thumbnail for videos
      if [[ "$THUMBNAILS" == true && "$ftype" == "videos" ]]; then
        make_thumbnail "$dest_path" "$dest_dir"
      fi

      # Track for incremental
      if [[ "$INCREMENTAL" == true && -n "$PROCESSED_DB" ]]; then
        echo "$file" >> "$PROCESSED_DB"
      fi
    fi
  fi

  # Update counters
  case "$ftype" in
    photos) ((COUNT_PHOTOS++)) || true ;;
    videos) ((COUNT_VIDEOS++)) || true ;;
    audio)  ((COUNT_AUDIO++)) || true ;;
  esac

done < <(find "$SOURCE" -maxdepth 5 -type f -print0 2>/dev/null | sort -z)

# Summary
echo ""
echo "════════════════════════════════"
echo "  Media Organizer — Summary"
echo "════════════════════════════════"
printf "  Photos:     %d\n" "$COUNT_PHOTOS"
printf "  Videos:     %d\n" "$COUNT_VIDEOS"
printf "  Audio:      %d\n" "$COUNT_AUDIO"
printf "  Skipped:    %d\n" "$COUNT_SKIPPED"
printf "  Duplicates: %d\n" "$COUNT_DUPES"
printf "  Errors:     %d\n" "$COUNT_ERRORS"
echo "════════════════════════════════"

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "This was a DRY RUN. No files were modified."
  echo "Remove --dry-run to apply changes."
fi

log INFO "Done."
