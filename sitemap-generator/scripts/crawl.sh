#!/bin/bash
# Sitemap Generator — Crawls a website and generates sitemap.xml
# Usage: bash crawl.sh --url https://example.com --depth 3 --output sitemap.xml

set -euo pipefail

# Defaults
URL=""
DEPTH=3
OUTPUT="sitemap.xml"
EXCLUDE=""
INCLUDE=""
DELAY="0.5"
TIMEOUT=10
MAX_URLS=50000
USER_AGENT="SitemapBot/1.0"
RESPECT_ROBOTS=false
DEFAULT_CHANGEFREQ="weekly"
DEFAULT_PRIORITY="0.5"
DRY_RUN=false
SPLIT=""
OUTPUT_DIR="."
CONCURRENCY=5

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --url) URL="$2"; shift 2 ;;
    --depth) DEPTH="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    --include) INCLUDE="$2"; shift 2 ;;
    --delay) DELAY="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --max-urls) MAX_URLS="$2"; shift 2 ;;
    --user-agent) USER_AGENT="$2"; shift 2 ;;
    --respect-robots) RESPECT_ROBOTS=true; shift ;;
    --changefreq) DEFAULT_CHANGEFREQ="$2"; shift 2 ;;
    --priority) DEFAULT_PRIORITY="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --split) SPLIT="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --concurrency) CONCURRENCY="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: bash crawl.sh --url <URL> [options]"
      echo ""
      echo "Options:"
      echo "  --url <URL>          Root URL to crawl (required)"
      echo "  --depth <N>          Max crawl depth (default: 3)"
      echo "  --output <file>      Output file (default: sitemap.xml)"
      echo "  --exclude <regex>    Exclude URLs matching pattern"
      echo "  --include <regex>    Only include URLs matching pattern"
      echo "  --delay <secs>       Delay between requests (default: 0.5)"
      echo "  --timeout <secs>     HTTP timeout (default: 10)"
      echo "  --max-urls <N>       Max URLs (default: 50000)"
      echo "  --user-agent <str>   User-Agent header"
      echo "  --respect-robots     Respect robots.txt"
      echo "  --changefreq <str>   Default changefreq (default: weekly)"
      echo "  --priority <N>       Default priority 0.0-1.0 (default: 0.5)"
      echo "  --dry-run            List URLs without generating XML"
      echo "  --split <N>          Split every N URLs"
      echo "  --output-dir <dir>   Directory for split output"
      echo "  --concurrency <N>    Parallel requests (default: 5)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$URL" ]]; then
  echo "Error: --url is required"
  echo "Usage: bash crawl.sh --url https://example.com [options]"
  exit 1
fi

# Normalize base URL (remove trailing slash)
BASE_URL="${URL%/}"
# Extract domain
DOMAIN=$(echo "$BASE_URL" | sed -E 's|^https?://([^/]+).*|\1|')
SCHEME=$(echo "$BASE_URL" | sed -E 's|^(https?)://.*|\1|')

# Temp files
TMPDIR=$(mktemp -d)
VISITED="$TMPDIR/visited.txt"
QUEUE="$TMPDIR/queue.txt"
NEXT_QUEUE="$TMPDIR/next_queue.txt"
FOUND="$TMPDIR/found.txt"
ROBOTS_DISALLOW="$TMPDIR/robots_disallow.txt"

touch "$VISITED" "$QUEUE" "$FOUND" "$ROBOTS_DISALLOW"

# Cleanup on exit
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# Fetch and parse robots.txt
if $RESPECT_ROBOTS; then
  echo "[robots] Fetching robots.txt..."
  ROBOTS_URL="${SCHEME}://${DOMAIN}/robots.txt"
  ROBOTS_CONTENT=$(curl -sL --max-time "$TIMEOUT" -A "$USER_AGENT" "$ROBOTS_URL" 2>/dev/null || true)
  if [[ -n "$ROBOTS_CONTENT" ]]; then
    echo "$ROBOTS_CONTENT" | awk '
      /^[Uu]ser-agent: \*/ { active=1; next }
      /^[Uu]ser-agent:/ { active=0; next }
      active && /^[Dd]isallow:/ { gsub(/^[Dd]isallow: */, ""); gsub(/ *$/, ""); if ($0 != "") print $0 }
    ' > "$ROBOTS_DISALLOW"
    DISALLOW_COUNT=$(wc -l < "$ROBOTS_DISALLOW")
    echo "[robots] Found $DISALLOW_COUNT disallow rules"
  fi
fi

# Check if URL is blocked by robots.txt
is_blocked() {
  local url_path="$1"
  if [[ ! -s "$ROBOTS_DISALLOW" ]]; then
    return 1
  fi
  while IFS= read -r pattern; do
    # Simple prefix matching (covers most cases)
    if [[ "$url_path" == "$pattern"* ]]; then
      return 0
    fi
  done < "$ROBOTS_DISALLOW"
  return 1
}

# Normalize URL
normalize_url() {
  local u="$1"
  # Remove fragment
  u="${u%%#*}"
  # Remove trailing slash (except root)
  if [[ "$u" != "${SCHEME}://${DOMAIN}" ]] && [[ "$u" != "${SCHEME}://${DOMAIN}/" ]]; then
    u="${u%/}"
  fi
  # Ensure root has trailing slash
  if [[ "$u" == "${SCHEME}://${DOMAIN}" ]]; then
    u="${u}/"
  fi
  echo "$u"
}

# Calculate URL depth
url_depth() {
  local path
  path=$(echo "$1" | sed "s|${SCHEME}://${DOMAIN}||")
  path="${path%/}"
  if [[ -z "$path" || "$path" == "/" ]]; then
    echo 0
  else
    echo "$path" | tr '/' '\n' | grep -c . || echo 0
  fi
}

# Auto-assign priority based on depth
auto_priority() {
  local d="$1"
  case $d in
    0) echo "1.0" ;;
    1) echo "0.8" ;;
    2) echo "0.6" ;;
    3) echo "0.4" ;;
    *) echo "0.3" ;;
  esac
}

# Auto-assign changefreq based on URL pattern
auto_changefreq() {
  local url="$1"
  local path
  path=$(echo "$url" | sed "s|${SCHEME}://${DOMAIN}||")
  
  if [[ "$path" == "/" || "$path" == "" ]]; then
    echo "daily"
  elif echo "$path" | grep -qiE '/blog|/news|/posts|/articles'; then
    echo "weekly"
  elif echo "$path" | grep -qiE '/about|/contact|/privacy|/terms|/legal'; then
    echo "monthly"
  elif echo "$path" | grep -qiE '/docs|/documentation|/help|/faq'; then
    echo "monthly"
  else
    echo "$DEFAULT_CHANGEFREQ"
  fi
}

# Extract links from HTML
extract_links() {
  local html="$1"
  # Extract href values from anchor tags
  echo "$html" | grep -oiE 'href="[^"]*"' | sed -E 's/^href="//I; s/"$//' | while read -r link; do
    # Skip non-HTTP links
    case "$link" in
      mailto:*|tel:*|javascript:*|data:*|'#'*) continue ;;
    esac
    
    # Resolve relative URLs
    if [[ "$link" == //* ]]; then
      link="${SCHEME}:${link}"
    elif [[ "$link" == /* ]]; then
      link="${SCHEME}://${DOMAIN}${link}"
    elif [[ "$link" != http* ]]; then
      continue  # Skip other relative URLs for simplicity
    fi
    
    # Only include same-domain URLs
    local link_domain
    link_domain=$(echo "$link" | sed -E 's|^https?://([^/]+).*|\1|')
    if [[ "$link_domain" != "$DOMAIN" ]]; then
      continue
    fi
    
    # Normalize
    normalize_url "$link"
  done
}

# Apply filters
should_include() {
  local url="$1"
  
  # Check exclude pattern
  if [[ -n "$EXCLUDE" ]] && echo "$url" | grep -qE "$EXCLUDE"; then
    return 1
  fi
  
  # Check include pattern
  if [[ -n "$INCLUDE" ]] && ! echo "$url" | grep -qE "$INCLUDE"; then
    return 1
  fi
  
  # Skip common non-page extensions (strip query params for check)
  local url_no_query="${url%%\?*}"
  if echo "$url_no_query" | grep -qiE '\.(jpg|jpeg|png|gif|svg|webp|ico|css|js|woff|woff2|ttf|eot|mp4|mp3|avi|mov|pdf|zip|gz|tar|rar|exe|dmg|xml|json|txt|rss|atom)$'; then
    return 1
  fi
  
  # Check robots.txt
  if $RESPECT_ROBOTS; then
    local path
    path=$(echo "$url" | sed "s|${SCHEME}://${DOMAIN}||")
    if is_blocked "$path"; then
      return 1
    fi
  fi
  
  return 0
}

echo "[crawl] Starting: $BASE_URL (depth: $DEPTH)"

# Seed the queue
echo "$BASE_URL/" > "$QUEUE"

TOTAL_FOUND=0

# BFS crawl
for ((d=0; d<=DEPTH; d++)); do
  if [[ ! -s "$QUEUE" ]]; then
    break
  fi
  
  LEVEL_COUNT=$(wc -l < "$QUEUE")
  echo "[crawl] Depth $d: $LEVEL_COUNT URLs to process"
  
  > "$NEXT_QUEUE"
  
  while IFS= read -r page_url; do
    # Skip if already visited
    if grep -qFx "$page_url" "$VISITED" 2>/dev/null; then
      continue
    fi
    echo "$page_url" >> "$VISITED"
    
    # Check max URLs
    if [[ $TOTAL_FOUND -ge $MAX_URLS ]]; then
      echo "[crawl] Reached max URLs ($MAX_URLS), stopping"
      break 2
    fi
    
    # Fetch page
    HTTP_RESPONSE=$(curl -sL -w "\n%{http_code}" --max-time "$TIMEOUT" -A "$USER_AGENT" "$page_url" 2>/dev/null || echo -e "\n000")
    HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -1)
    HTML_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')
    
    if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
      # Check content type (only process HTML)
      if should_include "$page_url"; then
        echo "$page_url" >> "$FOUND"
        TOTAL_FOUND=$((TOTAL_FOUND + 1))
        echo "[crawl] Found: $page_url ($HTTP_CODE)"
      fi
      
      # Extract links for next depth level
      if [[ $d -lt $DEPTH ]]; then
        extract_links "$HTML_BODY" | while read -r link; do
          if ! grep -qFx "$link" "$VISITED" 2>/dev/null && should_include "$link"; then
            echo "$link"
          fi
        done >> "$NEXT_QUEUE"
      fi
    else
      echo "[crawl] Skip: $page_url ($HTTP_CODE)"
    fi
    
    # Polite delay
    sleep "$DELAY"
    
  done < "$QUEUE"
  
  # Deduplicate next queue
  if [[ -s "$NEXT_QUEUE" ]]; then
    sort -u "$NEXT_QUEUE" > "$QUEUE"
  else
    > "$QUEUE"
  fi
done

# Sort and deduplicate found URLs
sort -u "$FOUND" -o "$FOUND"
TOTAL=$(wc -l < "$FOUND")

echo "[crawl] Crawl complete: $TOTAL URLs found"

# Dry run — just print URLs
if $DRY_RUN; then
  cat "$FOUND"
  echo "[done] $TOTAL URLs (dry run — no XML generated)"
  exit 0
fi

# Generate XML
TODAY=$(date +%Y-%m-%d)

generate_xml() {
  local input_file="$1"
  local output_file="$2"
  
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
    
    while IFS= read -r url; do
      local d
      d=$(url_depth "$url")
      local pri
      pri=$(auto_priority "$d")
      local freq
      freq=$(auto_changefreq "$url")
      
      echo "  <url>"
      echo "    <loc>$url</loc>"
      echo "    <lastmod>$TODAY</lastmod>"
      echo "    <changefreq>$freq</changefreq>"
      echo "    <priority>$pri</priority>"
      echo "  </url>"
    done < "$input_file"
    
    echo '</urlset>'
  } > "$output_file"
}

# Split mode
if [[ -n "$SPLIT" && $TOTAL -gt $SPLIT ]]; then
  mkdir -p "$OUTPUT_DIR"
  
  # Split found URLs into chunks
  PART=1
  split -l "$SPLIT" "$FOUND" "$TMPDIR/chunk_"
  
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  } > "$OUTPUT_DIR/sitemap-index.xml"
  
  for chunk in "$TMPDIR"/chunk_*; do
    PART_FILE="$OUTPUT_DIR/sitemap-${PART}.xml"
    generate_xml "$chunk" "$PART_FILE"
    CHUNK_COUNT=$(wc -l < "$chunk")
    echo "[split] sitemap-${PART}.xml ($CHUNK_COUNT URLs)"
    
    echo "  <sitemap>" >> "$OUTPUT_DIR/sitemap-index.xml"
    echo "    <loc>${BASE_URL}/sitemap-${PART}.xml</loc>" >> "$OUTPUT_DIR/sitemap-index.xml"
    echo "    <lastmod>$TODAY</lastmod>" >> "$OUTPUT_DIR/sitemap-index.xml"
    echo "  </sitemap>" >> "$OUTPUT_DIR/sitemap-index.xml"
    
    PART=$((PART + 1))
  done
  
  echo '</sitemapindex>' >> "$OUTPUT_DIR/sitemap-index.xml"
  
  echo "[done] $TOTAL URLs → $((PART - 1)) sitemaps + sitemap-index.xml in $OUTPUT_DIR/"
else
  # Single sitemap
  generate_xml "$FOUND" "$OUTPUT"
  echo "[done] $TOTAL URLs → $OUTPUT"
fi
