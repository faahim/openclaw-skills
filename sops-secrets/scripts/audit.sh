#!/bin/bash
set -euo pipefail

# Audit SOPS encryption status in a project

PROJECT_DIR="${1:-.}"

echo "📊 SOPS Encryption Audit"
echo "========================"
echo "Project: $(cd "$PROJECT_DIR" && pwd)"
echo ""

TOTAL=0
ENCRYPTED=0
UNENCRYPTED=0
WARNINGS=()

printf "%-45s | %-12s | %-15s\n" "File" "Status" "Recipients"
printf "%-45s-+-%-12s-+-%-15s\n" "---------------------------------------------" "------------" "---------------"

find "$PROJECT_DIR" -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.env" -o -name "*.ini" \) \
  ! -path "*/.git/*" ! -path "*/node_modules/*" ! -name ".sops.yaml" | sort | while read -r f; do

  REL_PATH="${f#$PROJECT_DIR/}"
  ((TOTAL++)) || true

  if head -20 "$f" | grep -q "sops:" 2>/dev/null; then
    # Count recipients
    RECIPIENTS=$(grep -c "age1" "$f" 2>/dev/null || echo "?")
    printf "%-45s | %-12s | %-15s\n" "$REL_PATH" "🔒 encrypted" "${RECIPIENTS} key(s)"
    ((ENCRYPTED++)) || true

    if [ "$RECIPIENTS" = "1" ]; then
      echo "  ⚠️  Only 1 recipient — no backup key!" >&2
    fi
  else
    # Check if file contains potential secrets
    if grep -qiE '(password|secret|api.?key|token|private|credential)' "$f" 2>/dev/null; then
      printf "%-45s | %-12s | %-15s\n" "$REL_PATH" "⚠️ PLAINTEXT" "has secrets!"
      ((UNENCRYPTED++)) || true
    fi
  fi
done

echo ""
echo "Summary:"
echo "  🔒 Encrypted files found (check output above)"
echo "  ⚠️  Unencrypted files with potential secrets flagged"
echo ""

# Check .sops.yaml
if [ -f "$PROJECT_DIR/.sops.yaml" ]; then
  echo "✅ .sops.yaml found"
else
  echo "⚠️  No .sops.yaml found — SOPS may not be configured for this project"
fi
