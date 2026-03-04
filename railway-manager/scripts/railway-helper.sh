#!/bin/bash
# Railway Helper — common operations wrapped for quick access
set -euo pipefail

CMD="${1:-help}"
shift 2>/dev/null || true

check_railway() {
  if ! command -v railway &>/dev/null; then
    echo "❌ Railway CLI not found. Run: bash scripts/install.sh"
    exit 1
  fi
}

check_token() {
  if [ -z "${RAILWAY_TOKEN:-}" ]; then
    echo "⚠️  No RAILWAY_TOKEN set. Run 'railway login' for interactive auth"
    echo "   or: export RAILWAY_TOKEN='your-token'"
  fi
}

case "$CMD" in
  status)
    check_railway
    echo "🚂 Railway Status"
    echo "=================="
    railway status 2>/dev/null || echo "Not linked to a project. Run: railway link"
    ;;

  deploy)
    check_railway
    echo "🚀 Deploying..."
    railway up --detach "$@"
    echo "✅ Deployment triggered"
    ;;

  logs)
    check_railway
    railway logs --follow "$@"
    ;;

  env)
    check_railway
    echo "🔐 Environment Variables"
    echo "========================"
    railway variables "$@"
    ;;

  env-set)
    check_railway
    if [ $# -lt 1 ]; then
      echo "Usage: railway-helper.sh env-set KEY=value [KEY2=value2 ...]"
      exit 1
    fi
    railway variables set "$@"
    echo "✅ Variables set"
    ;;

  domains)
    check_railway
    echo "🌐 Domains"
    echo "=========="
    railway domain "$@"
    ;;

  projects)
    check_railway
    check_token
    echo "📋 Projects"
    echo "==========="
    curl -s -H "Authorization: Bearer $RAILWAY_TOKEN" \
      -H "Content-Type: application/json" \
      https://backboard.railway.app/graphql \
      -d '{"query":"{ me { projects { edges { node { name id updatedAt } } } } }"}' \
      | jq -r '.data.me.projects.edges[] | .node | "\(.name) (\(.id)) — updated \(.updatedAt)"' 2>/dev/null \
      || echo "Could not fetch projects. Check RAILWAY_TOKEN."
    ;;

  init)
    check_railway
    echo "🆕 Initializing Railway project..."
    railway init "$@"
    ;;

  link)
    check_railway
    echo "🔗 Linking to Railway project..."
    railway link "$@"
    ;;

  add-db)
    check_railway
    DB_TYPE="${1:-postgresql}"
    echo "🗄️  Adding $DB_TYPE database..."
    railway add --plugin "$DB_TYPE"
    echo "✅ Database added. Check variables with: railway variables"
    ;;

  help|*)
    echo "🚂 Railway Helper"
    echo ""
    echo "Usage: bash scripts/railway-helper.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  status     — Show current project/service status"
    echo "  deploy     — Deploy current directory"
    echo "  logs       — Tail production logs"
    echo "  env        — List environment variables"
    echo "  env-set    — Set environment variables (KEY=value)"
    echo "  domains    — List/manage custom domains"
    echo "  projects   — List all Railway projects (needs RAILWAY_TOKEN)"
    echo "  init       — Initialize a new project"
    echo "  link       — Link to an existing project"
    echo "  add-db     — Add a database plugin (postgresql/redis/mysql)"
    echo "  help       — Show this help"
    ;;
esac
