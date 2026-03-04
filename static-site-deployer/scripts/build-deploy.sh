#!/bin/bash
# Static Site Deployer — Build + Deploy in one step
set -e

BUILD_CMD=""
GIT_PULL=false
PASSTHROUGH_ARGS=()

# Extract build-specific args, pass the rest to deploy.sh
while [[ $# -gt 0 ]]; do
  case $1 in
    --build-cmd) BUILD_CMD="$2"; shift 2 ;;
    --git-pull) GIT_PULL=true; shift ;;
    *) PASSTHROUGH_ARGS+=("$1"); shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step 1: Git pull (optional)
if [[ "$GIT_PULL" == true ]]; then
  echo "📥 Pulling latest from git..."
  git pull --rebase 2>&1 || { echo "⚠️  Git pull failed, continuing with current state"; }
  echo ""
fi

# Step 2: Build (optional)
if [[ -n "$BUILD_CMD" ]]; then
  echo "🔨 Building site: $BUILD_CMD"
  eval "$BUILD_CMD"
  echo ""
fi

# Step 3: Deploy
bash "$SCRIPT_DIR/deploy.sh" "${PASSTHROUGH_ARGS[@]}"
