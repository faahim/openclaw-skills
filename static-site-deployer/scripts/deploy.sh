#!/bin/bash
# Static Site Deployer — Deploy to GitHub Pages, Netlify, Cloudflare Pages, or Surge
# Usage: bash deploy.sh --provider <provider> --dir <directory> [options]

set -euo pipefail

# === Defaults ===
PROVIDER=""
DIR=""
SITE_NAME=""
DOMAIN=""
BRANCH="gh-pages"
REPO="origin"
PROJECT_NAME=""
DRAFT=false
PROD=false
TEARDOWN=false
LIST=false
BUILD_CMD=""
CONFIG_FILE=""
PROVIDERS=()

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_ok()    { echo -e "${GREEN}✅ $1${NC}"; }
log_warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}" >&2; }

# === Argument Parsing ===
while [[ $# -gt 0 ]]; do
  case $1 in
    --provider)    PROVIDER="$2"; shift 2 ;;
    --dir)         DIR="$2"; shift 2 ;;
    --site-name)   SITE_NAME="$2"; shift 2 ;;
    --domain)      DOMAIN="$2"; shift 2 ;;
    --branch)      BRANCH="$2"; shift 2 ;;
    --repo)        REPO="$2"; shift 2 ;;
    --project-name) PROJECT_NAME="$2"; shift 2 ;;
    --draft)       DRAFT=true; shift ;;
    --prod)        PROD=true; shift ;;
    --teardown)    TEARDOWN=true; shift ;;
    --list)        LIST=true; shift ;;
    --build)       BUILD_CMD="$2"; shift 2 ;;
    --config)      CONFIG_FILE="$2"; shift 2 ;;
    -h|--help)     show_help; exit 0 ;;
    *) log_error "Unknown option: $1"; exit 1 ;;
  esac
done

# === Config File Support ===
load_config() {
  if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    log_info "Loading config from $CONFIG_FILE"
    # Simple YAML parser for flat keys
    if command -v yq &>/dev/null; then
      [[ -z "$PROVIDER" ]] && PROVIDER=$(yq -r '.default_provider // ""' "$CONFIG_FILE")
      [[ -z "$DIR" ]] && DIR=$(yq -r '.default_dir // ""' "$CONFIG_FILE")
    else
      log_warn "yq not installed — config file requires yq. Using CLI args only."
    fi
  fi
}

load_config

# === Validation ===
if [[ -z "$PROVIDER" ]]; then
  log_error "Missing --provider. Options: surge, netlify, cloudflare, github-pages"
  exit 1
fi

# Split comma-separated providers
IFS=',' read -ra PROVIDERS <<< "$PROVIDER"

if [[ "$TEARDOWN" == false && "$LIST" == false && -z "$DIR" ]]; then
  log_error "Missing --dir. Specify the directory to deploy."
  exit 1
fi

if [[ -n "$DIR" && ! -d "$DIR" ]]; then
  log_error "Directory not found: $DIR"
  exit 1
fi

# === Pre-deploy Build ===
if [[ -n "$BUILD_CMD" ]]; then
  log_info "Running build: $BUILD_CMD"
  eval "$BUILD_CMD"
  log_ok "Build complete"
fi

# === Deploy Functions ===

deploy_surge() {
  local dir="$1"
  log_info "Deploying $dir to Surge..."

  if ! command -v surge &>/dev/null; then
    log_error "surge not installed. Run: npm install -g surge"
    return 1
  fi

  if [[ "$TEARDOWN" == true ]]; then
    if [[ -z "$DOMAIN" ]]; then
      log_error "--domain required for teardown"
      return 1
    fi
    surge teardown "$DOMAIN"
    log_ok "Teardown complete: $DOMAIN"
    return 0
  fi

  local domain_arg=""
  if [[ -n "$DOMAIN" ]]; then
    domain_arg="$DOMAIN"
  elif [[ -n "$SITE_NAME" ]]; then
    domain_arg="${SITE_NAME}.surge.sh"
  fi

  if [[ -n "$domain_arg" ]]; then
    surge "$dir" "$domain_arg"
    log_ok "Live at: https://$domain_arg"
  else
    surge "$dir"
    log_ok "Deployed to Surge (see URL above)"
  fi
}

deploy_netlify() {
  local dir="$1"
  log_info "Deploying $dir to Netlify..."

  if ! command -v netlify &>/dev/null && ! command -v npx &>/dev/null; then
    log_error "netlify-cli not installed. Run: npm install -g netlify-cli"
    return 1
  fi

  local cli="netlify"
  if ! command -v netlify &>/dev/null; then
    cli="npx netlify-cli"
  fi

  if [[ -z "${NETLIFY_AUTH_TOKEN:-}" ]]; then
    log_warn "NETLIFY_AUTH_TOKEN not set. You may be prompted to log in."
  fi

  if [[ "$LIST" == true ]]; then
    local site_flag=""
    [[ -n "$SITE_NAME" ]] && site_flag="--filter $SITE_NAME"
    $cli api listSiteDeploys --data '{}' $site_flag 2>/dev/null | head -20
    return 0
  fi

  if [[ "$TEARDOWN" == true ]]; then
    if [[ -n "${NETLIFY_SITE_ID:-}" ]]; then
      $cli api deleteSite --data "{\"site_id\": \"$NETLIFY_SITE_ID\"}"
    else
      log_error "Set NETLIFY_SITE_ID to teardown a site"
      return 1
    fi
    log_ok "Site deleted"
    return 0
  fi

  local deploy_args="--dir $dir"

  if [[ "$PROD" == true ]]; then
    deploy_args="$deploy_args --prod"
  fi

  if [[ -n "$SITE_NAME" ]]; then
    # Check if site exists; if not, create it
    local site_id
    site_id=$($cli api listSites --data '{}' 2>/dev/null | jq -r ".[] | select(.name == \"$SITE_NAME\") | .id" 2>/dev/null || true)
    if [[ -n "$site_id" ]]; then
      deploy_args="$deploy_args --site $site_id"
    else
      log_info "Creating new site: $SITE_NAME"
      $cli sites:create --name "$SITE_NAME" 2>/dev/null || true
      deploy_args="$deploy_args --site $SITE_NAME"
    fi
  fi

  $cli deploy $deploy_args
  log_ok "Deployed to Netlify"
}

deploy_cloudflare() {
  local dir="$1"
  log_info "Deploying $dir to Cloudflare Pages..."

  if ! command -v wrangler &>/dev/null && ! command -v npx &>/dev/null; then
    log_error "wrangler not installed. Run: npm install -g wrangler"
    return 1
  fi

  local cli="wrangler"
  if ! command -v wrangler &>/dev/null; then
    cli="npx wrangler"
  fi

  if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
    log_warn "CLOUDFLARE_API_TOKEN not set. You may be prompted to log in."
  fi

  local project="${PROJECT_NAME:-$SITE_NAME}"
  if [[ -z "$project" ]]; then
    log_error "Specify --project-name or --site-name for Cloudflare Pages"
    return 1
  fi

  # Create project if it doesn't exist
  $cli pages project list 2>/dev/null | grep -q "$project" || {
    log_info "Creating Cloudflare Pages project: $project"
    $cli pages project create "$project" --production-branch main 2>/dev/null || true
  }

  $cli pages deploy "$dir" --project-name "$project"
  log_ok "Live at: https://${project}.pages.dev"
}

deploy_github_pages() {
  local dir="$1"
  log_info "Deploying $dir to GitHub Pages (branch: $BRANCH)..."

  if ! command -v git &>/dev/null; then
    log_error "git not installed"
    return 1
  fi

  # Get repo URL for output
  local repo_url
  repo_url=$(git remote get-url "$REPO" 2>/dev/null || echo "unknown")

  # Create a temporary worktree approach
  local tmp_dir
  tmp_dir=$(mktemp -d)

  # Initialize a git repo in temp dir
  cd "$tmp_dir"
  git init -q
  git checkout -q --orphan "$BRANCH"

  # Copy files
  cp -r "$OLDPWD/$dir"/* . 2>/dev/null || cp -r "$OLDPWD/$dir"/. . 2>/dev/null

  # Add .nojekyll for non-Jekyll sites
  touch .nojekyll

  git add -A
  git commit -q -m "Deploy static site $(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Push to remote
  cd "$OLDPWD"
  git push "$REPO" "$tmp_dir:refs/heads/$BRANCH" --force 2>/dev/null || {
    # Alternative: push from temp dir
    cd "$tmp_dir"
    git remote add deploy "$repo_url"
    git push deploy "$BRANCH" --force
    cd "$OLDPWD"
  }

  # Cleanup
  rm -rf "$tmp_dir"

  # Extract GitHub Pages URL
  local pages_url
  if [[ "$repo_url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
    local owner="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    pages_url="https://${owner}.github.io/${repo}"
  else
    pages_url="(check repo Settings → Pages)"
  fi

  log_ok "Pushed to branch '$BRANCH'. Live at: $pages_url"
  log_info "Note: GitHub Pages may take 1-2 minutes to update"
}

# === Main Execution ===

for p in "${PROVIDERS[@]}"; do
  p=$(echo "$p" | xargs)  # trim whitespace
  case "$p" in
    surge)         deploy_surge "$DIR" ;;
    netlify)       deploy_netlify "$DIR" ;;
    cloudflare)    deploy_cloudflare "$DIR" ;;
    github-pages)  deploy_github_pages "$DIR" ;;
    *)
      log_error "Unknown provider: $p"
      log_info "Available: surge, netlify, cloudflare, github-pages"
      exit 1
      ;;
  esac
done

log_ok "All deployments complete! 🎉"
