#!/bin/bash
# Static Site Deployer — List deployments
set -e

PROVIDER=""
PROJECT=""
SITE=""
LIMIT=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --provider|-p) PROVIDER="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --site) SITE="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

[[ -z "$PROVIDER" ]] && echo "❌ --provider required" && exit 1

case "$PROVIDER" in
  cloudflare|cf)
    [[ -z "$PROJECT" ]] && echo "❌ --project required" && exit 1
    echo "📋 Recent deployments for '$PROJECT' (Cloudflare Pages):"
    npx wrangler pages deployment list --project-name "$PROJECT" 2>/dev/null | head -n "$((LIMIT + 2))"
    ;;
  netlify)
    SITE_FLAG=""
    [[ -n "$SITE" ]] && SITE_FLAG="--site $SITE"
    echo "📋 Recent deployments (Netlify):"
    npx netlify deploys:list $SITE_FLAG 2>/dev/null | head -n "$((LIMIT + 2))"
    ;;
  vercel)
    echo "📋 Recent deployments (Vercel):"
    npx vercel ls 2>/dev/null | head -n "$((LIMIT + 2))"
    ;;
  *)
    echo "❌ Unknown provider: $PROVIDER"
    exit 1
    ;;
esac
