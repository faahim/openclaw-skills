#!/bin/bash
# Static Site Deployer — Install provider CLIs
set -e

PROVIDER="${1:-}"

usage() {
  echo "Usage: bash scripts/install.sh <provider>"
  echo ""
  echo "Providers:"
  echo "  cloudflare   Install wrangler CLI for Cloudflare Pages"
  echo "  netlify      Install netlify-cli for Netlify"
  echo "  vercel       Install vercel CLI for Vercel"
  echo "  all          Install all provider CLIs"
  exit 1
}

install_cloudflare() {
  echo "📦 Installing wrangler (Cloudflare Pages CLI)..."
  if command -v wrangler &>/dev/null; then
    echo "  ✅ wrangler already installed: $(wrangler --version 2>/dev/null || echo 'unknown')"
    return 0
  fi
  npm install -g wrangler
  echo "  ✅ wrangler installed: $(wrangler --version 2>/dev/null || echo 'installed')"
}

install_netlify() {
  echo "📦 Installing netlify-cli..."
  if command -v netlify &>/dev/null; then
    echo "  ✅ netlify-cli already installed: $(netlify --version 2>/dev/null || echo 'unknown')"
    return 0
  fi
  npm install -g netlify-cli
  echo "  ✅ netlify-cli installed: $(netlify --version 2>/dev/null || echo 'installed')"
}

install_vercel() {
  echo "📦 Installing vercel CLI..."
  if command -v vercel &>/dev/null; then
    echo "  ✅ vercel already installed: $(vercel --version 2>/dev/null || echo 'unknown')"
    return 0
  fi
  npm install -g vercel
  echo "  ✅ vercel installed: $(vercel --version 2>/dev/null || echo 'installed')"
}

check_node() {
  if ! command -v node &>/dev/null; then
    echo "❌ Node.js is required. Install it first:"
    echo "   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
    echo "   sudo apt-get install -y nodejs"
    exit 1
  fi
  if ! command -v npm &>/dev/null; then
    echo "❌ npm is required. It should come with Node.js."
    exit 1
  fi
  echo "✅ Node.js $(node --version) + npm $(npm --version)"
}

case "$PROVIDER" in
  cloudflare|cf)
    check_node
    install_cloudflare
    ;;
  netlify)
    check_node
    install_netlify
    ;;
  vercel)
    check_node
    install_vercel
    ;;
  all)
    check_node
    install_cloudflare
    install_netlify
    install_vercel
    ;;
  *)
    usage
    ;;
esac

echo ""
echo "🎉 Done! Next steps:"
echo "  1. Authenticate: npx wrangler login / npx netlify login / npx vercel login"
echo "  2. Deploy: bash scripts/deploy.sh --provider $PROVIDER --dir ./dist --project my-site"
