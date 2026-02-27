#!/bin/bash
# GPG Encryption Tool — Simplified GPG key management, encryption, signing
# Requires: gpg (GnuPG 2.x), bash 4.0+

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}✅ $1${NC}"; }
log_err()  { echo -e "${RED}❌ $1${NC}" >&2; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Check gpg is installed
check_gpg() {
  if ! command -v gpg &>/dev/null; then
    log_err "GPG not found. Install: sudo apt install gnupg (Debian) or brew install gnupg (Mac)"
    exit 1
  fi
}

# Fix permissions on gpg homedir
fix_perms() {
  if [ -d "$HOME/.gnupg" ]; then
    chmod 700 "$HOME/.gnupg" 2>/dev/null || true
    chmod 600 "$HOME/.gnupg"/* 2>/dev/null || true
  fi
}

# --- KEY MANAGEMENT ---

cmd_keygen() {
  local name="" email="" expiry="2y" passphrase=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --email) email="$2"; shift 2 ;;
      --expiry) expiry="$2"; shift 2 ;;
      --passphrase) passphrase="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$name" || -z "$email" ]]; then
    log_err "Usage: gpg-tool.sh keygen --name \"Your Name\" --email \"you@example.com\" [--expiry 2y]"
    exit 1
  fi

  log_info "🔑 Generating GPG key pair for $name <$email>..."

  local batch_file=$(mktemp)
  cat > "$batch_file" <<EOF
%echo Generating GPG key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $name
Name-Email: $email
Expire-Date: $expiry
${passphrase:+Passphrase: $passphrase}
${passphrase:-"%no-protection"}
%commit
%echo Done
EOF

  gpg --batch --gen-key "$batch_file" 2>/dev/null
  rm -f "$batch_file"

  local key_id
  key_id=$(gpg --list-keys --keyid-format long "$email" 2>/dev/null | grep -m1 'pub' | awk '{print $2}' | cut -d'/' -f2)

  log_ok "Key generated: $key_id"
  echo -e "📋 Fingerprint: $(gpg --fingerprint "$email" 2>/dev/null | grep -A1 'pub' | tail -1 | xargs)"
  echo -e "💡 Export: bash $0 export --key \"$email\""
}

cmd_list() {
  local secret=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --secret) secret=true; shift ;;
      *) shift ;;
    esac
  done

  echo -e "${BLUE}🔑 GPG Keys:${NC}"
  echo ""

  if $secret; then
    gpg --list-secret-keys --keyid-format long 2>/dev/null | while IFS= read -r line; do
      if [[ "$line" =~ ^sec ]]; then
        local algo=$(echo "$line" | awk '{print $2}')
        local created=$(echo "$line" | awk '{print $3}')
        echo -e "  🔐 $algo (created: $created)"
      elif [[ "$line" =~ ^uid ]]; then
        local uid=$(echo "$line" | sed 's/^uid\s*\[.*\]\s*//')
        echo -e "     $uid"
      fi
    done
  else
    gpg --list-keys --keyid-format long 2>/dev/null | while IFS= read -r line; do
      if [[ "$line" =~ ^pub ]]; then
        local algo=$(echo "$line" | awk '{print $2}')
        local created=$(echo "$line" | awk '{print $3}')
        local expiry=$(echo "$line" | grep -oP '\[expires: \K[^\]]+' || echo "never")
        echo -e "  🔑 $algo (created: $created, expires: $expiry)"
      elif [[ "$line" =~ ^uid ]]; then
        local uid=$(echo "$line" | sed 's/^uid\s*\[.*\]\s*//')
        echo -e "     $uid"
      fi
    done
  fi
}

cmd_export() {
  local key="" output="" secret=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --key) key="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --secret) secret=true; shift ;;
      *) shift ;;
    esac
  done

  if [[ -z "$key" ]]; then
    log_err "Usage: gpg-tool.sh export --key \"user@example.com\" [--output file.asc] [--secret]"
    exit 1
  fi

  if $secret; then
    if [[ -n "$output" ]]; then
      gpg --armor --export-secret-keys "$key" > "$output" 2>/dev/null
      log_ok "Secret key exported to $output"
    else
      gpg --armor --export-secret-keys "$key" 2>/dev/null
    fi
  else
    if [[ -n "$output" ]]; then
      gpg --armor --export "$key" > "$output" 2>/dev/null
      log_ok "Public key exported to $output"
    else
      gpg --armor --export "$key" 2>/dev/null
    fi
  fi
}

cmd_import() {
  local file=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --file) file="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$file" || ! -f "$file" ]]; then
    log_err "Usage: gpg-tool.sh import --file key.asc"
    exit 1
  fi

  gpg --import "$file" 2>&1 | tail -2
  log_ok "Key imported from $file"
}

cmd_delete() {
  local key="" force=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --key) key="$2"; shift 2 ;;
      --force) force=true; shift ;;
      *) shift ;;
    esac
  done

  if [[ -z "$key" ]]; then
    log_err "Usage: gpg-tool.sh delete --key \"user@example.com\" [--force]"
    exit 1
  fi

  if $force; then
    gpg --batch --yes --delete-secret-and-public-key "$key" 2>/dev/null
  else
    gpg --delete-key "$key" 2>/dev/null
  fi
  log_ok "Key deleted: $key"
}

cmd_fingerprint() {
  local key=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --key) key="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$key" ]]; then
    log_err "Usage: gpg-tool.sh fingerprint --key \"user@example.com\""
    exit 1
  fi

  gpg --fingerprint "$key" 2>/dev/null
}

# --- ENCRYPTION ---

cmd_encrypt() {
  local file="" dir="" recipients=() symmetric=false sign=false armor=false delete_original=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --file) file="$2"; shift 2 ;;
      --dir) dir="$2"; shift 2 ;;
      --recipient) recipients+=("$2"); shift 2 ;;
      --symmetric) symmetric=true; shift ;;
      --sign) sign=true; shift ;;
      --armor) armor=true; shift ;;
      --delete-original) delete_original=true; shift ;;
      *) shift ;;
    esac
  done

  encrypt_single() {
    local f="$1"
    local args=()

    if $symmetric; then
      args+=(--symmetric)
    else
      for r in "${recipients[@]}"; do
        args+=(--recipient "$r")
      done
    fi

    $sign && args+=(--sign)
    $armor && args+=(--armor)

    local ext="gpg"
    $armor && ext="asc"

    gpg --batch --yes "${args[@]}" --output "${f}.${ext}" --encrypt "$f" 2>/dev/null
    local size=$(du -h "${f}.${ext}" | cut -f1)
    log_ok "Encrypted: ${f}.${ext} ($size)"
    $delete_original && rm -f "$f"
  }

  if [[ -n "$dir" ]]; then
    if [[ ! -d "$dir" ]]; then
      log_err "Directory not found: $dir"
      exit 1
    fi
    local count=0
    find "$dir" -maxdepth 1 -type f ! -name '*.gpg' ! -name '*.asc' | while read -r f; do
      encrypt_single "$f"
      ((count++))
    done
    log_ok "Encrypted all files in $dir"
  elif [[ -n "$file" ]]; then
    if [[ ! -f "$file" ]]; then
      log_err "File not found: $file"
      exit 1
    fi
    encrypt_single "$file"
  else
    log_err "Usage: gpg-tool.sh encrypt --file <file> --recipient <email> [--symmetric] [--sign] [--armor]"
    exit 1
  fi
}

cmd_decrypt() {
  local file="" output=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --file) file="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$file" || ! -f "$file" ]]; then
    log_err "Usage: gpg-tool.sh decrypt --file <file.gpg> [--output <file>]"
    exit 1
  fi

  if [[ -z "$output" ]]; then
    output="${file%.gpg}"
    output="${output%.asc}"
  fi

  log_info "🔓 Decrypting $file..."
  gpg --batch --yes --output "$output" --decrypt "$file" 2>/dev/null
  log_ok "Decrypted: $output"
}

# --- SIGNING ---

cmd_sign() {
  local file="" clear=false key=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --file) file="$2"; shift 2 ;;
      --clear) clear=true; shift ;;
      --key) key="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$file" || ! -f "$file" ]]; then
    log_err "Usage: gpg-tool.sh sign --file <file> [--clear] [--key <email>]"
    exit 1
  fi

  local args=()
  [[ -n "$key" ]] && args+=(--local-user "$key")

  if $clear; then
    gpg --batch --yes "${args[@]}" --clearsign "$file" 2>/dev/null
    log_ok "Clearsigned: ${file}.asc"
  else
    gpg --batch --yes "${args[@]}" --detach-sign --armor "$file" 2>/dev/null
    log_ok "Signed: ${file}.asc (detached signature)"
  fi
}

cmd_verify() {
  local file="" sig=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --file) file="$2"; shift 2 ;;
      --sig) sig="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$file" ]]; then
    log_err "Usage: gpg-tool.sh verify --file <file> [--sig <file.sig>]"
    exit 1
  fi

  if [[ -n "$sig" ]]; then
    gpg --verify "$sig" "$file" 2>&1
  else
    gpg --verify "$file" 2>&1
  fi
}

# --- BACKUP & RESTORE ---

cmd_backup() {
  local output="${1:-$HOME/gpg-backup}"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  mkdir -p "$output"

  gpg --armor --export > "$output/public-keys.asc" 2>/dev/null
  gpg --armor --export-secret-keys > "$output/secret-keys.asc" 2>/dev/null
  gpg --export-ownertrust > "$output/trustdb.txt" 2>/dev/null

  log_ok "Backup saved to $output/"
  echo "  📄 public-keys.asc"
  echo "  🔐 secret-keys.asc"
  echo "  🤝 trustdb.txt"
}

cmd_restore() {
  local input=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$input" || ! -d "$input" ]]; then
    log_err "Usage: gpg-tool.sh restore --input <backup-dir>"
    exit 1
  fi

  [[ -f "$input/public-keys.asc" ]] && gpg --import "$input/public-keys.asc" 2>/dev/null
  [[ -f "$input/secret-keys.asc" ]] && gpg --import "$input/secret-keys.asc" 2>/dev/null
  [[ -f "$input/trustdb.txt" ]] && gpg --import-ownertrust "$input/trustdb.txt" 2>/dev/null

  log_ok "Keys restored from $input/"
}

# --- AUDIT ---

cmd_audit() {
  echo -e "${BLUE}🔍 GPG Key Audit${NC}"
  echo ""

  local now=$(date +%s)
  local warn_days=90
  local warn_secs=$((warn_days * 86400))

  gpg --list-keys --with-colons 2>/dev/null | while IFS=: read -r type trust length algo keyid created expiry rest; do
    if [[ "$type" == "pub" ]]; then
      local uid=""
    elif [[ "$type" == "uid" && -n "$keyid" ]]; then
      uid="$trust"
    fi

    if [[ "$type" == "pub" && -n "$expiry" && "$expiry" != "" ]]; then
      local remaining=$((expiry - now))
      if [[ $remaining -lt 0 ]]; then
        log_err "$uid — EXPIRED $(( -remaining / 86400 )) days ago!"
      elif [[ $remaining -lt $warn_secs ]]; then
        log_warn "$uid — expires in $((remaining / 86400)) days"
      else
        log_ok "$uid — expires in $((remaining / 86400)) days"
      fi
    fi
  done
}

# --- TRUST ---

cmd_trust() {
  local key=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --key) key="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$key" ]]; then
    log_err "Usage: gpg-tool.sh trust --key \"user@example.com\""
    exit 1
  fi

  gpg --quick-lsign-key "$key" 2>/dev/null
  log_ok "Key locally signed/trusted: $key"
}

# --- MAIN ---

usage() {
  cat <<EOF
GPG Encryption Tool v$VERSION

Usage: bash gpg-tool.sh <command> [options]

Key Management:
  keygen       Generate a new key pair
  list         List all keys (--secret for private keys)
  export       Export a public/private key
  import       Import a key from file
  delete       Delete a key
  fingerprint  Show key fingerprint
  trust        Locally sign/trust a key
  audit        Check key expiry status

Encryption:
  encrypt      Encrypt file(s) for recipient or with passphrase
  decrypt      Decrypt a file

Signing:
  sign         Sign a file (detached or clearsign)
  verify       Verify a signature

Backup:
  backup       Export all keys + trust database
  restore      Import keys from backup

Examples:
  bash gpg-tool.sh keygen --name "Alice" --email "alice@example.com"
  bash gpg-tool.sh encrypt --file secret.txt --recipient "bob@example.com"
  bash gpg-tool.sh decrypt --file secret.txt.gpg
  bash gpg-tool.sh sign --file contract.pdf
  bash gpg-tool.sh verify --file contract.pdf --sig contract.pdf.asc
  bash gpg-tool.sh backup --output ~/gpg-backup
EOF
}

main() {
  check_gpg
  fix_perms

  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    keygen)      cmd_keygen "$@" ;;
    list)        cmd_list "$@" ;;
    export)      cmd_export "$@" ;;
    import)      cmd_import "$@" ;;
    delete)      cmd_delete "$@" ;;
    fingerprint) cmd_fingerprint "$@" ;;
    trust)       cmd_trust "$@" ;;
    audit)       cmd_audit "$@" ;;
    encrypt)     cmd_encrypt "$@" ;;
    decrypt)     cmd_decrypt "$@" ;;
    sign)        cmd_sign "$@" ;;
    verify)      cmd_verify "$@" ;;
    backup)      cmd_backup "$@" ;;
    restore)     cmd_restore "$@" ;;
    help|--help|-h) usage ;;
    *) log_err "Unknown command: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"
