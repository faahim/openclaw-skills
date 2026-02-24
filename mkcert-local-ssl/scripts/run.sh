#!/bin/bash
# mkcert Local SSL — Generate and manage locally-trusted SSL certificates
set -euo pipefail

CERT_DIR="${MKCERT_SSL_DIR:-$HOME/.local/share/mkcert-ssl}"
mkdir -p "$CERT_DIR"

# Parse arguments
ACTION="generate"
DOMAINS=""
OUTPUT_DIR=""

usage() {
  cat <<EOF
Usage: bash scripts/run.sh [OPTIONS]

Options:
  --domains "d1,d2,..."   Comma-separated domains to generate cert for
  --output /path/          Custom output directory (default: $CERT_DIR)
  --list                   List all generated certificates
  --status                 Show mkcert and CA status
  --remove "cert-name"     Remove a certificate (filename without extension)
  --uninstall-ca           Remove the local CA (untrust)
  -h, --help               Show this help

Examples:
  bash scripts/run.sh --domains "localhost,127.0.0.1"
  bash scripts/run.sh --domains "*.local.dev,local.dev" --output ./certs/
  bash scripts/run.sh --list
  bash scripts/run.sh --status
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --domains) DOMAINS="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --list) ACTION="list"; shift ;;
    --status) ACTION="status"; shift ;;
    --remove) ACTION="remove"; DOMAINS="$2"; shift 2 ;;
    --uninstall-ca) ACTION="uninstall"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Check mkcert is installed
check_mkcert() {
  if ! command -v mkcert &>/dev/null; then
    echo "❌ mkcert not installed. Run: bash scripts/install.sh"
    exit 1
  fi
}

# Generate certificates
do_generate() {
  check_mkcert

  if [[ -z "$DOMAINS" ]]; then
    echo "❌ No domains specified. Use --domains \"localhost,myapp.local\""
    exit 1
  fi

  local target_dir="${OUTPUT_DIR:-$CERT_DIR}"
  mkdir -p "$target_dir"

  # Convert comma-separated to space-separated
  IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"

  # Build cert name from first domain
  local first_domain="${DOMAIN_ARRAY[0]}"
  local cert_name="${first_domain//\*/_wildcard}"

  # If multiple domains, add count suffix
  if [[ ${#DOMAIN_ARRAY[@]} -gt 1 ]]; then
    cert_name="${cert_name}+$((${#DOMAIN_ARRAY[@]} - 1))"
  fi

  local cert_file="$target_dir/${cert_name}.pem"
  local key_file="$target_dir/${cert_name}-key.pem"

  echo "🔐 Generating certificate..."
  echo "   Domains: ${DOMAIN_ARRAY[*]}"
  echo ""

  # Generate cert
  cd "$target_dir"
  mkcert -cert-file "$cert_file" -key-file "$key_file" "${DOMAIN_ARRAY[@]}"

  echo ""
  echo "✅ Certificate generated:"
  echo "   cert: $cert_file"
  echo "   key:  $key_file"
  echo "   domains: $(IFS=', '; echo "${DOMAIN_ARRAY[*]}")"

  # Show expiry
  if command -v openssl &>/dev/null; then
    local expiry
    expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
    echo "   expires: $expiry"
  fi
}

# List certificates
do_list() {
  echo "📋 Certificates in $CERT_DIR/:"
  echo ""

  if [[ ! -d "$CERT_DIR" ]] || [[ -z "$(ls -A "$CERT_DIR"/*.pem 2>/dev/null)" ]]; then
    echo "   (none found)"
    return
  fi

  for cert in "$CERT_DIR"/*.pem; do
    # Skip key files
    [[ "$cert" == *-key.pem ]] && continue

    local name
    name=$(basename "$cert" .pem)

    # Get domains and expiry from cert
    if command -v openssl &>/dev/null; then
      local san expiry
      san=$(openssl x509 -in "$cert" -noout -ext subjectAltName 2>/dev/null | grep -oP '(?:DNS|IP Address):\K[^,]+' | tr '\n' ', ' | sed 's/,$//' | sed 's/,/, /g')
      expiry=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
      printf "  %-30s (%s) — expires %s\n" "$name.pem" "$san" "$expiry"
    else
      echo "  $name.pem"
    fi
  done
}

# Show status
do_status() {
  check_mkcert

  echo "🔐 mkcert Local SSL Status"
  echo "==========================="
  echo ""
  echo "mkcert version: $(mkcert --version 2>&1 || echo 'unknown')"
  echo "CA root: $(mkcert -CAROOT)"
  echo "Cert storage: $CERT_DIR"

  # Count certs
  local count=0
  if [[ -d "$CERT_DIR" ]]; then
    count=$(find "$CERT_DIR" -name "*.pem" ! -name "*-key.pem" 2>/dev/null | wc -l)
  fi
  echo "Certificates: $count generated"

  # Check if CA is installed
  echo ""
  if mkcert -install 2>&1 | grep -q "already"; then
    echo "✅ Local CA is installed and trusted"
  else
    echo "✅ Local CA installed"
  fi
}

# Remove certificate
do_remove() {
  if [[ -z "$DOMAINS" ]]; then
    echo "❌ Specify cert name to remove. Use --list to see certificates."
    exit 1
  fi

  local cert_file="$CERT_DIR/${DOMAINS}.pem"
  local key_file="$CERT_DIR/${DOMAINS}-key.pem"

  if [[ -f "$cert_file" ]]; then
    rm -f "$cert_file" "$key_file"
    echo "✅ Removed: $DOMAINS.pem (and key)"
  else
    echo "❌ Certificate not found: $cert_file"
    echo "   Use --list to see available certificates."
    exit 1
  fi
}

# Uninstall CA
do_uninstall() {
  check_mkcert
  echo "⚠️  Removing local CA trust..."
  mkcert -uninstall
  echo "✅ Local CA uninstalled. Generated certificates will no longer be trusted."
}

# Execute
case "$ACTION" in
  generate) do_generate ;;
  list) do_list ;;
  status) do_status ;;
  remove) do_remove ;;
  uninstall) do_uninstall ;;
esac
