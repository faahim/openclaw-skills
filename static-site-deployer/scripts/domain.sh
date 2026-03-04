#!/bin/bash
# Static Site Deployer — Custom domain management
set -e

PROVIDER=""
PROJECT=""
SITE=""
DOMAIN=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --provider|-p) PROVIDER="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --site) SITE="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

[[ -z "$PROVIDER" ]] && echo "❌ --provider required" && exit 1
[[ -z "$DOMAIN" ]] && echo "❌ --domain required" && exit 1

case "$PROVIDER" in
  cloudflare|cf)
    [[ -z "$PROJECT" ]] && echo "❌ --project required for Cloudflare" && exit 1
    echo "🌐 Adding custom domain to Cloudflare Pages..."
    echo ""
    echo "Cloudflare Pages custom domains must be added via the dashboard or API:"
    echo ""
    echo "  1. Go to: https://dash.cloudflare.com → Pages → $PROJECT → Custom domains"
    echo "  2. Click 'Set up a custom domain'"
    echo "  3. Enter: $DOMAIN"
    echo "  4. Follow DNS verification steps"
    echo ""
    echo "Or via API:"
    echo "  curl -X POST 'https://api.cloudflare.com/client/v4/accounts/\$CLOUDFLARE_ACCOUNT_ID/pages/projects/$PROJECT/domains' \\"
    echo "    -H 'Authorization: Bearer \$CLOUDFLARE_API_TOKEN' \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"name\": \"$DOMAIN\"}'"
    ;;
  netlify)
    [[ -z "$SITE" ]] && echo "❌ --site required for Netlify" && exit 1
    echo "🌐 Adding custom domain to Netlify..."
    npx netlify domains:add "$DOMAIN" --site "$SITE" 2>&1 || true
    echo ""
    echo "✅ Domain added. Configure DNS:"
    echo "   CNAME $DOMAIN → $SITE.netlify.app"
    echo "   Or use Netlify DNS for automatic SSL"
    ;;
  vercel)
    echo "🌐 Adding custom domain to Vercel..."
    npx vercel domains add "$DOMAIN" 2>&1 || true
    echo ""
    echo "✅ Domain added. Configure DNS:"
    echo "   A record → 76.76.21.21"
    echo "   Or CNAME → cname.vercel-dns.com"
    ;;
  *)
    echo "❌ Unknown provider: $PROVIDER"
    exit 1
    ;;
esac
