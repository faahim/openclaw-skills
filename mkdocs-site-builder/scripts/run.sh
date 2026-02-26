#!/bin/bash
# MkDocs Site Builder — Main Script
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find mkdocs (lazy — only needed for serve/build/deploy)
find_mkdocs() {
  if command -v mkdocs &>/dev/null; then
    MKDOCS_CMD="mkdocs"
  elif python3 -m mkdocs --version &>/dev/null 2>&1; then
    MKDOCS_CMD="python3 -m mkdocs"
  else
    echo "❌ MkDocs not installed. Run: bash scripts/install.sh"
    exit 1
  fi
}

# Parse command
COMMAND="${1:-help}"
shift 2>/dev/null || true

# Parse flags
DIR="."
NAME="My Documentation"
PRIMARY="indigo"
ACCENT="amber"
DARK_MODE="on"
STRICT=""
TITLE=""
PAGE_PATH=""
PAGES=""
FROM_DIR=""
DOMAIN=""
LANG="en"

while [[ $# -gt 0 ]]; do
  case $1 in
    --dir) DIR="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --primary) PRIMARY="$2"; shift 2 ;;
    --accent) ACCENT="$2"; shift 2 ;;
    --dark-mode) DARK_MODE="$2"; shift 2 ;;
    --strict) STRICT="--strict"; shift ;;
    --title) TITLE="$2"; shift 2 ;;
    --path) PAGE_PATH="$2"; shift 2 ;;
    --pages) PAGES="$2"; shift 2 ;;
    --from) FROM_DIR="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --lang) LANG="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

scaffold() {
  echo "🏗️  Scaffolding docs site: $NAME"
  
  mkdir -p "$DIR/docs/assets"
  mkdir -p "$DIR/.github/workflows"
  
  # Generate mkdocs.yml
  cat > "$DIR/mkdocs.yml" << YAML
site_name: "${NAME}"
site_url: ""
repo_url: ""

theme:
  name: material
  language: ${LANG}
  palette:
    - scheme: default
      primary: ${PRIMARY}
      accent: ${ACCENT}
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - scheme: slate
      primary: ${PRIMARY}
      accent: ${ACCENT}
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.instant
    - navigation.tracking
    - navigation.tabs
    - navigation.sections
    - navigation.expand
    - navigation.top
    - search.suggest
    - search.highlight
    - content.code.copy
    - content.tabs.link
  icon:
    repo: fontawesome/brands/github

plugins:
  - search
  - minify:
      minify_html: true

markdown_extensions:
  - admonition
  - pymdownx.details
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
  - pymdownx.highlight:
      anchor_linenums: true
      line_spans: __span
      pygments_lang_class: true
  - pymdownx.inlinehilite
  - pymdownx.snippets
  - pymdownx.tabbed:
      alternate_style: true
  - pymdownx.tasklist:
      custom_checkbox: true
  - pymdownx.emoji:
      emoji_index: !!python/name:material.extensions.emoji.twemoji
      emoji_generator: !!python/name:material.extensions.emoji.to_svg
  - tables
  - attr_list
  - md_in_html
  - def_list
  - footnotes
  - toc:
      permalink: true

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - Configuration: configuration.md
YAML

  # Generate index.md
  cat > "$DIR/docs/index.md" << 'MD'
# Welcome

Welcome to the documentation. Use the navigation to explore.

## Quick Links

- [Getting Started](getting-started.md) — Set up in 5 minutes
- [Configuration](configuration.md) — Customize your setup

## Features

!!! tip "Built with Material for MkDocs"
    This documentation site includes search, dark mode, code highlighting, and more.

```python
# Example code block with copy button
print("Hello, docs!")
```
MD

  # Generate getting-started.md
  cat > "$DIR/docs/getting-started.md" << 'MD'
# Getting Started

## Prerequisites

- Python 3.8+
- pip

## Installation

```bash
pip install mkdocs-material
```

## Your First Build

```bash
mkdocs serve
```

Open [http://127.0.0.1:8000](http://127.0.0.1:8000) to see your site.

## Next Steps

- Add more pages to the `docs/` folder
- Update `mkdocs.yml` navigation
- Deploy to GitHub Pages
MD

  # Generate configuration.md
  cat > "$DIR/docs/configuration.md" << 'MD'
# Configuration

## Site Settings

Edit `mkdocs.yml` to customize:

| Setting | Description | Default |
|---------|-------------|---------|
| `site_name` | Your site title | My Documentation |
| `site_url` | Deployed URL | — |
| `repo_url` | GitHub repo link | — |

## Theme Options

### Colors

Change `primary` and `accent` in `mkdocs.yml`:

```yaml
theme:
  palette:
    - scheme: default
      primary: indigo  # Header/link color
      accent: amber    # Hover/highlight color
```

Available colors: `red`, `pink`, `purple`, `deep-purple`, `indigo`, `blue`, `light-blue`, `cyan`, `teal`, `green`, `light-green`, `lime`, `yellow`, `amber`, `orange`, `deep-orange`.

### Dark Mode

Dark mode toggle is enabled by default. Remove the second palette entry to disable.

## Plugins

### Search

Built-in full-text search. No configuration needed.

### Minify

Minifies HTML output for faster loading.

```yaml
plugins:
  - minify:
      minify_html: true
```
MD

  # Generate GitHub Actions workflow
  cat > "$DIR/.github/workflows/deploy-docs.yml" << 'YAML'
name: Deploy Docs
on:
  push:
    branches: [main]
    paths: ['docs/**', 'mkdocs.yml']

permissions:
  contents: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'
      - run: pip install mkdocs-material mkdocs-minify-plugin pymdown-extensions
      - run: mkdocs gh-deploy --force
YAML

  echo ""
  echo "✅ Documentation site scaffolded at: $DIR"
  echo ""
  echo "Files created:"
  echo "  📄 mkdocs.yml — Site configuration"
  echo "  📝 docs/index.md — Home page"
  echo "  📝 docs/getting-started.md — Getting started guide"
  echo "  📝 docs/configuration.md — Configuration reference"
  echo "  🔧 .github/workflows/deploy-docs.yml — Auto-deploy workflow"
  echo ""
  echo "Next steps:"
  echo "  1. Preview:  cd $DIR && mkdocs serve"
  echo "  2. Build:    mkdocs build"
  echo "  3. Deploy:   mkdocs gh-deploy --force"
}

serve_site() {
  echo "🌐 Starting MkDocs dev server..."
  cd "$DIR"
  $MKDOCS_CMD serve
}

build_site() {
  echo "🔨 Building static site..."
  cd "$DIR"
  $MKDOCS_CMD build $STRICT
  
  SITE_SIZE=$(du -sh site/ 2>/dev/null | cut -f1)
  PAGE_COUNT=$(find site/ -name "*.html" 2>/dev/null | wc -l)
  
  echo ""
  echo "✅ Site built successfully!"
  echo "   📁 Output: $DIR/site/"
  echo "   📊 Size: $SITE_SIZE"
  echo "   📄 Pages: $PAGE_COUNT"
}

deploy_site() {
  echo "🚀 Deploying to GitHub Pages..."
  cd "$DIR"
  $MKDOCS_CMD gh-deploy --force
  echo ""
  echo "✅ Deployed! Check your repository's GitHub Pages settings for the URL."
}

add_page() {
  if [[ -z "$TITLE" || -z "$PAGE_PATH" ]]; then
    echo "❌ Usage: run.sh add-page --dir <dir> --title 'Page Title' --path path/to/page.md"
    exit 1
  fi
  
  FULL_PATH="$DIR/docs/$PAGE_PATH"
  mkdir -p "$(dirname "$FULL_PATH")"
  
  cat > "$FULL_PATH" << MD
# ${TITLE}

Write your content here.
MD

  echo "✅ Created: $FULL_PATH"
  echo "⚠️  Remember to add '$PAGE_PATH' to the nav section in mkdocs.yml"
}

add_section() {
  if [[ -z "$TITLE" || -z "$PAGES" ]]; then
    echo "❌ Usage: run.sh add-section --dir <dir> --title 'Section' --pages 'Page1,Page2,Page3'"
    exit 1
  fi
  
  SECTION_SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
  mkdir -p "$DIR/docs/$SECTION_SLUG"
  
  IFS=',' read -ra PAGE_LIST <<< "$PAGES"
  for page in "${PAGE_LIST[@]}"; do
    PAGE_SLUG=$(echo "$page" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
    cat > "$DIR/docs/$SECTION_SLUG/$PAGE_SLUG.md" << MD
# ${page}

Write your content here.
MD
    echo "  📝 Created: docs/$SECTION_SLUG/$PAGE_SLUG.md"
  done
  
  echo ""
  echo "✅ Section '$TITLE' created with ${#PAGE_LIST[@]} pages"
  echo ""
  echo "Add to mkdocs.yml nav:"
  echo "  - $TITLE:"
  for page in "${PAGE_LIST[@]}"; do
    PAGE_SLUG=$(echo "$page" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
    echo "    - $page: $SECTION_SLUG/$PAGE_SLUG.md"
  done
}

import_docs() {
  if [[ -z "$FROM_DIR" ]]; then
    echo "❌ Usage: run.sh import --dir <dir> --from /path/to/markdown-files"
    exit 1
  fi
  
  if [[ ! -d "$FROM_DIR" ]]; then
    echo "❌ Source directory not found: $FROM_DIR"
    exit 1
  fi
  
  mkdir -p "$DIR/docs"
  COUNT=0
  
  while IFS= read -r -d '' file; do
    REL_PATH="${file#$FROM_DIR/}"
    DEST="$DIR/docs/$REL_PATH"
    mkdir -p "$(dirname "$DEST")"
    cp "$file" "$DEST"
    COUNT=$((COUNT + 1))
    echo "  📝 Imported: $REL_PATH"
  done < <(find "$FROM_DIR" -name "*.md" -print0)
  
  echo ""
  echo "✅ Imported $COUNT markdown files"
  echo "⚠️  Update the nav section in mkdocs.yml to include imported pages"
}

set_theme() {
  if [[ ! -f "$DIR/mkdocs.yml" ]]; then
    echo "❌ No mkdocs.yml found in $DIR. Run scaffold first."
    exit 1
  fi
  
  # Use sed to update colors
  sed -i "s/primary: .*/primary: ${PRIMARY}/" "$DIR/mkdocs.yml"
  sed -i "s/accent: .*/accent: ${ACCENT}/" "$DIR/mkdocs.yml"
  
  echo "✅ Theme updated: primary=$PRIMARY, accent=$ACCENT"
}

set_domain() {
  if [[ -z "$DOMAIN" ]]; then
    echo "❌ Usage: run.sh domain --dir <dir> --domain docs.example.com"
    exit 1
  fi
  
  echo "$DOMAIN" > "$DIR/docs/CNAME"
  sed -i "s|site_url:.*|site_url: https://${DOMAIN}/|" "$DIR/mkdocs.yml"
  
  echo "✅ Custom domain set: $DOMAIN"
  echo "   📄 CNAME file created at docs/CNAME"
  echo "   🔧 site_url updated in mkdocs.yml"
  echo ""
  echo "Don't forget to configure DNS:"
  echo "  CNAME record: $DOMAIN → <username>.github.io"
}

validate_site() {
  echo "🔍 Validating docs site at $DIR..."
  
  if [[ ! -f "$DIR/mkdocs.yml" ]]; then
    echo "❌ No mkdocs.yml found"
    exit 1
  fi
  
  # Check nav references
  ERRORS=0
  while IFS= read -r line; do
    FILE=$(echo "$line" | grep -oP ':\s+\K\S+\.md' || true)
    if [[ -n "$FILE" && ! -f "$DIR/docs/$FILE" ]]; then
      echo "❌ Missing file referenced in nav: docs/$FILE"
      ERRORS=$((ERRORS + 1))
    fi
  done < "$DIR/mkdocs.yml"
  
  if [[ $ERRORS -eq 0 ]]; then
    echo "✅ All nav references valid"
  else
    echo ""
    echo "⚠️  Found $ERRORS missing file(s)"
  fi
  
  # Try strict build
  echo ""
  echo "Running strict build check..."
  cd "$DIR"
  if $MKDOCS_CMD build --strict 2>&1 | grep -i "warning\|error"; then
    echo "⚠️  Warnings found above"
  else
    echo "✅ Build passed strict checks"
  fi
}

case "$COMMAND" in
  scaffold)   scaffold ;;
  serve)      find_mkdocs; serve_site ;;
  build)      find_mkdocs; build_site ;;
  deploy)     find_mkdocs; deploy_site ;;
  add-page)   add_page ;;
  add-section) add_section ;;
  import)     import_docs ;;
  theme)      set_theme ;;
  domain)     set_domain ;;
  validate)   find_mkdocs; validate_site ;;
  help|*)
    echo "MkDocs Site Builder"
    echo ""
    echo "Usage: bash run.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  scaffold     Create a new docs site"
    echo "  serve        Start local dev server"
    echo "  build        Build static HTML"
    echo "  deploy       Deploy to GitHub Pages"
    echo "  add-page     Add a new page"
    echo "  add-section  Add a section with multiple pages"
    echo "  import       Import existing markdown files"
    echo "  theme        Update theme colors"
    echo "  domain       Set custom domain"
    echo "  validate     Check for issues"
    echo ""
    echo "Options:"
    echo "  --dir <path>      Project directory (default: .)"
    echo "  --name <name>     Site name (scaffold)"
    echo "  --primary <color> Primary color (theme)"
    echo "  --accent <color>  Accent color (theme)"
    echo "  --title <title>   Page/section title"
    echo "  --path <path>     Page path (add-page)"
    echo "  --pages <list>    Comma-separated pages (add-section)"
    echo "  --from <dir>      Source directory (import)"
    echo "  --domain <domain> Custom domain"
    echo "  --strict          Strict build mode"
    ;;
esac
