#!/usr/bin/env bash
# GitHub Release Manager — Automate releases with changelog generation
# Dependencies: gh, git, bash 4+

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
BUMP=""
DRAFT=false
PRERELEASE=""
ASSETS=""
LIST=false
DELETE=""
INFO=""
PUBLISH=""
UPLOAD=""
PREFIX=""
TAG_PREFIX="v"
REPO="${RELEASE_REPO:-}"
SIGN="${RELEASE_SIGN_TAGS:-false}"
TEMPLATE="${RELEASE_TEMPLATE:-}"

usage() {
  cat <<EOF
GitHub Release Manager v${VERSION}

Usage: $(basename "$0") [OPTIONS]

Create Releases:
  --bump <major|minor|patch>   Bump version and create release
  --draft                      Create as draft (don't publish yet)
  --prerelease <alpha|beta|rc> Mark as pre-release
  --assets <file1,file2,...>   Upload assets with release

Manage Releases:
  --list                       List recent releases
  --info <tag>                 Show release details
  --delete <tag>               Delete a release
  --publish <tag>              Publish a draft release
  --upload <tag>               Upload assets to existing release (use with --assets)

Options:
  --prefix <path>              Monorepo: only include commits under this path
  --tag-prefix <prefix>        Tag prefix (default: "v")
  --repo <owner/repo>          Override repository
  --help                       Show this help
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump) BUMP="$2"; shift 2 ;;
    --draft) DRAFT=true; shift ;;
    --prerelease) PRERELEASE="$2"; shift 2 ;;
    --assets) ASSETS="$2"; shift 2 ;;
    --list) LIST=true; shift ;;
    --delete) DELETE="$2"; shift 2 ;;
    --info) INFO="$2"; shift 2 ;;
    --publish) PUBLISH="$2"; shift 2 ;;
    --upload) UPLOAD="$2"; shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --tag-prefix) TAG_PREFIX="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Resolve repo
get_repo() {
  if [[ -n "$REPO" ]]; then
    echo "$REPO"
  else
    gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || {
      echo "Error: Not in a git repo or gh not authenticated" >&2
      exit 1
    }
  fi
}

REPO_FLAG=""
resolve_repo_flag() {
  local r
  r=$(get_repo)
  REPO_FLAG="--repo $r"
}

# Get latest tag matching prefix
get_latest_tag() {
  git tag --list "${TAG_PREFIX}*" --sort=-v:refname | head -1
}

# Parse semver from tag
parse_version() {
  local tag="$1"
  local ver="${tag#${TAG_PREFIX}}"
  # Strip pre-release suffix for bumping
  ver="${ver%%-*}"
  echo "$ver"
}

# Bump version
bump_version() {
  local ver="$1" bump="$2"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$ver"
  major=${major:-0}; minor=${minor:-0}; patch=${patch:-0}

  case "$bump" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    *) echo "Invalid bump: $bump (use major, minor, patch)" >&2; exit 1 ;;
  esac

  echo "${major}.${minor}.${patch}"
}

# Generate changelog from commits
generate_changelog() {
  local from_tag="$1" to_ref="${2:-HEAD}"
  local range="${from_tag}..${to_ref}"

  # If no from_tag, get all commits
  if [[ -z "$from_tag" ]]; then
    range="$to_ref"
  fi

  local path_filter=""
  if [[ -n "$PREFIX" ]]; then
    path_filter="-- $PREFIX"
  fi

  # Collect commits
  local log_format="%H|%s|%an"
  local commits
  commits=$(git log "$range" --pretty=format:"$log_format" $path_filter 2>/dev/null || echo "")

  if [[ -z "$commits" ]]; then
    echo "No changes since ${from_tag:-beginning}"
    return
  fi

  # Categorize
  local features="" fixes="" docs="" perf="" refactor="" tests="" ci="" chores="" breaking="" other=""

  while IFS='|' read -r hash subject author; do
    local short_hash="${hash:0:7}"
    local entry="- ${subject} (${short_hash})"

    case "$subject" in
      feat:*|feat\(*) features+="${entry}"$'\n' ;;
      fix:*|fix\(*) fixes+="${entry}"$'\n' ;;
      docs:*|docs\(*) docs+="${entry}"$'\n' ;;
      perf:*|perf\(*) perf+="${entry}"$'\n' ;;
      refactor:*|refactor\(*) refactor+="${entry}"$'\n' ;;
      test:*|test\(*|tests:*) tests+="${entry}"$'\n' ;;
      ci:*|ci\(*) ci+="${entry}"$'\n' ;;
      chore:*|chore\(*) chores+="${entry}"$'\n' ;;
      *!:*|breaking:*|BREAKING*) breaking+="${entry}"$'\n' ;;
      *) other+="${entry}"$'\n' ;;
    esac
  done <<< "$commits"

  # Build changelog
  local changelog="## What's Changed"$'\n\n'

  [[ -n "$breaking" ]] && changelog+="### ⚠️ Breaking Changes"$'\n'"${breaking}"$'\n'
  [[ -n "$features" ]] && changelog+="### 🚀 Features"$'\n'"${features}"$'\n'
  [[ -n "$fixes" ]] && changelog+="### 🐛 Bug Fixes"$'\n'"${fixes}"$'\n'
  [[ -n "$perf" ]] && changelog+="### ⚡ Performance"$'\n'"${perf}"$'\n'
  [[ -n "$docs" ]] && changelog+="### 📚 Documentation"$'\n'"${docs}"$'\n'
  [[ -n "$refactor" ]] && changelog+="### ♻️ Refactoring"$'\n'"${refactor}"$'\n'
  [[ -n "$tests" ]] && changelog+="### 🧪 Tests"$'\n'"${tests}"$'\n'
  [[ -n "$ci" ]] && changelog+="### 🔧 CI/CD"$'\n'"${ci}"$'\n'
  [[ -n "$chores" ]] && changelog+="### 🏗️ Chores"$'\n'"${chores}"$'\n'
  [[ -n "$other" ]] && changelog+="### Other Changes"$'\n'"${other}"$'\n'

  if [[ -n "$from_tag" ]]; then
    changelog+="**Full Changelog:** ${from_tag}...${TAG_PREFIX}${new_version}"$'\n'
  fi

  echo "$changelog"
}

# Count commits
count_commits() {
  local from="$1"
  local path_filter=""
  [[ -n "$PREFIX" ]] && path_filter="-- $PREFIX"

  if [[ -n "$from" ]]; then
    git rev-list --count "${from}..HEAD" $path_filter 2>/dev/null || echo "0"
  else
    git rev-list --count HEAD $path_filter 2>/dev/null || echo "0"
  fi
}

# Count merged PRs
count_prs() {
  local from="$1"
  local range="HEAD"
  [[ -n "$from" ]] && range="${from}..HEAD"
  git log "$range" --oneline --grep="Merge pull request" 2>/dev/null | wc -l | tr -d ' '
}

# ---- ACTIONS ----

do_list() {
  resolve_repo_flag
  echo "📋 Recent releases:"
  gh release list $REPO_FLAG --limit 10
}

do_info() {
  resolve_repo_flag
  gh release view "$INFO" $REPO_FLAG
}

do_delete() {
  resolve_repo_flag
  echo "🗑️  Deleting release $DELETE..."
  gh release delete "$DELETE" $REPO_FLAG --yes --cleanup-tag
  echo "✅ Release $DELETE deleted"
}

do_publish() {
  resolve_repo_flag
  echo "📢 Publishing draft release $PUBLISH..."
  gh release edit "$PUBLISH" $REPO_FLAG --draft=false
  echo "✅ Release $PUBLISH published"
}

do_upload() {
  resolve_repo_flag
  if [[ -z "$ASSETS" ]]; then
    echo "Error: --assets required with --upload" >&2
    exit 1
  fi
  echo "📦 Uploading assets to $UPLOAD..."
  IFS=',' read -ra asset_list <<< "$ASSETS"
  for asset in "${asset_list[@]}"; do
    asset=$(echo "$asset" | xargs)  # trim whitespace
    if [[ -f "$asset" ]]; then
      echo "  ⬆️  $asset"
      gh release upload "$UPLOAD" "$asset" $REPO_FLAG --clobber
    else
      echo "  ⚠️  Skipping $asset (file not found)"
    fi
  done
  echo "✅ Assets uploaded to $UPLOAD"
}

do_release() {
  resolve_repo_flag
  local latest_tag
  latest_tag=$(get_latest_tag)

  local current_version="0.0.0"
  if [[ -n "$latest_tag" ]]; then
    current_version=$(parse_version "$latest_tag")
    echo "📋 Generating changelog from ${latest_tag}..."
  else
    echo "📋 No previous tags found. Creating initial release..."
  fi

  new_version=$(bump_version "$current_version" "$BUMP")

  # Add pre-release suffix
  if [[ -n "$PRERELEASE" ]]; then
    # Find next pre-release number
    local pre_num=1
    while git tag --list "${TAG_PREFIX}${new_version}-${PRERELEASE}.${pre_num}" | grep -q .; do
      pre_num=$((pre_num + 1))
    done
    new_version="${new_version}-${PRERELEASE}.${pre_num}"
  fi

  local new_tag="${TAG_PREFIX}${new_version}"

  # Check tag doesn't already exist
  if git tag --list "$new_tag" | grep -q .; then
    echo "Error: Tag $new_tag already exists" >&2
    exit 1
  fi

  local num_commits num_prs
  num_commits=$(count_commits "$latest_tag")
  num_prs=$(count_prs "$latest_tag")
  echo "📝 Found ${num_commits} commits, ${num_prs} PRs merged"

  # Generate changelog
  local changelog
  changelog=$(generate_changelog "$latest_tag")

  # Create tag
  if [[ "$SIGN" == "true" ]]; then
    git tag -s "$new_tag" -m "Release ${new_tag}"
  else
    git tag "$new_tag" -m "Release ${new_tag}"
  fi
  git push origin "$new_tag"

  echo "🏷️  Creating release ${new_tag}..."

  # Build gh release create command
  local gh_args=("$new_tag" --title "$new_tag" --notes "$changelog")
  [[ "$DRAFT" == "true" ]] && gh_args+=(--draft)
  [[ -n "$PRERELEASE" ]] && gh_args+=(--prerelease)

  # Add assets
  if [[ -n "$ASSETS" ]]; then
    IFS=',' read -ra asset_list <<< "$ASSETS"
    for asset in "${asset_list[@]}"; do
      asset=$(echo "$asset" | xargs)
      [[ -f "$asset" ]] && gh_args+=("$asset")
    done
  fi

  local url
  url=$(gh release create "${gh_args[@]}" $REPO_FLAG 2>&1)

  local status_emoji="✅"
  local status_text="published"
  [[ "$DRAFT" == "true" ]] && status_text="created as draft"
  [[ -n "$PRERELEASE" ]] && status_text="published as pre-release"

  echo "${status_emoji} Release ${new_tag} ${status_text}: ${url}"
}

# ---- MAIN ----

if [[ "$LIST" == "true" ]]; then
  do_list
elif [[ -n "$INFO" ]]; then
  do_info
elif [[ -n "$DELETE" ]]; then
  do_delete
elif [[ -n "$PUBLISH" ]]; then
  do_publish
elif [[ -n "$UPLOAD" ]]; then
  do_upload
elif [[ -n "$BUMP" ]]; then
  do_release
else
  usage
fi
