#!/bin/bash
# Fly.io Manager — Deploy Script
# Deploy an app with configurable options

set -euo pipefail

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -a, --app NAME        App name (or set FLY_APP)"
    echo "  -r, --region REGION   Primary region (default: sjc)"
    echo "  -d, --dockerfile FILE Dockerfile path (default: Dockerfile)"
    echo "  -t, --timeout SECS    Wait timeout (default: 300)"
    echo "  -s, --strategy STR    Deploy strategy: immediate|bluegreen|rolling|canary"
    echo "  --no-cache            Build without cache"
    echo "  --init                Initialize new app (fly launch)"
    echo "  -h, --help            Show this help"
    exit 0
}

APP_NAME="${FLY_APP:-}"
REGION="sjc"
DOCKERFILE=""
TIMEOUT=300
STRATEGY=""
NO_CACHE=""
INIT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--app) APP_NAME="$2"; shift 2 ;;
        -r|--region) REGION="$2"; shift 2 ;;
        -d|--dockerfile) DOCKERFILE="$2"; shift 2 ;;
        -t|--timeout) TIMEOUT="$2"; shift 2 ;;
        -s|--strategy) STRATEGY="$2"; shift 2 ;;
        --no-cache) NO_CACHE="--no-cache"; shift ;;
        --init) INIT=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if $INIT; then
    echo "🚀 Initializing new Fly.io app..."
    CMD="fly launch --region $REGION"
    [[ -n "$APP_NAME" ]] && CMD="$CMD --name $APP_NAME"
    echo "Running: $CMD"
    eval "$CMD"
    exit 0
fi

if [[ -z "$APP_NAME" ]]; then
    # Try to detect from fly.toml
    if [[ -f "fly.toml" ]]; then
        APP_NAME=$(grep '^app' fly.toml | head -1 | sed 's/app = "\(.*\)"/\1/' | tr -d '"' | tr -d ' ')
    fi
    if [[ -z "$APP_NAME" ]]; then
        echo "❌ No app specified. Use -a flag or set FLY_APP or have fly.toml"
        exit 1
    fi
fi

echo "🚀 Deploying $APP_NAME..."
echo "   Region: $REGION"
echo "   Timeout: ${TIMEOUT}s"
[[ -n "$STRATEGY" ]] && echo "   Strategy: $STRATEGY"
echo ""

CMD="fly deploy -a $APP_NAME --wait-timeout $TIMEOUT"
[[ -n "$DOCKERFILE" ]] && CMD="$CMD --dockerfile $DOCKERFILE"
[[ -n "$STRATEGY" ]] && CMD="$CMD --strategy $STRATEGY"
[[ -n "$NO_CACHE" ]] && CMD="$CMD $NO_CACHE"

echo "Running: $CMD"
eval "$CMD"

echo ""
echo "✅ Deployment complete!"
fly status -a "$APP_NAME"
