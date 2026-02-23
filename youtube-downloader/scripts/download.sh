#!/bin/bash
# YouTube Downloader — yt-dlp wrapper with sensible defaults
# Usage: bash download.sh --url <URL> [options]

set -euo pipefail

# ─── Defaults ──────────────────────────────────────────────
CONFIG_FILE="${HOME}/.ytd-config"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

OUTPUT_DIR="${YTD_OUTPUT_DIR:-./downloads}"
AUDIO_FORMAT="${YTD_AUDIO_FORMAT:-mp3}"
AUDIO_QUALITY="${YTD_AUDIO_QUALITY:-320}"
VIDEO_QUALITY="${YTD_VIDEO_QUALITY:-best}"
EMBED_THUMBNAIL="${YTD_EMBED_THUMBNAIL:-true}"
RATE_LIMIT="${YTD_RATE_LIMIT:-}"
COOKIES="${YTD_COOKIES:-}"

# ─── Parse Arguments ───────────────────────────────────────
URL=""
AUDIO_ONLY=false
PLAYLIST=false
SUBS=false
SUBS_LANG="en"
INFO_ONLY=false
LIST_FORMATS=false
BATCH_FILE=""
FORMAT=""
SPLIT_CHAPTERS=false
ARCHIVE_FILE=""

usage() {
  cat << 'EOF'
YouTube Downloader — yt-dlp wrapper

Usage: bash download.sh --url <URL> [options]

Options:
  --url <URL>           Video/playlist URL (required unless --batch)
  --audio-only          Extract audio only
  --audio-format <fmt>  Audio format: mp3, opus, m4a, flac, wav (default: mp3)
  --audio-quality <q>   Audio quality: 0-9 (VBR) or kbps: 128, 192, 256, 320
  --quality <q>         Video quality: best, 2160, 1440, 1080, 720, 480
  --playlist            Download full playlist (organize in folder)
  --subs                Download subtitles
  --subs-lang <lang>    Subtitle language code (default: en)
  --info-only           Print video info without downloading
  --list-formats        List available formats
  --batch <file>        Batch download from file (one URL per line)
  --format <id>         Download specific format ID (from --list-formats)
  --cookies <file>      Cookie file for restricted content
  --rate-limit <rate>   Rate limit (e.g., 5M for 5MB/s)
  --split-chapters      Split video by chapters
  --archive <file>      Archive file (skip already downloaded)
  --output-dir <dir>    Output directory (default: ./downloads)
  -h, --help            Show this help
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --url) URL="$2"; shift 2 ;;
    --audio-only) AUDIO_ONLY=true; shift ;;
    --audio-format) AUDIO_FORMAT="$2"; shift 2 ;;
    --audio-quality) AUDIO_QUALITY="$2"; shift 2 ;;
    --quality) VIDEO_QUALITY="$2"; shift 2 ;;
    --playlist) PLAYLIST=true; shift ;;
    --subs) SUBS=true; shift ;;
    --subs-lang) SUBS_LANG="$2"; shift 2 ;;
    --info-only) INFO_ONLY=true; shift ;;
    --list-formats) LIST_FORMATS=true; shift ;;
    --batch) BATCH_FILE="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --cookies) COOKIES="$2"; shift 2 ;;
    --rate-limit) RATE_LIMIT="$2"; shift 2 ;;
    --split-chapters) SPLIT_CHAPTERS=true; shift ;;
    --archive) ARCHIVE_FILE="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "❌ Unknown option: $1"; usage ;;
  esac
done

# ─── Validate ──────────────────────────────────────────────
if [[ -z "$URL" && -z "$BATCH_FILE" ]]; then
  echo "❌ Error: --url or --batch required"
  usage
fi

# Check dependencies
for cmd in yt-dlp; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Missing dependency: $cmd"
    echo "Install: pip3 install --user yt-dlp"
    exit 1
  fi
done

if [[ "$AUDIO_ONLY" == true ]] && ! command -v ffmpeg &>/dev/null; then
  echo "❌ ffmpeg required for audio extraction"
  echo "Install: sudo apt-get install -y ffmpeg"
  exit 1
fi

# ─── Build yt-dlp Command ─────────────────────────────────
mkdir -p "$OUTPUT_DIR"
CMD=(yt-dlp)

# Output template
if [[ "$PLAYLIST" == true ]]; then
  CMD+=(--output "${OUTPUT_DIR}/%(playlist_title)s/%(playlist_index)03d - %(title)s.%(ext)s")
  CMD+=(--yes-playlist)
else
  CMD+=(--output "${OUTPUT_DIR}/%(title)s.%(ext)s")
  CMD+=(--no-playlist)
fi

# Info only
if [[ "$INFO_ONLY" == true ]]; then
  CMD+=(--print "Title: %(title)s")
  CMD+=(--print "Duration: %(duration_string)s")
  CMD+=(--print "Resolution: %(width)sx%(height)s")
  CMD+=(--print "Filesize: %(filesize_approx)s")
  CMD+=(--print "Upload date: %(upload_date)s")
  CMD+=(--print "Channel: %(channel)s")
  CMD+=(--skip-download)
  if [[ -n "$URL" ]]; then
    "${CMD[@]}" "$URL"
  fi
  exit 0
fi

# List formats
if [[ "$LIST_FORMATS" == true ]]; then
  yt-dlp --list-formats "$URL"
  exit 0
fi

# Audio only mode
if [[ "$AUDIO_ONLY" == true ]]; then
  CMD+=(--extract-audio)
  CMD+=(--audio-format "$AUDIO_FORMAT")
  CMD+=(--audio-quality "$AUDIO_QUALITY")
  if [[ "$EMBED_THUMBNAIL" == true ]]; then
    CMD+=(--embed-thumbnail)
  fi
else
  # Video mode
  if [[ -n "$FORMAT" ]]; then
    CMD+=(--format "$FORMAT")
  elif [[ "$VIDEO_QUALITY" == "best" ]]; then
    CMD+=(--format "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best")
  else
    CMD+=(--format "bestvideo[height<=${VIDEO_QUALITY}][ext=mp4]+bestaudio[ext=m4a]/best[height<=${VIDEO_QUALITY}][ext=mp4]/best[height<=${VIDEO_QUALITY}]")
  fi
  CMD+=(--merge-output-format mp4)
fi

# Metadata
CMD+=(--embed-metadata)

# Subtitles
if [[ "$SUBS" == true ]]; then
  CMD+=(--write-subs --write-auto-subs --sub-langs "$SUBS_LANG" --embed-subs)
fi

# Cookies
if [[ -n "$COOKIES" ]]; then
  CMD+=(--cookies "$COOKIES")
fi

# Rate limit
if [[ -n "$RATE_LIMIT" ]]; then
  CMD+=(--limit-rate "$RATE_LIMIT")
fi

# Split chapters
if [[ "$SPLIT_CHAPTERS" == true ]]; then
  CMD+=(--split-chapters)
fi

# Archive
if [[ -n "$ARCHIVE_FILE" ]]; then
  CMD+=(--download-archive "$ARCHIVE_FILE")
fi

# ─── Execute ───────────────────────────────────────────────
if [[ -n "$BATCH_FILE" ]]; then
  CMD+=(--batch-file "$BATCH_FILE")
  echo "📥 Batch downloading from: $BATCH_FILE"
  "${CMD[@]}"
else
  echo "📥 Downloading: $URL"
  "${CMD[@]}" "$URL"
fi

echo ""
echo "✅ Done! Files saved to: $OUTPUT_DIR"
