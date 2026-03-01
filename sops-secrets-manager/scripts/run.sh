#!/bin/bash
# SOPS Secrets Manager — Main entry point
set -euo pipefail

COMMAND="${1:-help}"
shift || true

# Ensure sops is available
if ! command -v sops &>/dev/null; then
  echo "❌ sops not found. Run: bash scripts/install.sh"
  exit 1
fi

# Ensure age key exists
AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
if [[ -z "${SOPS_AGE_KEY:-}" ]] && [[ ! -f "$AGE_KEY_FILE" ]]; then
  echo "❌ No age key found. Run: bash scripts/setup-keys.sh"
  exit 1
fi

encrypt_file() {
  local FILE="$1"
  shift
  local EXTRA_ARGS=("$@")

  if [[ ! -f "$FILE" ]]; then
    echo "❌ File not found: $FILE"
    exit 1
  fi

  # Check if already encrypted
  if head -5 "$FILE" | grep -q "sops:" 2>/dev/null || head -5 "$FILE" | grep -q '"sops"' 2>/dev/null; then
    echo "⚠️  $FILE appears already encrypted. Use 'edit' to modify or 'rotate' to re-encrypt."
    exit 1
  fi

  sops --encrypt "${EXTRA_ARGS[@]}" --in-place "$FILE"
  echo "✅ Encrypted $FILE"
  echo "   Safe to commit to git!"
}

decrypt_file() {
  local FILE="$1"
  shift
  local STDOUT=false
  local OUTPUT_TYPE=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --stdout) STDOUT=true; shift ;;
      --output-type) OUTPUT_TYPE="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ ! -f "$FILE" ]]; then
    echo "❌ File not found: $FILE"
    exit 1
  fi

  if [[ "$STDOUT" == true ]]; then
    if [[ -n "$OUTPUT_TYPE" ]]; then
      sops --decrypt --output-type "$OUTPUT_TYPE" "$FILE"
    else
      sops --decrypt "$FILE"
    fi
  else
    sops --decrypt --in-place "$FILE"
    echo "✅ Decrypted $FILE"
    echo "   ⚠️  Remember: don't commit the decrypted file!"
  fi
}

edit_file() {
  local FILE="$1"
  if [[ ! -f "$FILE" ]]; then
    echo "❌ File not found: $FILE"
    exit 1
  fi
  sops "$FILE"
  echo "✅ Saved and re-encrypted $FILE"
}

rotate_keys() {
  local FILE="$1"
  shift

  if [[ ! -f "$FILE" ]]; then
    echo "❌ File not found: $FILE"
    exit 1
  fi

  # Handle --add-key
  while [[ $# -gt 0 ]]; do
    case $1 in
      --add-key)
        echo "📋 To add a new key, update .sops.yaml with the new public key, then run:"
        echo "   sops updatekeys $FILE"
        sops updatekeys "$FILE"
        echo "✅ Keys updated for $FILE"
        return
        ;;
      *) shift ;;
    esac
  done

  sops --rotate --in-place "$FILE"
  echo "✅ Rotated data key for $FILE"
}

encrypt_dir() {
  local DIR="$1"
  if [[ ! -d "$DIR" ]]; then
    echo "❌ Directory not found: $DIR"
    exit 1
  fi

  local COUNT=0
  while IFS= read -r -d '' FILE; do
    # Skip already encrypted files
    if head -5 "$FILE" | grep -q "sops:" 2>/dev/null; then
      echo "⏭️  Skipping (already encrypted): $FILE"
      continue
    fi
    sops --encrypt --in-place "$FILE"
    echo "✅ Encrypted: $FILE"
    ((COUNT++))
  done < <(find "$DIR" -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.env" -o -name "*.env.*" -o -name "*.ini" \) -print0)

  echo ""
  echo "✅ Encrypted $COUNT files in $DIR"
}

audit_repo() {
  echo "🔍 SOPS Secrets Audit"
  echo "====================="
  local ISSUES=0

  # Check for .sops.yaml
  if [[ ! -f ".sops.yaml" ]]; then
    echo "❌ No .sops.yaml found in current directory"
    ((ISSUES++))
  else
    echo "✅ .sops.yaml found"
  fi

  # Check for unencrypted files that look like secrets
  echo ""
  echo "Scanning for potential unencrypted secrets..."
  local PATTERNS=("password" "secret" "api_key" "token" "private_key" "credentials")

  for PATTERN in "${PATTERNS[@]}"; do
    FOUND=$(grep -ril "$PATTERN" --include="*.yaml" --include="*.yml" --include="*.json" --include="*.env" --include="*.env.*" . 2>/dev/null | head -20 || true)
    if [[ -n "$FOUND" ]]; then
      while IFS= read -r FILE; do
        # Check if encrypted
        if ! head -5 "$FILE" | grep -q "sops:" 2>/dev/null && ! head -5 "$FILE" | grep -q '"sops"' 2>/dev/null; then
          echo "⚠️  Potentially unencrypted secret in: $FILE (contains '$PATTERN')"
          ((ISSUES++))
        fi
      done <<< "$FOUND"
    fi
  done

  echo ""
  if [[ $ISSUES -eq 0 ]]; then
    echo "✅ No issues found!"
  else
    echo "⚠️  Found $ISSUES potential issue(s)"
  fi
}

case "$COMMAND" in
  encrypt)
    FILE="${1:?Usage: run.sh encrypt <file> [--encrypted-regex <regex>]}"
    shift
    EXTRA=()
    while [[ $# -gt 0 ]]; do
      case $1 in
        --encrypted-regex) EXTRA+=("--encrypted-regex" "$2"); shift 2 ;;
        *) shift ;;
      esac
    done
    encrypt_file "$FILE" "${EXTRA[@]+"${EXTRA[@]}"}"
    ;;
  decrypt)
    FILE="${1:?Usage: run.sh decrypt <file> [--stdout] [--output-type dotenv]}"
    shift
    decrypt_file "$FILE" "$@"
    ;;
  edit)
    FILE="${1:?Usage: run.sh edit <file>}"
    edit_file "$FILE"
    ;;
  rotate)
    FILE="${1:?Usage: run.sh rotate <file> [--add-key <age-key>]}"
    shift
    rotate_keys "$FILE" "$@"
    ;;
  encrypt-dir)
    DIR="${1:?Usage: run.sh encrypt-dir <directory>}"
    encrypt_dir "$DIR"
    ;;
  audit)
    audit_repo
    ;;
  help|--help|-h)
    echo "SOPS Secrets Manager"
    echo ""
    echo "Usage: bash scripts/run.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  encrypt <file>        Encrypt a file in-place"
    echo "  decrypt <file>        Decrypt a file in-place"
    echo "  edit <file>           Edit encrypted file (decrypt → edit → re-encrypt)"
    echo "  rotate <file>         Rotate data encryption key"
    echo "  encrypt-dir <dir>     Encrypt all supported files in directory"
    echo "  audit                 Scan repo for unencrypted secrets"
    echo ""
    echo "Options:"
    echo "  --encrypted-regex <r>  Only encrypt keys matching regex (encrypt)"
    echo "  --stdout               Output to stdout instead of in-place (decrypt)"
    echo "  --output-type <type>   Convert output format: dotenv, json, yaml (decrypt)"
    echo "  --add-key <key>        Add a new age recipient key (rotate)"
    ;;
  *)
    echo "❌ Unknown command: $COMMAND"
    echo "Run: bash scripts/run.sh help"
    exit 1
    ;;
esac
