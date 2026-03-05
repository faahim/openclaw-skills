#!/bin/bash
# Age Encryption Tool — Main Script
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_KEY="${AGE_KEY_FILE:-$HOME/.age/key.txt}"

usage() {
    cat <<EOF
🔐 Age Encryption Tool

Usage: bash $0 <command> [options]

Commands:
  keygen          Generate a new age key pair
  encrypt         Encrypt a file
  decrypt         Decrypt a file
  encrypt-dir     Encrypt an entire directory (tar + age)
  decrypt-dir     Decrypt a directory archive
  batch-encrypt   Encrypt multiple files matching a pattern
  batch-decrypt   Decrypt multiple .age files in a directory
  verify          Check if a file is valid age-encrypted
  list-keys       List public keys from identity files

Options:
  --input, -i       Input file path
  --output, -o      Output file path (use - for stdout)
  --passphrase, -p  Use passphrase-based encryption
  --key, -k         Key file for encryption (extracts public key)
  --identity, -d    Identity (private key) file for decryption
  --recipient, -r   Public key recipient (repeatable)
  --ssh-key, -s     SSH public key file for encryption
  --pattern          File glob pattern (for batch operations)
  --dir              Directory path
  --delete-original  Delete original after successful encrypt/decrypt

Environment:
  AGE_KEY_FILE      Default identity file (default: ~/.age/key.txt)
  AGE_PASSPHRASE    Passphrase for non-interactive use

EOF
    exit 1
}

# Parse arguments
COMMAND="${1:-}"
shift 2>/dev/null || true

INPUT=""
OUTPUT=""
PASSPHRASE=false
KEY_FILE=""
IDENTITY=""
RECIPIENTS=()
SSH_KEY=""
PATTERN=""
DIR=""
DELETE_ORIGINAL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --input|-i) INPUT="$2"; shift 2 ;;
        --output|-o) OUTPUT="$2"; shift 2 ;;
        --passphrase|-p) PASSPHRASE=true; shift ;;
        --key|-k) KEY_FILE="$2"; shift 2 ;;
        --identity|-d) IDENTITY="$2"; shift 2 ;;
        --recipient|-r) RECIPIENTS+=("$2"); shift 2 ;;
        --ssh-key|-s) SSH_KEY="$2"; shift 2 ;;
        --pattern) PATTERN="$2"; shift 2 ;;
        --dir) DIR="$2"; shift 2 ;;
        --delete-original) DELETE_ORIGINAL=true; shift ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Check age is installed
check_age() {
    if ! command -v age &>/dev/null; then
        echo "❌ age is not installed. Run: bash scripts/install.sh"
        exit 1
    fi
}

# Generate key pair
cmd_keygen() {
    check_age
    local out="${OUTPUT:-$DEFAULT_KEY}"
    local dir=$(dirname "$out")
    mkdir -p "$dir"
    chmod 700 "$dir"

    if [ -f "$out" ]; then
        echo "⚠️  Key already exists at $out"
        read -p "Overwrite? [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 0
    fi

    age-keygen -o "$out" 2>&1
    chmod 600 "$out"
    echo ""
    echo "🔑 Key pair generated at: $out"
    echo "📋 Public key: $(age-keygen -y "$out")"
    echo ""
    echo "Share the public key freely. Keep the key file private."
}

# Build recipient flags
build_recipient_flags() {
    local flags=()

    if [ "$PASSPHRASE" = true ]; then
        flags+=("-p")
    fi

    for r in "${RECIPIENTS[@]}"; do
        flags+=("-r" "$r")
    done

    if [ -n "$KEY_FILE" ]; then
        local pubkey
        pubkey=$(age-keygen -y "$KEY_FILE" 2>/dev/null)
        if [ -n "$pubkey" ]; then
            flags+=("-r" "$pubkey")
        fi
    fi

    if [ -n "$SSH_KEY" ]; then
        flags+=("-R" "$SSH_KEY")
    fi

    echo "${flags[@]}"
}

# Encrypt a file
cmd_encrypt() {
    check_age
    [ -z "$INPUT" ] && [ ! -t 0 ] && INPUT="-"
    [ -z "$INPUT" ] && { echo "❌ --input required"; usage; }

    if [ -z "$OUTPUT" ]; then
        if [ "$INPUT" = "-" ]; then
            OUTPUT="-"
        else
            OUTPUT="${INPUT}.age"
        fi
    fi

    local flags
    flags=($(build_recipient_flags))

    if [ ${#flags[@]} -eq 0 ]; then
        echo "❌ Specify --passphrase, --recipient, --key, or --ssh-key"
        exit 1
    fi

    if [ "$INPUT" = "-" ]; then
        age "${flags[@]}" -o "$OUTPUT"
    else
        [ ! -f "$INPUT" ] && { echo "❌ File not found: $INPUT"; exit 1; }
        local size=$(stat -c%s "$INPUT" 2>/dev/null || stat -f%z "$INPUT" 2>/dev/null)

        age "${flags[@]}" -o "$OUTPUT" "$INPUT"

        if [ "$OUTPUT" != "-" ] && [ -f "$OUTPUT" ]; then
            local enc_size=$(stat -c%s "$OUTPUT" 2>/dev/null || stat -f%z "$OUTPUT" 2>/dev/null)
            echo "✅ Encrypted: $INPUT → $OUTPUT (${size}B → ${enc_size}B)"

            if [ "$DELETE_ORIGINAL" = true ]; then
                rm -f "$INPUT"
                echo "🗑️  Original deleted: $INPUT"
            fi
        fi
    fi
}

# Decrypt a file
cmd_decrypt() {
    check_age
    [ -z "$INPUT" ] && { echo "❌ --input required"; usage; }
    [ ! -f "$INPUT" ] && { echo "❌ File not found: $INPUT"; exit 1; }

    if [ -z "$OUTPUT" ]; then
        OUTPUT="${INPUT%.age}"
        [ "$OUTPUT" = "$INPUT" ] && OUTPUT="${INPUT}.decrypted"
    fi

    local flags=()

    if [ "$PASSPHRASE" = true ]; then
        flags+=("-p")
    fi

    if [ -n "$IDENTITY" ]; then
        flags+=("-i" "$IDENTITY")
    elif [ -f "$DEFAULT_KEY" ] && [ "$PASSPHRASE" = false ]; then
        flags+=("-i" "$DEFAULT_KEY")
    fi

    if [ -n "$AGE_PASSPHRASE" ] && [ "$PASSPHRASE" = true ]; then
        age -d "${flags[@]}" -o "$OUTPUT" "$INPUT"
    else
        age -d "${flags[@]}" -o "$OUTPUT" "$INPUT"
    fi

    if [ -f "$OUTPUT" ]; then
        local size=$(stat -c%s "$OUTPUT" 2>/dev/null || stat -f%z "$OUTPUT" 2>/dev/null)
        echo "✅ Decrypted: $INPUT → $OUTPUT (${size}B)"

        if [ "$DELETE_ORIGINAL" = true ]; then
            rm -f "$INPUT"
            echo "🗑️  Encrypted file deleted: $INPUT"
        fi
    fi
}

# Encrypt directory
cmd_encrypt_dir() {
    check_age
    [ -z "$INPUT" ] && { echo "❌ --input required (directory path)"; usage; }
    [ ! -d "$INPUT" ] && { echo "❌ Not a directory: $INPUT"; exit 1; }

    if [ -z "$OUTPUT" ]; then
        OUTPUT="$(basename "$INPUT").tar.age"
    fi

    local flags
    flags=($(build_recipient_flags))
    [ ${#flags[@]} -eq 0 ] && { echo "❌ Specify --passphrase, --recipient, --key, or --ssh-key"; exit 1; }

    local count=$(find "$INPUT" -type f | wc -l)
    echo "📦 Archiving $count files from $INPUT..."

    if [ -n "$AGE_PASSPHRASE" ] && [ "$PASSPHRASE" = true ]; then
        tar -cf - -C "$(dirname "$INPUT")" "$(basename "$INPUT")" | \
            (age "${flags[@]}" -o "$OUTPUT")
    else
        tar -cf - -C "$(dirname "$INPUT")" "$(basename "$INPUT")" | \
            age "${flags[@]}" -o "$OUTPUT"
    fi

    local enc_size=$(stat -c%s "$OUTPUT" 2>/dev/null || stat -f%z "$OUTPUT" 2>/dev/null)
    echo "✅ Encrypted directory: $INPUT → $OUTPUT ($count files, ${enc_size}B)"
}

# Decrypt directory
cmd_decrypt_dir() {
    check_age
    [ -z "$INPUT" ] && { echo "❌ --input required"; usage; }
    [ ! -f "$INPUT" ] && { echo "❌ File not found: $INPUT"; exit 1; }

    local outdir="${OUTPUT:-.}"
    mkdir -p "$outdir"

    local flags=()
    if [ "$PASSPHRASE" = true ]; then flags+=("-p"); fi
    if [ -n "$IDENTITY" ]; then
        flags+=("-i" "$IDENTITY")
    elif [ -f "$DEFAULT_KEY" ] && [ "$PASSPHRASE" = false ]; then
        flags+=("-i" "$DEFAULT_KEY")
    fi

    if [ -n "$AGE_PASSPHRASE" ] && [ "$PASSPHRASE" = true ]; then
        age -d "${flags[@]}" "$INPUT" | tar -xf - -C "$outdir"
    else
        age -d "${flags[@]}" "$INPUT" | tar -xf - -C "$outdir"
    fi

    echo "✅ Decrypted directory archive to: $outdir/"
}

# Batch encrypt
cmd_batch_encrypt() {
    check_age
    [ -z "$PATTERN" ] && { echo "❌ --pattern required"; usage; }
    [ -z "$DIR" ] && DIR="."

    local flags
    flags=($(build_recipient_flags))
    [ ${#flags[@]} -eq 0 ] && { echo "❌ Specify --passphrase, --recipient, --key, or --ssh-key"; exit 1; }

    local count=0
    for f in "$DIR"/$PATTERN; do
        [ ! -f "$f" ] && continue
        [ "${f%.age}" != "$f" ] && continue  # Skip already encrypted

        if [ -n "$AGE_PASSPHRASE" ] && [ "$PASSPHRASE" = true ]; then
            age "${flags[@]}" -o "${f}.age" "$f"
        else
            age "${flags[@]}" -o "${f}.age" "$f"
        fi
        echo "  ✅ ${f} → ${f}.age"
        count=$((count + 1))

        if [ "$DELETE_ORIGINAL" = true ]; then
            rm -f "$f"
        fi
    done

    echo "✅ Batch encrypted $count files"
}

# Batch decrypt
cmd_batch_decrypt() {
    check_age
    [ -z "$DIR" ] && DIR="."

    local flags=()
    if [ "$PASSPHRASE" = true ]; then flags+=("-p"); fi
    if [ -n "$IDENTITY" ]; then
        flags+=("-i" "$IDENTITY")
    elif [ -f "$DEFAULT_KEY" ] && [ "$PASSPHRASE" = false ]; then
        flags+=("-i" "$DEFAULT_KEY")
    fi

    local count=0
    for f in "$DIR"/*.age; do
        [ ! -f "$f" ] && continue
        local out="${f%.age}"

        if [ -n "$AGE_PASSPHRASE" ] && [ "$PASSPHRASE" = true ]; then
            age -d "${flags[@]}" -o "$out" "$f"
        else
            age -d "${flags[@]}" -o "$out" "$f"
        fi
        echo "  ✅ ${f} → ${out}"
        count=$((count + 1))

        if [ "$DELETE_ORIGINAL" = true ]; then
            rm -f "$f"
        fi
    done

    echo "✅ Batch decrypted $count files"
}

# Verify file
cmd_verify() {
    check_age
    [ -z "$INPUT" ] && { echo "❌ --input required"; usage; }
    [ ! -f "$INPUT" ] && { echo "❌ File not found: $INPUT"; exit 1; }

    # Check magic bytes (age encrypted files start with "age-encryption.org")
    local header
    header=$(head -c 20 "$INPUT" 2>/dev/null | strings)

    if echo "$header" | grep -q "age-encryption"; then
        local size=$(stat -c%s "$INPUT" 2>/dev/null || stat -f%z "$INPUT" 2>/dev/null)
        local mod=$(stat -c%Y "$INPUT" 2>/dev/null || stat -f%m "$INPUT" 2>/dev/null)
        local date=$(date -d "@$mod" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$mod" '+%Y-%m-%d %H:%M' 2>/dev/null)
        echo "✅ Valid age-encrypted file: $INPUT (${size}B, modified ${date})"
    else
        # Could be binary/passphrase-encrypted (different header)
        local size=$(stat -c%s "$INPUT" 2>/dev/null || stat -f%z "$INPUT" 2>/dev/null)
        echo "⚠️  File may be age-encrypted (binary format): $INPUT (${size}B)"
        echo "   Try decrypting to verify."
    fi
}

# List keys
cmd_list_keys() {
    check_age
    echo "🔑 Age Keys:"
    echo ""

    for keyfile in ~/.age/*.txt; do
        [ ! -f "$keyfile" ] && continue
        local pubkey
        pubkey=$(age-keygen -y "$keyfile" 2>/dev/null)
        if [ -n "$pubkey" ]; then
            echo "  📄 $keyfile"
            echo "     Public: $pubkey"
            echo ""
        fi
    done

    if [ ! -f ~/.age/*.txt ] 2>/dev/null; then
        echo "  No keys found in ~/.age/"
        echo "  Generate one: bash $0 keygen"
    fi
}

# Route commands
case "$COMMAND" in
    keygen) cmd_keygen ;;
    encrypt) cmd_encrypt ;;
    decrypt) cmd_decrypt ;;
    encrypt-dir) cmd_encrypt_dir ;;
    decrypt-dir) cmd_decrypt_dir ;;
    batch-encrypt) cmd_batch_encrypt ;;
    batch-decrypt) cmd_batch_decrypt ;;
    verify) cmd_verify ;;
    list-keys) cmd_list_keys ;;
    *) usage ;;
esac
