# Listing Copy: Zola Site Manager

## Metadata
- **Type:** Skill
- **Name:** zola-site-manager
- **Display Name:** Zola Static Site Manager
- **Categories:** [dev-tools, writing]
- **Price:** $10
- **Dependencies:** [bash, curl, tar, git]

## Tagline

Install, scaffold, and deploy blazing-fast Zola static sites from your terminal

## Description

Setting up a static site shouldn't take an afternoon. Between choosing a generator, installing dependencies, configuring themes, writing deployment scripts — it adds up fast. Zola is already the fastest static site generator (single Rust binary, millisecond builds), but you still need to wire everything together.

Zola Site Manager handles the entire lifecycle. Install Zola with one command (auto-detects your OS and architecture). Scaffold new sites with blog sections pre-configured. Browse and install themes from the Zola ecosystem. Create posts, pages, and sections with proper frontmatter. Build for production with HTML minification. Deploy to GitHub Pages, Netlify, Cloudflare Pages, or Vercel — each with the right config files auto-generated.

**What it does:**
- 📦 One-command Zola install (Linux & macOS, x86_64 & ARM)
- 🏗️ Scaffold sites with themes and blog sections
- 🎨 Browse and install 50+ community themes
- 📝 Create posts, pages, sections with proper frontmatter
- 🔨 Build with minification, feeds, sitemaps, syntax highlighting
- 🚀 Deploy configs for GitHub Pages, Netlify, Cloudflare, Vercel
- 🔍 Built-in link checker and error detection
- 📐 Custom templates and shortcodes scaffolding

Perfect for developers, writers, and indie hackers who want a personal site or blog without the bloat of Next.js or the complexity of Hugo.

## Quick Start Preview

```bash
# Install Zola
bash scripts/install.sh

# Create a blog
bash scripts/manage.sh new my-blog --blog --theme terminimal

# Write a post
bash scripts/manage.sh post my-blog "Hello World"

# Deploy to GitHub Pages
bash scripts/deploy.sh my-blog github-pages
```

## Core Capabilities

1. Auto-install — Downloads correct binary for your OS/arch
2. Site scaffolding — config.toml, directories, blog section ready
3. Theme management — Install from name or Git URL, auto-configure
4. Content creation — Posts, pages, sections with proper frontmatter
5. Build optimization — Minified HTML, Sass compilation, feeds, sitemaps
6. Multi-target deploy — GitHub Pages, Netlify, Cloudflare, Vercel
7. Link checking — Detect broken internal links before deploy
8. Template scaffolding — Base templates and shortcodes
9. Multilingual support — Built-in i18n configuration
10. Taxonomy management — Tags, categories with auto-generated pages
