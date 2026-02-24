#!/bin/bash
# Lighthouse Performance Auditor — Main runner
set -e

# ── Defaults ──
URL=""
FORMAT="summary"
OUTPUT_DIR="${LIGHTHOUSE_OUTPUT_DIR:-/tmp/lighthouse}"
PRESET="${LIGHTHOUSE_PRESET:-mobile}"
ONLY_CATEGORIES=""
THRESHOLD=""
EXTRA_FLAGS=""
BATCH_FILE=""
CONFIG_FILE=""
NUM_RUNS=1

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Parse Args ──
while [[ $# -gt 0 ]]; do
  case $1 in
    --url) URL="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --preset) PRESET="$2"; shift 2 ;;
    --only-categories) ONLY_CATEGORIES="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --extra-flags) EXTRA_FLAGS="$2"; shift 2 ;;
    --batch) BATCH_FILE="$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --runs) NUM_RUNS="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: bash run.sh --url <URL> [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --url URL              URL to audit"
      echo "  --format FORMAT        Output: summary (default), html, json, csv"
      echo "  --output DIR           Output directory (default: /tmp/lighthouse)"
      echo "  --preset PRESET        mobile (default) or desktop"
      echo "  --only-categories CAT  Comma-separated: performance,accessibility,seo,best-practices"
      echo "  --threshold RULES      e.g. 'performance=80,accessibility=90'"
      echo "  --extra-flags FLAGS    Additional Lighthouse CLI flags"
      echo "  --batch FILE           File with one URL per line"
      echo "  --config FILE          YAML config file"
      echo "  --runs N               Number of runs (median score reported)"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Find Chrome ──
find_chrome() {
  if [ -n "$CHROME_PATH" ]; then echo "$CHROME_PATH"; return; fi
  for c in chromium-browser chromium google-chrome google-chrome-stable; do
    local p=$(which "$c" 2>/dev/null)
    if [ -n "$p" ]; then echo "$p"; return; fi
  done
  # Check common Playwright cache locations
  local pw_chrome=$(find ~/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1)
  if [ -n "$pw_chrome" ]; then echo "$pw_chrome"; return; fi
  echo ""
}

CHROME=$(find_chrome)
if [ -z "$CHROME" ]; then
  echo -e "${RED}❌ Chrome/Chromium not found. Run: bash scripts/install.sh${NC}"
  exit 1
fi

# ── Check lighthouse ──
if ! command -v lighthouse &>/dev/null; then
  echo -e "${RED}❌ lighthouse CLI not found. Run: bash scripts/install.sh${NC}"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# ── Score color helper ──
score_color() {
  local score=$1
  if [ "$score" -ge 90 ]; then echo -e "${GREEN}${score} 🟢${NC}"
  elif [ "$score" -ge 50 ]; then echo -e "${YELLOW}${score} 🟠${NC}"
  else echo -e "${RED}${score} 🔴${NC}"; fi
}

# ── Run single audit ──
run_audit() {
  local url=$1
  local slug=$(echo "$url" | sed 's|https\?://||;s|/|_|g;s|[^a-zA-Z0-9._-]|_|g')
  local date_str=$(date +%Y-%m-%d_%H%M%S)
  local json_file="${OUTPUT_DIR}/${slug}-${date_str}.json"

  # Build flags
  local flags="--chrome-flags=\"--headless --no-sandbox --disable-gpu\" --no-enable-error-reporting --quiet"
  flags="$flags --chrome-path=$CHROME"

  if [ "$PRESET" = "desktop" ]; then
    flags="$flags --preset=desktop"
  fi

  if [ -n "$ONLY_CATEGORIES" ]; then
    flags="$flags --only-categories=$ONLY_CATEGORIES"
  fi

  if [ -n "$EXTRA_FLAGS" ]; then
    flags="$flags $EXTRA_FLAGS"
  fi

  # Always generate JSON for parsing
  flags="$flags --output=json --output-path=$json_file"

  echo -e "${CYAN}🔍 Auditing ${url}...${NC}"

  # Run lighthouse
  eval lighthouse "$url" $flags 2>/dev/null

  if [ ! -f "$json_file" ]; then
    echo -e "${RED}❌ Audit failed for ${url}${NC}"
    return 1
  fi

  # Extract scores
  local perf=$(jq -r '(.categories.performance.score // 0) * 100 | floor' "$json_file" 2>/dev/null)
  local a11y=$(jq -r '(.categories.accessibility.score // 0) * 100 | floor' "$json_file" 2>/dev/null)
  local bp=$(jq -r '((.categories["best-practices"].score // 0) * 100) | floor' "$json_file" 2>/dev/null)
  local seo=$(jq -r '(.categories.seo.score // 0) * 100 | floor' "$json_file" 2>/dev/null)

  if [ "$FORMAT" = "summary" ] || [ "$FORMAT" = "html" ]; then
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}  LIGHTHOUSE REPORT — ${url}${NC}"
    echo -e "${BOLD}═══════════════════════════════════════${NC}"
    echo -e "  Performance:    $(score_color ${perf:-0})"
    echo -e "  Accessibility:  $(score_color ${a11y:-0})"
    echo -e "  Best Practices: $(score_color ${bp:-0})"
    echo -e "  SEO:            $(score_color ${seo:-0})"
    echo -e "${BOLD}═══════════════════════════════════════${NC}"

    # Extract top opportunities
    local opportunities=$(jq -r '
      [.audits | to_entries[] |
       select(.value.details.type == "opportunity" and .value.score != null and .value.score < 1) |
       {title: .value.title, savings: (.value.details.overallSavingsMs // 0)}] |
      sort_by(-.savings) | .[0:5][] |
      "  ⚠️  \(.title)" + if .savings > 0 then " (est. \(.savings / 1000 | . * 10 | floor / 10)s savings)" else "" end
    ' "$json_file" 2>/dev/null)

    if [ -n "$opportunities" ]; then
      echo ""
      echo -e "${YELLOW}Top Issues:${NC}"
      echo "$opportunities"
    fi

    echo ""
    echo -e "Full report: ${json_file}"
  fi

  # Generate HTML if requested
  if [ "$FORMAT" = "html" ]; then
    local html_file="${OUTPUT_DIR}/${slug}-${date_str}.html"
    eval lighthouse "$url" $flags --output=html --output-path="$html_file" 2>/dev/null
    echo -e "HTML report: ${html_file}"
  fi

  # Check thresholds
  if [ -n "$THRESHOLD" ]; then
    local failed=0
    IFS=',' read -ra RULES <<< "$THRESHOLD"
    for rule in "${RULES[@]}"; do
      local cat=$(echo "$rule" | cut -d'=' -f1)
      local min=$(echo "$rule" | cut -d'=' -f2)
      local actual=0
      case "$cat" in
        performance) actual=$perf ;;
        accessibility) actual=$a11y ;;
        best-practices) actual=$bp ;;
        seo) actual=$seo ;;
      esac
      if [ "${actual:-0}" -lt "$min" ]; then
        echo -e "${RED}❌ THRESHOLD FAIL: ${cat} = ${actual} (minimum: ${min})${NC}"
        failed=1
      fi
    done
    if [ "$failed" -eq 1 ]; then return 1; fi
  fi

  # Return scores for batch mode
  echo "$perf|$a11y|$bp|$seo" > "${OUTPUT_DIR}/.last-scores"
  return 0
}

# ── Batch mode ──
run_batch() {
  local file=$1
  echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  BATCH AUDIT RESULTS${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
  printf "  %-30s %-6s %-6s %-6s %-6s\n" "URL" "Perf" "A11y" "BP" "SEO"
  echo "  ─────────────────────────────── ───── ───── ──── ────"

  local worst_url=""
  local worst_score=101

  while IFS= read -r url; do
    [ -z "$url" ] && continue
    [[ "$url" =~ ^# ]] && continue

    # Suppress normal output for batch
    local orig_format=$FORMAT
    FORMAT="quiet"
    run_audit "$url" 2>/dev/null || true
    FORMAT=$orig_format

    if [ -f "${OUTPUT_DIR}/.last-scores" ]; then
      IFS='|' read -r perf a11y bp seo < "${OUTPUT_DIR}/.last-scores"
      local short_url=$(echo "$url" | sed 's|https\?://[^/]*||')
      [ -z "$short_url" ] && short_url="/"
      printf "  %-30s %-6s %-6s %-6s %-6s\n" "$short_url" "$perf" "$a11y" "$bp" "$seo"

      if [ "${perf:-0}" -lt "$worst_score" ]; then
        worst_score=$perf
        worst_url=$short_url
      fi
    fi
  done < "$file"

  echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
  if [ -n "$worst_url" ]; then
    echo -e "  Worst performer: ${worst_url} (Performance: ${worst_score})"
  fi
}

# ── Main ──
if [ -n "$BATCH_FILE" ]; then
  if [ ! -f "$BATCH_FILE" ]; then
    echo -e "${RED}❌ Batch file not found: ${BATCH_FILE}${NC}"
    exit 1
  fi
  run_batch "$BATCH_FILE"
elif [ -n "$URL" ]; then
  if [ "$NUM_RUNS" -gt 1 ]; then
    echo -e "${CYAN}Running $NUM_RUNS audits (median scores)...${NC}"
    declare -a perf_scores a11y_scores bp_scores seo_scores
    for i in $(seq 1 $NUM_RUNS); do
      FORMAT="quiet"
      run_audit "$URL" 2>/dev/null || true
      if [ -f "${OUTPUT_DIR}/.last-scores" ]; then
        IFS='|' read -r p a b s < "${OUTPUT_DIR}/.last-scores"
        perf_scores+=($p); a11y_scores+=($a); bp_scores+=($b); seo_scores+=($s)
      fi
    done
    # Sort and pick median
    median() { printf '%s\n' "$@" | sort -n | sed -n "$((($# + 1) / 2))p"; }
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}  MEDIAN SCORES ($NUM_RUNS runs) — ${URL}${NC}"
    echo -e "${BOLD}═══════════════════════════════════════${NC}"
    echo -e "  Performance:    $(score_color $(median ${perf_scores[@]}))"
    echo -e "  Accessibility:  $(score_color $(median ${a11y_scores[@]}))"
    echo -e "  Best Practices: $(score_color $(median ${bp_scores[@]}))"
    echo -e "  SEO:            $(score_color $(median ${seo_scores[@]}))"
    echo -e "${BOLD}═══════════════════════════════════════${NC}"
  else
    run_audit "$URL"
  fi
else
  echo "Usage: bash run.sh --url <URL> [--format summary|html|json] [--preset mobile|desktop]"
  echo "       bash run.sh --batch urls.txt [--output ./reports/]"
  echo "       bash run.sh --help"
  exit 1
fi
