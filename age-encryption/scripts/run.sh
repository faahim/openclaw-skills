#!/bin/bash
# Age Encryption Tool — main script
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  encrypt          Encrypt a file
  decrypt          Decrypt a file
  batch-encrypt    Encrypt all files in a directory
  batch-decrypt    Decrypt all .age files in a directory
  keygen           Generate a new age key pair
  info             Show info about an encrypted file

Encryption Options:
  --input FILE          Input file path
  --output FILE         Output file path
  --passphrase          Use passphrase-based encryption
  --recipient KEY       Recipient public key (repeatable)
  --recipient-file FILE File with recipient public keys
  --key FILE            Key file for encryption (extracts public key)
  --identity FILE       Identity/key file for decryption
  --armor               Output ASCII-armored text
  --shred               Securely delete original after encryption
  --dir DIR             Directory for batch operations
  --ext PATTERN         File extension filter for batch (default: *)

Examples:
  $(basename "$0") encrypt --passphrase --input secret.txt --output secret.txt.age
  $(basename "$0") decrypt --passphrase --input secret.txt.age --output secret.txt
  $(basename "$0") keygen --output ~/.age/key.txt
  $(basename "$0") batch-encrypt --passphrase --dir ~/docs/ --output ~/encrypted/
EOF
  exit 1
}

check_age() {
  if ! command -v age &>/dev/null; then
    echo -e "${RED}❌ age is not installed.${NC}"
    echo "   Run: bash scripts/install.sh"
    exit 1
  fi
}

human_size() {
  local bytes=$1
  if [ "$bytes" -lt 1024 ]; then echo "${bytes} B"
  elif [ "$bytes" -lt 1048576 ]; then echo "$(echo "scale=1; $bytes/1024" | bc) KB"
  elif [ "$bytes" -lt 1073741824 ]; then echo "$(echo "scale=1; $bytes/1048576" | bc) MB"
  else echo "$(echo "scale=1; $bytes/1073741824" | bc) GB"
  fi
}

do_encrypt() {
  local input="" output="" passphrase=false armor=false shred_original=false
  local recipients=() recipient_files=() key_file=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --passphrase) passphrase=true; shift ;;
      --recipient) recipients+=("$2"); shift 2 ;;
      --recipient-file) recipient_files+=("$2"); shift 2 ;;
      --key) key_file="$2"; shift 2 ;;
      --armor) armor=true; shift ;;
      --shred) shred_original=true; shift ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [ -z "$input" ] && { echo -e "${RED}❌ --input required${NC}"; exit 1; }
  [ ! -f "$input" ] && { echo -e "${RED}❌ File not found: $input${NC}"; exit 1; }
  [ -z "$output" ] && output="${input}.age"

  # Build age command
  local cmd="age"
  
  if [ "$passphrase" = true ]; then
    cmd="$cmd -p"
  else
    for r in "${recipients[@]}"; do
      cmd="$cmd -r $r"
    done
    for rf in "${recipient_files[@]}"; do
      cmd="$cmd -R $rf"
    done
    if [ -n "$key_file" ]; then
      # Extract public key from identity file
      local pubkey
      pubkey=$(age-keygen -y "$key_file" 2>/dev/null)
      cmd="$cmd -r $pubkey"
    fi
    if [ ${#recipients[@]} -eq 0 ] && [ ${#recipient_files[@]} -eq 0 ] && [ -z "$key_file" ]; then
      echo -e "${RED}❌ Specify --passphrase, --recipient, --recipient-file, or --key${NC}"
      exit 1
    fi
  fi

  [ "$armor" = true ] && cmd="$cmd -a"
  cmd="$cmd -o \"$output\" \"$input\""

  eval "$cmd"

  local in_size out_size
  in_size=$(stat -c%s "$input" 2>/dev/null || stat -f%z "$input" 2>/dev/null)
  out_size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null)

  local method="X25519 key"
  [ "$passphrase" = true ] && method="scrypt passphrase"

  echo -e "${GREEN}🔒 Encrypted:${NC} $(basename "$input") → $(basename "$output") ($(human_size "$out_size"))"
  echo -e "   Method: $method"

  if [ "$shred_original" = true ]; then
    if command -v shred &>/dev/null; then
      shred -vfz -n 3 "$input" && rm -f "$input"
      echo -e "   ${YELLOW}🗑️ Original securely shredded (3-pass overwrite)${NC}"
    else
      rm -f "$input"
      echo -e "   ${YELLOW}🗑️ Original deleted (shred not available, used rm)${NC}"
    fi
  else
    echo -e "   Original deleted: No (use --shred to securely delete)"
  fi
}

do_decrypt() {
  local input="" output="" passphrase=false identity=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --passphrase) passphrase=true; shift ;;
      --identity) identity="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [ -z "$input" ] && { echo -e "${RED}❌ --input required${NC}"; exit 1; }
  [ ! -f "$input" ] && { echo -e "${RED}❌ File not found: $input${NC}"; exit 1; }
  [ -z "$output" ] && output="${input%.age}"

  local cmd="age -d"

  if [ -n "$identity" ]; then
    cmd="$cmd -i \"$identity\""
  elif [ -n "$AGE_IDENTITY" ]; then
    cmd="$cmd -i \"$AGE_IDENTITY\""
  fi
  # age auto-detects passphrase-encrypted files

  cmd="$cmd -o \"$output\" \"$input\""
  eval "$cmd"

  local out_size
  out_size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null)

  echo -e "${GREEN}🔓 Decrypted:${NC} $(basename "$input") → $(basename "$output") ($(human_size "$out_size"))"
}

do_batch_encrypt() {
  local dir="" output_dir="" passphrase=false ext="*"
  local recipients=() recipient_files=() key_file=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --dir) dir="$2"; shift 2 ;;
      --output) output_dir="$2"; shift 2 ;;
      --passphrase) passphrase=true; shift ;;
      --recipient) recipients+=("$2"); shift 2 ;;
      --recipient-file) recipient_files+=("$2"); shift 2 ;;
      --key) key_file="$2"; shift 2 ;;
      --ext) ext="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [ -z "$dir" ] && { echo -e "${RED}❌ --dir required${NC}"; exit 1; }
  [ ! -d "$dir" ] && { echo -e "${RED}❌ Directory not found: $dir${NC}"; exit 1; }
  [ -z "$output_dir" ] && output_dir="${dir}_encrypted"

  mkdir -p "$output_dir"

  local count=0 total_in=0 total_out=0
  local encrypt_args=""

  if [ "$passphrase" = true ]; then
    encrypt_args="--passphrase"
  else
    for r in "${recipients[@]}"; do encrypt_args="$encrypt_args --recipient $r"; done
    for rf in "${recipient_files[@]}"; do encrypt_args="$encrypt_args --recipient-file $rf"; done
    [ -n "$key_file" ] && encrypt_args="$encrypt_args --key $key_file"
  fi

  while IFS= read -r -d '' file; do
    local relpath="${file#$dir/}"
    local outfile="$output_dir/${relpath}.age"
    local outdir
    outdir=$(dirname "$outfile")
    mkdir -p "$outdir"

    # Suppress individual output for batch
    local age_cmd="age"
    [ "$passphrase" = true ] && age_cmd="$age_cmd -p"
    for r in "${recipients[@]}"; do age_cmd="$age_cmd -r $r"; done
    for rf in "${recipient_files[@]}"; do age_cmd="$age_cmd -R $rf"; done
    if [ -n "$key_file" ]; then
      local bpubkey
      bpubkey=$(age-keygen -y "$key_file" 2>/dev/null)
      age_cmd="$age_cmd -r $bpubkey"
    fi
    eval "$age_cmd -o \"$outfile\" \"$file\"" 2>/dev/null && {
      count=$((count + 1))
      local fsize
      fsize=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
      local osize
      osize=$(stat -c%s "$outfile" 2>/dev/null || stat -f%z "$outfile" 2>/dev/null || echo 0)
      total_in=$((total_in + fsize))
      total_out=$((total_out + osize))
      echo -e "  ${GREEN}✓${NC} $relpath"
    } || {
      echo -e "  ${RED}✗${NC} $relpath (failed)"
    }
  done < <(find "$dir" -type f -not -name "*.age" -print0)

  echo ""
  echo -e "${GREEN}🔒 Batch encryption complete:${NC}"
  echo -e "   Files encrypted: $count"
  echo -e "   Total size: $(human_size $total_in) → $(human_size $total_out)"
  echo -e "   Output: $output_dir/"
}

do_batch_decrypt() {
  local dir="" output_dir="" identity=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --dir) dir="$2"; shift 2 ;;
      --output) output_dir="$2"; shift 2 ;;
      --identity) identity="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [ -z "$dir" ] && { echo -e "${RED}❌ --dir required${NC}"; exit 1; }
  [ -z "$output_dir" ] && output_dir="${dir}_decrypted"
  mkdir -p "$output_dir"

  local id_flag=""
  [ -n "$identity" ] && id_flag="-i \"$identity\""
  [ -n "$AGE_IDENTITY" ] && [ -z "$identity" ] && id_flag="-i \"$AGE_IDENTITY\""

  local count=0
  while IFS= read -r -d '' file; do
    local relpath="${file#$dir/}"
    local outfile="$output_dir/${relpath%.age}"
    local outdir
    outdir=$(dirname "$outfile")
    mkdir -p "$outdir"

    eval "age -d $id_flag -o \"$outfile\" \"$file\"" 2>/dev/null && {
      count=$((count + 1))
      echo -e "  ${GREEN}✓${NC} $relpath"
    } || {
      echo -e "  ${RED}✗${NC} $relpath (failed)"
    }
  done < <(find "$dir" -type f -name "*.age" -print0)

  echo ""
  echo -e "${GREEN}🔓 Batch decryption complete: $count files${NC}"
  echo -e "   Output: $output_dir/"
}

do_keygen() {
  local output=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --output) output="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [ -z "$output" ] && output="$HOME/.age/key.txt"

  local outdir
  outdir=$(dirname "$output")
  mkdir -p "$outdir"

  if [ -f "$output" ]; then
    echo -e "${YELLOW}⚠️  Key file already exists: $output${NC}"
    echo -n "Overwrite? [y/N] "
    read -r confirm
    [ "$confirm" != "y" ] && { echo "Aborted."; exit 0; }
  fi

  age-keygen -o "$output" 2>&1

  chmod 600 "$output"

  local pubkey
  pubkey=$(age-keygen -y "$output")

  echo ""
  echo -e "${GREEN}🔑 Key pair generated:${NC}"
  echo -e "   Identity:   $output"
  echo -e "   Public key: $pubkey"
  echo ""
  echo "Share the public key freely. Keep the identity file SECRET."
}

do_info() {
  local input=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [ -z "$input" ] && { echo -e "${RED}❌ --input required${NC}"; exit 1; }
  [ ! -f "$input" ] && { echo -e "${RED}❌ File not found: $input${NC}"; exit 1; }

  local size
  size=$(stat -c%s "$input" 2>/dev/null || stat -f%z "$input" 2>/dev/null)
  local header
  header=$(head -c 50 "$input" 2>/dev/null)

  local format="binary"
  local armor="No"
  if echo "$header" | grep -q "age-encryption.org"; then
    format="age v1"
    if echo "$header" | grep -q "BEGIN AGE ENCRYPTED FILE"; then
      armor="Yes"
    fi
  else
    echo -e "${YELLOW}⚠️  File may not be age-encrypted${NC}"
  fi

  echo -e "${BLUE}📄 File:${NC} $(basename "$input")"
  echo -e "   Path:   $input"
  echo -e "   Format: $format"
  echo -e "   Size:   $(human_size "$size")"
  echo -e "   Armor:  $armor"
}

# Main
check_age

COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
  encrypt) do_encrypt "$@" ;;
  decrypt) do_decrypt "$@" ;;
  batch-encrypt) do_batch_encrypt "$@" ;;
  batch-decrypt) do_batch_decrypt "$@" ;;
  keygen) do_keygen "$@" ;;
  info) do_info "$@" ;;
  *) usage ;;
esac
