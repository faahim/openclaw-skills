#!/bin/bash
# Zola site manager — scaffold, theme, content, build
set -euo pipefail

CMD="${1:-help}"
SITE="${2:-}"

usage() {
  cat <<EOF
Zola Site Manager

Usage: manage.sh <command> <site> [options]

Commands:
  new <name> [--theme T] [--blog]    Create a new Zola site
  theme <site> <name|url> [--list]   Install/list themes
  themes                             List popular themes
  post <site> "Title"                Create a blog post
  page <site> "slug"                 Create a standalone page
  section <site> "name"              Create a content section
  list <site>                        List all content
  serve <site>                       Start dev server
  build <site> [--base-url URL]      Build for production
  check <site>                       Check for errors
  template <site> <name>             Create a template
  shortcode <site> <name>            Create a shortcode

EOF
}

ensure_zola() {
  if ! command -v zola &>/dev/null; then
    echo "❌ Zola not found. Run: bash scripts/install.sh"
    exit 1
  fi
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

cmd_new() {
  local name="$1"; shift
  local theme="" blog=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --theme) theme="$2"; shift 2 ;;
      --blog) blog=true; shift ;;
      *) shift ;;
    esac
  done

  ensure_zola

  if [[ -d "$name" ]]; then
    echo "❌ Directory '$name' already exists"
    exit 1
  fi

  # Manual init (zola init is interactive, not scriptable)
  mkdir -p "$name"/{content,templates,static,themes,sass}
  cat > "$name/config.toml" <<TOML
base_url = "https://example.com"
title = "$name"
description = ""
compile_sass = true
generate_feed = true
feed_filename = "atom.xml"
minify_html = false

[markdown]
highlight_code = true
highlight_theme = "css"

taxonomies = [
    { name = "tags", feed = true },
    { name = "categories" },
]

[extra]
author = ""
TOML

  if $blog; then
    mkdir -p "$name/content/blog"
    cat > "$name/content/blog/_index.md" <<MD
+++
title = "Blog"
sort_by = "date"
paginate_by = 10
+++
MD
    echo "📝 Blog section created at content/blog/"
  fi

  if [[ -n "$theme" ]]; then
    cmd_theme "$name" "$theme"
  fi

  echo "✅ Created Zola site: $name/"
  echo "📁 $name/config.toml"
  echo "📁 $name/content/"
  echo "📁 $name/templates/"
  echo "📁 $name/static/"
  echo "📁 $name/themes/"
}

cmd_theme() {
  local site="$1" theme="$2"
  shift 2
  local list_only=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --list) list_only=true; shift ;;
      *) shift ;;
    esac
  done

  if $list_only; then
    echo "Installed themes in $site/themes/:"
    ls -1 "$site/themes/" 2>/dev/null || echo "  (none)"
    return
  fi

  mkdir -p "$site/themes"

  # Determine git URL
  local git_url
  if [[ "$theme" == http* ]]; then
    git_url="$theme"
    theme=$(basename "$theme" .git)
  else
    git_url="https://github.com/pawrber/${theme}.git"
    # Try common Zola theme repos
    if ! git ls-remote "$git_url" &>/dev/null 2>&1; then
      git_url="https://github.com/getzola/${theme}.git"
    fi
    if ! git ls-remote "$git_url" &>/dev/null 2>&1; then
      # Search on GitHub
      git_url=$(curl -sL "https://api.github.com/search/repositories?q=${theme}+zola+theme&sort=stars" | \
        grep -m1 '"clone_url"' | sed -E 's/.*"(https[^"]+)".*/\1/' || true)
    fi
  fi

  if [[ -z "$git_url" ]]; then
    echo "❌ Could not find theme: $theme"
    echo "   Try providing a full Git URL: manage.sh theme $site https://github.com/user/theme.git"
    exit 1
  fi

  echo "📦 Installing theme '$theme'..."
  if [[ -d "$site/themes/$theme" ]]; then
    cd "$site/themes/$theme" && git pull && cd - >/dev/null
  else
    git clone --depth 1 "$git_url" "$site/themes/$theme" 2>/dev/null || {
      echo "❌ Failed to clone theme from: $git_url"
      exit 1
    }
  fi

  # Set theme in config
  if grep -q '^theme\s*=' "$site/config.toml" 2>/dev/null; then
    sed -i "s/^theme\s*=.*/theme = \"$theme\"/" "$site/config.toml"
  else
    echo "theme = \"$theme\"" >> "$site/config.toml"
  fi

  echo "✅ Theme '$theme' installed and configured"
}

cmd_themes() {
  cat <<EOF
Popular Zola Themes:

  terminimal     — Minimal, clean, monospace terminal aesthetic
  after-dark     — Dark theme with syntax highlighting
  even           — Clean blog theme (port of Hugo Even)
  DeepThought    — Feature-rich blog/docs theme
  blow           — Minimal portfolio/blog
  papaya         — Colorful portfolio theme
  serene         — Clean and serene blog
  tale-zola      — Port of Tale theme (simple blog)
  zola-386       — Retro DOS/386 aesthetic
  adidoks        — Modern documentation theme
  tabi           — Fast, accessible blog theme
  kodama-theme   — Japanese-inspired minimal theme
  zerm           — Minimal dark theme

Browse all: https://www.getzola.org/themes/
EOF
}

cmd_post() {
  local site="$1" title="$2"
  local slug=$(slugify "$title")
  local date=$(date +%Y-%m-%d)
  local dir="$site/content/blog"

  mkdir -p "$dir"

  # Ensure blog _index.md exists
  if [[ ! -f "$dir/_index.md" ]]; then
    cat > "$dir/_index.md" <<MD
+++
title = "Blog"
sort_by = "date"
paginate_by = 10
+++
MD
  fi

  local file="$dir/${slug}.md"
  if [[ -f "$file" ]]; then
    echo "❌ Post already exists: $file"
    exit 1
  fi

  cat > "$file" <<MD
+++
title = "$title"
date = $date
description = ""
[taxonomies]
tags = []
categories = []
[extra]
author = ""
+++

Write your content here...
MD

  echo "✅ Created post: $file"
}

cmd_page() {
  local site="$1" slug="$2"
  local file="$site/content/${slug}.md"

  mkdir -p "$(dirname "$file")"

  if [[ -f "$file" ]]; then
    echo "❌ Page already exists: $file"
    exit 1
  fi

  cat > "$file" <<MD
+++
title = "$slug"
+++

Page content here...
MD

  echo "✅ Created page: $file"
}

cmd_section() {
  local site="$1" name="$2"
  local dir="$site/content/$name"
  mkdir -p "$dir"

  if [[ ! -f "$dir/_index.md" ]]; then
    cat > "$dir/_index.md" <<MD
+++
title = "$name"
sort_by = "date"
+++
MD
  fi

  echo "✅ Created section: $dir/"
}

cmd_list() {
  local site="$1"
  echo "Content in $site:"
  find "$site/content" -name "*.md" ! -name "_index.md" -printf "  📄 %P\n" 2>/dev/null || \
    find "$site/content" -name "*.md" ! -name "_index.md" | sed "s|$site/content/|  📄 |"
}

cmd_serve() {
  local site="$1"
  ensure_zola
  echo "🚀 Starting dev server at http://127.0.0.1:1111"
  cd "$site" && zola serve
}

cmd_build() {
  local site="$1"; shift
  local base_url=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --base-url) base_url="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  ensure_zola

  local args=""
  [[ -n "$base_url" ]] && args="--base-url $base_url"

  cd "$site"
  local start=$(date +%s%3N 2>/dev/null || date +%s)
  zola build $args
  local end=$(date +%s%3N 2>/dev/null || date +%s)
  local elapsed=$(( end - start ))

  local pages=$(find public -name "*.html" | wc -l)
  echo "✅ Built site: ${pages} pages in ${elapsed}ms → ${site}/public/"
}

cmd_check() {
  local site="$1"
  ensure_zola
  cd "$site" && zola check
}

cmd_template() {
  local site="$1" name="$2"
  local file="$site/templates/${name}.html"
  mkdir -p "$site/templates"

  if [[ -f "$file" ]]; then
    echo "❌ Template already exists: $file"
    exit 1
  fi

  if [[ "$name" == "base" ]]; then
    cat > "$file" <<'HTML'
<!DOCTYPE html>
<html lang="{{ lang }}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{% block title %}{{ config.title }}{% endblock %}</title>
  {% block head %}{% endblock %}
</head>
<body>
  <header>
    <nav>
      <a href="{{ get_url(path="/") }}">Home</a>
      <a href="{{ get_url(path="/blog") }}">Blog</a>
    </nav>
  </header>
  <main>
    {% block content %}{% endblock %}
  </main>
  <footer>
    <p>&copy; {{ now() | date(format="%Y") }} {{ config.title }}</p>
  </footer>
</body>
</html>
HTML
  else
    cat > "$file" <<HTML
{% extends "base.html" %}
{% block title %}${name} — {{ config.title }}{% endblock %}
{% block content %}
  <h1>{{ section.title | default(value="${name}") }}</h1>
  {{ section.content | safe }}
{% endblock %}
HTML
  fi

  echo "✅ Created template: $file"
}

cmd_shortcode() {
  local site="$1" name="$2"
  local dir="$site/templates/shortcodes"
  local file="$dir/${name}.html"
  mkdir -p "$dir"

  if [[ -f "$file" ]]; then
    echo "❌ Shortcode already exists: $file"
    exit 1
  fi

  case "$name" in
    youtube)
      cat > "$file" <<'HTML'
<div style="position:relative;padding-bottom:56.25%;height:0;overflow:hidden;">
  <iframe src="https://www.youtube.com/embed/{{ id }}"
    style="position:absolute;top:0;left:0;width:100%;height:100%;"
    frameborder="0" allowfullscreen loading="lazy"></iframe>
</div>
HTML
      ;;
    *)
      cat > "$file" <<HTML
{# Shortcode: $name #}
{# Usage: {{ ${name}(param="value") }} #}
<div class="shortcode-${name}">
  {{ body | safe }}
</div>
HTML
      ;;
  esac

  echo "✅ Created shortcode: $file"
  echo "   Usage: {{ ${name}(param=\"value\") }}"
}

# Route commands
case "$CMD" in
  new) shift; cmd_new "$@" ;;
  theme) shift 2; cmd_theme "$SITE" "$@" ;;
  themes) cmd_themes ;;
  post) shift 2; cmd_post "$SITE" "$@" ;;
  page) shift 2; cmd_page "$SITE" "$@" ;;
  section) shift 2; cmd_section "$SITE" "$@" ;;
  list) cmd_list "$SITE" ;;
  serve) cmd_serve "$SITE" ;;
  build) shift 2; cmd_build "$SITE" "$@" ;;
  check) cmd_check "$SITE" ;;
  template) shift 2; cmd_template "$SITE" "$@" ;;
  shortcode) shift 2; cmd_shortcode "$SITE" "$@" ;;
  help|--help|-h) usage ;;
  *) echo "Unknown command: $CMD"; usage; exit 1 ;;
esac
