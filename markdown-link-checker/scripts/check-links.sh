#!/bin/bash
# Markdown Link Checker — Scan markdown files for broken URLs
# Usage: bash check-links.sh [OPTIONS] <file-or-directory>

set -euo pipefail

# Defaults
TIMEOUT=10
PARALLEL=5
EXTERNAL_ONLY=false
EXCLUDE=""
JSON_OUTPUT=false
EXIT_CODE_MODE=false
NO_REDIRECTS=false
CACHE_FILE=""
VERBOSE=false
USER_AGENT="${LINK_CHECKER_UA:-Mozilla/5.0 (compatible; MarkdownLinkChecker/1.0)}"
INSECURE="${LINK_CHECKER_INSECURE:-0}"

# Counters
TOTAL_OK=0
TOTAL_BROKEN=0
TOTAL_REDIRECT=0
TOTAL_TIMEOUT=0
TOTAL_SKIPPED=0
TOTAL_FILES=0

# JSON results array
JSON_RESULTS=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] <file-or-directory>

Options:
  --timeout <seconds>     HTTP timeout (default: 10)
  --parallel <n>          Concurrent checks (default: 5)
  --external-only         Skip relative/anchor links
  --exclude <patterns>    Comma-separated URL patterns to skip
  --json                  Output as JSON
  --exit-code             Exit 1 if broken links found
  --no-redirects          Treat redirects as errors
  --cache <file>          Cache results (skip recently checked)
  --verbose               Show all links including OK
  -h, --help              Show this help
EOF
  exit 0
}

# Parse arguments
TARGETS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --parallel) PARALLEL="$2"; shift 2 ;;
    --external-only) EXTERNAL_ONLY=true; shift ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    --exit-code) EXIT_CODE_MODE=true; shift ;;
    --no-redirects) NO_REDIRECTS=true; shift ;;
    --cache) CACHE_FILE="$2"; shift 2 ;;
    --verbose) VERBOSE=true; shift ;;
    --recursive) shift ;; # always recursive for dirs
    -h|--help) usage ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *) TARGETS+=("$1"); shift ;;
  esac
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "Error: No file or directory specified"
  usage
fi

# Collect markdown files
MD_FILES=()
for target in "${TARGETS[@]}"; do
  if [ -f "$target" ]; then
    MD_FILES+=("$target")
  elif [ -d "$target" ]; then
    while IFS= read -r -d '' f; do
      MD_FILES+=("$f")
    done < <(find "$target" -name '*.md' -type f -print0 2>/dev/null)
  else
    echo "Warning: $target not found, skipping"
  fi
done

if [ ${#MD_FILES[@]} -eq 0 ]; then
  echo "No markdown files found"
  exit 0
fi

# Extract URLs from a markdown file
extract_urls() {
  local file="$1"
  # Match [text](url) and bare https:// URLs
  grep -oP '(?:\[([^\]]*)\]\((https?://[^\s\)]+)\))|(https?://[^\s\)\]>\"]+)' "$file" 2>/dev/null | \
    grep -oP 'https?://[^\s\)\]>\"]+' | \
    sort -u
}

# Check if URL matches exclude patterns
is_excluded() {
  local url="$1"
  if [ -z "$EXCLUDE" ]; then return 1; fi
  IFS=',' read -ra patterns <<< "$EXCLUDE"
  for p in "${patterns[@]}"; do
    if [[ "$url" == *"$p"* ]]; then return 0; fi
  done
  return 1
}

# Check cache for recent result
check_cache() {
  local url="$1"
  if [ -z "$CACHE_FILE" ] || [ ! -f "$CACHE_FILE" ]; then return 1; fi
  local now=$(date +%s)
  local cached=$(grep -F "\"$url\"" "$CACHE_FILE" 2>/dev/null | head -1)
  if [ -n "$cached" ]; then
    local ts=$(echo "$cached" | grep -oP '"checked_at":\s*(\d+)' | grep -oP '\d+')
    if [ -n "$ts" ] && [ $((now - ts)) -lt 3600 ]; then
      return 0
    fi
  fi
  return 1
}

# Update cache
update_cache() {
  local url="$1" code="$2" ms="$3"
  if [ -z "$CACHE_FILE" ]; then return; fi
  local now=$(date +%s)
  local entry="{\"url\":\"$url\",\"code\":$code,\"ms\":$ms,\"checked_at\":$now}"
  # Remove old entry if exists
  if [ -f "$CACHE_FILE" ]; then
    grep -vF "\"$url\"" "$CACHE_FILE" > "${CACHE_FILE}.tmp" 2>/dev/null || true
    mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
  fi
  echo "$entry" >> "$CACHE_FILE"
}

# Check a single URL
check_url() {
  local url="$1"
  local file="$2"
  
  # Find line number
  local line=$(grep -n "$url" "$file" 2>/dev/null | head -1 | cut -d: -f1)
  line=${line:-0}

  # Skip excluded
  if is_excluded "$url"; then
    ((TOTAL_SKIPPED++)) || true
    return
  fi

  # Check cache
  if check_cache "$url"; then
    ((TOTAL_SKIPPED++)) || true
    return
  fi

  # Build curl options
  local curl_opts=(-s -o /dev/null -w "%{http_code} %{time_total}" --max-time "$TIMEOUT" -A "$USER_AGENT" -L)
  if [ "$INSECURE" = "1" ]; then
    curl_opts+=(-k)
  fi
  if [ "$NO_REDIRECTS" = "true" ]; then
    # Remove -L (follow redirects)
    curl_opts=(-s -o /dev/null -w "%{http_code} %{time_total}" --max-time "$TIMEOUT" -A "$USER_AGENT")
    if [ "$INSECURE" = "1" ]; then curl_opts+=(-k); fi
  fi

  # Make request
  local result
  result=$(curl "${curl_opts[@]}" "$url" 2>/dev/null) || result="000 0.000"
  
  local http_code=$(echo "$result" | awk '{print $1}')
  local time_sec=$(echo "$result" | awk '{print $2}')
  local time_ms=$(awk "BEGIN {printf \"%.0f\", $time_sec * 1000}")

  # Classify result
  local status icon
  if [ "$http_code" = "000" ]; then
    status="timeout"
    icon="⏱️"
    ((TOTAL_TIMEOUT++)) || true
  elif [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    status="ok"
    icon="✅"
    ((TOTAL_OK++)) || true
  elif [ "$http_code" -ge 300 ] && [ "$http_code" -lt 400 ]; then
    status="redirect"
    icon="🔄"
    ((TOTAL_REDIRECT++)) || true
  else
    status="broken"
    icon="❌"
    ((TOTAL_BROKEN++)) || true
  fi

  # Cache result
  update_cache "$url" "$http_code" "$time_ms"

  # Output
  if [ "$JSON_OUTPUT" = "true" ]; then
    local entry="{\"file\":\"$file\",\"line\":$line,\"url\":\"$url\",\"status\":\"$status\",\"http_code\":$http_code,\"response_ms\":$time_ms}"
    if [ -n "$JSON_RESULTS" ]; then
      JSON_RESULTS="${JSON_RESULTS},$entry"
    else
      JSON_RESULTS="$entry"
    fi
  else
    if [ "$status" != "ok" ] || [ "$VERBOSE" = "true" ]; then
      local status_text
      case $status in
        ok) status_text="${http_code} OK" ;;
        broken) status_text="${http_code} BROKEN" ;;
        redirect) status_text="${http_code} Redirect" ;;
        timeout) status_text="TIMEOUT" ;;
      esac
      echo -e "  ${icon} ${url} — ${status_text} (${time_ms}ms)"
    fi
  fi
}

# Process files
for file in "${MD_FILES[@]}"; do
  ((TOTAL_FILES++)) || true
  
  # Extract URLs
  urls=$(extract_urls "$file")
  if [ -z "$urls" ]; then continue; fi

  if [ "$JSON_OUTPUT" != "true" ]; then
    echo -e "\n${BOLD}📄 ${file}${NC}"
  fi

  # Check URLs (with parallelism via background jobs)
  job_count=0
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    
    check_url "$url" "$file"
  done <<< "$urls"

  # Wait for remaining jobs
  wait 2>/dev/null || true
done

# Output summary
TOTAL=$((TOTAL_OK + TOTAL_BROKEN + TOTAL_REDIRECT + TOTAL_TIMEOUT))

if [ "$JSON_OUTPUT" = "true" ]; then
  cat <<EOF
{
  "checked_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_files": $TOTAL_FILES,
  "total_links": $TOTAL,
  "results": [$JSON_RESULTS],
  "summary": {
    "ok": $TOTAL_OK,
    "broken": $TOTAL_BROKEN,
    "redirect": $TOTAL_REDIRECT,
    "timeout": $TOTAL_TIMEOUT,
    "skipped": $TOTAL_SKIPPED
  }
}
EOF
else
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "📊 ${BOLD}Summary:${NC} $TOTAL links checked in $TOTAL_FILES files"
  echo -e "  ${GREEN}✅ $TOTAL_OK OK${NC}"
  [ "$TOTAL_BROKEN" -gt 0 ] && echo -e "  ${RED}❌ $TOTAL_BROKEN Broken${NC}"
  [ "$TOTAL_REDIRECT" -gt 0 ] && echo -e "  ${YELLOW}🔄 $TOTAL_REDIRECT Redirect${NC}"
  [ "$TOTAL_TIMEOUT" -gt 0 ] && echo -e "  ${CYAN}⏱️  $TOTAL_TIMEOUT Timeout${NC}"
  [ "$TOTAL_SKIPPED" -gt 0 ] && echo -e "  ⏭️  $TOTAL_SKIPPED Skipped"
fi

# Exit code
if [ "$EXIT_CODE_MODE" = "true" ] && [ "$TOTAL_BROKEN" -gt 0 ]; then
  exit 1
fi

exit 0
