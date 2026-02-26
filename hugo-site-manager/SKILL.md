---
name: hugo-site-manager
description: >-
  Install Hugo, scaffold sites, manage content, build & deploy to GitHub Pages or Netlify — all from your agent.
categories: [writing, dev-tools]
dependencies: [bash, curl, git, hugo]
---

# Hugo Site Manager

## What This Does

Automates the full lifecycle of Hugo static sites: install Hugo, create new sites with themes, write/manage content, build production bundles, and deploy to GitHub Pages or Netlify. No manual terminal work — your agent handles everything.

**Example:** "Create a blog, add a post about AI, build it, deploy to GitHub Pages" — done in 2 minutes.

## Quick Start (5 minutes)

### 1. Install Hugo

```bash
bash scripts/install.sh
```

This installs the latest Hugo extended edition for your platform (Linux/macOS, amd64/arm64).

### 2. Create a New Site

```bash
bash scripts/manage.sh new --name my-blog --theme PaperMod
```

Creates a new Hugo site at `./my-blog/` with the PaperMod theme pre-configured.

### 3. Create Your First Post

```bash
bash scripts/manage.sh post --site my-blog --title "Hello World" --content "Welcome to my blog!"
```

### 4. Preview Locally

```bash
bash scripts/manage.sh serve --site my-blog
# Server running at http://localhost:1313
```

### 5. Build & Deploy

```bash
# Build production bundle
bash scripts/manage.sh build --site my-blog

# Deploy to GitHub Pages
bash scripts/manage.sh deploy --site my-blog --target github --repo user/user.github.io
```

## Core Workflows

### Workflow 1: Create a Blog

```bash
# Create site with popular blog theme
bash scripts/manage.sh new --name my-blog --theme PaperMod

# Configure site
bash scripts/manage.sh config --site my-blog \
  --title "My Blog" \
  --base-url "https://myblog.com" \
  --language "en"

# Add first post
bash scripts/manage.sh post --site my-blog \
  --title "Getting Started" \
  --tags "intro,hello" \
  --content "This is my first post on my new blog!"
```

### Workflow 2: Create Documentation Site

```bash
# Create site with docs theme
bash scripts/manage.sh new --name docs --theme docsy

# Add a docs section
bash scripts/manage.sh post --site docs \
  --section "docs" \
  --title "Installation Guide" \
  --weight 1 \
  --content "## Step 1: Download\n\nGet the latest release..."
```

### Workflow 3: Bulk Content Creation

```bash
# Create multiple posts from a directory of markdown files
bash scripts/manage.sh bulk-import --site my-blog --source ./drafts/

# Create posts from a CSV
# CSV format: title,tags,date,content_file
bash scripts/manage.sh bulk-csv --site my-blog --csv posts.csv
```

### Workflow 4: Deploy to GitHub Pages

```bash
# Initialize GitHub Pages deployment
bash scripts/manage.sh deploy --site my-blog \
  --target github \
  --repo username/username.github.io \
  --branch gh-pages

# Output:
# ✅ Built 24 pages in 150ms
# ✅ Pushed to github.com/username/username.github.io (gh-pages)
# 🌐 Live at https://username.github.io
```

### Workflow 5: Deploy to Netlify

```bash
# Deploy via Netlify CLI
bash scripts/manage.sh deploy --site my-blog \
  --target netlify \
  --site-id your-netlify-site-id

# Or deploy via git push (if Netlify is connected to repo)
bash scripts/manage.sh deploy --site my-blog --target git-push
```

## Configuration

### Hugo Config (hugo.toml)

The `config` command updates your `hugo.toml`:

```bash
bash scripts/manage.sh config --site my-blog \
  --title "My Awesome Blog" \
  --base-url "https://example.com" \
  --language "en" \
  --paginate 10 \
  --param "author=John Doe" \
  --param "description=A blog about tech"
```

### Supported Themes

Popular themes auto-configured by this skill:

| Theme | Type | Command |
|-------|------|---------|
| PaperMod | Blog | `--theme PaperMod` |
| Stack | Blog | `--theme Stack` |
| Docsy | Docs | `--theme docsy` |
| Ananke | General | `--theme ananke` |
| Terminal | Minimal | `--theme terminal` |
| Blowfish | Blog | `--theme blowfish` |

Custom themes: `--theme https://github.com/user/theme.git`

### Environment Variables

```bash
# GitHub deployment
export GITHUB_TOKEN="<your-token>"  # For pushing to GitHub Pages

# Netlify deployment
export NETLIFY_AUTH_TOKEN="<your-token>"
export NETLIFY_SITE_ID="<your-site-id>"
```

## Advanced Usage

### Custom Archetypes

```bash
# Create a custom archetype for project posts
bash scripts/manage.sh archetype --site my-blog \
  --name "project" \
  --frontmatter "title,description,github_url,demo_url,tags,status"
```

### Taxonomies & Sections

```bash
# List all content
bash scripts/manage.sh list --site my-blog

# List by section
bash scripts/manage.sh list --site my-blog --section blog

# List tags
bash scripts/manage.sh list --site my-blog --taxonomies
```

### Site Stats

```bash
bash scripts/manage.sh stats --site my-blog

# Output:
# 📊 Site: my-blog
# 📝 Posts: 42
# 🏷️ Tags: 15
# 📁 Sections: 3 (blog, projects, about)
# 📦 Build size: 2.1 MB
# ⚡ Build time: 180ms
```

### Migrate from Other Platforms

```bash
# From Jekyll
bash scripts/manage.sh migrate --from jekyll --source ./jekyll-site --site my-blog

# From WordPress (export XML)
bash scripts/manage.sh migrate --from wordpress --source export.xml --site my-blog
```

## Troubleshooting

### Issue: "hugo: command not found"

```bash
# Re-run install
bash scripts/install.sh

# Verify
hugo version
```

### Issue: Theme not rendering

```bash
# Ensure theme submodule is initialized
cd my-blog && git submodule update --init --recursive

# Or re-add theme
bash scripts/manage.sh theme --site my-blog --set PaperMod
```

### Issue: GitHub Pages deploy fails

**Check:**
1. `GITHUB_TOKEN` is set and has repo permissions
2. Repository exists: `gh repo view username/repo`
3. Branch is correct (usually `gh-pages` or `main`)

### Issue: Build errors

```bash
# Run with verbose output
bash scripts/manage.sh build --site my-blog --verbose

# Check for draft content
hugo --buildDrafts -s my-blog
```

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `git` (theme management, deployment)
- `hugo` (installed by `scripts/install.sh`)
- Optional: `gh` CLI (GitHub Pages deployment)
- Optional: `netlify` CLI (Netlify deployment)
