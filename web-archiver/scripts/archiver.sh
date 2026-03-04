#!/bin/bash
# Web Page Archiver — Save complete web pages as self-contained HTML files
set -euo pipefail

# Configuration
ARCHIVE_DIR="${WEB_ARCHIVE_DIR:-$HOME/web-archive}"
TIMEOUT="${WEB_ARCHIVE_TIMEOUT:-30}"
INCLUDE_JS="${WEB_ARCHIVE_JS:-true}"
USER_AGENT="${WEB_ARCHIVE_UA:-Mozilla/5.0 (compatible; WebArchiver/1.0)}"
INDEX_FILE="$ARCHIVE_DIR/index.tsv"

# Ensure archive directory exists
mkdir -p "$ARCHIVE_DIR"

# Initialize index if needed
if [ ! -f "$INDEX_FILE" ]; then
  echo -e "date\turl\tfile\tsize\ttags\ttitle" > "$INDEX_FILE"
fi

# ─── HELPERS ─────────────────────────────────────────────────────────

slugify() {
  echo "$1" | sed -E 's|https?://||;s|[^a-zA-Z0-9._-]|_|g;s|_+|_|g;s|^_||;s|_$||' | cut -c1-80
}

extract_title() {
  grep -ioP '(?<=<title>).*?(?=</title>)' "$1" 2>/dev/null | head -1 | sed 's/[[:space:]]\+/ /g;s/^ //;s/ $//' || echo "(untitled)"
}

file_size_human() {
  local bytes=$(stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null || echo 0)
  if [ "$bytes" -gt 1048576 ]; then
    echo "$(( bytes / 1048576 )).$(( (bytes % 1048576) * 10 / 1048576 )) MB"
  elif [ "$bytes" -gt 1024 ]; then
    echo "$(( bytes / 1024 )) KB"
  else
    echo "${bytes} B"
  fi
}

check_monolith() {
  if ! command -v monolith &>/dev/null; then
    echo "❌ monolith not found. Run: bash scripts/install.sh"
    exit 1
  fi
}

# ─── SAVE ────────────────────────────────────────────────────────────

cmd_save() {
  check_monolith
  local url=""
  local tags=()
  local no_js=false
  local no_images=false
  local isolate=false
  local if_changed=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --tag) tags+=("$2"); shift 2 ;;
      --no-js) no_js=true; shift ;;
      --no-images) no_images=true; shift ;;
      --isolate) isolate=true; shift ;;
      --if-changed) if_changed=true; shift ;;
      *) url="$1"; shift ;;
    esac
  done

  if [ -z "$url" ]; then
    echo "Usage: archiver.sh save <url> [--tag <tag>] [--no-js] [--no-images] [--isolate] [--if-changed]"
    exit 1
  fi

  # Build date-based path
  local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local year=$(date -u +%Y)
  local month=$(date -u +%m)
  local timestamp=$(date -u +%Y-%m-%d_%H%M%S)
  local slug=$(slugify "$url")
  local out_dir="$ARCHIVE_DIR/$year/$month"
  local out_file="$out_dir/${slug}_${timestamp}.html"

  mkdir -p "$out_dir"

  # Check if-changed: compare with last archive of same URL
  if $if_changed; then
    local last_file=$(grep -F "$url" "$INDEX_FILE" 2>/dev/null | tail -1 | cut -f3)
    if [ -n "$last_file" ] && [ -f "$ARCHIVE_DIR/$last_file" ]; then
      # Download to temp, compare checksums
      local tmp_file=$(mktemp /tmp/archiver_XXXXXX.html)
      if _do_save "$url" "$tmp_file" "$no_js" "$no_images" "$isolate" 2>/dev/null; then
        local old_hash=$(md5sum "$ARCHIVE_DIR/$last_file" 2>/dev/null | cut -d' ' -f1 || md5 -q "$ARCHIVE_DIR/$last_file" 2>/dev/null)
        local new_hash=$(md5sum "$tmp_file" 2>/dev/null | cut -d' ' -f1 || md5 -q "$tmp_file" 2>/dev/null)
        if [ "$old_hash" = "$new_hash" ]; then
          echo "⏭️  No changes detected for $url"
          rm -f "$tmp_file"
          return 0
        fi
        mv "$tmp_file" "$out_file"
      else
        rm -f "$tmp_file"
        echo "❌ Failed to save $url"
        return 1
      fi
    else
      _do_save "$url" "$out_file" "$no_js" "$no_images" "$isolate" || { echo "❌ Failed to save $url"; return 1; }
    fi
  else
    echo "🔖 Saving $url ..."
    _do_save "$url" "$out_file" "$no_js" "$no_images" "$isolate" || { echo "❌ Failed to save $url"; return 1; }
  fi

  # Extract metadata
  local title=$(extract_title "$out_file")
  local size=$(file_size_human "$out_file")
  local rel_path="$year/$month/$(basename "$out_file")"
  local tag_str=$(IFS=,; echo "${tags[*]:-}")

  # Log to index
  echo -e "${now}\t${url}\t${rel_path}\t${size}\t${tag_str}\t${title}" >> "$INDEX_FILE"

  # Create tag symlinks
  for tag in "${tags[@]}"; do
    local tag_dir="$ARCHIVE_DIR/tags/$tag"
    mkdir -p "$tag_dir"
    ln -sf "../../$rel_path" "$tag_dir/$(basename "$out_file")" 2>/dev/null || true
  done

  echo "✅ Saved → $out_file"
  echo "   Size: $size | Tags: ${tag_str:-none}"
}

_do_save() {
  local url="$1" out="$2" no_js="$3" no_images="$4" isolate="$5"
  local args=(-u "$USER_AGENT" -t "$TIMEOUT")

  if $no_js; then args+=(-j); fi
  if $no_images; then args+=(-I); fi
  if $isolate; then args+=(-e); fi

  monolith "${args[@]}" "$url" -o "$out"
}

# ─── BATCH ───────────────────────────────────────────────────────────

cmd_batch() {
  local file=""
  local extra_args=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --tag) extra_args+=(--tag "$2"); shift 2 ;;
      *) file="$1"; shift ;;
    esac
  done

  if [ -z "$file" ] || [ ! -f "$file" ]; then
    echo "Usage: archiver.sh batch <url-list-file> [--tag <tag>]"
    exit 1
  fi

  local total=$(grep -c '[^[:space:]]' "$file")
  local saved=0
  local failed=0
  local i=0

  echo "📦 Batch archiving $total URLs..."

  while IFS= read -r url; do
    [ -z "$url" ] && continue
    [[ "$url" =~ ^# ]] && continue
    i=$((i + 1))

    if cmd_save "$url" "${extra_args[@]}" 2>/dev/null; then
      saved=$((saved + 1))
      echo "[$i/$total] ✅ $(echo "$url" | sed 's|https\?://||' | cut -c1-60)"
    else
      failed=$((failed + 1))
      echo "[$i/$total] ❌ $(echo "$url" | sed 's|https\?://||' | cut -c1-60)"
    fi

    # Rate limit: 2 second delay between saves
    sleep 2
  done < "$file"

  echo "Done: $saved saved, $failed failed"
}

# ─── SEARCH ──────────────────────────────────────────────────────────

cmd_search() {
  local query=""
  local domain=""
  local tag=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --domain) domain="$2"; shift 2 ;;
      --tag) tag="$2"; shift 2 ;;
      *) query="$1"; shift ;;
    esac
  done

  if [ -z "$query" ] && [ -z "$domain" ] && [ -z "$tag" ]; then
    echo "Usage: archiver.sh search <query> | --domain <domain> | --tag <tag>"
    exit 1
  fi

  local results=()
  local count=0

  # Search by tag (via symlinks)
  if [ -n "$tag" ]; then
    local tag_dir="$ARCHIVE_DIR/tags/$tag"
    if [ -d "$tag_dir" ]; then
      echo "🏷️  Archives tagged '$tag':"
      ls -1 "$tag_dir" | while read -r f; do
        count=$((count + 1))
        local entry=$(grep "$(basename "$f" .html)" "$INDEX_FILE" 2>/dev/null | tail -1)
        local date=$(echo "$entry" | cut -f1 | cut -dT -f1)
        local title=$(echo "$entry" | cut -f6)
        echo "  $count. [$date] $title"
      done
    else
      echo "No archives with tag '$tag'"
    fi
    return
  fi

  # Search by domain
  if [ -n "$domain" ]; then
    echo "🔍 Archives from $domain:"
    grep -i "$domain" "$INDEX_FILE" 2>/dev/null | tail -n +1 | while IFS=$'\t' read -r date url file size tags title; do
      count=$((count + 1))
      echo "  $count. [${date:0:10}] $title ($size) [${tags:-no tags}]"
      echo "     $file"
    done
    return
  fi

  # Full-text search
  echo "🔍 Searching for \"$query\"..."

  # First search index (title + URL)
  grep -i "$query" "$INDEX_FILE" 2>/dev/null | while IFS=$'\t' read -r date url file size tags title; do
    count=$((count + 1))
    echo "  $count. [${date:0:10}] $title ($size) [${tags:-no tags}]"
    echo "     $ARCHIVE_DIR/$file"
  done

  # If fzf available, offer interactive search
  if command -v fzf &>/dev/null && [ -t 1 ]; then
    echo ""
    echo "💡 Tip: pipe to fzf for interactive filtering"
  fi
}

# ─── LIST ────────────────────────────────────────────────────────────

cmd_list() {
  local recent=20

  while [[ $# -gt 0 ]]; do
    case $1 in
      --recent) recent="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  echo "📋 Recent archives (last $recent):"
  tail -n "$recent" "$INDEX_FILE" | while IFS=$'\t' read -r date url file size tags title; do
    [ "$date" = "date" ] && continue
    echo "  [${date:0:10}] $title ($size) [${tags:-}]"
    echo "     $url"
  done
}

# ─── STATS ───────────────────────────────────────────────────────────

cmd_stats() {
  local total=$(( $(wc -l < "$INDEX_FILE") - 1 ))
  local total_size=$(du -sh "$ARCHIVE_DIR" 2>/dev/null | cut -f1)
  local domains=$(tail -n +2 "$INDEX_FILE" | cut -f2 | sed 's|https\?://||;s|/.*||' | sort -u | wc -l)
  local oldest=$(tail -n +2 "$INDEX_FILE" | head -1 | cut -f1 | cut -dT -f1)
  local newest=$(tail -n +2 "$INDEX_FILE" | tail -1 | cut -f1 | cut -dT -f1)

  echo "📊 Web Archive Stats"
  echo "   Total pages: $total"
  echo "   Total size:  $total_size"
  echo "   Domains:     $domains"
  echo "   Oldest:      ${oldest:-N/A}"
  echo "   Newest:      ${newest:-N/A}"

  # Top domains
  echo ""
  echo "🌐 Top domains:"
  tail -n +2 "$INDEX_FILE" | cut -f2 | sed 's|https\?://||;s|/.*||' | sort | uniq -c | sort -rn | head -10 | while read -r count domain; do
    echo "   $count  $domain"
  done
}

# ─── EXPORT ──────────────────────────────────────────────────────────

cmd_export() {
  local format="json"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --format) format="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  case "$format" in
    json)
      echo "["
      local first=true
      tail -n +2 "$INDEX_FILE" | while IFS=$'\t' read -r date url file size tags title; do
        $first || echo ","
        first=false
        printf '  {"date":"%s","url":"%s","file":"%s","size":"%s","tags":"%s","title":"%s"}' \
          "$date" "$url" "$file" "$size" "$tags" "$title"
      done
      echo ""
      echo "]"
      ;;
    csv)
      echo "date,url,file,size,tags,title"
      tail -n +2 "$INDEX_FILE" | tr '\t' ','
      ;;
    *)
      cat "$INDEX_FILE"
      ;;
  esac
}

# ─── PRUNE ───────────────────────────────────────────────────────────

cmd_prune() {
  local days=90

  while [[ $# -gt 0 ]]; do
    case $1 in
      --older-than) days="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  echo "🗑️  Pruning archives older than $days days..."
  local count=0

  find "$ARCHIVE_DIR" -name "*.html" -mtime +$days -type f | while read -r f; do
    echo "  Removing: $(basename "$f")"
    rm -f "$f"
    count=$((count + 1))
  done

  # Rebuild index (remove entries for deleted files)
  if [ -f "$INDEX_FILE" ]; then
    local tmp=$(mktemp)
    head -1 "$INDEX_FILE" > "$tmp"
    tail -n +2 "$INDEX_FILE" | while IFS=$'\t' read -r date url file size tags title; do
      [ -f "$ARCHIVE_DIR/$file" ] && echo -e "${date}\t${url}\t${file}\t${size}\t${tags}\t${title}"
    done >> "$tmp"
    mv "$tmp" "$INDEX_FILE"
  fi

  echo "✅ Prune complete"
}

# ─── DEDUP ───────────────────────────────────────────────────────────

cmd_dedup() {
  echo "🔄 Checking for duplicate URLs..."
  local dupes=$(tail -n +2 "$INDEX_FILE" | cut -f2 | sort | uniq -d)

  if [ -z "$dupes" ]; then
    echo "✅ No duplicates found"
    return
  fi

  local count=0
  echo "$dupes" | while read -r url; do
    # Keep the newest, remove older
    local files=$(grep -F "$url" "$INDEX_FILE" | sort -t$'\t' -k1 | head -n -1 | cut -f3)
    echo "$files" | while read -r f; do
      [ -f "$ARCHIVE_DIR/$f" ] && rm -f "$ARCHIVE_DIR/$f" && count=$((count + 1))
      echo "  Removed older: $f"
    done
  done

  # Rebuild index
  cmd_prune --older-than 999999 2>/dev/null
  echo "✅ Deduplication complete"
}

# ─── MAIN ────────────────────────────────────────────────────────────

case "${1:-help}" in
  save)    shift; cmd_save "$@" ;;
  batch)   shift; cmd_batch "$@" ;;
  search)  shift; cmd_search "$@" ;;
  list)    shift; cmd_list "$@" ;;
  stats)   cmd_stats ;;
  export)  shift; cmd_export "$@" ;;
  prune)   shift; cmd_prune "$@" ;;
  dedup)   cmd_dedup ;;
  help|*)
    echo "Web Page Archiver — Save complete web pages as self-contained HTML"
    echo ""
    echo "Usage: archiver.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  save <url>          Save a web page"
    echo "  batch <file>        Save URLs from a text file"
    echo "  search <query>      Search archived pages"
    echo "  list [--recent N]   List recent archives"
    echo "  stats               Show archive statistics"
    echo "  export [--format]   Export index (json/csv/tsv)"
    echo "  prune [--older-than N]  Remove old archives"
    echo "  dedup               Remove duplicate URL archives"
    echo ""
    echo "Options for save:"
    echo "  --tag <tag>         Add tag (repeatable)"
    echo "  --no-js             Exclude JavaScript"
    echo "  --no-images         Exclude images"
    echo "  --isolate           No external network requests"
    echo "  --if-changed        Only save if content changed"
    ;;
esac
