#!/bin/bash
# Fly.io Manager — Status Check
# Shows overview of all Fly.io apps and their status

set -euo pipefail

APP_NAME="${1:-}"

if [[ -z "$APP_NAME" ]]; then
    echo "📊 Fly.io Account Overview"
    echo "=========================="
    echo ""

    # List all apps
    echo "📱 Apps:"
    fly apps list 2>/dev/null || { echo "❌ Not authenticated. Run: fly auth login"; exit 1; }

    echo ""

    # Show organizations
    echo "🏢 Organizations:"
    fly orgs list 2>/dev/null

    echo ""

    # Show current auth
    echo "👤 Authenticated as:"
    fly auth whoami 2>/dev/null
else
    echo "📊 App Status: $APP_NAME"
    echo "=========================="
    echo ""

    # App status
    fly status -a "$APP_NAME"

    echo ""
    echo "🌐 IPs:"
    fly ips list -a "$APP_NAME" 2>/dev/null

    echo ""
    echo "📦 Machines:"
    fly machine list -a "$APP_NAME" 2>/dev/null

    echo ""
    echo "💾 Volumes:"
    fly volumes list -a "$APP_NAME" 2>/dev/null

    echo ""
    echo "🔐 Secrets:"
    fly secrets list -a "$APP_NAME" 2>/dev/null

    echo ""
    echo "🌍 Regions:"
    fly regions list -a "$APP_NAME" 2>/dev/null

    echo ""
    echo "📜 Recent Logs:"
    fly logs -a "$APP_NAME" --no-tail 2>/dev/null | tail -20
fi
