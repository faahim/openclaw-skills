#!/bin/bash
# Scale Fly.io app machines
# Usage: bash scale.sh [--count N] [--size SIZE] [--memory MB] [--region REGIONS] [--app NAME]

set -euo pipefail

PREFIX="[flyio-manager]"
APP=""
COUNT=""
SIZE=""
MEMORY=""
REGIONS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --count) COUNT="$2"; shift 2 ;;
        --size) SIZE="$2"; shift 2 ;;
        --memory) MEMORY="$2"; shift 2 ;;
        --region) REGIONS="$2"; shift 2 ;;
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

# Show current state
echo "$PREFIX Current machines:"
fly machine list $APP_FLAG 2>/dev/null || fly status $APP_FLAG

# Scale count
if [[ -n "$COUNT" ]]; then
    REGION_FLAG=""
    if [[ -n "$REGIONS" ]]; then
        # Scale to specific regions
        IFS=',' read -ra REGION_ARRAY <<< "$REGIONS"
        for region in "${REGION_ARRAY[@]}"; do
            echo "$PREFIX Scaling to $COUNT machine(s) in $region..."
            fly scale count "$COUNT" --region "$region" $APP_FLAG --yes
        done
    else
        echo "$PREFIX Scaling to $COUNT machine(s)..."
        fly scale count "$COUNT" $APP_FLAG --yes
    fi
fi

# Scale size
if [[ -n "$SIZE" ]]; then
    echo "$PREFIX Changing machine size to $SIZE..."
    fly scale vm "$SIZE" $APP_FLAG
fi

# Scale memory
if [[ -n "$MEMORY" ]]; then
    echo "$PREFIX Setting memory to ${MEMORY}MB..."
    fly scale memory "$MEMORY" $APP_FLAG
fi

echo ""
echo "$PREFIX ✅ Scaling complete"
echo "$PREFIX Current state:"
fly scale show $APP_FLAG 2>/dev/null || fly status $APP_FLAG
