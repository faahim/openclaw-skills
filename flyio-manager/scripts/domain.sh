#!/bin/bash
# Manage custom domains and SSL certificates for Fly.io apps
# Usage: bash domain.sh --add DOMAIN | --check DOMAIN | --list [--app NAME]

set -euo pipefail

PREFIX="[flyio-manager]"
ACTION=""
DOMAIN=""
APP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --add) ACTION="add"; DOMAIN="$2"; shift 2 ;;
        --check) ACTION="check"; DOMAIN="$2"; shift 2 ;;
        --remove) ACTION="remove"; DOMAIN="$2"; shift 2 ;;
        --list) ACTION="list"; shift ;;
        --app) APP="$2"; shift 2 ;;
        *) echo "$PREFIX Unknown option: $1"; exit 1 ;;
    esac
done

if ! command -v fly &>/dev/null; then
    echo "$PREFIX flyctl not found. Run: bash scripts/install.sh"
    exit 1
fi

APP_FLAG=""
[[ -n "$APP" ]] && APP_FLAG="--app $APP"

case "$ACTION" in
    add)
        echo "$PREFIX Adding domain: $DOMAIN"
        fly certs create "$DOMAIN" $APP_FLAG
        echo ""
        echo "$PREFIX ✅ Domain added. Configure DNS:"
        echo ""
        # Get app name for CNAME target
        APP_NAME=${APP:-$(grep '^app' fly.toml 2>/dev/null | sed 's/app *= *"\?\([^"]*\)"\?/\1/')}
        if [[ "$DOMAIN" =~ ^\. ]] || [[ $(echo "$DOMAIN" | tr -cd '.' | wc -c) -le 1 ]]; then
            echo "  For apex domain ($DOMAIN):"
            echo "    A     $DOMAIN → $(fly ips list $APP_FLAG 2>/dev/null | grep v4 | awk '{print $2}' || echo '<your-fly-ipv4>')"
            echo "    AAAA  $DOMAIN → $(fly ips list $APP_FLAG 2>/dev/null | grep v6 | awk '{print $2}' || echo '<your-fly-ipv6>')"
        else
            echo "  CNAME  $DOMAIN → ${APP_NAME}.fly.dev"
        fi
        echo ""
        echo "$PREFIX SSL certificate will be auto-provisioned once DNS propagates."
        ;;
    check)
        echo "$PREFIX Certificate status for $DOMAIN:"
        fly certs show "$DOMAIN" $APP_FLAG
        ;;
    remove)
        echo "$PREFIX Removing domain: $DOMAIN"
        fly certs delete "$DOMAIN" $APP_FLAG --yes
        echo "$PREFIX ✅ Domain removed"
        ;;
    list)
        echo "$PREFIX Configured domains:"
        fly certs list $APP_FLAG
        ;;
    *)
        echo "$PREFIX Usage:"
        echo "  bash domain.sh --add example.com [--app NAME]"
        echo "  bash domain.sh --check example.com [--app NAME]"
        echo "  bash domain.sh --remove example.com [--app NAME]"
        echo "  bash domain.sh --list [--app NAME]"
        exit 1
        ;;
esac
