#!/bin/bash
# podcast-dl.sh — Download and manage podcast episodes from RSS feeds
# Requires: curl, xmlstarlet, yt-dlp, jq

set -euo pipefail

# Defaults
PODCAST_DIR="${PODCAST_DIR:-$HOME/Podcasts}"
MAX_EPISODES="${PODCAST_MAX_EPISODES:-20}"
AUDIO_FORMAT="mp3"
AUDIO_QUALITY="192k"
SUBS_FILE=""
STATE_DIR="$PODCAST_DIR/.podcast-dl"
USER_AGENT="podcast-dl/1.0"
PROXY="${PODCAST_PROXY:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
Usage: podcast-dl.sh [OPTIONS]

Download & manage podcast episodes from RSS feeds.

OPTIONS:
  --feed URL          Download from a single RSS feed
  --subs FILE         Download from subscriptions YAML file
  --subscribe URL     Add a feed to subscriptions
  --sync              Sync all subscribed feeds (download new only)
  --list              List episodes without downloading
  --search QUERY      Search episodes by title keyword
  --download          Download search results
  --limit N           Max episodes to download (default: all new)
  --episode N         Download specific episode number
  --output DIR        Output directory (default: ~/Podcasts)
  --audio-only        Extract audio only (strip video)
  --format FMT        Audio format: mp3, opus, m4a (default: mp3)
  --quality RATE      Audio bitrate: 128k, 192k, 320k (default: 192k)
  --keep N            Max episodes to keep per show (default: 20)
  --cleanup           Remove episodes exceeding --keep limit
  --index             Generate markdown index of all episodes
  --import-opml FILE  Import subscriptions from OPML file
  --install-cron      Install cron job for auto-sync
  --interval TIME     Cron interval: 1h, 6h, 12h, 24h (default: 6h)
  --user-agent STR    Custom user-agent for HTTP requests
  -h, --help          Show this help

EXAMPLES:
  podcast-dl.sh --feed "https://example.com/rss" --limit 5
  podcast-dl.sh --subscribe "https://example.com/rss"
  podcast-dl.sh --sync
  podcast-dl.sh --cleanup --keep 10
EOF
  exit 0
}

# Check dependencies
check_deps() {
  local missing=()
  for cmd in curl xmlstarlet jq; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  # yt-dlp is optional if enclosure URLs are direct mp3
  if ! command -v yt-dlp &>/dev/null; then
    echo -e "${YELLOW}⚠️  yt-dlp not found — direct downloads only (no format conversion)${NC}"
  fi
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Missing dependencies: ${missing[*]}${NC}"
    echo "Install with: sudo apt-get install -y ${missing[*]}"
    exit 1
  fi
}

# Initialize state directory
init_state() {
  mkdir -p "$STATE_DIR"
  [[ -f "$STATE_DIR/downloaded.json" ]] || echo '{}' > "$STATE_DIR/downloaded.json"
  [[ -f "$STATE_DIR/subscriptions.json" ]] || echo '[]' > "$STATE_DIR/subscriptions.json"
}

# Sanitize filename
sanitize() {
  echo "$1" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | head -c 200
}

# Parse RSS feed and output JSON array of episodes
parse_feed() {
  local feed_url="$1"
  local xml
  xml=$(curl -sL --max-time 30 -A "$USER_AGENT" ${PROXY:+--proxy "$PROXY"} "$feed_url") || {
    echo -e "${RED}❌ Failed to fetch feed: $feed_url${NC}" >&2
    return 1
  }

  # Extract show title
  local show_title
  show_title=$(echo "$xml" | xmlstarlet sel -t -v "//channel/title" 2>/dev/null | head -1) || show_title="Unknown-Podcast"

  # Extract episodes as JSON
  echo "$xml" | xmlstarlet sel -t \
    -m "//item" \
    -o "{" \
    -o '"title":"' -v "normalize-space(title)" -o '",' \
    -o '"date":"' -v "normalize-space(pubDate)" -o '",' \
    -o '"url":"' -v "enclosure/@url" -o '",' \
    -o '"duration":"' -v "normalize-space(*[local-name()='duration'])" -o '",' \
    -o '"guid":"' -v "normalize-space(guid)" -o '"' \
    -o "}" -n 2>/dev/null | \
  jq -Rs --arg show "$show_title" '
    split("\n") | map(select(length > 0)) | map(try fromjson // empty) |
    map(. + {show: $show})
  ' 2>/dev/null || echo "[]"
}

# Download a single episode
download_episode() {
  local url="$1"
  local show="$2"
  local title="$3"
  local date_str="$4"
  local output_dir="$5"
  local audio_only="${6:-false}"

  local show_dir="$output_dir/$(sanitize "$show")"
  mkdir -p "$show_dir"

  # Parse date to YYYY-MM-DD
  local date_formatted
  date_formatted=$(date -d "$date_str" '+%Y-%m-%d' 2>/dev/null || echo "unknown-date")

  local filename="${date_formatted}_$(sanitize "$title")"
  local filepath="$show_dir/${filename}.${AUDIO_FORMAT}"

  # Skip if already downloaded
  if [[ -f "$filepath" ]]; then
    echo -e "${YELLOW}⏭️  Already exists: $(basename "$filepath")${NC}"
    return 0
  fi

  echo -e "${BLUE}📥 Downloading: $title ($date_formatted)${NC}"

  if command -v yt-dlp &>/dev/null && [[ "$audio_only" == "true" ]]; then
    yt-dlp \
      --no-playlist \
      -x --audio-format "$AUDIO_FORMAT" --audio-quality "$AUDIO_QUALITY" \
      -o "$show_dir/${filename}.%(ext)s" \
      --no-progress \
      ${PROXY:+--proxy "$PROXY"} \
      "$url" 2>/dev/null && {
        echo -e "${GREEN}✅ Saved: $filepath${NC}"
      } || {
        # Fallback to direct curl download
        curl -sL --max-time 600 -A "$USER_AGENT" ${PROXY:+--proxy "$PROXY"} -o "$filepath" "$url" && \
          echo -e "${GREEN}✅ Saved: $filepath${NC}" || \
          echo -e "${RED}❌ Failed: $title${NC}"
      }
  else
    # Direct download (most podcast enclosures are already mp3)
    curl -sL --max-time 600 -A "$USER_AGENT" ${PROXY:+--proxy "$PROXY"} -o "$filepath" "$url" && {
      echo -e "${GREEN}✅ Saved: $filepath${NC}"
    } || {
      echo -e "${RED}❌ Failed: $title${NC}"
      return 1
    }
  fi

  # Track in state
  local guid
  guid=$(echo "$url" | md5sum | cut -d' ' -f1)
  local state_file="$STATE_DIR/downloaded.json"
  local tmp
  tmp=$(jq --arg guid "$guid" --arg path "$filepath" --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.[$guid] = {path: $path, downloaded_at: $date}' "$state_file")
  echo "$tmp" > "$state_file"
}

# Download from a single feed
download_feed() {
  local feed_url="$1"
  local limit="${2:-0}"
  local audio_only="${3:-false}"
  local list_only="${4:-false}"
  local search_query="${5:-}"

  echo -e "${BLUE}🎙️ Fetching feed: $feed_url${NC}"
  local episodes
  episodes=$(parse_feed "$feed_url")

  local show
  show=$(echo "$episodes" | jq -r '.[0].show // "Unknown"')
  echo -e "${GREEN}🎙️ Podcast: $show${NC}"

  local count
  count=$(echo "$episodes" | jq 'length')
  echo -e "   Found $count episodes"

  # Apply search filter
  if [[ -n "$search_query" ]]; then
    episodes=$(echo "$episodes" | jq --arg q "$search_query" \
      '[.[] | select(.title | ascii_downcase | contains($q | ascii_downcase))]')
    count=$(echo "$episodes" | jq 'length')
    echo -e "   Matching \"$search_query\": $count episodes"
  fi

  # Apply limit
  if [[ "$limit" -gt 0 ]]; then
    episodes=$(echo "$episodes" | jq --argjson n "$limit" '.[:$n]')
  fi

  # List mode
  if [[ "$list_only" == "true" ]]; then
    echo "$episodes" | jq -r 'to_entries[] | "\(.key + 1). [\(.value.date | split(" ") | .[0:4] | join(" "))] \(.value.title) (\(.value.duration // "?"))"'
    return 0
  fi

  # Download
  echo "$episodes" | jq -c '.[]' | while IFS= read -r ep; do
    local title url date_str
    title=$(echo "$ep" | jq -r '.title')
    url=$(echo "$ep" | jq -r '.url')
    date_str=$(echo "$ep" | jq -r '.date')

    [[ -z "$url" || "$url" == "null" ]] && continue
    download_episode "$url" "$show" "$title" "$date_str" "$PODCAST_DIR" "$audio_only"
  done
}

# Subscribe to a feed
subscribe_feed() {
  local feed_url="$1"
  init_state

  # Check if already subscribed
  local existing
  existing=$(jq --arg url "$feed_url" '[.[] | select(.url == $url)] | length' "$STATE_DIR/subscriptions.json")
  if [[ "$existing" -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Already subscribed to: $feed_url${NC}"
    return 0
  fi

  # Fetch show name
  local show_name
  show_name=$(curl -sL --max-time 15 -A "$USER_AGENT" "$feed_url" | xmlstarlet sel -t -v "//channel/title" 2>/dev/null | head -1) || show_name="Unknown"

  # Add to subscriptions
  local tmp
  tmp=$(jq --arg url "$feed_url" --arg name "$show_name" \
    '. += [{"url": $url, "name": $name, "added_at": (now | todate)}]' \
    "$STATE_DIR/subscriptions.json")
  echo "$tmp" > "$STATE_DIR/subscriptions.json"

  echo -e "${GREEN}✅ Subscribed to: $show_name${NC}"
  echo -e "   Feed: $feed_url"
}

# Sync all subscriptions
sync_all() {
  init_state
  local subs
  subs=$(cat "$STATE_DIR/subscriptions.json")
  local count
  count=$(echo "$subs" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  No subscriptions. Use --subscribe URL to add feeds.${NC}"
    return 0
  fi

  echo -e "${BLUE}🔄 Syncing $count podcast subscriptions...${NC}"
  echo "$subs" | jq -c '.[]' | while IFS= read -r sub; do
    local url name max
    url=$(echo "$sub" | jq -r '.url')
    name=$(echo "$sub" | jq -r '.name')
    max=$(echo "$sub" | jq -r '.max_episodes // empty')

    echo -e "\n${BLUE}━━━ $name ━━━${NC}"
    download_feed "$url" "${max:-3}" "false" "false" ""
  done
  echo -e "\n${GREEN}✅ Sync complete!${NC}"
}

# Import OPML file
import_opml() {
  local opml_file="$1"
  if [[ ! -f "$opml_file" ]]; then
    echo -e "${RED}❌ OPML file not found: $opml_file${NC}"
    exit 1
  fi

  init_state
  local feeds
  feeds=$(xmlstarlet sel -t -m "//outline[@xmlUrl]" -v "@xmlUrl" -n "$opml_file" 2>/dev/null)
  local count=0

  while IFS= read -r feed_url; do
    [[ -z "$feed_url" ]] && continue
    subscribe_feed "$feed_url"
    ((count++))
  done <<< "$feeds"

  echo -e "${GREEN}✅ Imported $count feeds from OPML${NC}"
}

# Cleanup old episodes
cleanup_episodes() {
  local keep="$1"
  echo -e "${BLUE}🧹 Cleaning up episodes (keeping last $keep per show)...${NC}"

  find "$PODCAST_DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".podcast-dl" | while IFS= read -r show_dir; do
    local show_name
    show_name=$(basename "$show_dir")
    local file_count
    file_count=$(find "$show_dir" -maxdepth 1 -type f -name "*.mp3" -o -name "*.opus" -o -name "*.m4a" | wc -l)

    if [[ "$file_count" -gt "$keep" ]]; then
      local to_delete=$((file_count - keep))
      echo -e "   $show_name: $file_count episodes → keeping $keep, removing $to_delete"
      find "$show_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.opus" -o -name "*.m4a" \) | \
        sort | head -n "$to_delete" | while IFS= read -r f; do
          rm -f "$f"
          echo -e "   ${RED}🗑️  Removed: $(basename "$f")${NC}"
        done
    fi
  done
  echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Generate episode index
generate_index() {
  echo "# 🎙️ Podcast Library"
  echo ""
  echo "Generated: $(date -u '+%Y-%m-%d %H:%M UTC')"
  echo ""

  find "$PODCAST_DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".podcast-dl" | sort | while IFS= read -r show_dir; do
    local show_name
    show_name=$(basename "$show_dir")
    local count
    count=$(find "$show_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.opus" -o -name "*.m4a" \) | wc -l)

    echo "## $show_name ($count episodes)"
    echo ""
    find "$show_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.opus" -o -name "*.m4a" \) | sort -r | while IFS= read -r f; do
      echo "- $(basename "$f")"
    done
    echo ""
  done
}

# Install cron job
install_cron() {
  local interval="$1"
  local cron_expr

  case "$interval" in
    1h)  cron_expr="0 * * * *" ;;
    6h)  cron_expr="0 */6 * * *" ;;
    12h) cron_expr="0 */12 * * *" ;;
    24h) cron_expr="0 6 * * *" ;;
    *)   cron_expr="0 */6 * * *" ;;
  esac

  local script_path
  script_path=$(realpath "$0")
  local cron_line="$cron_expr cd $(dirname "$script_path") && bash $script_path --sync >> $PODCAST_DIR/.podcast-dl/sync.log 2>&1"

  # Check if already installed
  if crontab -l 2>/dev/null | grep -qF "podcast-dl.sh"; then
    echo -e "${YELLOW}⚠️  Cron job already exists. Updating...${NC}"
    crontab -l 2>/dev/null | grep -vF "podcast-dl.sh" | { cat; echo "$cron_line"; } | crontab -
  else
    (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
  fi

  echo -e "${GREEN}✅ Cron job installed: sync every $interval${NC}"
  echo -e "   Expression: $cron_expr"
  echo -e "   Log: $PODCAST_DIR/.podcast-dl/sync.log"
}

# Parse YAML subscriptions (simple parser — no external dep)
parse_yaml_subs() {
  local yaml_file="$1"
  # Extract feed URLs using grep/sed (simple YAML parsing)
  grep -E '^\s+- url:' "$yaml_file" | sed 's/.*url:\s*//' | sed 's/"//g' | sed "s/'//g"
}

# ─── Main ───

ACTION=""
FEED_URL=""
LIMIT=0
AUDIO_ONLY="false"
LIST_ONLY="false"
SEARCH_QUERY=""
DO_DOWNLOAD="false"
EPISODE_NUM=""
OPML_FILE=""
CRON_INTERVAL="6h"
KEEP="$MAX_EPISODES"

while [[ $# -gt 0 ]]; do
  case $1 in
    --feed)        FEED_URL="$2"; ACTION="feed"; shift 2 ;;
    --subs)        SUBS_FILE="$2"; ACTION="subs"; shift 2 ;;
    --subscribe)   FEED_URL="$2"; ACTION="subscribe"; shift 2 ;;
    --sync)        ACTION="sync"; shift ;;
    --list)        LIST_ONLY="true"; shift ;;
    --search)      SEARCH_QUERY="$2"; shift 2 ;;
    --download)    DO_DOWNLOAD="true"; shift ;;
    --limit)       LIMIT="$2"; shift 2 ;;
    --episode)     EPISODE_NUM="$2"; shift 2 ;;
    --output)      PODCAST_DIR="$2"; shift 2 ;;
    --audio-only)  AUDIO_ONLY="true"; shift ;;
    --format)      AUDIO_FORMAT="$2"; shift 2 ;;
    --quality)     AUDIO_QUALITY="$2"; shift 2 ;;
    --keep)        KEEP="$2"; shift 2 ;;
    --cleanup)     ACTION="cleanup"; shift ;;
    --index)       ACTION="index"; shift ;;
    --import-opml) OPML_FILE="$2"; ACTION="opml"; shift 2 ;;
    --install-cron) ACTION="cron"; shift ;;
    --interval)    CRON_INTERVAL="$2"; shift 2 ;;
    --user-agent)  USER_AGENT="$2"; shift 2 ;;
    -h|--help)     usage ;;
    *)             echo "Unknown option: $1"; usage ;;
  esac
done

check_deps
init_state

case "$ACTION" in
  feed)
    download_feed "$FEED_URL" "$LIMIT" "$AUDIO_ONLY" "$LIST_ONLY" "$SEARCH_QUERY"
    ;;
  subs)
    if [[ -n "$SUBS_FILE" && -f "$SUBS_FILE" ]]; then
      while IFS= read -r url; do
        [[ -z "$url" ]] && continue
        download_feed "$url" "$LIMIT" "$AUDIO_ONLY" "$LIST_ONLY" "$SEARCH_QUERY"
      done < <(parse_yaml_subs "$SUBS_FILE")
    else
      echo -e "${RED}❌ Subscriptions file not found: $SUBS_FILE${NC}"
      exit 1
    fi
    ;;
  subscribe)
    subscribe_feed "$FEED_URL"
    ;;
  sync)
    sync_all
    ;;
  cleanup)
    cleanup_episodes "$KEEP"
    ;;
  index)
    generate_index
    ;;
  opml)
    import_opml "$OPML_FILE"
    ;;
  cron)
    install_cron "$CRON_INTERVAL"
    ;;
  *)
    echo -e "${RED}❌ No action specified. Use --help for usage.${NC}"
    exit 1
    ;;
esac
