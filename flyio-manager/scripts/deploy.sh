#!/bin/bash
# Deploy application to Fly.io
# Usage: bash deploy.sh [--init] [--app NAME] [--strategy canary|rolling] [--rollback] [--wait-timeout SEC]

set -euo pipefail

PREFIX="[flyio-manager]"
APP=""
INIT=false
STRATEGY=""
ROLLBACK=false
WAIT_TIMEOUT=120

while [[ $# -gt 0 ]]; do
    case $1 in
        --init) INIT=true; shift ;;
        --app) APP="$2"; shift 2 ;;
        --strategy) STRATEGY="$2"; shift 2 ;;
        --rollback) ROLLBACK=true; shift ;;
        --wait-timeout) WAIT_TIMEOUT="$2"; shift 2 ;;
        *) echo "$PREFIX Unknown option: $1"; exit 1 ;;
    esac
done

# Check flyctl
if ! command -v fly &>/dev/null; then
    echo "$PREFIX flyctl not found. Run: bash scripts/install.sh"
    exit 1
fi

# Check auth
if ! fly auth whoami &>/dev/null 2>&1; then
    echo "$PREFIX Not authenticated. Run: fly auth login"
    exit 1
fi

APP_FLAG=""
[[ -n "$APP" ]] && APP_FLAG="--app $APP"

# Rollback
if $ROLLBACK; then
    echo "$PREFIX Rolling back to previous release..."
    RELEASES=$(fly releases $APP_FLAG --json 2>/dev/null)
    PREV=$(echo "$RELEASES" | jq -r '.[1].Version // empty')
    if [[ -z "$PREV" ]]; then
        echo "$PREFIX No previous release to rollback to"
        exit 1
    fi
    fly deploy $APP_FLAG --image-ref "$(echo "$RELEASES" | jq -r '.[1].ImageRef')"
    echo "$PREFIX ✅ Rolled back to version $PREV"
    exit 0
fi

# Initialize
if $INIT; then
    if [[ -f "fly.toml" ]]; then
        echo "$PREFIX fly.toml already exists. Delete it first to re-init."
        exit 1
    fi
    echo "$PREFIX Initializing new Fly.io app..."
    fly launch --no-deploy $APP_FLAG
    echo "$PREFIX ✅ App initialized. Edit fly.toml, then run: bash scripts/deploy.sh"
    exit 0
fi

# Check fly.toml
if [[ ! -f "fly.toml" ]] && [[ -z "$APP" ]]; then
    echo "$PREFIX No fly.toml found. Run with --init first, or specify --app NAME"
    exit 1
fi

# Build deploy command
DEPLOY_CMD="fly deploy $APP_FLAG --wait-timeout ${WAIT_TIMEOUT}"

case "$STRATEGY" in
    canary)
        DEPLOY_CMD="$DEPLOY_CMD --strategy canary"
        echo "$PREFIX Deploying with canary strategy..."
        ;;
    rolling)
        DEPLOY_CMD="$DEPLOY_CMD --strategy rolling"
        echo "$PREFIX Deploying with rolling strategy..."
        ;;
    *)
        echo "$PREFIX Deploying..."
        ;;
esac

# Deploy
eval $DEPLOY_CMD

# Get app URL
APP_NAME=${APP:-$(grep '^app' fly.toml 2>/dev/null | sed 's/app = "\(.*\)"/\1/' | tr -d '"' | tr -d ' ')}
echo ""
echo "$PREFIX ✅ Deployed: https://${APP_NAME}.fly.dev"
echo "$PREFIX    Status:  fly status $APP_FLAG"
echo "$PREFIX    Logs:    fly logs $APP_FLAG"
