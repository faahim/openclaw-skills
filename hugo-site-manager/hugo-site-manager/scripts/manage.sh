#!/bin/bash
# Hugo Site Manager — Main management script
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}✅${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️${NC} $*"; }
err() { echo -e "${RED}❌${NC} $*" >&2; }
info() { echo -e "${BLUE}ℹ️${NC} $*"; }

# Theme repository map
declare -A THEME_REPOS=(
  [PaperMod]="https://github.com/adityatelange/hugo-PaperMod.git"
  [Stack]="https://github.com/CaiJimmy/hugo-theme-stack.git"
  [docsy]="https://github.com/google/docsy.git"
  [ananke]="https://github.com/theNewDynamic/gohugo-theme-ananke.git"
  [terminal]="https://github.com/panr/hugo-theme-terminal.git"
  [blowfish]="https://github.com/nunocoracao/blowfish.git"
)

usage() {
  cat <<EOF
Hugo Site Manager — Manage Hugo sites from your agent

USAGE:
  bash manage.sh <command> [options]

COMMANDS:
  new       Create a new Hugo site
  post      Create a new content post
  config    Update site configuration
  serve     Start local dev server
  build     Build production site
  deploy    Deploy to GitHub Pages or Netlify
  list      List content/taxonomies
  stats     Show site statistics
  theme     Change or update theme
  migrate   Migrate from Jekyll/WordPress
  bulk-import  Import markdown files as posts
  bulk-csv     Import posts from CSV
  archetype    Create custom archetype

OPTIONS:
  --name <name>        Site name (for 'new')
  --site <path>        Path to Hugo site
  --theme <theme>      Theme name or git URL
  --title <title>      Post/site title
  --content <text>     Post content (markdown)
  --section <name>     Content section (default: posts)
  --tags <t1,t2>       Comma-separated tags
  --weight <n>         Sort weight for docs
  --target <target>    Deploy target (github|netlify|git-push)
  --repo <user/repo>   GitHub repo for deployment
  --branch <branch>    Deploy branch (default: gh-pages)
  --base-url <url>     Site base URL
  --language <lang>    Site language code
  --paginate <n>       Posts per page
  --param <k=v>        Extra site param
  --source <path>      Source for migration/import
  --from <platform>    Migration source platform
  --csv <file>         CSV file for bulk import
  --verbose            Verbose output
  --help               Show this help

EXAMPLES:
  bash manage.sh new --name my-blog --theme PaperMod
  bash manage.sh post --site my-blog --title "Hello" --content "World"
  bash manage.sh build --site my-blog
  bash manage.sh deploy --site my-blog --target github --repo user/blog
EOF
}

# Parse arguments
COMMAND="${1:-}"
shift 2>/dev/null || true

SITE="" NAME="" THEME="" TITLE="" CONTENT="" SECTION="posts"
TAGS="" WEIGHT="" TARGET="" REPO="" BRANCH="gh-pages"
BASE_URL="" LANGUAGE="en" PAGINATE="10" VERBOSE=""
SOURCE="" FROM="" CSV_FILE="" ARCHETYPE_NAME="" FRONTMATTER=""
SITE_ID="" PARAMS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --site) SITE="$2"; shift 2 ;;
    --theme) THEME="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --content) CONTENT="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --tags) TAGS="$2"; shift 2 ;;
    --weight) WEIGHT="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --base-url) BASE_URL="$2"; shift 2 ;;
    --language) LANGUAGE="$2"; shift 2 ;;
    --paginate) PAGINATE="$2"; shift 2 ;;
    --param) PARAMS+=("$2"); shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    --from) FROM="$2"; shift 2 ;;
    --csv) CSV_FILE="$2"; shift 2 ;;
    --site-id) SITE_ID="$2"; shift 2 ;;
    --frontmatter) FRONTMATTER="$2"; shift 2 ;;
    --verbose) VERBOSE="--verbose" ; shift ;;
    --help) usage; exit 0 ;;
    *) err "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Require hugo for most commands
require_hugo() {
  if ! command -v hugo &>/dev/null; then
    err "Hugo not found. Run: bash scripts/install.sh"
    exit 1
  fi
}

# Resolve theme URL
resolve_theme() {
  local theme="$1"
  if [[ -n "${THEME_REPOS[$theme]+x}" ]]; then
    echo "${THEME_REPOS[$theme]}"
  elif [[ "$theme" == http* ]]; then
    echo "$theme"
  else
    echo "https://github.com/theNewDynamic/gohugo-theme-${theme}.git"
  fi
}

# Slugify a title
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g'
}

# === COMMANDS ===

cmd_new() {
  require_hugo
  [[ -z "$NAME" ]] && { err "Missing --name"; exit 1; }

  info "Creating new Hugo site: ${NAME}"
  hugo new site "$NAME"
  cd "$NAME"

  # Initialize git
  git init -q
  log "Git initialized"

  # Add theme
  if [[ -n "$THEME" ]]; then
    local theme_url
    theme_url=$(resolve_theme "$THEME")
    local theme_name
    theme_name=$(basename "$theme_url" .git)

    info "Adding theme: ${THEME} (${theme_url})"
    git submodule add "$theme_url" "themes/${theme_name}" 2>/dev/null || \
      git clone --depth 1 "$theme_url" "themes/${theme_name}"

    # Set theme in config
    if [[ -f hugo.toml ]]; then
      echo "theme = '${theme_name}'" >> hugo.toml
    elif [[ -f config.toml ]]; then
      echo "theme = '${theme_name}'" >> config.toml
    fi
    log "Theme '${theme_name}' configured"
  fi

  # Create initial content directory
  mkdir -p content/posts

  log "Site created at ./${NAME}/"
  info "Next: bash manage.sh post --site ${NAME} --title 'Hello World'"
}

cmd_post() {
  require_hugo
  [[ -z "$SITE" ]] && { err "Missing --site"; exit 1; }
  [[ -z "$TITLE" ]] && { err "Missing --title"; exit 1; }

  local slug
  slug=$(slugify "$TITLE")
  local date
  date=$(date -u +%Y-%m-%dT%H:%M:%S+00:00)
  local filepath="content/${SECTION}/${slug}.md"

  cd "$SITE"

  mkdir -p "content/${SECTION}"

  # Build frontmatter
  cat > "$filepath" <<FRONTMATTER
---
title: "${TITLE}"
date: ${date}
draft: false
FRONTMATTER

  [[ -n "$TAGS" ]] && echo "tags: [$(echo "$TAGS" | sed 's/,/, /g')]" >> "$filepath"
  [[ -n "$WEIGHT" ]] && echo "weight: ${WEIGHT}" >> "$filepath"

  echo "---" >> "$filepath"
  echo "" >> "$filepath"

  # Add content
  if [[ -n "$CONTENT" ]]; then
    echo -e "$CONTENT" >> "$filepath"
  else
    echo "Write your content here." >> "$filepath"
  fi

  log "Created: ${filepath}"
  info "Title: ${TITLE}"
  info "Section: ${SECTION}"
}

cmd_config() {
  require_hugo
  [[ -z "$SITE" ]] && { err "Missing --site"; exit 1; }

  cd "$SITE"

  local config_file="hugo.toml"
  [[ ! -f "$config_file" ]] && config_file="config.toml"
  [[ ! -f "$config_file" ]] && { err "No config file found"; exit 1; }

  [[ -n "$TITLE" ]] && sed -i "s|^title = .*|title = '${TITLE}'|" "$config_file"
  [[ -n "$BASE_URL" ]] && sed -i "s|^baseURL = .*|baseURL = '${BASE_URL}'|" "$config_file"
  [[ -n "$LANGUAGE" ]] && sed -i "s|^languageCode = .*|languageCode = '${LANGUAGE}'|" "$config_file"

  # Add paginate if not present
  if [[ -n "$PAGINATE" ]]; then
    if grep -q "^paginate" "$config_file"; then
      sed -i "s|^paginate = .*|paginate = ${PAGINATE}|" "$config_file"
    else
      echo "paginate = ${PAGINATE}" >> "$config_file"
    fi
  fi

  # Add extra params
  for param in "${PARAMS[@]}"; do
    local key="${param%%=*}"
    local value="${param#*=}"
    if grep -q "^\[params\]" "$config_file"; then
      # Add under [params] section
      sed -i "/^\[params\]/a ${key} = '${value}'" "$config_file"
    else
      echo -e "\n[params]\n${key} = '${value}'" >> "$config_file"
    fi
  done

  log "Configuration updated: ${config_file}"
  cat "$config_file"
}

cmd_serve() {
  require_hugo
  [[ -z "$SITE" ]] && { err "Missing --site"; exit 1; }

  info "Starting Hugo dev server for ${SITE}..."
  cd "$SITE"
  hugo server --buildDrafts --disableFastRender &
  local pid=$!
  log "Server running at http://localhost:1313 (PID: ${pid})"
  info "Press Ctrl+C to stop"
  wait $pid
}

cmd_build() {
  require_hugo
  [[ -z "$SITE" ]] && { err "Missing --site"; exit 1; }

  info "Building ${SITE}..."
  cd "$SITE"

  local start=$(date +%s%3N)
  hugo --minify $VERBOSE
  local end=$(date +%s%3N)
  local elapsed=$((end - start))

  local page_count
  page_count=$(find public -name "*.html" 2>/dev/null | wc -l)
  local size
  size=$(du -sh public 2>/dev/null | cut -f1)

  log "Built ${page_count} pages in ${elapsed}ms"
  info "Output: ${SITE}/public/ (${size})"
}

cmd_deploy() {
  require_hugo
  [[ -z "$SITE" ]] && { err "Missing --site"; exit 1; }
  [[ -z "$TARGET" ]] && { err "Missing --target (github|netlify|git-push)"; exit 1; }

  cd "$SITE"

  # Build first
  info "Building site..."
  hugo --minify

  case "$TARGET" in
    github)
      [[ -z "$REPO" ]] && { err "Missing --repo for GitHub deployment"; exit 1; }

      info "Deploying to GitHub Pages: ${REPO} (${BRANCH})"

      cd public

      git init -q 2>/dev/null || true
      git checkout -B "$BRANCH" 2>/dev/null
      git add -A
      git commit -m "Deploy $(date -u +%Y-%m-%d\ %H:%M:%S)" --allow-empty

      if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        git push -f "https://${GITHUB_TOKEN}@github.com/${REPO}.git" "${BRANCH}"
      else
        git push -f "git@github.com:${REPO}.git" "${BRANCH}"
      fi

      log "Deployed to github.com/${REPO} (${BRANCH})"
      info "🌐 Live at https://$(echo "$REPO" | cut -d/ -f1).github.io/$(echo "$REPO" | cut -d/ -f2)"
      ;;

    netlify)
      if ! command -v netlify &>/dev/null; then
        info "Installing Netlify CLI..."
        npm install -g netlify-cli
      fi

      local site_flag=""
      [[ -n "$SITE_ID" ]] && site_flag="--site ${SITE_ID}"

      netlify deploy --prod --dir=public $site_flag
      log "Deployed to Netlify"
      ;;

    git-push)
      cd ..
      git add -A
      git commit -m "Update site $(date -u +%Y-%m-%d\ %H:%M:%S)"
      git push
      log "Pushed to git remote (Netlify/Vercel will auto-deploy)"
      ;;

    *)
      err "Unknown target: ${TARGET}. Use: github, netlify, git-push"
      exit 1
      ;;
  esac
}

cmd_list() {
  require_hugo
  [[ -z "$SITE" ]] && { err "Missing --site"; exit 1; }

  cd "$SITE"

  if [[ "$SECTION" == "taxonomies" || "$TAGS" == "true" ]]; then
    info "Taxonomies:"
    hugo list all 2>/dev/null | head -1
    find content -name "*.md" -exec grep -h "^tags:" {} \; | \
      sed 's/tags: \[//; s/\]//; s/, /\n/g' | sort | uniq -c | sort -rn
  else
    info "Content in ${SITE}:"
    hugo list all 2>/dev/null || find content -name "*.md" -printf "%P\n"
  fi
}

cmd_stats() {
  require_hugo
  [[ -z "$SITE" ]] && { err "Missing --site"; exit 1; }

  cd "$SITE"

  local post_count
  post_count=$(find content -name "*.md" 2>/dev/null | wc -l)
  local tag_count
  tag_count=$(find content -name "*.md" -exec grep -h "^tags:" {} \; 2>/dev/null | \
    sed 's/tags: \[//; s/\]//; s/, /\n/g' | sort -u | wc -l)
  local section_count
  section_count=$(find content -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  local sections
  sections=$(find content -mindepth 1 -maxdepth 1 -type d -printf "%f, " 2>/dev/null | sed 's/, $//')

  echo "📊 Site: $(basename "$SITE")"
  echo "📝 Posts: ${post_count}"
  echo "🏷️  Tags: ${tag_count}"
  echo "📁 Sections: ${section_count} (${sections})"

  # Build stats
  if [[ -d "public" ]]; then
    local size
    size=$(du -sh public | cut -f1)
    echo "📦 Build size: ${size}"
  fi

  # Build time
  local start=$(date +%s%3N)
  hugo --quiet 2>/dev/null
  local end=$(date +%s%3N)
  echo "⚡ Build time: $((end - start))ms"
}

cmd_theme() {
  require_hugo
  [[ -z "$SITE" ]] && { err "Missing --site"; exit 1; }
  [[ -z "$THEME" ]] && { err "Missing --theme"; exit 1; }

  cd "$SITE"

  local theme_url
  theme_url=$(resolve_theme "$THEME")
  local theme_name
  theme_name=$(basename "$theme_url" .git)

  # Remove old theme submodules
  info "Setting theme to: ${THEME}"
  git submodule add "$theme_url" "themes/${theme_name}" 2>/dev/null || \
    git clone --depth 1 "$theme_url" "themes/${theme_name}"

  # Update config
  local config_file="hugo.toml"
  [[ ! -f "$config_file" ]] && config_file="config.toml"
  sed -i "s|^theme = .*|theme = '${theme_name}'|" "$config_file"

  log "Theme set to '${theme_name}'"
}

cmd_migrate() {
  require_hugo
  [[ -z "$SITE" ]] && { err "Missing --site"; exit 1; }
  [[ -z "$FROM" ]] && { err "Missing --from (jekyll|wordpress)"; exit 1; }
  [[ -z "$SOURCE" ]] && { err "Missing --source"; exit 1; }

  case "$FROM" in
    jekyll)
      info "Migrating from Jekyll..."
      hugo import jekyll "$SOURCE" "$SITE"
      log "Jekyll site migrated to ${SITE}"
      ;;
    wordpress)
      info "Migrating from WordPress..."
      if ! command -v wp2hugo &>/dev/null; then
        warn "wp2hugo not found. Converting XML manually..."
        # Basic WordPress XML to Hugo markdown conversion
        mkdir -p "${SITE}/content/posts"
        python3 -c "
import xml.etree.ElementTree as ET
import os, re
tree = ET.parse('${SOURCE}')
root = tree.getroot()
ns = {'wp': 'http://wordpress.org/export/1.2/', 'content': 'http://purl.org/rss/1.0/modules/content/'}
for item in root.iter('item'):
    title = item.find('title').text or 'Untitled'
    content = item.find('content:encoded', ns)
    content_text = content.text if content is not None and content.text else ''
    date_el = item.find('wp:post_date', ns)
    date = date_el.text if date_el is not None else '2024-01-01'
    slug = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')
    with open(f'${SITE}/content/posts/{slug}.md', 'w') as f:
        f.write(f'---\ntitle: \"{title}\"\ndate: {date}\ndraft: false\n---\n\n{content_text}\n')
    print(f'  Migrated: {title}')
" 2>/dev/null || err "WordPress migration failed. Install python3 or use wp2hugo."
      else
        wp2hugo --source "$SOURCE" --output "$SITE"
      fi
      log "WordPress content migrated to ${SITE}"
      ;;
    *)
      err "Unsupported platform: ${FROM}. Use: jekyll, wordpress"
      exit 1
      ;;
  esac
}

cmd_bulk_import() {
  require_hugo
  [[ -z "$SITE" ]] && { err "Missing --site"; exit 1; }
  [[ -z "$SOURCE" ]] && { err "Missing --source"; exit 1; }

  cd "$SITE"
  mkdir -p "content/${SECTION}"

  local count=0
  for file in "${SOURCE}"/*.md; do
    [[ ! -f "$file" ]] && continue
    local basename
    basename=$(basename "$file")
    cp "$file" "content/${SECTION}/${basename}"
    count=$((count + 1))
  done

  log "Imported ${count} posts to content/${SECTION}/"
}

cmd_bulk_csv() {
  require_hugo
  [[ -z "$SITE" ]] && { err "Missing --site"; exit 1; }
  [[ -z "$CSV_FILE" ]] && { err "Missing --csv"; exit 1; }

  cd "$SITE"
  mkdir -p "content/${SECTION}"

  local count=0
  while IFS=, read -r title tags date content_file; do
    [[ "$title" == "title" ]] && continue  # Skip header
    local slug
    slug=$(slugify "$title")
    local filepath="content/${SECTION}/${slug}.md"
    local post_date="${date:-$(date -u +%Y-%m-%dT%H:%M:%S+00:00)}"

    cat > "$filepath" <<EOF
---
title: "${title}"
date: ${post_date}
tags: [${tags}]
draft: false
---

EOF
    if [[ -n "$content_file" && -f "$content_file" ]]; then
      cat "$content_file" >> "$filepath"
    fi
    count=$((count + 1))
  done < "$CSV_FILE"

  log "Created ${count} posts from CSV"
}

# === MAIN ===

case "${COMMAND}" in
  new) cmd_new ;;
  post) cmd_post ;;
  config) cmd_config ;;
  serve) cmd_serve ;;
  build) cmd_build ;;
  deploy) cmd_deploy ;;
  list) cmd_list ;;
  stats) cmd_stats ;;
  theme) cmd_theme ;;
  migrate) cmd_migrate ;;
  bulk-import) cmd_bulk_import ;;
  bulk-csv) cmd_bulk_csv ;;
  help|--help|-h) usage ;;
  "") err "No command specified"; usage; exit 1 ;;
  *) err "Unknown command: ${COMMAND}"; usage; exit 1 ;;
esac
