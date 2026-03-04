#!/bin/bash
# Static Site Deployer — Manage environment variables
set -e

PROVIDER=""
PROJECT=""
SITE=""
SET_VAR=""
LIST=false
DELETE_VAR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --provider|-p) PROVIDER="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --site) SITE="$2"; shift 2 ;;
    --set) SET_VAR="$2"; shift 2 ;;
    --delete) DELETE_VAR="$2"; shift 2 ;;
    --list) LIST=true; shift ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

[[ -z "$PROVIDER" ]] && echo "❌ --provider required" && exit 1

case "$PROVIDER" in
  cloudflare|cf)
    [[ -z "$PROJECT" ]] && echo "❌ --project required for Cloudflare" && exit 1
    if [[ -n "$SET_VAR" ]]; then
      KEY="${SET_VAR%%=*}"
      VALUE="${SET_VAR#*=}"
      echo "Setting $KEY on Cloudflare Pages project '$PROJECT'..."
      echo "$VALUE" | npx wrangler pages secret put "$KEY" --project-name "$PROJECT"
      echo "✅ Set $KEY"
    elif [[ "$LIST" == true ]]; then
      echo "📋 Cloudflare Pages secrets (names only — values are hidden):"
      npx wrangler pages secret list --project-name "$PROJECT" 2>/dev/null || echo "  (use wrangler dashboard to view)"
    fi
    ;;
  netlify)
    SITE_FLAG=""
    [[ -n "$SITE" ]] && SITE_FLAG="--site $SITE"
    if [[ -n "$SET_VAR" ]]; then
      KEY="${SET_VAR%%=*}"
      VALUE="${SET_VAR#*=}"
      echo "Setting $KEY on Netlify site..."
      npx netlify env:set "$KEY" "$VALUE" $SITE_FLAG
      echo "✅ Set $KEY"
    elif [[ "$LIST" == true ]]; then
      npx netlify env:list $SITE_FLAG
    elif [[ -n "$DELETE_VAR" ]]; then
      npx netlify env:unset "$DELETE_VAR" $SITE_FLAG
      echo "✅ Deleted $DELETE_VAR"
    fi
    ;;
  vercel)
    if [[ -n "$SET_VAR" ]]; then
      KEY="${SET_VAR%%=*}"
      VALUE="${SET_VAR#*=}"
      echo "Setting $KEY on Vercel..."
      echo "$VALUE" | npx vercel env add "$KEY" production
      echo "✅ Set $KEY"
    elif [[ "$LIST" == true ]]; then
      npx vercel env ls
    elif [[ -n "$DELETE_VAR" ]]; then
      npx vercel env rm "$DELETE_VAR" production --yes
      echo "✅ Deleted $DELETE_VAR"
    fi
    ;;
  *)
    echo "❌ Unknown provider: $PROVIDER"
    exit 1
    ;;
esac
