#!/bin/bash
# Migrate a project from npm/yarn/pnpm to Bun
set -euo pipefail

PROJECT_DIR="${1:-.}"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "❌ Directory not found: $PROJECT_DIR"
  exit 1
fi

cd "$PROJECT_DIR"

if [[ ! -f "package.json" ]]; then
  echo "❌ No package.json found in $PROJECT_DIR"
  exit 1
fi

# Check bun is installed
if ! command -v bun &>/dev/null; then
  echo "❌ Bun not installed. Run: bash scripts/install.sh"
  exit 1
fi

echo "🔍 Analyzing project: $(basename "$PWD")"
echo ""

# Detect current package manager
PM="unknown"
if [[ -f "pnpm-lock.yaml" ]]; then
  PM="pnpm"
  LOCKFILE="pnpm-lock.yaml"
elif [[ -f "yarn.lock" ]]; then
  PM="yarn"
  LOCKFILE="yarn.lock"
elif [[ -f "package-lock.json" ]]; then
  PM="npm"
  LOCKFILE="package-lock.json"
elif [[ -f "bun.lockb" ]]; then
  echo "✅ Project already uses Bun!"
  exit 0
else
  PM="none"
  LOCKFILE=""
fi

echo "📦 Detected package manager: $PM"

# Count dependencies
DEPS=$(jq -r '.dependencies // {} | length' package.json 2>/dev/null || echo "?")
DEV_DEPS=$(jq -r '.devDependencies // {} | length' package.json 2>/dev/null || echo "?")
echo "📊 Dependencies: $DEPS production, $DEV_DEPS development"
echo ""

# Check for known incompatible packages
echo "🔍 Checking compatibility..."
WARNINGS=()

check_pkg() {
  if jq -e ".dependencies.\"$1\" // .devDependencies.\"$1\"" package.json &>/dev/null; then
    WARNINGS+=("   ⚠️  $1 → $2")
  fi
}

check_pkg "node-sass" "Replace with 'sass' (dart-sass)"
check_pkg "node-gyp" "May need native build tools"
check_pkg "fsevents" "macOS only — usually optional"
check_pkg "canvas" "Native addon — check bun compatibility"
check_pkg "better-sqlite3" "Use bun:sqlite instead (built-in)"

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo "⚠️  Potential compatibility issues:"
  for w in "${WARNINGS[@]}"; do
    echo "$w"
  done
  echo ""
fi

# Confirm migration
echo "🔄 Migration plan:"
if [[ -n "$LOCKFILE" ]]; then
  echo "   1. Remove $LOCKFILE"
fi
echo "   2. Remove node_modules/"
echo "   3. Run 'bun install'"
echo "   4. Test build (if build script exists)"
echo ""

read -p "Proceed? [Y/n] " -n 1 -r REPLY
echo ""
REPLY=${REPLY:-Y}

if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

# Execute migration
START_TIME=$(date +%s)

if [[ -n "$LOCKFILE" ]]; then
  echo "🗑️  Removing $LOCKFILE"
  rm -f "$LOCKFILE"
fi

if [[ -d "node_modules" ]]; then
  echo "🗑️  Removing node_modules/"
  rm -rf node_modules
fi

echo "📦 Running bun install..."
INSTALL_START=$(date +%s%N)
bun install 2>&1
INSTALL_END=$(date +%s%N)
INSTALL_MS=$(( (INSTALL_END - INSTALL_START) / 1000000 ))

echo ""
echo "⚡ Install completed in ${INSTALL_MS}ms"

# Test build
if jq -e '.scripts.build' package.json &>/dev/null; then
  echo ""
  echo "🔨 Testing build..."
  if bun run build 2>&1; then
    echo "✅ Build succeeded!"
  else
    echo "⚠️  Build failed — may need manual fixes"
  fi
fi

END_TIME=$(date +%s)
TOTAL=$((END_TIME - START_TIME))

echo ""
echo "════════════════════════════════════"
echo "✅ Migration complete!"
echo "   From: $PM → Bun $(bun --version)"
echo "   Time: ${TOTAL}s total"
echo "   Install: ${INSTALL_MS}ms"
echo "════════════════════════════════════"
echo ""
echo "Next steps:"
echo "   bun run dev          # Start dev server"
echo "   bun test             # Run tests"
echo "   bun run build        # Build for production"
