#!/bin/bash
# Static Site Deployer — Deploy to Cloudflare Pages, Netlify, or Vercel
set -e

# Defaults
PROVIDER=""
DIR=""
PROJECT=""
SITE=""
BRANCH=""
PROD=false
CONFIG=""

usage() {
  cat <<EOF
Usage: bash scripts/deploy.sh --provider <cf|netlify|vercel> --dir <path> [options]

Options:
  --provider, -p   Provider: cloudflare (cf), netlify, vercel
  --dir, -d        Directory to deploy (e.g., ./dist, ./build, ./out)
  --project        Project name (Cloudflare Pages)
  --site           Site name (Netlify)
  --branch, -b     Branch name (affects preview vs production on CF)
  --prod           Deploy to production (Netlify/Vercel)
  --config         Path to deploy.yaml config file

Examples:
  bash scripts/deploy.sh --provider cloudflare --dir ./dist --project my-site
  bash scripts/deploy.sh --provider netlify --dir ./build --site my-app --prod
  bash scripts/deploy.sh --provider vercel --dir ./out --prod
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --provider|-p) PROVIDER="$2"; shift 2 ;;
    --dir|-d) DIR="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --site) SITE="$2"; shift 2 ;;
    --branch|-b) BRANCH="$2"; shift 2 ;;
    --prod) PROD=true; shift ;;
    --config) CONFIG="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Parse YAML config if provided (basic key: value parsing)
if [[ -n "$CONFIG" && -f "$CONFIG" ]]; then
  [[ -z "$PROVIDER" ]] && PROVIDER=$(grep -E '^provider:' "$CONFIG" | awk '{print $2}' | tr -d '"' || true)
  [[ -z "$DIR" ]] && DIR=$(grep -E '^directory:' "$CONFIG" | awk '{print $2}' | tr -d '"' || true)
  [[ -z "$PROJECT" ]] && PROJECT=$(grep -E '^project:' "$CONFIG" | awk '{print $2}' | tr -d '"' || true)
  [[ -z "$SITE" ]] && SITE=$(grep -E '^site:' "$CONFIG" | awk '{print $2}' | tr -d '"' || true)
  [[ -z "$BRANCH" ]] && BRANCH=$(grep -E '^branch:' "$CONFIG" | awk '{print $2}' | tr -d '"' || true)
fi

# Validate
[[ -z "$PROVIDER" ]] && echo "❌ --provider is required" && usage
[[ -z "$DIR" ]] && echo "❌ --dir is required" && usage

# Normalize provider name
case "$PROVIDER" in
  cloudflare|cf) PROVIDER="cloudflare" ;;
  netlify) PROVIDER="netlify" ;;
  vercel) PROVIDER="vercel" ;;
  *) echo "❌ Unknown provider: $PROVIDER (use cloudflare, netlify, or vercel)" && exit 1 ;;
esac

# Validate directory
if [[ ! -d "$DIR" ]]; then
  echo "❌ Directory not found: $DIR"
  echo "   Make sure you've built your site first (e.g., npm run build)"
  exit 1
fi

FILE_COUNT=$(find "$DIR" -type f | wc -l)
DIR_SIZE=$(du -sh "$DIR" 2>/dev/null | cut -f1)

if [[ "$FILE_COUNT" -eq 0 ]]; then
  echo "❌ Directory is empty: $DIR"
  exit 1
fi

echo "🚀 Deploying to ${PROVIDER^}..."
echo "   Directory: $DIR ($FILE_COUNT files, $DIR_SIZE)"

START_TIME=$(date +%s)

# ============ CLOUDFLARE PAGES ============
deploy_cloudflare() {
  local name="${PROJECT:-$(basename "$(pwd)")}"
  echo "   Project: $name"

  if ! command -v wrangler &>/dev/null; then
    echo "❌ wrangler not found. Install: bash scripts/install.sh cloudflare"
    exit 1
  fi

  local args=("pages" "deploy" "$DIR" "--project-name" "$name")
  [[ -n "$BRANCH" ]] && args+=("--branch" "$BRANCH")
  [[ "$BRANCH" == "main" || "$BRANCH" == "master" || "$PROD" == true ]] && args+=("--branch" "main")

  echo "   Branch: ${BRANCH:-main} ($( [[ "$PROD" == true || "$BRANCH" == "main" || -z "$BRANCH" ]] && echo 'production' || echo 'preview'))"
  echo ""

  npx wrangler "${args[@]}" 2>&1 | tee /tmp/ssd-deploy-output.txt

  local url
  url=$(grep -oP 'https://[^\s]+\.pages\.dev' /tmp/ssd-deploy-output.txt | head -1 || true)
  rm -f /tmp/ssd-deploy-output.txt

  local elapsed=$(( $(date +%s) - START_TIME ))
  echo ""
  echo "✅ Deployed successfully!"
  [[ -n "$url" ]] && echo "   URL: $url"
  echo "   Time: ${elapsed}s"
}

# ============ NETLIFY ============
deploy_netlify() {
  local name="${SITE:-$(basename "$(pwd)")}"
  echo "   Site: $name"

  if ! command -v netlify &>/dev/null; then
    echo "❌ netlify-cli not found. Install: bash scripts/install.sh netlify"
    exit 1
  fi

  local args=("deploy" "--dir" "$DIR")
  [[ -n "$SITE" ]] && args+=("--site" "$SITE")
  [[ "$PROD" == true ]] && args+=("--prod")

  echo "   Production: $PROD"
  echo ""

  npx netlify "${args[@]}" 2>&1 | tee /tmp/ssd-deploy-output.txt

  local url
  url=$(grep -oP 'https://[^\s]+\.netlify\.app' /tmp/ssd-deploy-output.txt | head -1 || true)
  [[ -z "$url" ]] && url=$(grep -oP 'Website URL:\s+\Khttps://[^\s]+' /tmp/ssd-deploy-output.txt | head -1 || true)
  rm -f /tmp/ssd-deploy-output.txt

  local elapsed=$(( $(date +%s) - START_TIME ))
  echo ""
  echo "✅ Deployed successfully!"
  [[ -n "$url" ]] && echo "   URL: $url"
  echo "   Time: ${elapsed}s"
}

# ============ VERCEL ============
deploy_vercel() {
  echo "   Production: $PROD"

  if ! command -v vercel &>/dev/null; then
    echo "❌ vercel CLI not found. Install: bash scripts/install.sh vercel"
    exit 1
  fi

  local args=("deploy" "$DIR")
  [[ "$PROD" == true ]] && args+=("--prod")
  [[ -n "$VERCEL_TOKEN" ]] && args+=("--token" "$VERCEL_TOKEN")
  args+=("--yes")  # Skip confirmation prompts

  echo ""

  npx vercel "${args[@]}" 2>&1 | tee /tmp/ssd-deploy-output.txt

  local url
  url=$(grep -oP 'https://[^\s]+\.vercel\.app' /tmp/ssd-deploy-output.txt | head -1 || true)
  rm -f /tmp/ssd-deploy-output.txt

  local elapsed=$(( $(date +%s) - START_TIME ))
  echo ""
  echo "✅ Deployed successfully!"
  [[ -n "$url" ]] && echo "   URL: $url"
  echo "   Time: ${elapsed}s"
}

# Dispatch
case "$PROVIDER" in
  cloudflare) deploy_cloudflare ;;
  netlify) deploy_netlify ;;
  vercel) deploy_vercel ;;
esac
