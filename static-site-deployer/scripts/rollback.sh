#!/bin/bash
# Static Site Deployer — Rollback to previous deployment
set -e

PROVIDER=""
PROJECT=""
SITE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --provider|-p) PROVIDER="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --site) SITE="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

[[ -z "$PROVIDER" ]] && echo "❌ --provider required" && exit 1

case "$PROVIDER" in
  cloudflare|cf)
    echo "⚠️  Cloudflare Pages rollback:"
    echo "   Use the dashboard: https://dash.cloudflare.com → Pages → ${PROJECT:-your-project} → Deployments"
    echo "   Click the ⋯ menu on a previous deployment → 'Rollback to this deploy'"
    echo ""
    echo "   Or re-deploy the previous version's directory."
    ;;
  netlify)
    SITE_FLAG=""
    [[ -n "$SITE" ]] && SITE_FLAG="--site $SITE"
    echo "🔄 Rolling back Netlify to previous production deploy..."
    # Get the second-most-recent production deploy
    DEPLOY_ID=$(npx netlify api listSiteDeploys --data "{}" $SITE_FLAG 2>/dev/null | \
      jq -r '[.[] | select(.context == "production")] | .[1].id // empty' 2>/dev/null || true)
    if [[ -n "$DEPLOY_ID" ]]; then
      npx netlify api restoreSiteDeploy --data "{\"deploy_id\": \"$DEPLOY_ID\"}" $SITE_FLAG
      echo "✅ Rolled back to deploy: $DEPLOY_ID"
    else
      echo "❌ Could not find previous deploy. Use 'bash scripts/list.sh --provider netlify' to find a deploy ID."
    fi
    ;;
  vercel)
    echo "🔄 Rolling back Vercel to previous deployment..."
    echo "   Use: npx vercel rollback"
    npx vercel rollback 2>&1 || echo "   If that fails, use 'npx vercel promote <deployment-url>' with a specific URL."
    ;;
  *)
    echo "❌ Unknown provider: $PROVIDER"
    exit 1
    ;;
esac
