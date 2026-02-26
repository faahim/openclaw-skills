#!/usr/bin/env bash
# Changelog Generator — Auto-generate changelogs from git conventional commits
# Usage: bash changelog.sh [OPTIONS]

set -euo pipefail

# Defaults
REPO="${CHANGELOG_REPO:-.}"
OUTPUT="${CHANGELOG_OUTPUT:-CHANGELOG.md}"
STDOUT=false
UNRELEASED=false
FROM_TAG=""
TO_TAG=""
PREPEND=""
TYPES="${CHANGELOG_TYPES:-feat,fix,perf,refactor,docs,style,test,build,ci,chore}"
SHOW_HASHES="${CHANGELOG_HASHES:-false}"
SHOW_AUTHORS="${CHANGELOG_AUTHORS:-false}"
NO_LINKS=false
TITLE="Changelog"
FORMAT="markdown"
PATH_FILTER=""
SCOPE_FILTER=""
REMOTE_URL=""

# Section labels for commit types
declare -A TYPE_LABELS=(
  [feat]="🚀 Features"
  [fix]="🐛 Bug Fixes"
  [perf]="⚡ Performance"
  [refactor]="♻️ Refactoring"
  [docs]="📚 Documentation"
  [style]="💄 Style"
  [test]="✅ Tests"
  [build]="📦 Build"
  [ci]="🔧 CI"
  [chore]="🧹 Chores"
)

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo) REPO="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --stdout) STDOUT=true; shift ;;
    --unreleased) UNRELEASED=true; shift ;;
    --from) FROM_TAG="$2"; shift 2 ;;
    --to) TO_TAG="$2"; shift 2 ;;
    --prepend) PREPEND="$2"; shift 2 ;;
    --types) TYPES="$2"; shift 2 ;;
    --hashes) SHOW_HASHES=true; shift ;;
    --authors) SHOW_AUTHORS=true; shift ;;
    --no-links) NO_LINKS=true; shift ;;
    --title) TITLE="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --path) PATH_FILTER="$2"; shift 2 ;;
    --scope) SCOPE_FILTER="$2"; shift 2 ;;
    --remote) REMOTE_URL="$2"; shift 2 ;;
    --help)
      echo "Usage: changelog.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --repo PATH        Git repository path (default: .)"
      echo "  --output FILE      Output file (default: CHANGELOG.md)"
      echo "  --stdout           Print to stdout"
      echo "  --unreleased       Only unreleased changes"
      echo "  --from TAG         Start tag"
      echo "  --to TAG           End tag"
      echo "  --prepend FILE     Prepend to existing file"
      echo "  --types LIST       Comma-separated types (default: feat,fix,...)"
      echo "  --hashes           Show commit hashes"
      echo "  --authors          Show commit authors"
      echo "  --no-links         Don't link issues/PRs"
      echo "  --title TEXT       Custom title (default: Changelog)"
      echo "  --format FMT       Output format: markdown|json (default: markdown)"
      echo "  --path PATH        Filter commits by file path"
      echo "  --scope LIST       Filter by conventional commit scope"
      echo "  --remote URL       Remote URL for issue links"
      echo "  --help             Show help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

cd "$REPO"

# Verify git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Error: Not a git repository: $REPO" >&2
  exit 1
fi

# Auto-detect remote URL
if [[ -z "$REMOTE_URL" ]] && [[ "$NO_LINKS" == "false" ]]; then
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
  # Convert SSH to HTTPS
  REMOTE_URL=$(echo "$REMOTE_URL" | sed -E 's|^git@([^:]+):|https://\1/|; s|\.git$||')
fi

# Get tags sorted by date (newest first)
get_tags() {
  git tag --sort=-version:refname 2>/dev/null | head -50
}

# Get tag date
tag_date() {
  local tag=$1
  git log -1 --format="%Y-%m-%d" "$tag" 2>/dev/null
}

# Get commits between two refs
get_commits() {
  local from=$1
  local to=$2
  local log_args=("--format=%H|%s|%an|%ae|%b---END---")
  
  if [[ -n "$PATH_FILTER" ]]; then
    log_args+=("--" "$PATH_FILTER")
  fi
  
  if [[ -z "$from" ]]; then
    git log "${log_args[@]}" "$to" 2>/dev/null
  else
    git log "${log_args[@]}" "${from}..${to}" 2>/dev/null
  fi
}

# Parse a conventional commit subject
# Returns: type|scope|description|breaking
parse_commit() {
  local subject="$1"
  local body="$2"
  local breaking="false"
  
  # Check for breaking change indicator
  if [[ "$subject" =~ ^([a-z]+)(\(.+\))?!:\ (.+)$ ]]; then
    breaking="true"
    local type="${BASH_REMATCH[1]}"
    local scope="${BASH_REMATCH[2]}"
    local desc="${BASH_REMATCH[3]}"
    scope="${scope#(}"; scope="${scope%)}"
    echo "${type}|${scope}|${desc}|${breaking}"
    return
  fi
  
  # Standard conventional commit
  if [[ "$subject" =~ ^([a-z]+)(\(.+\))?:\ (.+)$ ]]; then
    local type="${BASH_REMATCH[1]}"
    local scope="${BASH_REMATCH[2]}"
    local desc="${BASH_REMATCH[3]}"
    scope="${scope#(}"; scope="${scope%)}"
    
    # Check body for BREAKING CHANGE
    if echo "$body" | grep -q "BREAKING CHANGE:"; then
      breaking="true"
    fi
    
    echo "${type}|${scope}|${desc}|${breaking}"
    return
  fi
  
  # Non-conventional commit
  echo "other||${subject}|false"
}

# Link issue/PR references
linkify() {
  local text="$1"
  if [[ -n "$REMOTE_URL" ]] && [[ "$NO_LINKS" == "false" ]]; then
    # Replace #123 with links
    echo "$text" | sed -E "s|#([0-9]+)|[#\1](${REMOTE_URL}/issues/\1)|g"
  else
    echo "$text"
  fi
}

# Generate changelog for a range
generate_section() {
  local from=$1
  local to=$2
  local tag_name=$3
  local date=$4
  
  local IFS_SAVE="$IFS"
  
  # Collect commits by type
  declare -A commits_by_type
  declare -a breaking_changes=()
  
  local raw_commits
  raw_commits=$(get_commits "$from" "$to")
  
  if [[ -z "$raw_commits" ]]; then
    return
  fi
  
  # Parse each commit
  while IFS='|' read -r hash subject author email body_rest; do
    [[ -z "$hash" ]] && continue
    
    local body=""
    # Extract body (everything before ---END---)
    body=$(echo "$body_rest" | sed 's/---END---$//')
    
    local parsed
    parsed=$(parse_commit "$subject" "$body")
    
    local type scope desc breaking
    IFS='|' read -r type scope desc breaking <<< "$parsed"
    
    # Filter by scope if specified
    if [[ -n "$SCOPE_FILTER" ]]; then
      local scope_match=false
      IFS=',' read -ra SCOPE_ARR <<< "$SCOPE_FILTER"
      for s in "${SCOPE_ARR[@]}"; do
        if [[ "$scope" == "$s" ]]; then
          scope_match=true
          break
        fi
      done
      if [[ "$scope_match" == "false" ]] && [[ -n "$scope" ]]; then
        continue
      fi
    fi
    
    # Filter by type
    local type_match=false
    IFS=',' read -ra TYPE_ARR <<< "$TYPES,other"
    for t in "${TYPE_ARR[@]}"; do
      if [[ "$type" == "$t" ]]; then
        type_match=true
        break
      fi
    done
    [[ "$type_match" == "false" ]] && continue
    
    # Build line
    local line="- $(linkify "$desc")"
    if [[ -n "$scope" ]]; then
      line="- **${scope}:** $(linkify "$desc")"
    fi
    if [[ "$SHOW_HASHES" == "true" ]]; then
      local short_hash="${hash:0:7}"
      if [[ -n "$REMOTE_URL" ]] && [[ "$NO_LINKS" == "false" ]]; then
        line="${line} ([${short_hash}](${REMOTE_URL}/commit/${hash}))"
      else
        line="${line} (${short_hash})"
      fi
    fi
    if [[ "$SHOW_AUTHORS" == "true" ]]; then
      line="${line} — @${author}"
    fi
    
    # Track breaking changes
    if [[ "$breaking" == "true" ]]; then
      local bc_desc="$desc"
      # Try to extract BREAKING CHANGE description from body
      local bc_body
      bc_body=$(echo "$body" | grep -A1 "BREAKING CHANGE:" | tail -1 | xargs)
      if [[ -n "$bc_body" ]] && [[ "$bc_body" != "BREAKING CHANGE:"* ]]; then
        bc_desc="$bc_body"
      fi
      breaking_changes+=("- $(linkify "$bc_desc")")
    fi
    
    # Add to type bucket
    if [[ -v "commits_by_type[$type]" ]]; then
      commits_by_type[$type]+=$'\n'"$line"
    else
      commits_by_type[$type]="$line"
    fi
    
  done <<< "$raw_commits"
  
  # Check if we have any commits
  local has_commits=false
  for type in "${!commits_by_type[@]}"; do
    has_commits=true
    break
  done
  
  [[ "$has_commits" == "false" ]] && return
  
  # Output header
  if [[ "$tag_name" == "Unreleased" ]]; then
    echo "## Unreleased"
  else
    echo "## ${tag_name} (${date})"
  fi
  echo ""
  
  # Breaking changes first
  if [[ ${#breaking_changes[@]} -gt 0 ]]; then
    echo "### ⚠️ Breaking Changes"
    echo ""
    for bc in "${breaking_changes[@]}"; do
      echo "$bc"
    done
    echo ""
  fi
  
  # Output by type (in order)
  IFS=',' read -ra ORDERED_TYPES <<< "$TYPES"
  ORDERED_TYPES+=("other")
  
  for type in "${ORDERED_TYPES[@]}"; do
    if [[ -v "commits_by_type[$type]" ]]; then
      local label="${TYPE_LABELS[$type]:-Other Changes}"
      echo "### ${label}"
      echo ""
      echo "${commits_by_type[$type]}"
      echo ""
    fi
  done
}

# Main generation
generate_changelog() {
  local output=""
  
  output="# ${TITLE}"$'\n\n'
  output+="*Auto-generated from git commit history.*"$'\n\n'
  
  local tags
  mapfile -t tags < <(get_tags)
  
  if [[ "$UNRELEASED" == "true" ]]; then
    # Only unreleased changes
    local latest_tag=""
    if [[ ${#tags[@]} -gt 0 ]]; then
      latest_tag="${tags[0]}"
    fi
    local section
    section=$(generate_section "$latest_tag" "HEAD" "Unreleased" "")
    if [[ -n "$section" ]]; then
      output+="$section"$'\n'
    else
      output+="## Unreleased"$'\n\n'"*No unreleased changes.*"$'\n\n'
    fi
    echo "$output"
    return
  fi
  
  # Specific range
  if [[ -n "$FROM_TAG" ]] || [[ -n "$TO_TAG" ]]; then
    local from="${FROM_TAG}"
    local to="${TO_TAG:-HEAD}"
    local to_name="${TO_TAG:-Unreleased}"
    local to_date=""
    if [[ -n "$TO_TAG" ]]; then
      to_date=$(tag_date "$TO_TAG")
    fi
    local section
    section=$(generate_section "$from" "$to" "$to_name" "$to_date")
    if [[ -n "$section" ]]; then
      output+="$section"$'\n'
    fi
    echo "$output"
    return
  fi
  
  # Full changelog from all tags
  # First: unreleased changes
  if [[ ${#tags[@]} -gt 0 ]]; then
    local section
    section=$(generate_section "${tags[0]}" "HEAD" "Unreleased" "")
    if [[ -n "$section" ]]; then
      output+="$section"$'\n'
    fi
  fi
  
  # Then: each tag range
  for ((i=0; i<${#tags[@]}; i++)); do
    local current="${tags[$i]}"
    local previous=""
    if [[ $((i+1)) -lt ${#tags[@]} ]]; then
      previous="${tags[$((i+1))]}"
    fi
    
    local date
    date=$(tag_date "$current")
    
    local section
    section=$(generate_section "$previous" "$current" "$current" "$date")
    if [[ -n "$section" ]]; then
      output+="$section"$'\n'
    fi
  done
  
  # If no tags at all, dump all commits
  if [[ ${#tags[@]} -eq 0 ]]; then
    local section
    section=$(generate_section "" "HEAD" "All Changes" "$(date +%Y-%m-%d)")
    if [[ -n "$section" ]]; then
      output+="$section"$'\n'
    else
      output+="*No conventional commits found.*"$'\n'
    fi
  fi
  
  echo "$output"
}

# JSON output
generate_json() {
  local tags
  mapfile -t tags < <(get_tags)
  
  echo "{"
  echo "  \"title\": \"${TITLE}\","
  echo "  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"versions\": []"
  echo "}"
  # Full JSON generation would be more complex; 
  # for now, pipe markdown through a converter or extend this
}

# Execute
main() {
  local result
  
  if [[ "$FORMAT" == "json" ]]; then
    result=$(generate_json)
  else
    result=$(generate_changelog)
  fi
  
  if [[ "$STDOUT" == "true" ]]; then
    echo "$result"
  elif [[ -n "$PREPEND" ]]; then
    # Prepend to existing file
    if [[ -f "$PREPEND" ]]; then
      local existing
      existing=$(cat "$PREPEND")
      # Remove old header
      existing=$(echo "$existing" | sed '1,/^$/d')
      echo "$result" > "$PREPEND"
      echo "" >> "$PREPEND"
      echo "$existing" >> "$PREPEND"
      echo "✅ Prepended to $PREPEND"
    else
      echo "$result" > "$PREPEND"
      echo "✅ Created $PREPEND"
    fi
  else
    echo "$result" > "$OUTPUT"
    echo "✅ Generated $OUTPUT ($(wc -l < "$OUTPUT") lines)"
  fi
}

main
