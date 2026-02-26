---
name: mkdocs-site-builder
description: >-
  Build and deploy beautiful documentation sites with MkDocs and Material theme. Scaffold, build, preview, and publish to GitHub Pages in minutes.
categories: [dev-tools, writing]
dependencies: [python3, pip, git]
---

# MkDocs Site Builder

## What This Does

Installs MkDocs with the Material for MkDocs theme, scaffolds a professional documentation site, builds it to static HTML, and deploys to GitHub Pages. Turns your markdown files into a polished, searchable documentation website with zero frontend work.

**Example:** "Create a docs site for my project, add navigation, search, dark mode, then deploy to GitHub Pages — all from the terminal."

## Quick Start (5 minutes)

### 1. Install MkDocs + Material Theme

```bash
bash scripts/install.sh
```

This installs:
- `mkdocs` — static site generator for documentation
- `mkdocs-material` — professional Material Design theme
- `mkdocs-minify-plugin` — HTML/CSS/JS minification
- `mkdocs-redirects` — URL redirect support

### 2. Scaffold a New Docs Site

```bash
bash scripts/run.sh scaffold --name "My Project Docs" --dir ./docs-site
```

Creates a ready-to-use docs project:
```
docs-site/
├── mkdocs.yml          # Site configuration
├── docs/
│   ├── index.md        # Home page
│   ├── getting-started.md
│   ├── configuration.md
│   └── assets/
│       └── logo.png    # Placeholder logo
└── .github/
    └── workflows/
        └── deploy-docs.yml  # Auto-deploy on push
```

### 3. Preview Locally

```bash
bash scripts/run.sh serve --dir ./docs-site
# Opens at http://127.0.0.1:8000
```

### 4. Build Static Site

```bash
bash scripts/run.sh build --dir ./docs-site
# Output: docs-site/site/
```

### 5. Deploy to GitHub Pages

```bash
bash scripts/run.sh deploy --dir ./docs-site
# Pushes to gh-pages branch
```

## Core Workflows

### Workflow 1: Create Documentation for Existing Repo

**Use case:** Add a `/docs` folder to your GitHub repo and deploy it.

```bash
cd /path/to/your-repo
bash /path/to/scripts/run.sh scaffold --name "MyApp" --dir .
bash /path/to/scripts/run.sh build --dir .
bash /path/to/scripts/run.sh deploy --dir .
```

### Workflow 2: Add Pages to Existing Site

**Use case:** Add new documentation pages.

```bash
# Add a new page
bash scripts/run.sh add-page --dir ./docs-site --title "API Reference" --path api/reference.md

# Add a section with multiple pages
bash scripts/run.sh add-section --dir ./docs-site --title "Guides" --pages "Installation,Configuration,Deployment"
```

### Workflow 3: Import Markdown Files

**Use case:** Turn a folder of markdown files into a docs site.

```bash
bash scripts/run.sh import --dir ./docs-site --from /path/to/markdown-files
# Copies .md files, generates nav structure in mkdocs.yml
```

### Workflow 4: Custom Theme Colors

```bash
bash scripts/run.sh theme --dir ./docs-site \
  --primary "indigo" \
  --accent "amber" \
  --dark-mode on
```

### Workflow 5: Build and Serve for CI/CD

```bash
# Strict build (fails on warnings)
bash scripts/run.sh build --dir ./docs-site --strict

# Check for broken links
bash scripts/run.sh build --dir ./docs-site --strict 2>&1 | grep "WARNING"
```

## Configuration

### mkdocs.yml (Generated)

```yaml
site_name: My Project Docs
site_url: https://username.github.io/repo-name/
theme:
  name: material
  palette:
    - scheme: default
      primary: indigo
      accent: amber
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - scheme: slate
      primary: indigo
      accent: amber
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.instant
    - navigation.tracking
    - navigation.tabs
    - navigation.sections
    - navigation.expand
    - search.suggest
    - search.highlight
    - content.code.copy
    - content.tabs.link

plugins:
  - search
  - minify:
      minify_html: true

markdown_extensions:
  - admonition
  - pymdownx.details
  - pymdownx.superfences
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.inlinehilite
  - pymdownx.snippets
  - pymdownx.tabbed:
      alternate_style: true
  - tables
  - attr_list
  - md_in_html
  - toc:
      permalink: true

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - Configuration: configuration.md
```

## Advanced Usage

### GitHub Actions Auto-Deploy

The scaffold includes `.github/workflows/deploy-docs.yml`:

```yaml
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
      - run: pip install mkdocs-material mkdocs-minify-plugin
      - run: mkdocs gh-deploy --force
```

### Multi-Language Support

```bash
bash scripts/run.sh scaffold --name "My Docs" --dir ./docs-site --lang en,ja,es
```

### Custom Domain

```bash
bash scripts/run.sh domain --dir ./docs-site --domain docs.example.com
# Creates CNAME file and updates mkdocs.yml
```

### Versioning

```bash
pip install mike
mike deploy --push --update-aliases 1.0 latest
mike set-default --push latest
```

## Troubleshooting

### Issue: "pip: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install python3-pip

# Mac
brew install python3
```

### Issue: "mkdocs: command not found" after install

```bash
# Add to PATH
export PATH="$HOME/.local/bin:$PATH"
# Or use pipx
pipx install mkdocs-material
```

### Issue: Deploy fails with permission error

```bash
# Ensure GitHub Pages is enabled in repo settings
# Settings → Pages → Source: "Deploy from a branch" → gh-pages
```

### Issue: Build warnings about missing pages

```bash
# Check nav references match actual files
bash scripts/run.sh validate --dir ./docs-site
```

## Dependencies

- `python3` (3.8+)
- `pip` (Python package manager)
- `git` (for deployment)
- Optional: `gh` CLI (for GitHub Pages setup)
