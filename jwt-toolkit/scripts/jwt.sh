#!/usr/bin/env bash
# JWT Toolkit — Decode, verify, generate, and debug JWTs from the CLI
# Dependencies: bash 4+, openssl, jq, base64, date

set -euo pipefail

VERSION="1.0.0"

# ─── Helpers ──────────────────────────────────────────────────────────────────

b64url_decode() {
  local data="$1"
  # Add padding
  local pad=$((4 - ${#data} % 4))
  [ "$pad" -lt 4 ] && data="${data}$(printf '%*s' "$pad" '' | tr ' ' '=')"
  # URL-safe → standard base64
  echo "$data" | tr '_-' '/+' | base64 -d 2>/dev/null
}

b64url_encode() {
  base64 -w0 2>/dev/null || base64 2>/dev/null | tr -d '\n' | tr '/+' '_-' | sed 's/=*$//'
}

b64url_encode_clean() {
  base64 -w0 2>/dev/null || base64 2>/dev/null
  true
}

raw_b64url_encode() {
  local input="$1"
  echo -n "$input" | base64 -w0 2>/dev/null || echo -n "$input" | base64 2>/dev/null
  true
}

to_b64url() {
  tr '/+' '_-' | tr -d '=' | tr -d '\n'
}

split_token() {
  local token="$1"
  IFS='.' read -r HEADER_B64 PAYLOAD_B64 SIGNATURE_B64 <<< "$token"
}

die() { echo "❌ $*" >&2; exit 1; }
info() { echo "$*"; }

# ─── Commands ─────────────────────────────────────────────────────────────────

cmd_decode() {
  local token="" claim="" compact=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --claim) claim="$2"; shift 2 ;;
      --compact) compact=true; shift ;;
      -*) die "Unknown option: $1" ;;
      *) token="$1"; shift ;;
    esac
  done

  [ -z "$token" ] && die "Usage: jwt.sh decode <token> [--claim <name>] [--compact]"

  split_token "$token"

  local header payload
  header=$(b64url_decode "$HEADER_B64" | jq . 2>/dev/null) || header="(invalid JSON)"
  payload=$(b64url_decode "$PAYLOAD_B64" | jq . 2>/dev/null) || payload="(invalid JSON)"

  if [ -n "$claim" ]; then
    echo "$payload" | jq -r ".$claim // empty"
    return
  fi

  if $compact; then
    local alg sub exp_val
    alg=$(echo "$header" | jq -r '.alg // "?"')
    sub=$(echo "$payload" | jq -r '.sub // "?"')
    exp_val=$(echo "$payload" | jq -r '.exp // empty')
    local exp_str="no-expiry"
    if [ -n "$exp_val" ]; then
      local now=$(date +%s)
      if [ "$exp_val" -gt "$now" ] 2>/dev/null; then
        exp_str="valid"
      else
        exp_str="EXPIRED"
      fi
    fi
    echo "[$alg] sub=$sub exp=$exp_str"
    return
  fi

  echo "=== HEADER ==="
  echo "$header"
  echo "=== PAYLOAD ==="
  echo "$payload"

  # Check expiry
  echo "=== TOKEN STATUS ==="
  local exp_val
  exp_val=$(echo "$payload" | jq -r '.exp // empty')
  if [ -z "$exp_val" ]; then
    echo "⚠️  No 'exp' claim — token does not expire"
  else
    local now=$(date +%s)
    if [ "$exp_val" -gt "$now" ] 2>/dev/null; then
      local diff=$((exp_val - now))
      local hours=$((diff / 3600))
      local mins=$(((diff % 3600) / 60))
      local exp_date=$(date -d "@$exp_val" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -r "$exp_val" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "?")
      echo "✅ Token is VALID — expires in ${hours}h ${mins}m ($exp_date)"
    else
      local diff=$((now - exp_val))
      local days=$((diff / 86400))
      local hours=$(((diff % 86400) / 3600))
      local exp_date=$(date -d "@$exp_val" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -r "$exp_val" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "?")
      if [ "$days" -gt 0 ]; then
        echo "❌ Token EXPIRED ${days}d ${hours}h ago ($exp_date)"
      else
        echo "❌ Token EXPIRED ${hours}h ago ($exp_date)"
      fi
    fi
  fi

  # Show issued-at
  local iat_val
  iat_val=$(echo "$payload" | jq -r '.iat // empty')
  if [ -n "$iat_val" ]; then
    local iat_date=$(date -d "@$iat_val" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -r "$iat_val" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "?")
    echo "📅 Issued at: $iat_date"
  fi
}

cmd_check() {
  local token="$1"
  [ -z "$token" ] && die "Usage: jwt.sh check <token>"

  split_token "$token"
  local payload
  payload=$(b64url_decode "$PAYLOAD_B64" | jq . 2>/dev/null) || die "Invalid token"

  local exp_val
  exp_val=$(echo "$payload" | jq -r '.exp // empty')
  if [ -z "$exp_val" ]; then
    echo "⚠️  No 'exp' claim — token does not expire"
    return 0
  fi

  local now=$(date +%s)
  if [ "$exp_val" -gt "$now" ] 2>/dev/null; then
    local diff=$((exp_val - now))
    local hours=$((diff / 3600))
    local mins=$(((diff % 3600) / 60))
    local exp_date=$(date -d "@$exp_val" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -r "$exp_val" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "?")
    echo "✅ Token is VALID — expires in ${hours}h ${mins}m ($exp_date)"
    return 0
  else
    local diff=$((now - exp_val))
    local days=$((diff / 86400))
    local exp_date=$(date -d "@$exp_val" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -r "$exp_val" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "?")
    echo "❌ Token EXPIRED ${days}d ago ($exp_date)"
    return 1
  fi
}

cmd_verify() {
  local token="" secret="${JWT_SECRET:-}" pubkey="${JWT_PUBKEY:-}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --secret) secret="$2"; shift 2 ;;
      --pubkey) pubkey="$2"; shift 2 ;;
      -*) die "Unknown option: $1" ;;
      *) token="$1"; shift ;;
    esac
  done

  [ -z "$token" ] && die "Usage: jwt.sh verify <token> --secret <key> | --pubkey <path>"

  split_token "$token"
  local header
  header=$(b64url_decode "$HEADER_B64") || die "Invalid header"
  local alg=$(echo "$header" | jq -r '.alg')

  local signing_input="${HEADER_B64}.${PAYLOAD_B64}"

  case "$alg" in
    HS256|HS384|HS512)
      [ -z "$secret" ] && die "HMAC algorithm requires --secret"
      local hash_alg
      case "$alg" in
        HS256) hash_alg="sha256" ;;
        HS384) hash_alg="sha384" ;;
        HS512) hash_alg="sha512" ;;
      esac
      local expected_sig
      expected_sig=$(echo -n "$signing_input" | openssl dgst -"$hash_alg" -hmac "$secret" -binary | base64 -w0 2>/dev/null || echo -n "$signing_input" | openssl dgst -"$hash_alg" -hmac "$secret" -binary | base64 | tr -d '\n')
      expected_sig=$(echo -n "$expected_sig" | tr '/+' '_-' | tr -d '=' | tr -d '\n')
      # Normalize actual signature
      local actual_sig=$(echo -n "$SIGNATURE_B64" | tr -d '=')
      if [ "$expected_sig" = "$actual_sig" ]; then
        echo "✅ Signature VALID ($alg)"
        return 0
      else
        echo "❌ Signature INVALID — token may be tampered"
        return 1
      fi
      ;;
    RS256|RS384|RS512)
      [ -z "$pubkey" ] && die "RSA algorithm requires --pubkey <path>"
      [ ! -f "$pubkey" ] && die "Public key file not found: $pubkey"
      local hash_alg
      case "$alg" in
        RS256) hash_alg="sha256" ;;
        RS384) hash_alg="sha384" ;;
        RS512) hash_alg="sha512" ;;
      esac
      # Decode signature from base64url
      local sig_decoded
      sig_decoded=$(echo -n "$SIGNATURE_B64" | tr '_-' '/+' | {
        local s=$(cat)
        local pad=$((4 - ${#s} % 4))
        [ "$pad" -lt 4 ] && s="${s}$(printf '%*s' "$pad" '' | tr ' ' '=')"
        echo "$s"
      } | base64 -d 2>/dev/null)
      local sig_file=$(mktemp)
      echo -n "$sig_decoded" > "$sig_file"
      if echo -n "$signing_input" | openssl dgst -"$hash_alg" -verify "$pubkey" -signature "$sig_file" > /dev/null 2>&1; then
        echo "✅ Signature VALID ($alg)"
        rm -f "$sig_file"
        return 0
      else
        echo "❌ Signature INVALID — token may be tampered"
        rm -f "$sig_file"
        return 1
      fi
      ;;
    ES256|ES384|ES512)
      [ -z "$pubkey" ] && die "EC algorithm requires --pubkey <path>"
      [ ! -f "$pubkey" ] && die "Public key file not found: $pubkey"
      local hash_alg
      case "$alg" in
        ES256) hash_alg="sha256" ;;
        ES384) hash_alg="sha384" ;;
        ES512) hash_alg="sha512" ;;
      esac
      local sig_file=$(mktemp)
      b64url_decode "$SIGNATURE_B64" > "$sig_file"
      if echo -n "$signing_input" | openssl dgst -"$hash_alg" -verify "$pubkey" -signature "$sig_file" > /dev/null 2>&1; then
        echo "✅ Signature VALID ($alg)"
        rm -f "$sig_file"
        return 0
      else
        echo "❌ Signature INVALID — token may be tampered"
        rm -f "$sig_file"
        return 1
      fi
      ;;
    *)
      die "Unsupported algorithm: $alg"
      ;;
  esac
}

cmd_generate() {
  local alg="${JWT_ALG:-HS256}" secret="${JWT_SECRET:-}" privkey="${JWT_PRIVKEY:-}"
  local expires="" claims=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --alg) alg="$2"; shift 2 ;;
      --secret) secret="$2"; shift 2 ;;
      --privkey) privkey="$2"; shift 2 ;;
      --expires) expires="$2"; shift 2 ;;
      --claim) claims+=("$2"); shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  # Build header
  local header='{"alg":"'"$alg"'","typ":"JWT"}'
  local header_b64=$(echo -n "$header" | base64 -w0 2>/dev/null || echo -n "$header" | base64 | tr -d '\n')
  header_b64=$(echo -n "$header_b64" | to_b64url)

  # Build payload
  local now=$(date +%s)
  local payload_json="{\"iat\":$now"
  if [ -n "$expires" ]; then
    local exp=$((now + expires))
    payload_json="$payload_json,\"exp\":$exp"
  fi
  for claim in "${claims[@]}"; do
    local key="${claim%%=*}"
    local val="${claim#*=}"
    # Try to parse as JSON, fall back to string
    if echo "$val" | jq . > /dev/null 2>&1 && [[ "$val" == "["* || "$val" == "{"* || "$val" == "true" || "$val" == "false" || "$val" =~ ^[0-9]+$ ]]; then
      payload_json="$payload_json,\"$key\":$val"
    else
      payload_json="$payload_json,\"$key\":\"$val\""
    fi
  done
  payload_json="$payload_json}"

  local payload_b64=$(echo -n "$payload_json" | base64 -w0 2>/dev/null || echo -n "$payload_json" | base64 | tr -d '\n')
  payload_b64=$(echo -n "$payload_b64" | to_b64url)

  local signing_input="${header_b64}.${payload_b64}"

  # Sign
  local signature=""
  case "$alg" in
    HS256|HS384|HS512)
      [ -z "$secret" ] && die "HMAC requires --secret"
      local hash_alg
      case "$alg" in
        HS256) hash_alg="sha256" ;;
        HS384) hash_alg="sha384" ;;
        HS512) hash_alg="sha512" ;;
      esac
      signature=$(echo -n "$signing_input" | openssl dgst -"$hash_alg" -hmac "$secret" -binary | base64 -w0 2>/dev/null || echo -n "$signing_input" | openssl dgst -"$hash_alg" -hmac "$secret" -binary | base64 | tr -d '\n')
      signature=$(echo -n "$signature" | to_b64url)
      ;;
    RS256|RS384|RS512)
      [ -z "$privkey" ] && die "RSA requires --privkey <path>"
      [ ! -f "$privkey" ] && die "Private key not found: $privkey"
      local hash_alg
      case "$alg" in
        RS256) hash_alg="sha256" ;;
        RS384) hash_alg="sha384" ;;
        RS512) hash_alg="sha512" ;;
      esac
      signature=$(echo -n "$signing_input" | openssl dgst -"$hash_alg" -sign "$privkey" | base64 -w0 2>/dev/null || echo -n "$signing_input" | openssl dgst -"$hash_alg" -sign "$privkey" | base64 | tr -d '\n')
      signature=$(echo -n "$signature" | to_b64url)
      ;;
    ES256|ES384|ES512)
      [ -z "$privkey" ] && die "EC requires --privkey <path>"
      [ ! -f "$privkey" ] && die "Private key not found: $privkey"
      local hash_alg
      case "$alg" in
        ES256) hash_alg="sha256" ;;
        ES384) hash_alg="sha384" ;;
        ES512) hash_alg="sha512" ;;
      esac
      signature=$(echo -n "$signing_input" | openssl dgst -"$hash_alg" -sign "$privkey" | base64 -w0 2>/dev/null || echo -n "$signing_input" | openssl dgst -"$hash_alg" -sign "$privkey" | base64 | tr -d '\n')
      signature=$(echo -n "$signature" | to_b64url)
      ;;
    none)
      signature=""
      ;;
    *)
      die "Unsupported algorithm: $alg"
      ;;
  esac

  echo "${signing_input}.${signature}"
}

cmd_diff() {
  local token1="$1" token2="$2"
  [ -z "$token1" ] || [ -z "$token2" ] && die "Usage: jwt.sh diff <token1> <token2>"

  local h1 p1 s1 h2 p2 s2
  IFS='.' read -r h1 p1 s1 <<< "$token1"
  IFS='.' read -r h2 p2 s2 <<< "$token2"

  local header1 header2 payload1 payload2
  header1=$(b64url_decode "$h1" | jq -S . 2>/dev/null) || header1="(invalid)"
  header2=$(b64url_decode "$h2" | jq -S . 2>/dev/null) || header2="(invalid)"
  payload1=$(b64url_decode "$p1" | jq -S . 2>/dev/null) || payload1="(invalid)"
  payload2=$(b64url_decode "$p2" | jq -S . 2>/dev/null) || payload2="(invalid)"

  echo "=== HEADER DIFF ==="
  if [ "$header1" = "$header2" ]; then
    echo "(no changes)"
  else
    diff <(echo "$header1") <(echo "$header2") --color=auto || true
  fi

  echo "=== PAYLOAD DIFF ==="
  if [ "$payload1" = "$payload2" ]; then
    echo "(no changes)"
  else
    diff <(echo "$payload1") <(echo "$payload2") --color=auto || true
  fi

  echo "=== SIGNATURE ==="
  if [ "$s1" = "$s2" ]; then
    echo "(same signature)"
  else
    echo "Signatures differ"
  fi
}

cmd_keygen() {
  local alg="RS256" outdir="."
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --alg) alg="$2"; shift 2 ;;
      --out) outdir="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  mkdir -p "$outdir"

  case "$alg" in
    RS256|RS384|RS512)
      openssl genrsa -out "$outdir/private.pem" 2048 2>/dev/null
      openssl rsa -in "$outdir/private.pem" -pubout -out "$outdir/public.pem" 2>/dev/null
      echo "✅ RSA key pair generated:"
      echo "   Private key: $outdir/private.pem"
      echo "   Public key:  $outdir/public.pem"
      ;;
    ES256)
      openssl ecparam -genkey -name prime256v1 -noout -out "$outdir/private.pem" 2>/dev/null
      openssl ec -in "$outdir/private.pem" -pubout -out "$outdir/public.pem" 2>/dev/null
      echo "✅ EC P-256 key pair generated:"
      echo "   Private key: $outdir/private.pem"
      echo "   Public key:  $outdir/public.pem"
      ;;
    ES384)
      openssl ecparam -genkey -name secp384r1 -noout -out "$outdir/private.pem" 2>/dev/null
      openssl ec -in "$outdir/private.pem" -pubout -out "$outdir/public.pem" 2>/dev/null
      echo "✅ EC P-384 key pair generated:"
      echo "   Private key: $outdir/private.pem"
      echo "   Public key:  $outdir/public.pem"
      ;;
    ES512)
      openssl ecparam -genkey -name secp521r1 -noout -out "$outdir/private.pem" 2>/dev/null
      openssl ec -in "$outdir/private.pem" -pubout -out "$outdir/public.pem" 2>/dev/null
      echo "✅ EC P-521 key pair generated:"
      echo "   Private key: $outdir/private.pem"
      echo "   Public key:  $outdir/public.pem"
      ;;
    *)
      die "Unsupported algorithm for keygen: $alg (use RS256/ES256/ES384/ES512)"
      ;;
  esac
}

# ─── Main ─────────────────────────────────────────────────────────────────────

usage() {
  cat <<EOF
JWT Toolkit v$VERSION — Decode, verify, generate, and debug JWTs

USAGE:
  jwt.sh <command> [options]

COMMANDS:
  decode <token>   Decode and display header + payload
  check <token>    Check if token is expired
  verify <token>   Verify token signature
  generate         Generate a new JWT
  diff <t1> <t2>   Compare two tokens
  keygen           Generate RSA/EC key pair

OPTIONS (decode):
  --claim <name>   Extract a specific claim value
  --compact        One-line output

OPTIONS (verify):
  --secret <key>   HMAC secret key
  --pubkey <path>  RSA/EC public key file

OPTIONS (generate):
  --alg <alg>      Algorithm (HS256, RS256, ES256, etc.)
  --secret <key>   HMAC secret
  --privkey <path> RSA/EC private key
  --claim <k=v>    Add claim (repeatable)
  --expires <sec>  Token lifetime in seconds

OPTIONS (keygen):
  --alg <alg>      Algorithm (RS256, ES256, etc.)
  --out <dir>      Output directory (default: .)

ENVIRONMENT:
  JWT_SECRET       Default HMAC secret
  JWT_ALG          Default algorithm (HS256)
  JWT_PRIVKEY      Default private key path
  JWT_PUBKEY       Default public key path

EXAMPLES:
  jwt.sh decode "eyJhbG..."
  jwt.sh check "eyJhbG..."
  jwt.sh verify "eyJhbG..." --secret "my-key"
  jwt.sh generate --secret "key" --claim "sub=user1" --expires 3600
  jwt.sh diff "eyJ..." "eyJ..."
  jwt.sh keygen --alg RS256 --out ./keys/
EOF
}

case "${1:-}" in
  decode) shift; cmd_decode "$@" ;;
  check)  shift; cmd_check "$@" ;;
  verify) shift; cmd_verify "$@" ;;
  generate) shift; cmd_generate "$@" ;;
  diff)   shift; cmd_diff "$@" ;;
  keygen) shift; cmd_keygen "$@" ;;
  --version|-v) echo "JWT Toolkit v$VERSION" ;;
  --help|-h|"") usage ;;
  *) die "Unknown command: $1. Run 'jwt.sh --help' for usage." ;;
esac
