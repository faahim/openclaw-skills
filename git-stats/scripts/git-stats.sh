#!/bin/bash
# Git Stats & Insights — Analyze any git repository
# Usage: bash git-stats.sh [--repo PATH] [--since DATE] [--only SECTION] [--format FORMAT]

set -e

# ─── Defaults ────────────────────────────────────────────────────────
REPO_PATH="."
SINCE=""
UNTIL=""
ONLY=""
TOP=10
WEEKS=12
FORMAT="text"
COMPARE=""
EXCLUDE_PATTERNS="${GIT_STATS_EXCLUDE:-node_modules,vendor,dist,.git}"
SCC_CMD="${SCC_PATH:-scc}"

# ─── Parse args ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)       REPO_PATH="$2"; shift 2 ;;
    --since)      SINCE="$2"; shift 2 ;;
    --until)      UNTIL="$2"; shift 2 ;;
    --only)       ONLY="$2"; shift 2 ;;
    --top)        TOP="$2"; shift 2 ;;
    --weeks)      WEEKS="$2"; shift 2 ;;
    --format)     FORMAT="$2"; shift 2 ;;
    --compare)    COMPARE="$2"; shift 2 ;;
    --exclude)    EXCLUDE_PATTERNS="$EXCLUDE_PATTERNS,$2"; shift 2 ;;
    -h|--help)
      echo "Usage: git-stats.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --repo PATH        Repository path (default: .)"
      echo "  --since DATE       Start date (e.g., '3 months ago')"
      echo "  --until DATE       End date (default: now)"
      echo "  --only SECTION     languages|contributors|hotspots|trends|churn"
      echo "  --top N            Items to show (default: 10)"
      echo "  --weeks N          Weeks for trend chart (default: 12)"
      echo "  --format FORMAT    text|json|markdown (default: text)"
      echo "  --compare RANGE    Compare branches (e.g., main..develop)"
      echo "  --exclude PATTERN  Exclude paths (repeatable)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

cd "$REPO_PATH"

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "❌ Not a git repository: $REPO_PATH"
  exit 1
fi

REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")

# Build git log date args
DATE_ARGS=""
[ -n "$SINCE" ] && DATE_ARGS="$DATE_ARGS --since=\"$SINCE\""
[ -n "$UNTIL" ] && DATE_ARGS="$DATE_ARGS --until=\"$UNTIL\""

PERIOD_START="${SINCE:-$(git log --reverse --format='%as' | head -1)}"
PERIOD_END="${UNTIL:-$(date +%Y-%m-%d)}"

# ─── JSON output helpers ─────────────────────────────────────────────
json_started=false

json_start() {
  echo "{"
  echo "  \"repo\": \"$REPO_NAME\","
  echo "  \"period\": {\"start\": \"$PERIOD_START\", \"end\": \"$PERIOD_END\"},"
}

json_end() {
  # Remove trailing comma hack
  echo "}"
}

# ─── Section: Languages ─────────────────────────────────────────────
section_languages() {
  if [ "$FORMAT" = "json" ]; then
    echo "  \"languages\": ["
    if command -v "$SCC_CMD" &>/dev/null; then
      "$SCC_CMD" --format json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = []
for lang in sorted(data, key=lambda x: -x.get('Code', 0)):
    items.append('    {\"language\": \"%s\", \"files\": %d, \"lines\": %d, \"code\": %d, \"comments\": %d, \"blanks\": %d}' % (
        lang['Name'], lang['Count'], lang['Lines'], lang['Code'], lang['Comment'], lang['Blank']))
print(',\n'.join(items))
" 2>/dev/null || echo "    {\"error\": \"scc not available\"}"
    fi
    echo "  ],"
    return
  fi

  echo ""
  echo "📊 LANGUAGE BREAKDOWN"
  echo "──────────────────────────────────────────────"

  if command -v "$SCC_CMD" &>/dev/null; then
    printf "%-20s %6s %8s %8s %8s %8s\n" "Language" "Files" "Lines" "Code" "Comments" "Blanks"
    "$SCC_CMD" --format json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
total_files = total_lines = total_code = total_comments = total_blanks = 0
for lang in sorted(data, key=lambda x: -x.get('Code', 0))[:15]:
    print('%-20s %6d %8d %8d %8d %8d' % (
        lang['Name'][:20], lang['Count'], lang['Lines'], lang['Code'], lang['Comment'], lang['Blank']))
    total_files += lang['Count']; total_lines += lang['Lines']; total_code += lang['Code']
    total_comments += lang['Comment']; total_blanks += lang['Blank']
print('─' * 72)
print('%-20s %6d %8d %8d %8d %8d' % ('Total', total_files, total_lines, total_code, total_comments, total_blanks))
" 2>/dev/null
  else
    echo "⚠️  scc not installed. Run: bash scripts/install-scc.sh"
    echo "Falling back to git file extensions..."
    git ls-files | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -"$TOP" | \
      awk '{printf "  .%-15s %d files\n", $2, $1}'
  fi
}

# ─── Section: Contributors ───────────────────────────────────────────
section_contributors() {
  if [ "$FORMAT" = "json" ]; then
    echo "  \"contributors\": ["
    eval git log $DATE_ARGS --format='%aN' | sort | uniq -c | sort -rn | head -"$TOP" | \
      awk '{
        name = ""; for(i=2;i<=NF;i++) name = name (i>2?" ":"") $i;
        if(NR>1) printf ",\n";
        printf "    {\"name\": \"%s\", \"commits\": %d}", name, $1
      }'
    echo ""
    echo "  ],"
    return
  fi

  echo ""
  echo "👥 TOP CONTRIBUTORS (by commits)"
  echo "──────────────────────────────────────────────"

  local i=1
  eval git log $DATE_ARGS --format='%aN' | sort | uniq -c | sort -rn | head -"$TOP" | while read count name; do
    # Get additions/deletions for this author
    local stats
    stats=$(eval git log $DATE_ARGS --author="$name" --pretty=tformat: --numstat 2>/dev/null | \
      awk '{add+=$1; del+=$2} END {printf "+%d / -%d", add, del}')
    printf "  %2d. %-20s %4d commits  (%s)\n" "$i" "$name" "$count" "$stats"
    i=$((i + 1))
  done
}

# ─── Section: Hotspots ───────────────────────────────────────────────
section_hotspots() {
  if [ "$FORMAT" = "json" ]; then
    echo "  \"hotspots\": ["
    eval git log $DATE_ARGS --pretty=format: --name-only | grep -v '^$' | sort | uniq -c | sort -rn | head -"$TOP" | \
      awk '{
        if(NR>1) printf ",\n";
        printf "    {\"file\": \"%s\", \"changes\": %d}", $2, $1
      }'
    echo ""
    echo "  ],"
    return
  fi

  echo ""
  echo "🔥 FILE HOTSPOTS (most changed files)"
  echo "──────────────────────────────────────────────"

  local i=1
  eval git log $DATE_ARGS --pretty=format: --name-only | grep -v '^$' | sort | uniq -c | sort -rn | head -"$TOP" | while read count file; do
    printf "  %2d. %-45s %3d changes\n" "$i" "$file" "$count"
    i=$((i + 1))
  done
}

# ─── Section: Trends ─────────────────────────────────────────────────
section_trends() {
  if [ "$FORMAT" = "json" ]; then
    echo "  \"trends\": ["
    local week_num=0
    for i in $(seq "$WEEKS" -1 0); do
      local week_start=$(date -d "$i weeks ago" +%Y-%m-%d 2>/dev/null || date -v-"${i}"w +%Y-%m-%d 2>/dev/null)
      local week_end=$(date -d "$((i-1)) weeks ago" +%Y-%m-%d 2>/dev/null || date -v-"$((i-1))"w +%Y-%m-%d 2>/dev/null)
      local count=$(git log --after="$week_start" --before="$week_end" --oneline 2>/dev/null | wc -l | tr -d ' ')
      [ "$week_num" -gt 0 ] && printf ",\n"
      printf "    {\"week_start\": \"%s\", \"commits\": %d}" "$week_start" "$count"
      week_num=$((week_num + 1))
    done
    echo ""
    echo "  ],"
    return
  fi

  echo ""
  echo "📈 COMMIT FREQUENCY (last $WEEKS weeks)"
  echo "──────────────────────────────────────────────"

  local max_count=1
  local -a counts=()
  local -a labels=()

  for i in $(seq "$WEEKS" -1 0); do
    local week_start=$(date -d "$i weeks ago" +%Y-%m-%d 2>/dev/null || date -v-"${i}"w +%Y-%m-%d 2>/dev/null)
    local week_end=$(date -d "$((i-1)) weeks ago" +%Y-%m-%d 2>/dev/null || date -v-"$((i-1))"w +%Y-%m-%d 2>/dev/null)
    local count=$(git log --after="$week_start" --before="$week_end" --oneline 2>/dev/null | wc -l | tr -d ' ')
    counts+=("$count")
    local label=$(date -d "$i weeks ago" +"%b %d" 2>/dev/null || date -v-"${i}"w +"%b %d" 2>/dev/null)
    labels+=("$label")
    [ "$count" -gt "$max_count" ] && max_count=$count
  done

  local bar_width=30
  for j in "${!counts[@]}"; do
    local c=${counts[$j]}
    local l=${labels[$j]}
    local bar_len=0
    [ "$max_count" -gt 0 ] && bar_len=$(( c * bar_width / max_count ))
    local bar=$(printf '█%.0s' $(seq 1 $((bar_len > 0 ? bar_len : 0))) 2>/dev/null)
    printf "  %s: %-${bar_width}s %d\n" "$l" "$bar" "$c"
  done
}

# ─── Section: Churn ──────────────────────────────────────────────────
section_churn() {
  local stats
  stats=$(eval git log $DATE_ARGS --pretty=tformat: --numstat | awk '
    {add+=$1; del+=$2}
    END {
      net = add - del
      ratio = (add > 0) ? del/add : 0
      health = "healthy"
      if (ratio > 0.8) health = "high churn — consider refactoring"
      else if (ratio > 0.5) health = "moderate"
      printf "%d %d %d %.2f %s", add, del, net, ratio, health
    }')

  local add=$(echo "$stats" | awk '{print $1}')
  local del=$(echo "$stats" | awk '{print $2}')
  local net=$(echo "$stats" | awk '{print $3}')
  local ratio=$(echo "$stats" | awk '{print $4}')
  local health=$(echo "$stats" | awk '{for(i=5;i<=NF;i++) printf "%s ", $i}')

  if [ "$FORMAT" = "json" ]; then
    echo "  \"churn\": {"
    echo "    \"additions\": $add,"
    echo "    \"deletions\": $del,"
    echo "    \"net_growth\": $net,"
    echo "    \"ratio\": $ratio,"
    echo "    \"health\": \"$health\""
    echo "  }"
    return
  fi

  echo ""
  echo "🔄 CODE CHURN (additions vs deletions)"
  echo "──────────────────────────────────────────────"
  printf "  Total additions:  +%s\n" "$(printf '%d' "$add" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')"
  printf "  Total deletions:  -%s\n" "$(printf '%d' "$del" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')"
  printf "  Net growth:       %s%s\n" "$([ "$net" -ge 0 ] && echo '+' || echo '')" "$(printf '%d' "$net" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')"
  printf "  Churn ratio:      %s (%s)\n" "$ratio" "$health"
}

# ─── Section: Compare ────────────────────────────────────────────────
section_compare() {
  if [ -z "$COMPARE" ]; then return; fi

  echo ""
  echo "🔀 BRANCH COMPARISON: $COMPARE"
  echo "──────────────────────────────────────────────"

  local commit_count=$(git log --oneline "$COMPARE" 2>/dev/null | wc -l | tr -d ' ')
  echo "  Commits: $commit_count"

  local stats=$(git diff --stat "$COMPARE" 2>/dev/null | tail -1)
  echo "  $stats"

  echo ""
  echo "  Files changed:"
  git diff --name-only "$COMPARE" 2>/dev/null | head -"$TOP" | while read f; do
    echo "    $f"
  done
  local total=$(git diff --name-only "$COMPARE" 2>/dev/null | wc -l | tr -d ' ')
  [ "$total" -gt "$TOP" ] && echo "    ... and $((total - TOP)) more"
}

# ─── Main ────────────────────────────────────────────────────────────

if [ "$FORMAT" = "json" ]; then
  json_start
else
  echo "═══════════════════════════════════════════════"
  echo "  GIT STATS & INSIGHTS — $REPO_NAME"
  echo "  Period: $PERIOD_START to $PERIOD_END"
  echo "═══════════════════════════════════════════════"
fi

case "$ONLY" in
  languages)    section_languages ;;
  contributors) section_contributors ;;
  hotspots)     section_hotspots ;;
  trends)       section_trends ;;
  churn)        section_churn ;;
  *)
    section_languages
    section_contributors
    section_hotspots
    section_trends
    section_churn
    [ -n "$COMPARE" ] && section_compare
    ;;
esac

[ "$FORMAT" = "json" ] && json_end

if [ "$FORMAT" = "text" ]; then
  echo ""
  echo "═══════════════════════════════════════════════"
  total_commits=$(eval git log $DATE_ARGS --oneline | wc -l | tr -d ' ')
  total_authors=$(eval git log $DATE_ARGS --format='%aN' | sort -u | wc -l | tr -d ' ')
  echo "  Total: $total_commits commits by $total_authors contributors"
  echo "═══════════════════════════════════════════════"
fi
