#!/usr/bin/env bash
# OpenSSL Toolkit — Certificate & Key management automation
# Usage: bash openssl-toolkit.sh <command> [options]

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
OpenSSL Toolkit v${VERSION}

Usage: $(basename "$0") <command> [options]

Commands:
  self-signed     Generate a self-signed certificate
  csr             Generate a Certificate Signing Request
  inspect         Inspect a local certificate file
  inspect-remote  Inspect a remote server's certificate
  check-expiry    Check days until remote cert expires
  convert         Convert between PEM/DER/PKCS12 formats
  verify-chain    Verify a certificate chain
  genkey          Generate a private key (RSA/ECDSA/Ed25519)
  match           Check if a certificate and key match

Options vary by command. Use: $(basename "$0") <command> --help
EOF
  exit 0
}

die() { echo -e "${RED}❌ $*${NC}" >&2; exit 1; }
ok()  { echo -e "${GREEN}✅ $*${NC}"; }
info() { echo -e "${BLUE}🔍 $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }

check_openssl() {
  command -v openssl >/dev/null 2>&1 || die "openssl not found. Install it first."
}

# ── self-signed ──────────────────────────────────────────────────────
cmd_self_signed() {
  local cn="" days=365 out="." sans="" keysize=2048
  while [[ $# -gt 0 ]]; do
    case $1 in
      --cn) cn="$2"; shift 2 ;;
      --days) days="$2"; shift 2 ;;
      --out) out="$2"; shift 2 ;;
      --sans) sans="$2"; shift 2 ;;
      --keysize) keysize="$2"; shift 2 ;;
      --help) echo "Usage: self-signed --cn <name> [--days N] [--sans 'DNS:a,IP:b'] [--keysize N] [--out dir]"; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -z "$cn" ]] && die "Missing --cn (common name)"
  mkdir -p "$out"

  local keyfile="$out/${cn}.key"
  local certfile="$out/${cn}.crt"

  # Build SAN config
  local san_conf=""
  if [[ -n "$sans" ]]; then
    san_conf=$(mktemp)
    cat > "$san_conf" <<SANEOF
[req]
distinguished_name = req_dn
x509_extensions = v3_ext
prompt = no

[req_dn]
CN = ${cn}

[v3_ext]
subjectAltName = ${sans}
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
SANEOF
  fi

  if [[ -n "$san_conf" ]]; then
    openssl req -x509 -newkey "rsa:${keysize}" -nodes \
      -keyout "$keyfile" -out "$certfile" \
      -days "$days" -config "$san_conf" 2>/dev/null
    rm -f "$san_conf"
  else
    openssl req -x509 -newkey "rsa:${keysize}" -nodes \
      -keyout "$keyfile" -out "$certfile" \
      -days "$days" -subj "/CN=${cn}" 2>/dev/null
  fi

  local expiry
  expiry=$(openssl x509 -enddate -noout -in "$certfile" | cut -d= -f2)

  ok "Generated self-signed certificate:"
  echo "   Key:  ${keyfile}"
  echo "   Cert: ${certfile}"
  echo "   Valid: ${days} days (expires ${expiry})"
}

# ── csr ──────────────────────────────────────────────────────────────
cmd_csr() {
  local cn="" org="" country="" sans="" keysize=2048 out="."
  while [[ $# -gt 0 ]]; do
    case $1 in
      --cn) cn="$2"; shift 2 ;;
      --org) org="$2"; shift 2 ;;
      --country) country="$2"; shift 2 ;;
      --sans) sans="$2"; shift 2 ;;
      --keysize) keysize="$2"; shift 2 ;;
      --out) out="$2"; shift 2 ;;
      --help) echo "Usage: csr --cn <name> [--org O] [--country C] [--sans 'DNS:a'] [--keysize N] [--out dir]"; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -z "$cn" ]] && die "Missing --cn (common name)"
  mkdir -p "$out"

  local keyfile="$out/${cn}.key"
  local csrfile="$out/${cn}.csr"
  local subj="/CN=${cn}"
  [[ -n "$org" ]] && subj="/O=${org}${subj}"
  [[ -n "$country" ]] && subj="/C=${country}${subj}"

  if [[ -n "$sans" ]]; then
    local san_conf
    san_conf=$(mktemp)
    cat > "$san_conf" <<SANEOF
[req]
distinguished_name = req_dn
req_extensions = v3_req
prompt = no

[req_dn]
CN = ${cn}
$([ -n "$org" ] && echo "O = ${org}")
$([ -n "$country" ] && echo "C = ${country}")

[v3_req]
subjectAltName = ${sans}
SANEOF
    openssl req -new -newkey "rsa:${keysize}" -nodes \
      -keyout "$keyfile" -out "$csrfile" \
      -config "$san_conf" 2>/dev/null
    rm -f "$san_conf"
  else
    openssl req -new -newkey "rsa:${keysize}" -nodes \
      -keyout "$keyfile" -out "$csrfile" \
      -subj "$subj" 2>/dev/null
  fi

  ok "Generated CSR:"
  echo "   Key: ${keyfile}"
  echo "   CSR: ${csrfile}"
  echo "   Submit the CSR to your Certificate Authority."
}

# ── inspect (local file) ────────────────────────────────────────────
cmd_inspect() {
  local file=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --file) file="$2"; shift 2 ;;
      --help) echo "Usage: inspect --file <cert.pem>"; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -z "$file" ]] && die "Missing --file"
  [[ ! -f "$file" ]] && die "File not found: $file"

  info "Certificate: $file"
  openssl x509 -in "$file" -noout \
    -subject -issuer -dates -serial -ext subjectAltName 2>/dev/null | \
    sed 's/^/   /'
}

# ── inspect-remote ──────────────────────────────────────────────────
cmd_inspect_remote() {
  local host="" port=443
  while [[ $# -gt 0 ]]; do
    case $1 in
      --host) host="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --help) echo "Usage: inspect-remote --host <domain> [--port N]"; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -z "$host" ]] && die "Missing --host"

  local cert
  cert=$(echo | openssl s_client -servername "$host" -connect "${host}:${port}" 2>/dev/null | \
    openssl x509 2>/dev/null) || die "Could not retrieve certificate from ${host}:${port}"

  info "Certificate for ${host}:${port}"
  echo "$cert" | openssl x509 -noout \
    -subject -issuer -dates -serial -ext subjectAltName 2>/dev/null | \
    sed 's/^/   /'

  # Days remaining
  local end_date
  end_date=$(echo "$cert" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  local end_epoch
  end_epoch=$(date -d "$end_date" +%s 2>/dev/null || date -jf "%b %d %T %Y %Z" "$end_date" +%s 2>/dev/null || echo "")
  if [[ -n "$end_epoch" ]]; then
    local now_epoch
    now_epoch=$(date +%s)
    local days_left=$(( (end_epoch - now_epoch) / 86400 ))
    if [[ $days_left -lt 30 ]]; then
      warn "Days left: ${days_left} ⚠️"
    else
      echo -e "   ${GREEN}Days left: ${days_left}${NC}"
    fi
  fi
}

# ── check-expiry ────────────────────────────────────────────────────
cmd_check_expiry() {
  local host="" port=443
  while [[ $# -gt 0 ]]; do
    case $1 in
      --host) host="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --help) echo "Usage: check-expiry --host <domain> [--port N]"; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -z "$host" ]] && die "Missing --host"

  local end_date
  end_date=$(echo | openssl s_client -servername "$host" -connect "${host}:${port}" 2>/dev/null | \
    openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2) || die "Could not check ${host}:${port}"

  local end_epoch now_epoch days_left
  end_epoch=$(date -d "$end_date" +%s 2>/dev/null || date -jf "%b %d %T %Y %Z" "$end_date" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  days_left=$(( (end_epoch - now_epoch) / 86400 ))

  if [[ $days_left -lt 0 ]]; then
    die "${host} — SSL certificate EXPIRED ${days_left#-} days ago!"
  elif [[ $days_left -lt 30 ]]; then
    warn "${host} — SSL expires in ${days_left} days (${end_date}) ⚠️"
  else
    echo -e "${GREEN}🔐 ${host} — SSL expires in ${days_left} days (${end_date})${NC}"
  fi
}

# ── convert ─────────────────────────────────────────────────────────
cmd_convert() {
  local from="" to="" input="" output="" key="" password=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --from) from="$2"; shift 2 ;;
      --to) to="$2"; shift 2 ;;
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --key) key="$2"; shift 2 ;;
      --password) password="$2"; shift 2 ;;
      --help) echo "Usage: convert --from <pem|der|p12> --to <pem|der|p12> --input <file> --output <file> [--key <keyfile>] [--password <pass>]"; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -z "$from" || -z "$to" || -z "$input" || -z "$output" ]] && die "Missing required options. Use --help"

  local pass_args=()
  [[ -n "$password" ]] && pass_args=(-passout "pass:${password}" -passin "pass:${password}")

  case "${from}->${to}" in
    "pem->der")
      openssl x509 -in "$input" -outform DER -out "$output"
      ;;
    "der->pem")
      openssl x509 -in "$input" -inform DER -outform PEM -out "$output"
      ;;
    "pem->p12")
      [[ -z "$key" ]] && die "Need --key for PEM to PKCS12 conversion"
      if [[ ${#pass_args[@]} -gt 0 ]]; then
        openssl pkcs12 -export -out "$output" -inkey "$key" -in "$input" "${pass_args[@]}"
      else
        openssl pkcs12 -export -out "$output" -inkey "$key" -in "$input"
      fi
      ;;
    "p12->pem")
      if [[ ${#pass_args[@]} -gt 0 ]]; then
        openssl pkcs12 -in "$input" -out "$output" -nodes "${pass_args[@]}"
      else
        openssl pkcs12 -in "$input" -out "$output" -nodes
      fi
      ;;
    *)
      die "Unsupported conversion: ${from} → ${to}. Supported: pem↔der, pem↔p12"
      ;;
  esac

  ok "Converted ${input} (${from}) → ${output} (${to})"
}

# ── verify-chain ────────────────────────────────────────────────────
cmd_verify_chain() {
  local cert="" ca=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --cert) cert="$2"; shift 2 ;;
      --ca) ca="$2"; shift 2 ;;
      --help) echo "Usage: verify-chain --cert <server.crt> --ca <ca-bundle.crt>"; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -z "$cert" || -z "$ca" ]] && die "Missing --cert and/or --ca"

  if openssl verify -CAfile "$ca" "$cert" 2>/dev/null | grep -q "OK"; then
    ok "Certificate chain is valid"
    # Show chain
    local subject issuer
    subject=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/subject=//')
    issuer=$(openssl x509 -in "$cert" -noout -issuer 2>/dev/null | sed 's/issuer=//')
    echo "   ${subject} → ${issuer}"
  else
    die "Certificate chain verification FAILED"
  fi
}

# ── genkey ──────────────────────────────────────────────────────────
cmd_genkey() {
  local type="rsa" bits=4096 curve="prime256v1" out=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --type) type="$2"; shift 2 ;;
      --bits) bits="$2"; shift 2 ;;
      --curve) curve="$2"; shift 2 ;;
      --out) out="$2"; shift 2 ;;
      --help) echo "Usage: genkey --type <rsa|ecdsa|ed25519> [--bits N] [--curve name] --out <file>"; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -z "$out" ]] && die "Missing --out"

  case "$type" in
    rsa)
      openssl genpkey -algorithm RSA -pkeyopt "rsa_keygen_bits:${bits}" -out "$out" 2>/dev/null
      ok "Generated RSA ${bits}-bit key: ${out}"
      ;;
    ecdsa)
      openssl genpkey -algorithm EC -pkeyopt "ec_paramgen_curve:${curve}" -out "$out" 2>/dev/null
      ok "Generated ECDSA (${curve}) key: ${out}"
      ;;
    ed25519)
      openssl genpkey -algorithm Ed25519 -out "$out" 2>/dev/null
      ok "Generated Ed25519 key: ${out}"
      ;;
    *)
      die "Unknown key type: ${type}. Use rsa, ecdsa, or ed25519."
      ;;
  esac
}

# ── match ───────────────────────────────────────────────────────────
cmd_match() {
  local cert="" key=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --cert) cert="$2"; shift 2 ;;
      --key) key="$2"; shift 2 ;;
      --help) echo "Usage: match --cert <cert.pem> --key <key.pem>"; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ -z "$cert" || -z "$key" ]] && die "Missing --cert and/or --key"

  local cert_md5 key_md5
  cert_md5=$(openssl x509 -noout -modulus -in "$cert" 2>/dev/null | openssl md5)
  key_md5=$(openssl rsa -noout -modulus -in "$key" 2>/dev/null | openssl md5)

  if [[ "$cert_md5" == "$key_md5" ]]; then
    ok "Certificate and key MATCH"
  else
    die "Certificate and key DO NOT MATCH"
  fi
}

# ── main ────────────────────────────────────────────────────────────
check_openssl

case "${1:-}" in
  self-signed)    shift; cmd_self_signed "$@" ;;
  csr)            shift; cmd_csr "$@" ;;
  inspect)        shift; cmd_inspect "$@" ;;
  inspect-remote) shift; cmd_inspect_remote "$@" ;;
  check-expiry)   shift; cmd_check_expiry "$@" ;;
  convert)        shift; cmd_convert "$@" ;;
  verify-chain)   shift; cmd_verify_chain "$@" ;;
  genkey)         shift; cmd_genkey "$@" ;;
  match)          shift; cmd_match "$@" ;;
  --version)      echo "OpenSSL Toolkit v${VERSION}" ;;
  --help|"")      usage ;;
  *)              die "Unknown command: $1. Use --help for usage." ;;
esac
