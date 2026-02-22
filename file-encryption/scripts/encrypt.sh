#!/bin/bash
# File Encryption Tool — encrypt/decrypt files with GPG or OpenSSL
# Usage: bash encrypt.sh [options]

set -euo pipefail

# Defaults
METHOD="${ENCRYPT_METHOD:-symmetric}"
CIPHER="${ENCRYPT_CIPHER:-aes-256-cbc}"
SHRED_ORIGINAL="${ENCRYPT_SHRED:-false}"
RECIPIENT="${ENCRYPT_RECIPIENT:-}"
DECRYPT=false
FILE=""
DIR=""
PASSPHRASE=""
ARCHIVE=""
EXTRACT=false
GENERATE_KEY=false
KEY_NAME=""
KEY_EMAIL=""
LIST_KEYS=false
EXPORT_KEY=""
IMPORT_KEY=""
OUTPUT=""
CHECKSUM=false
VERIFY_CHECKSUM=false
INCLUDE_HIDDEN=false

usage() {
  cat <<EOF
File Encryption Tool

ENCRYPT:
  encrypt.sh --file <path> [--method symmetric|openssl|asymmetric] [--passphrase <pass>] [--shred]
  encrypt.sh --dir <path> [--method symmetric|openssl|asymmetric] [--passphrase <pass>]
  encrypt.sh --archive <dir> [--method symmetric|openssl|asymmetric] [--passphrase <pass>]

DECRYPT:
  encrypt.sh --decrypt --file <path> [--passphrase <pass>]
  encrypt.sh --decrypt --dir <path> [--passphrase <pass>]
  encrypt.sh --decrypt --extract --file <path.tar.gz.gpg> [--passphrase <pass>]

KEY MANAGEMENT:
  encrypt.sh --generate-key --name <name> --email <email>
  encrypt.sh --list-keys
  encrypt.sh --export-key <email> --output <file>
  encrypt.sh --import-key <file>

CHECKSUM:
  encrypt.sh --checksum --file <path>
  encrypt.sh --verify-checksum --file <path>

OPTIONS:
  --method          symmetric (GPG), openssl (AES-256), asymmetric (GPG key-pair)
  --recipient       Email/key ID for asymmetric encryption
  --shred           Securely delete original after encryption
  --include-hidden  Include hidden files in directory operations
  --passphrase      Passphrase (omit for interactive prompt)
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file) FILE="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    --method) METHOD="$2"; shift 2 ;;
    --passphrase) PASSPHRASE="$2"; shift 2 ;;
    --recipient) RECIPIENT="$2"; shift 2 ;;
    --decrypt) DECRYPT=true; shift ;;
    --shred) SHRED_ORIGINAL=true; shift ;;
    --archive) ARCHIVE="$2"; shift 2 ;;
    --extract) EXTRACT=true; shift ;;
    --generate-key) GENERATE_KEY=true; shift ;;
    --name) KEY_NAME="$2"; shift 2 ;;
    --email) KEY_EMAIL="$2"; shift 2 ;;
    --list-keys) LIST_KEYS=true; shift ;;
    --export-key) EXPORT_KEY="$2"; shift 2 ;;
    --import-key) IMPORT_KEY="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --checksum) CHECKSUM=true; shift ;;
    --verify-checksum) VERIFY_CHECKSUM=true; shift ;;
    --include-hidden) INCLUDE_HIDDEN=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# --- Key Management ---

if $LIST_KEYS; then
  echo "=== Public Keys ==="
  gpg --list-keys --keyid-format short 2>/dev/null || echo "No public keys found"
  echo ""
  echo "=== Secret Keys ==="
  gpg --list-secret-keys --keyid-format short 2>/dev/null || echo "No secret keys found"
  exit 0
fi

if $GENERATE_KEY; then
  [[ -z "$KEY_NAME" || -z "$KEY_EMAIL" ]] && { echo "❌ --name and --email required"; exit 1; }
  echo "🔑 Generating GPG key pair for $KEY_NAME <$KEY_EMAIL>..."
  gpg --batch --gen-key <<KEYEOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $KEY_NAME
Name-Email: $KEY_EMAIL
Expire-Date: 2y
%commit
KEYEOF
  echo "✅ Key pair generated for $KEY_EMAIL"
  gpg --list-keys "$KEY_EMAIL"
  exit 0
fi

if [[ -n "$EXPORT_KEY" ]]; then
  OUT="${OUTPUT:-${EXPORT_KEY}.pub.asc}"
  gpg --armor --export "$EXPORT_KEY" > "$OUT"
  echo "✅ Public key exported to $OUT"
  exit 0
fi

if [[ -n "$IMPORT_KEY" ]]; then
  gpg --import "$IMPORT_KEY"
  echo "✅ Key imported from $IMPORT_KEY"
  exit 0
fi

# --- Checksum ---

if $CHECKSUM; then
  [[ -z "$FILE" ]] && { echo "❌ --file required"; exit 1; }
  sha256sum "$FILE" > "${FILE}.sha256"
  echo "✅ Checksum saved to ${FILE}.sha256"
  cat "${FILE}.sha256"
  exit 0
fi

if $VERIFY_CHECKSUM; then
  [[ -z "$FILE" ]] && { echo "❌ --file required"; exit 1; }
  [[ ! -f "${FILE}.sha256" ]] && { echo "❌ No checksum file found: ${FILE}.sha256"; exit 1; }
  sha256sum -c "${FILE}.sha256"
  exit $?
fi

# --- Helper Functions ---

secure_shred() {
  local f="$1"
  if command -v shred &>/dev/null; then
    shred -vfz -n 3 "$f" && rm -f "$f"
    echo "🗑️  Securely shredded: $f"
  else
    rm -f "$f"
    echo "⚠️  Deleted (shred not available): $f"
  fi
}

encrypt_file_symmetric() {
  local src="$1"
  local out="${src}.gpg"
  if [[ -n "$PASSPHRASE" ]]; then
    echo "$PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 -o "$out" "$src"
  else
    gpg --symmetric --cipher-algo AES256 -o "$out" "$src"
  fi
  echo "✅ Encrypted: $src → $out"
  [[ "$SHRED_ORIGINAL" == "true" ]] && secure_shred "$src"
}

decrypt_file_symmetric() {
  local src="$1"
  local out="${src%.gpg}"
  [[ "$out" == "$src" ]] && out="${src}.decrypted"
  if [[ -n "$PASSPHRASE" ]]; then
    echo "$PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 -d -o "$out" "$src"
  else
    gpg -d -o "$out" "$src"
  fi
  echo "✅ Decrypted: $src → $out"
}

encrypt_file_openssl() {
  local src="$1"
  local out="${src}.enc"
  if [[ -n "$PASSPHRASE" ]]; then
    openssl enc -"$CIPHER" -salt -pbkdf2 -in "$src" -out "$out" -pass pass:"$PASSPHRASE"
  else
    openssl enc -"$CIPHER" -salt -pbkdf2 -in "$src" -out "$out"
  fi
  echo "✅ Encrypted (OpenSSL): $src → $out"
  [[ "$SHRED_ORIGINAL" == "true" ]] && secure_shred "$src"
}

decrypt_file_openssl() {
  local src="$1"
  local out="${src%.enc}"
  [[ "$out" == "$src" ]] && out="${src}.decrypted"
  if [[ -n "$PASSPHRASE" ]]; then
    openssl enc -d -"$CIPHER" -pbkdf2 -in "$src" -out "$out" -pass pass:"$PASSPHRASE"
  else
    openssl enc -d -"$CIPHER" -pbkdf2 -in "$src" -out "$out"
  fi
  echo "✅ Decrypted (OpenSSL): $src → $out"
}

encrypt_file_asymmetric() {
  local src="$1"
  local out="${src}.gpg"
  [[ -z "$RECIPIENT" ]] && { echo "❌ --recipient required for asymmetric encryption"; exit 1; }
  gpg --yes --trust-model always -e -r "$RECIPIENT" -o "$out" "$src"
  echo "✅ Encrypted (asymmetric): $src → $out"
  [[ "$SHRED_ORIGINAL" == "true" ]] && secure_shred "$src"
}

decrypt_file_asymmetric() {
  local src="$1"
  local out="${src%.gpg}"
  [[ "$out" == "$src" ]] && out="${src}.decrypted"
  gpg -d -o "$out" "$src"
  echo "✅ Decrypted (asymmetric): $src → $out"
}

encrypt_single() {
  case "$METHOD" in
    symmetric) encrypt_file_symmetric "$1" ;;
    openssl) encrypt_file_openssl "$1" ;;
    asymmetric) encrypt_file_asymmetric "$1" ;;
    *) echo "❌ Unknown method: $METHOD"; exit 1 ;;
  esac
}

decrypt_single() {
  local f="$1"
  if [[ "$f" == *.enc ]]; then
    decrypt_file_openssl "$f"
  elif [[ "$f" == *.gpg ]]; then
    # Try symmetric first, fall back to asymmetric
    if [[ -n "$PASSPHRASE" ]]; then
      decrypt_file_symmetric "$f"
    else
      decrypt_file_symmetric "$f" 2>/dev/null || decrypt_file_asymmetric "$f"
    fi
  else
    echo "❌ Unknown encrypted format: $f (expected .gpg or .enc)"
    exit 1
  fi
}

# --- Archive Mode ---

if [[ -n "$ARCHIVE" ]]; then
  if $DECRYPT || $EXTRACT; then
    echo "Use --decrypt --extract --file <archive.tar.gz.gpg> instead"
    exit 1
  fi
  BASENAME=$(basename "$ARCHIVE")
  TAR_FILE="/tmp/${BASENAME}.tar.gz"
  tar -czf "$TAR_FILE" -C "$(dirname "$ARCHIVE")" "$BASENAME"
  echo "📦 Archived: $ARCHIVE → $TAR_FILE"
  FILE="$TAR_FILE"
  encrypt_single "$FILE"
  ENCRYPTED="${FILE}.gpg"
  [[ "$METHOD" == "openssl" ]] && ENCRYPTED="${FILE}.enc"
  mv "$ENCRYPTED" "./${BASENAME}.tar.gz${ENCRYPTED##*tar.gz}"
  rm -f "$TAR_FILE"
  echo "✅ Archive encrypted: ./${BASENAME}.tar.gz${ENCRYPTED##*tar.gz}"
  exit 0
fi

if $EXTRACT && $DECRYPT && [[ -n "$FILE" ]]; then
  decrypt_single "$FILE"
  # Figure out the decrypted tar name
  DECRYPTED="${FILE%.gpg}"
  [[ "$DECRYPTED" == "$FILE" ]] && DECRYPTED="${FILE%.enc}"
  if [[ -f "$DECRYPTED" ]]; then
    tar -xzf "$DECRYPTED"
    echo "📦 Extracted archive: $DECRYPTED"
    rm -f "$DECRYPTED"
  fi
  exit 0
fi

# --- Single File Mode ---

if [[ -n "$FILE" ]]; then
  [[ ! -f "$FILE" ]] && { echo "❌ File not found: $FILE"; exit 1; }
  if $DECRYPT; then
    decrypt_single "$FILE"
  else
    encrypt_single "$FILE"
  fi
  exit 0
fi

# --- Directory Mode ---

if [[ -n "$DIR" ]]; then
  [[ ! -d "$DIR" ]] && { echo "❌ Directory not found: $DIR"; exit 1; }

  FIND_OPTS=(-type f)
  if ! $INCLUDE_HIDDEN; then
    FIND_OPTS+=(-not -name ".*")
  fi

  COUNT=0
  if $DECRYPT; then
    while IFS= read -r -d '' f; do
      decrypt_single "$f"
      ((COUNT++))
    done < <(find "$DIR" "${FIND_OPTS[@]}" \( -name "*.gpg" -o -name "*.enc" \) -print0)
  else
    while IFS= read -r -d '' f; do
      # Skip already encrypted files
      [[ "$f" == *.gpg || "$f" == *.enc ]] && continue
      encrypt_single "$f"
      ((COUNT++))
    done < <(find "$DIR" "${FIND_OPTS[@]}" -print0)
  fi
  echo ""
  echo "✅ Processed $COUNT files in $DIR"
  exit 0
fi

echo "❌ No file, directory, or archive specified. Use --help for usage."
exit 1
