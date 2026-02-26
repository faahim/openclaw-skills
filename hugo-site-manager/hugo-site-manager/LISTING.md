# Listing Copy: Hugo Site Manager

## Metadata
- **Type:** Skill
- **Name:** hugo-site-manager
- **Display Name:** Hugo Site Manager
- **Categories:** [writing, dev-tools]
- **Price:** $12
- **Dependencies:** [bash, curl, git, hugo]

## Tagline

"Build & deploy Hugo sites — install, scaffold, write, and ship from your agent"

## Description

Setting up a blog or docs site shouldn't require memorizing Hugo's CLI flags, wrestling with theme configs, or manually deploying to GitHub Pages. Yet every time you start a new site, it's the same 20 minutes of setup.

Hugo Site Manager handles the entire lifecycle: installs Hugo Extended automatically, scaffolds new sites with popular themes (PaperMod, Docsy, Stack), creates content with proper frontmatter, builds production bundles, and deploys to GitHub Pages or Netlify — all through simple commands your agent runs directly.

**What it does:**
- 🚀 One-command Hugo installation (auto-detects OS/arch)
- 📝 Create sites with 6+ popular themes pre-configured
- ✍️ Write posts with automatic slugs, dates, and frontmatter
- 📦 Build minified production bundles with stats
- 🌐 Deploy to GitHub Pages, Netlify, or any git remote
- 📊 Site stats: post count, tags, build time, output size
- 🔄 Migrate from Jekyll or WordPress
- 📋 Bulk import from markdown files or CSV

Perfect for developers, writers, and indie makers who want a fast, beautiful static site without the setup friction.

## Quick Start Preview

```bash
# Install Hugo
bash scripts/install.sh

# Create a blog
bash scripts/manage.sh new --name my-blog --theme PaperMod

# Add a post
bash scripts/manage.sh post --site my-blog --title "Hello World" --content "My first post!"

# Build & deploy
bash scripts/manage.sh build --site my-blog
bash scripts/manage.sh deploy --site my-blog --target github --repo user/blog
```

## Core Capabilities

1. Hugo installation — Auto-install Hugo Extended for Linux/macOS (amd64/arm64)
2. Site scaffolding — Create new sites with themes in one command
3. Theme management — Switch between PaperMod, Stack, Docsy, Ananke, Terminal, Blowfish
4. Content creation — Posts with proper frontmatter, slugs, tags, sections
5. Bulk import — Import from markdown directories or CSV files
6. Local preview — Start dev server with live reload
7. Production builds — Minified output with page count and timing stats
8. GitHub Pages deploy — Push to any repo/branch with token auth
9. Netlify deploy — Deploy via Netlify CLI or git push
10. Jekyll/WordPress migration — Import existing content automatically
11. Site statistics — Post count, tags, sections, build size, build time
12. Configuration management — Update title, URL, language, custom params

## Dependencies
- `bash` (4.0+)
- `curl` (for Hugo download)
- `git` (themes, deployment)
- `hugo` (auto-installed by skill)
- Optional: `gh` CLI, `netlify` CLI

## Installation Time
**5 minutes** — Run install script, create first site
