# Listing Copy: MkDocs Site Builder

## Metadata
- **Type:** Skill
- **Name:** mkdocs-site-builder
- **Display Name:** MkDocs Site Builder
- **Categories:** [dev-tools, writing]
- **Price:** $10
- **Icon:** 📚
- **Dependencies:** [python3, pip, git]

## Tagline

Build beautiful documentation sites from markdown — deploy to GitHub Pages in minutes

## Description

Your project deserves great documentation, but setting up a docs site from scratch is tedious. You need a theme, search, navigation, dark mode, code highlighting, and deployment — that's hours of yak-shaving before writing a single word.

MkDocs Site Builder handles the entire docs pipeline. One command scaffolds a professional documentation site with Material for MkDocs — the most popular documentation theme with 20k+ GitHub stars. It comes pre-configured with search, dark mode toggle, code copy buttons, tabbed content, admonitions, and Mermaid diagram support.

**What it does:**
- 🏗️ Scaffold a complete docs site with one command
- 📝 Add pages and sections with auto-generated navigation
- 🎨 Material theme with dark mode, search, and code highlighting
- 📦 Import existing markdown files into a docs structure
- 🚀 Deploy to GitHub Pages (includes CI/CD workflow)
- ✅ Validate nav references and run strict build checks
- 🎯 Custom domains, theme colors, and Mermaid diagrams

**Who it's for:** Developers, open-source maintainers, and teams who want polished documentation without the frontend work.

## Quick Start Preview

```bash
# Install
bash scripts/install.sh

# Scaffold a new docs site
bash scripts/run.sh scaffold --name "My Project" --dir ./docs

# Preview locally
bash scripts/run.sh serve --dir ./docs

# Deploy to GitHub Pages
bash scripts/run.sh deploy --dir ./docs
```

## Core Capabilities

1. One-command scaffold — Full docs site with theme, config, and CI/CD
2. Material theme — Dark mode, search, code copy, tabs, admonitions
3. GitHub Pages deploy — Push to gh-pages with `mkdocs gh-deploy`
4. CI/CD workflow — Auto-deploy on push via GitHub Actions
5. Page management — Add pages and sections from CLI
6. Markdown import — Turn existing .md files into a docs site
7. Theme customization — Change colors, enable/disable features
8. Custom domains — CNAME + site_url configuration
9. Mermaid diagrams — Render flowcharts and diagrams in docs
10. Strict validation — Catch broken links and missing files before deploy

## Installation Time
**5 minutes** — Install dependencies, scaffold, preview
