#!/bin/bash
# Password Generator — Secure password generation with strength checking
# Dependencies: bash 4+, openssl (or /dev/urandom)

set -euo pipefail

# Defaults
LENGTH=20
COUNT=1
MODE="random"  # random, memorable, pin, passphrase
CHARSET="all"  # all, alpha, alnum, hex
NO_AMBIGUOUS=false
EXCLUDE=""
SEPARATOR="-"
WORDS=4
COPY=false
CHECK=""
QUIET=false

usage() {
  cat <<'EOF'
Password Generator — Generate secure passwords, passphrases, and PINs

USAGE:
  passgen.sh [OPTIONS]
  passgen.sh --check "password"

MODES:
  --random         Random character password (default)
  --memorable      Pronounceable password (alternating consonant/vowel)
  --pin            Numeric PIN
  --passphrase     Word-based passphrase (diceware-style)

OPTIONS:
  -l, --length N       Password length (default: 20)
  -c, --count N        Number of passwords to generate (default: 1)
  --charset CHARSET    Character set: all, alpha, alnum, hex (default: all)
  --no-ambiguous       Exclude ambiguous chars (0O1lI)
  --exclude CHARS      Exclude specific characters
  --words N            Number of words for passphrase (default: 4)
  --separator SEP      Passphrase word separator (default: -)
  --check PASSWORD     Check password strength instead of generating
  --copy               Copy last password to clipboard (requires xclip/pbcopy)
  -q, --quiet          Output password only (no labels)
  -h, --help           Show this help

EXAMPLES:
  passgen.sh                          # 20-char random password
  passgen.sh -l 32 -c 5              # 5 passwords, 32 chars each
  passgen.sh --pin -l 6              # 6-digit PIN
  passgen.sh --passphrase --words 5  # 5-word passphrase
  passgen.sh --memorable -l 16       # Pronounceable 16-char password
  passgen.sh --check "MyP@ss123"     # Check password strength
  passgen.sh --no-ambiguous -l 16    # No confusing characters
EOF
  exit 0
}

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    -l|--length) LENGTH="$2"; shift 2 ;;
    -c|--count) COUNT="$2"; shift 2 ;;
    --random) MODE="random"; shift ;;
    --memorable) MODE="memorable"; shift ;;
    --pin) MODE="pin"; shift ;;
    --passphrase) MODE="passphrase"; shift ;;
    --charset) CHARSET="$2"; shift 2 ;;
    --no-ambiguous) NO_AMBIGUOUS=true; shift ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    --words) WORDS="$2"; shift 2 ;;
    --separator) SEPARATOR="$2"; shift 2 ;;
    --check) CHECK="$2"; shift 2 ;;
    --copy) COPY=true; shift ;;
    -q|--quiet) QUIET=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# === PASSWORD STRENGTH CHECKER ===
check_strength() {
  local pw="$1"
  local len=${#pw}
  local score=0
  local feedback=()

  # Length scoring
  if [[ $len -ge 8 ]]; then ((score+=1)); fi
  if [[ $len -ge 12 ]]; then ((score+=1)); fi
  if [[ $len -ge 16 ]]; then ((score+=1)); fi
  if [[ $len -ge 20 ]]; then ((score+=1)); fi

  # Character class scoring
  if [[ "$pw" =~ [a-z] ]]; then ((score+=1)); else feedback+=("Missing lowercase letters"); fi
  if [[ "$pw" =~ [A-Z] ]]; then ((score+=1)); else feedback+=("Missing uppercase letters"); fi
  if [[ "$pw" =~ [0-9] ]]; then ((score+=1)); else feedback+=("Missing numbers"); fi
  if [[ "$pw" =~ [^a-zA-Z0-9] ]]; then ((score+=1)); else feedback+=("Missing special characters"); fi

  # Common pattern penalties
  if [[ "$pw" =~ ^[0-9]+$ ]]; then score=$((score-2)); feedback+=("Numbers only — easily cracked"); fi
  if [[ "$pw" =~ ^[a-zA-Z]+$ ]]; then score=$((score-1)); feedback+=("Letters only — add numbers/symbols"); fi
  if echo "$pw" | grep -qiE '(password|123456|qwerty|admin|letmein|welcome)'; then
    score=$((score-3)); feedback+=("Contains common password pattern")
  fi
  if [[ $len -lt 8 ]]; then feedback+=("Too short — use 12+ characters"); fi

  # Entropy estimate (bits)
  local pool=0
  [[ "$pw" =~ [a-z] ]] && ((pool+=26))
  [[ "$pw" =~ [A-Z] ]] && ((pool+=26))
  [[ "$pw" =~ [0-9] ]] && ((pool+=10))
  [[ "$pw" =~ [^a-zA-Z0-9] ]] && ((pool+=32))
  local entropy=0
  if [[ $pool -gt 0 ]]; then
    entropy=$(python3 -c "import math; print(int(math.log2($pool) * $len))" 2>/dev/null || echo "?")
  fi

  # Rating
  local rating
  if [[ $score -le 2 ]]; then rating="🔴 Weak"
  elif [[ $score -le 4 ]]; then rating="🟡 Fair"
  elif [[ $score -le 6 ]]; then rating="🟢 Strong"
  else rating="🟢 Very Strong"
  fi

  echo "Password: ${pw:0:3}$( printf '*%.0s' $(seq 1 $((len-6))) )${pw: -3}"
  echo "Length:   $len characters"
  echo "Entropy:  ~${entropy} bits"
  echo "Rating:   $rating"
  if [[ ${#feedback[@]} -gt 0 ]]; then
    echo ""
    echo "Suggestions:"
    for fb in "${feedback[@]}"; do
      echo "  ⚠️  $fb"
    done
  fi
}

if [[ -n "$CHECK" ]]; then
  check_strength "$CHECK"
  exit 0
fi

# === CHARACTER SETS ===
LOWER="abcdefghijklmnopqrstuvwxyz"
UPPER="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
DIGITS="0123456789"
SPECIAL="!@#\$%^&*()_+-=[]{}|;:,.<>?"
AMBIGUOUS="0O1lI"

build_charset() {
  local chars=""
  case $CHARSET in
    all)   chars="${LOWER}${UPPER}${DIGITS}${SPECIAL}" ;;
    alpha) chars="${LOWER}${UPPER}" ;;
    alnum) chars="${LOWER}${UPPER}${DIGITS}" ;;
    hex)   chars="0123456789abcdef" ;;
    *)     chars="${LOWER}${UPPER}${DIGITS}${SPECIAL}" ;;
  esac

  if $NO_AMBIGUOUS; then
    for c in $(echo "$AMBIGUOUS" | grep -o .); do
      chars="${chars//$c/}"
    done
  fi

  if [[ -n "$EXCLUDE" ]]; then
    for c in $(echo "$EXCLUDE" | grep -o .); do
      chars="${chars//$c/}"
    done
  fi

  echo "$chars"
}

# === GENERATORS ===

gen_random() {
  local chars
  chars=$(build_charset)
  local len=${#chars}
  local pw=""
  local bytes
  bytes=$(openssl rand -hex "$LENGTH" 2>/dev/null || head -c "$LENGTH" /dev/urandom | od -An -tx1 | tr -d ' \n')

  for ((i=0; i<LENGTH; i++)); do
    local hex="${bytes:$((i*2)):2}"
    local idx=$(( 16#$hex % len ))
    pw+="${chars:$idx:1}"
  done
  echo "$pw"
}

gen_memorable() {
  local consonants="bcdfghjklmnpqrstvwxyz"
  local vowels="aeiou"
  local pw=""
  for ((i=0; i<LENGTH; i++)); do
    if (( i % 2 == 0 )); then
      local idx=$(( RANDOM % ${#consonants} ))
      local c="${consonants:$idx:1}"
      # Randomly capitalize
      if (( RANDOM % 3 == 0 )); then c="${c^^}"; fi
      pw+="$c"
    else
      local idx=$(( RANDOM % ${#vowels} ))
      pw+="${vowels:$idx:1}"
    fi
  done
  # Append a digit and special char if room
  if (( LENGTH > 4 )); then
    pw="${pw:0:$((LENGTH-2))}$(( RANDOM % 10 ))!"
  fi
  echo "$pw"
}

gen_pin() {
  local pw=""
  local bytes
  bytes=$(openssl rand -hex "$LENGTH" 2>/dev/null || head -c "$LENGTH" /dev/urandom | od -An -tx1 | tr -d ' \n')
  for ((i=0; i<LENGTH; i++)); do
    local hex="${bytes:$((i*2)):2}"
    pw+="$(( 16#$hex % 10 ))"
  done
  echo "$pw"
}

gen_passphrase() {
  # Common English words for diceware-style passphrase
  local wordlist=(
    apple bacon beach candy dance eagle flame grape heart ivory
    joker karma lemon mango noble ocean piano quest river sugar
    tiger umbra vivid whale xenon yacht zebra amber blaze cedar
    delta ember frost glyph haven intro jewel knack lunar marsh
    nexus oasis pearl quilt ridge solar tempo ultra vapor waltz
    acorn brisk charm drift expat forge gleam haste inlet jumbo
    kiosk latch moose notch onset plumb quirky reign stump thaw
    usher vault whisk xerox yearn zesty alpha bravo charm delta
    globe hunch igloo jolly kayak limbo merit nudge orbit prism
    quake roost slate trunk unity vigor wheat pixel yacht zonal
  )
  local len=${#wordlist[@]}
  local words=()
  for ((i=0; i<WORDS; i++)); do
    local bytes
    bytes=$(openssl rand -hex 2 2>/dev/null || printf '%04x' $RANDOM)
    local idx=$(( 16#$bytes % len ))
    words+=("${wordlist[$idx]}")
  done
  local IFS="$SEPARATOR"
  echo "${words[*]}"
}

# === MAIN ===
LAST_PW=""
for ((n=0; n<COUNT; n++)); do
  case $MODE in
    random)     pw=$(gen_random) ;;
    memorable)  pw=$(gen_memorable) ;;
    pin)        pw=$(gen_pin) ;;
    passphrase) pw=$(gen_passphrase) ;;
  esac

  if $QUIET; then
    echo "$pw"
  else
    if [[ $COUNT -gt 1 ]]; then
      echo "[$((n+1))] $pw"
    else
      echo "$pw"
    fi
  fi
  LAST_PW="$pw"
done

# Copy to clipboard
if $COPY && [[ -n "$LAST_PW" ]]; then
  if command -v pbcopy &>/dev/null; then
    echo -n "$LAST_PW" | pbcopy
    $QUIET || echo "📋 Copied to clipboard"
  elif command -v xclip &>/dev/null; then
    echo -n "$LAST_PW" | xclip -selection clipboard
    $QUIET || echo "📋 Copied to clipboard"
  elif command -v xsel &>/dev/null; then
    echo -n "$LAST_PW" | xsel --clipboard
    $QUIET || echo "📋 Copied to clipboard"
  else
    $QUIET || echo "⚠️  No clipboard tool found (install xclip or xsel)"
  fi
fi
