#!/bin/bash
# Zola deployment helper — GitHub Pages, Netlify, Cloudflare Pages
set -euo pipefail

SITE="${1:?Usage: deploy.sh <site> <target>}"
TARGET="${2:?Targets: github-pages, netlify, cloudflare, vercel}"

ensure_zola() {
  command -v zola &>/dev/null || { echo "❌ Zola not found. Run: bash scripts/install.sh"; exit 1; }
}

deploy_github_pages() {
  local site="$1"
  local workflow_dir="$site/.github/workflows"
  mkdir -p "$workflow_dir"

  cat > "$workflow_dir/deploy.yml" <<'YAML'
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true

      - name: Install Zola
        run: |
          ZOLA_VERSION=$(curl -sL https://api.github.com/repos/getzola/zola/releases/latest | grep tag_name | sed 's/.*"v\(.*\)".*/\1/')
          curl -sL "https://github.com/getzola/zola/releases/download/v${ZOLA_VERSION}/zola-v${ZOLA_VERSION}-x86_64-unknown-linux-gnu.tar.gz" | tar xz
          sudo mv zola /usr/local/bin/

      - name: Build
        run: zola build

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./public

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
YAML

  echo "✅ GitHub Pages workflow created: $workflow_dir/deploy.yml"
  echo ""
  echo "Next steps:"
  echo "  1. Push to GitHub: git add . && git commit -m 'Add Zola site' && git push"
  echo "  2. Go to repo Settings → Pages → Source: GitHub Actions"
  echo "  3. Site deploys automatically on push to main"
}

deploy_netlify() {
  local site="$1"

  cat > "$site/netlify.toml" <<TOML
[build]
  command = "zola build"
  publish = "public"

[build.environment]
  ZOLA_VERSION = "0.19.2"

[context.deploy-preview]
  command = "zola build --base-url \$DEPLOY_PRIME_URL"
TOML

  echo "✅ Netlify config created: $site/netlify.toml"
  echo ""
  echo "Next steps:"
  echo "  1. Push to GitHub/GitLab"
  echo "  2. Connect repo on https://app.netlify.com"
  echo "  3. Or drag-and-drop '$site/public/' after running: cd $site && zola build"
}

deploy_cloudflare() {
  local site="$1"

  echo "✅ Cloudflare Pages deployment ready"
  echo ""
  echo "Next steps:"
  echo "  1. Push to GitHub/GitLab"
  echo "  2. Go to https://dash.cloudflare.com → Pages → Create project"
  echo "  3. Connect your repository"
  echo "  4. Build settings:"
  echo "     - Framework preset: None"
  echo "     - Build command: zola build"
  echo "     - Build output directory: public"
  echo "     - Environment variable: ZOLA_VERSION = 0.19.2"
}

deploy_vercel() {
  local site="$1"

  cat > "$site/vercel.json" <<JSON
{
  "buildCommand": "zola build",
  "outputDirectory": "public",
  "installCommand": "curl -sL https://github.com/getzola/zola/releases/latest/download/zola-v0.19.2-x86_64-unknown-linux-gnu.tar.gz | tar xz && mv zola /usr/local/bin/"
}
JSON

  echo "✅ Vercel config created: $site/vercel.json"
  echo ""
  echo "Next steps:"
  echo "  1. Push to GitHub"
  echo "  2. Import project on https://vercel.com/new"
}

ensure_zola

case "$TARGET" in
  github-pages|gh-pages) deploy_github_pages "$SITE" ;;
  netlify) deploy_netlify "$SITE" ;;
  cloudflare|cf-pages) deploy_cloudflare "$SITE" ;;
  vercel) deploy_vercel "$SITE" ;;
  *) echo "❌ Unknown target: $TARGET"; echo "Targets: github-pages, netlify, cloudflare, vercel"; exit 1 ;;
esac
