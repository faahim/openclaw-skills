#!/bin/bash
# Install ShellCheck as a git pre-commit hook
set -euo pipefail

REPO_DIR="${1:-.}"

if [[ ! -d "$REPO_DIR/.git" ]]; then
    echo "❌ Not a git repository: $REPO_DIR"
    exit 1
fi

HOOK_FILE="$REPO_DIR/.git/hooks/pre-commit"

if [[ -f "$HOOK_FILE" ]]; then
    if grep -q "shellcheck" "$HOOK_FILE"; then
        echo "✅ ShellCheck hook already installed in $REPO_DIR"
        exit 0
    fi
    echo "⚠️  Existing pre-commit hook found. Appending ShellCheck check."
    echo "" >> "$HOOK_FILE"
else
    echo "#!/bin/bash" > "$HOOK_FILE"
    chmod +x "$HOOK_FILE"
fi

cat >> "$HOOK_FILE" << 'HOOK'

# ShellCheck pre-commit hook
STAGED_SH=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(sh|bash|ksh)$' || true)

if [[ -n "$STAGED_SH" ]]; then
    echo "🔍 Running ShellCheck on staged shell scripts..."
    ERRORS=0
    while IFS= read -r file; do
        if ! shellcheck --severity=warning "$file"; then
            ERRORS=$((ERRORS + 1))
        fi
    done <<< "$STAGED_SH"

    if [[ $ERRORS -gt 0 ]]; then
        echo ""
        echo "❌ ShellCheck found issues in $ERRORS file(s). Fix before committing."
        echo "   To bypass: git commit --no-verify"
        exit 1
    fi
    echo "✅ ShellCheck passed!"
fi
HOOK

echo "✅ ShellCheck pre-commit hook installed in $REPO_DIR"
echo "   Staged .sh/.bash/.ksh files will be checked before each commit."
echo "   Bypass with: git commit --no-verify"
