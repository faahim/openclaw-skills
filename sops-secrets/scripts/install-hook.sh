#!/bin/bash
set -euo pipefail

# Install git pre-commit hook to prevent committing unencrypted secrets

PROJECT_DIR="${1:-.}"
HOOKS_DIR="$PROJECT_DIR/.git/hooks"

if [ ! -d "$PROJECT_DIR/.git" ]; then
  echo "❌ Not a git repository: $PROJECT_DIR"
  exit 1
fi

mkdir -p "$HOOKS_DIR"

cat > "$HOOKS_DIR/pre-commit" <<'HOOK'
#!/bin/bash
# SOPS pre-commit hook — blocks unencrypted secrets

ERRORS=0

# Check files matching secret patterns
for f in $(git diff --cached --name-only --diff-filter=ACM); do
  case "$f" in
    secrets/*|*.encrypted|*.secret.*)
      if ! head -20 "$f" | grep -q "sops:" 2>/dev/null; then
        echo "❌ BLOCKED: $f appears to contain unencrypted secrets!"
        echo "   Encrypt first: sops encrypt -i $f"
        ((ERRORS++))
      fi
      ;;
  esac

  # Check for common secret patterns in any file
  if git diff --cached --diff-filter=ACM -p "$f" | grep -qiE '(password|api_key|secret_key|private_key)\s*[:=]\s*["\x27]?[A-Za-z0-9]' 2>/dev/null; then
    if ! head -20 "$f" | grep -q "sops:" 2>/dev/null; then
      echo "⚠️  WARNING: $f may contain plaintext secrets"
    fi
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "🛑 Commit blocked: $ERRORS file(s) with unencrypted secrets"
  echo "   Encrypt them with SOPS before committing."
  exit 1
fi
HOOK

chmod +x "$HOOKS_DIR/pre-commit"
echo "✅ Pre-commit hook installed at $HOOKS_DIR/pre-commit"
echo "   Unencrypted secrets in secrets/ will be blocked."
