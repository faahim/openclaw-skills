#!/bin/bash
set -euo pipefail

# Bitwarden Password Generator

LENGTH=20
UPPER=true
LOWER=true
NUMBERS=true
SPECIAL=false
PASSPHRASE=false
WORDS=4
SEPARATOR="-"
COPY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --passphrase) PASSPHRASE=true; shift ;;
    --words) WORDS="$2"; shift 2 ;;
    --separator) SEPARATOR="$2"; shift 2 ;;
    --uppercase) UPPER=true; shift ;;
    --lowercase) LOWER=true; shift ;;
    --numbers) NUMBERS=true; shift ;;
    --special) SPECIAL=true; shift ;;
    --copy) COPY=true; shift ;;
    [0-9]*) LENGTH="$1"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if $PASSPHRASE; then
  PASSWORD=$(bw generate --passphrase --words "$WORDS" --separator "$SEPARATOR" 2>/dev/null)
  echo "🔐 Generated passphrase: $PASSWORD"
  echo "   Words: $WORDS | Separator: '$SEPARATOR'"
else
  ARGS="--length $LENGTH"
  $UPPER && ARGS="$ARGS --uppercase"
  $LOWER && ARGS="$ARGS --lowercase"
  $NUMBERS && ARGS="$ARGS --number"
  $SPECIAL && ARGS="$ARGS --special"

  PASSWORD=$(bw generate $ARGS 2>/dev/null)

  # Calculate rough entropy
  CHARSET=0
  $UPPER && CHARSET=$((CHARSET + 26))
  $LOWER && CHARSET=$((CHARSET + 26))
  $NUMBERS && CHARSET=$((CHARSET + 10))
  $SPECIAL && CHARSET=$((CHARSET + 33))
  ENTROPY=$(echo "l($CHARSET^$LENGTH)/l(2)" | bc -l 2>/dev/null | cut -d. -f1 || echo "N/A")

  echo "🔐 Generated password: $PASSWORD"
  echo -n "   Length: $LENGTH"
  $UPPER && echo -n " | Uppercase ✅" || echo -n " | Uppercase ❌"
  $LOWER && echo -n " | Lowercase ✅" || echo -n " | Lowercase ❌"
  $NUMBERS && echo -n " | Numbers ✅" || echo -n " | Numbers ❌"
  $SPECIAL && echo -n " | Special ✅" || echo -n " | Special ❌"
  echo ""
  [ "$ENTROPY" != "N/A" ] && echo "   Strength: ~${ENTROPY} bits entropy"
fi

if $COPY; then
  if command -v xclip &>/dev/null; then
    echo -n "$PASSWORD" | xclip -selection clipboard
    echo "📋 Copied to clipboard!"
  elif command -v pbcopy &>/dev/null; then
    echo -n "$PASSWORD" | pbcopy
    echo "📋 Copied to clipboard!"
  else
    echo "⚠️  No clipboard tool found (install xclip or pbcopy)"
  fi
fi
