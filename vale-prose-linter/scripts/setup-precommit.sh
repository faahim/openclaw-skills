#!/bin/bash
# Set up git pre-commit hook for Vale prose linting
set -euo pipefail

if [[ ! -d .git ]]; then
  echo "❌ Not in a git repository. Run from project root."
  exit 1
fi

if ! command -v vale &>/dev/null; then
  echo "❌ Vale not installed. Run: bash scripts/install.sh"
  exit 1
fi

HOOK_FILE=".git/hooks/pre-commit"

# Backup existing hook
if [[ -f "$HOOK_FILE" ]]; then
  cp "$HOOK_FILE" "${HOOK_FILE}.bak"
  echo "📋 Backed up existing pre-commit hook to ${HOOK_FILE}.bak"
fi

cat > "$HOOK_FILE" << 'HOOK'
#!/bin/bash
# Vale prose lint pre-commit hook
# Lints staged .md files before allowing commit

STAGED_MD=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.md$' || true)

if [[ -z "$STAGED_MD" ]]; then
  exit 0  # No markdown files staged
fi

echo "📝 Linting staged markdown files..."

ERRORS=0
while IFS= read -r file; do
  if [[ -f "$file" ]]; then
    OUTPUT=$(vale --minAlertLevel=error "$file" 2>&1)
    if [[ $? -ne 0 ]]; then
      echo "$OUTPUT"
      ERRORS=$((ERRORS + 1))
    fi
  fi
done <<< "$STAGED_MD"

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "❌ Prose lint errors found in $ERRORS file(s)."
  echo "   Fix errors or commit with --no-verify to skip."
  exit 1
fi

echo "✅ Prose lint passed."
HOOK

chmod +x "$HOOK_FILE"
echo "✅ Pre-commit hook installed at $HOOK_FILE"
echo "   Staged .md files will be linted before each commit."
echo "   Bypass with: git commit --no-verify"
