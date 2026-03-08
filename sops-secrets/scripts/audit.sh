#!/bin/bash
# Audit project for secret management issues
set -euo pipefail

PROJECT_DIR="${1:-.}"
ISSUES=0

echo "🔍 Auditing secrets in $PROJECT_DIR..."
echo ""

# Check .sops.yaml exists
if [ ! -f "$PROJECT_DIR/.sops.yaml" ]; then
  echo "❌ CRITICAL: No .sops.yaml found — secrets are not being encrypted!"
  ISSUES=$((ISSUES + 1))
fi

# Check for unencrypted files that look like secrets
echo "📋 Checking for unencrypted secret files..."
for pattern in "secret" "credential" "password" "apikey" "token"; do
  find "$PROJECT_DIR" -type f \( -name "*${pattern}*" -o -name "*.env" -o -name "*.env.*" \) \
    ! -path "*/.git/*" ! -path "*/node_modules/*" ! -name ".sops.yaml" 2>/dev/null | while read -r file; do
    if ! grep -q "ENC\[AES256_GCM" "$file" 2>/dev/null; then
      if grep -qiE "(password|secret|key|token)\s*[:=]" "$file" 2>/dev/null; then
        echo "  ⚠️  Potentially unencrypted: $file"
        ISSUES=$((ISSUES + 1))
      fi
    fi
  done
done

# Check for files committed to git that shouldn't be
if [ -d "$PROJECT_DIR/.git" ]; then
  echo ""
  echo "📋 Checking git for leaked secrets..."
  
  # Check if .env files are in .gitignore
  if [ -f "$PROJECT_DIR/.gitignore" ]; then
    if ! grep -q "\.env" "$PROJECT_DIR/.gitignore" 2>/dev/null; then
      echo "  ⚠️  .env files not in .gitignore"
      ISSUES=$((ISSUES + 1))
    fi
  else
    echo "  ⚠️  No .gitignore file found"
    ISSUES=$((ISSUES + 1))
  fi
fi

# List encrypted files
echo ""
echo "📋 Encrypted files found:"
find "$PROJECT_DIR" -type f \( -name "*.yaml" -o -name "*.json" -o -name "*.env" -o -name "*.env.*" \) \
  ! -name ".sops.yaml" ! -path "*/.git/*" ! -path "*/node_modules/*" 2>/dev/null | while read -r file; do
  if grep -q "ENC\[AES256_GCM" "$file" 2>/dev/null; then
    echo "  ✅ $file"
  fi
done

# Summary
echo ""
if [ $ISSUES -eq 0 ]; then
  echo "✅ Audit passed — no issues found."
else
  echo "⚠️  Found $ISSUES potential issue(s). Review above."
fi
