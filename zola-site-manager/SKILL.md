---
name: zola-site-manager
description: >-
  Install, scaffold, theme, build, and deploy Zola static sites from the terminal.
categories: [dev-tools, writing]
dependencies: [bash, curl, tar]
---

# Zola Static Site Manager

## What This Does

Automates the entire Zola static site lifecycle — install the binary, scaffold new sites, manage themes, build for production, and deploy to common hosts (GitHub Pages, Netlify, Cloudflare Pages, Vercel). Zola is a blazing-fast static site generator written in Rust (single binary, no dependencies, builds in milliseconds).

**Example:** "Create a blog with the `terminimal` theme, write posts in Markdown, deploy to GitHub Pages — all from your terminal."

## Quick Start (5 minutes)

### 1. Install Zola

```bash
bash scripts/install.sh
# Detects OS/arch, downloads latest Zola release, installs to ~/.local/bin
# Output: ✅ Zola v0.19.x installed to ~/.local/bin/zola
```

### 2. Create a New Site

```bash
bash scripts/manage.sh new my-blog
# Scaffolds a new Zola site in ./my-blog with default config
# Output:
# ✅ Created Zola site: my-blog/
# 📁 my-blog/config.toml
# 📁 my-blog/content/
# 📁 my-blog/templates/
# 📁 my-blog/static/
# 📁 my-blog/themes/
```

### 3. Add a Theme

```bash
bash scripts/manage.sh theme my-blog terminimal
# Clones the terminimal theme and configures it
# Output: ✅ Theme 'terminimal' installed and configured
```

### 4. Create a Post

```bash
bash scripts/manage.sh post my-blog "My First Post"
# Creates content/blog/my-first-post.md with frontmatter
# Output: ✅ Created post: content/blog/my-first-post.md
```

### 5. Build & Preview

```bash
bash scripts/manage.sh serve my-blog
# Starts local dev server at http://127.0.0.1:1111
# Live-reloads on file changes

bash scripts/manage.sh build my-blog
# Builds static site to my-blog/public/
# Output: ✅ Built site: 42 pages in 85ms → my-blog/public/
```

## Core Workflows

### Workflow 1: Install or Update Zola

```bash
# Install latest
bash scripts/install.sh

# Install specific version
bash scripts/install.sh --version 0.19.2

# Update to latest
bash scripts/install.sh --update

# Check current version
zola --version
```

**Supported platforms:** Linux (x86_64, aarch64), macOS (x86_64, aarch64)

### Workflow 2: Scaffold a New Site

```bash
bash scripts/manage.sh new my-site

# With a specific theme from the start
bash scripts/manage.sh new my-site --theme after-dark

# With blog section pre-configured
bash scripts/manage.sh new my-site --blog
```

### Workflow 3: Manage Themes

```bash
# List popular themes
bash scripts/manage.sh themes

# Install a theme
bash scripts/manage.sh theme my-site terminimal

# Install from custom Git URL
bash scripts/manage.sh theme my-site https://github.com/user/zola-theme.git

# List installed themes
bash scripts/manage.sh theme my-site --list
```

**Popular themes:** terminimal, after-dark, even, DeepThought, blow, papaya, serene, tale-zola, zola-386, codinfox-zola

### Workflow 4: Content Management

```bash
# Create a blog post
bash scripts/manage.sh post my-site "Post Title"

# Create a page (non-blog)
bash scripts/manage.sh page my-site "about"

# Create a section
bash scripts/manage.sh section my-site "projects"

# List all content
bash scripts/manage.sh list my-site
```

### Workflow 5: Build & Deploy

```bash
# Build for production
bash scripts/manage.sh build my-site

# Build with custom base URL
bash scripts/manage.sh build my-site --base-url https://example.com

# Deploy to GitHub Pages
bash scripts/deploy.sh my-site github-pages

# Deploy to Netlify (drag & drop)
bash scripts/deploy.sh my-site netlify

# Deploy to Cloudflare Pages
bash scripts/deploy.sh my-site cloudflare
```

### Workflow 6: SEO & Optimization

```bash
# Generate sitemap (built-in to Zola)
# Just build — sitemap.xml is auto-generated

# Check for broken internal links
bash scripts/manage.sh check my-site

# Generate RSS/Atom feed (built-in)
# Configure in config.toml: generate_feed = true
```

## Configuration

### config.toml (Zola Config)

```toml
# Base URL for production
base_url = "https://example.com"

# Site metadata
title = "My Blog"
description = "A blog about things"

# Build options
compile_sass = true
generate_feed = true
feed_filename = "atom.xml"
minify_html = true

# Syntax highlighting
[markdown]
highlight_code = true
highlight_theme = "css"

# Taxonomy (tags, categories)
taxonomies = [
    { name = "tags", feed = true },
    { name = "categories" },
]

# Theme
theme = "terminimal"

# Extra config (theme-specific)
[extra]
author = "Your Name"
```

### Post Frontmatter

```markdown
+++
title = "My First Post"
date = 2026-03-02
description = "A short description for SEO"
[taxonomies]
tags = ["rust", "webdev"]
categories = ["tutorial"]
[extra]
author = "Your Name"
+++

Your markdown content here...
```

## Advanced Usage

### Custom Templates

```bash
# Create a custom template
bash scripts/manage.sh template my-site base

# This creates templates/base.html with Tera template syntax
```

### Multilingual Sites

```toml
# config.toml
default_language = "en"

[languages.fr]
title = "Mon Blog"
generate_feed = true

[languages.es]
title = "Mi Blog"
```

### Shortcodes

```bash
# Create a shortcode
bash scripts/manage.sh shortcode my-site youtube

# Creates templates/shortcodes/youtube.html
```

Usage in content:
```markdown
{{ youtube(id="dQw4w9WgXcQ") }}
```

### Automated Builds with Cron

```bash
# Rebuild site every hour (if using dynamic data)
# Add to crontab:
0 * * * * cd /path/to/my-site && zola build 2>&1 >> /var/log/zola-build.log
```

## Deploy Configurations

### GitHub Pages

```bash
bash scripts/deploy.sh my-site github-pages
# Creates .github/workflows/deploy.yml
# Commits and pushes to trigger GitHub Actions
```

### Netlify

```bash
bash scripts/deploy.sh my-site netlify
# Creates netlify.toml with build command
# Output: Drag 'public/' folder to Netlify, or connect repo
```

### Cloudflare Pages

```bash
bash scripts/deploy.sh my-site cloudflare
# Output: Connect repo to Cloudflare Pages
# Build command: zola build
# Output directory: public
```

## Troubleshooting

### Issue: "zola: command not found"

**Fix:**
```bash
# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### Issue: Theme not rendering

**Fix:**
1. Check theme is in `themes/` directory
2. Check `config.toml` has `theme = "theme-name"`
3. Check theme's required `[extra]` config is set

### Issue: Build fails with template error

**Fix:**
```bash
# Check for syntax errors
zola check

# Build with verbose output
zola build -v
```

### Issue: Posts not showing up

**Fix:**
1. Check frontmatter has `date` field
2. Check date is not in the future (Zola skips future posts by default)
3. Check file is in correct section directory

## Dependencies

- `bash` (4.0+)
- `curl` (downloading Zola)
- `tar` (extracting archive)
- `git` (theme management)
- `zola` (installed by this skill)
