---
name: age-encryption
description: >-
  Encrypt and decrypt files using age — the modern, simple file encryption tool. Manage keys, batch encrypt, and secure sensitive data.
categories: [security, productivity]
dependencies: [age]
---

# Age Encryption Tool

## What This Does

Encrypt and decrypt files using [age](https://github.com/FiloSottile/age) — a modern, simple, and secure file encryption tool. Unlike GPG, age has no configuration, no key servers, and no complexity. Generate keys, encrypt files for recipients, batch-process directories, and manage encrypted archives.

**Example:** "Encrypt all `.env` files in a project, decrypt a backup archive, generate a new key pair."

## Quick Start (2 minutes)

### 1. Install age

```bash
# Detect OS and install
if command -v apt-get &>/dev/null; then
  sudo apt-get update && sudo apt-get install -y age
elif command -v brew &>/dev/null; then
  brew install age
elif command -v pacman &>/dev/null; then
  sudo pacman -S age
elif command -v dnf &>/dev/null; then
  sudo dnf install age
else
  # Install from GitHub release (works everywhere)
  AGE_VERSION="1.2.1"
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
  esac
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  curl -sLO "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-${OS}-${ARCH}.tar.gz"
  tar xzf "age-v${AGE_VERSION}-${OS}-${ARCH}.tar.gz"
  sudo mv age/age age/age-keygen /usr/local/bin/
  rm -rf age "age-v${AGE_VERSION}-${OS}-${ARCH}.tar.gz"
fi

# Verify
age --version
```

### 2. Generate a Key Pair

```bash
# Generate key and save to file
age-keygen -o ~/.config/age/key.txt 2>&1

# Output shows your public key:
# Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

# Save the public key for sharing
age-keygen -y ~/.config/age/key.txt > ~/.config/age/pubkey.txt
```

### 3. Encrypt a File

```bash
# Encrypt for yourself
age -r $(cat ~/.config/age/pubkey.txt) -o secret.txt.age secret.txt

# Decrypt
age -d -i ~/.config/age/key.txt -o secret.txt secret.txt.age
```

## Core Workflows

### Workflow 1: Encrypt a Single File

**Use case:** Protect a sensitive file (env vars, credentials, private notes)

```bash
# Encrypt with your public key
PUBKEY=$(cat ~/.config/age/pubkey.txt)
age -r "$PUBKEY" -o config.env.age config.env

# The original file still exists — remove it if desired
rm config.env

echo "✅ Encrypted to config.env.age"
```

### Workflow 2: Encrypt with a Passphrase (No Keys Needed)

**Use case:** Quick encryption when you don't want to manage keys

```bash
# Encrypt with passphrase (interactive prompt)
age -p -o backup.tar.age backup.tar

# Decrypt (will prompt for passphrase)
age -d -o backup.tar backup.tar.age
```

### Workflow 3: Batch Encrypt All Sensitive Files

**Use case:** Encrypt all `.env`, `.pem`, `.key` files in a project

```bash
bash scripts/batch-encrypt.sh ~/myproject
```

### Workflow 4: Encrypt for Multiple Recipients

**Use case:** Share encrypted files with team members

```bash
# Encrypt for multiple people
age -r age1abc...recipient1 \
    -r age1def...recipient2 \
    -r age1ghi...recipient3 \
    -o shared-secret.age shared-secret.txt

# Any of the three recipients can decrypt with their private key
age -d -i ~/.config/age/key.txt -o shared-secret.txt shared-secret.age
```

### Workflow 5: Encrypt & Compress a Directory

**Use case:** Create an encrypted backup of a directory

```bash
# Compress + encrypt in one pipeline
tar czf - ~/important-docs | age -r $(cat ~/.config/age/pubkey.txt) -o docs-backup.tar.gz.age

# Decrypt + extract
age -d -i ~/.config/age/key.txt docs-backup.tar.gz.age | tar xzf -
```

### Workflow 6: SSH Key Encryption

**Use case:** Encrypt files using existing SSH keys (no age keys needed)

```bash
# Encrypt using an SSH public key
age -R ~/.ssh/id_ed25519.pub -o secret.age secret.txt

# Decrypt using the SSH private key
age -d -i ~/.ssh/id_ed25519 -o secret.txt secret.age
```

## Scripts

### scripts/install.sh — Install age

```bash
#!/bin/bash
set -e

if command -v age &>/dev/null; then
  echo "✅ age is already installed: $(age --version)"
  exit 0
fi

echo "📦 Installing age..."

if command -v apt-get &>/dev/null; then
  sudo apt-get update -qq && sudo apt-get install -y -qq age
elif command -v brew &>/dev/null; then
  brew install age
elif command -v pacman &>/dev/null; then
  sudo pacman -S --noconfirm age
elif command -v dnf &>/dev/null; then
  sudo dnf install -y age
else
  AGE_VERSION="1.2.1"
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
  esac
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  cd /tmp
  curl -sLO "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-${OS}-${ARCH}.tar.gz"
  tar xzf "age-v${AGE_VERSION}-${OS}-${ARCH}.tar.gz"
  sudo mv age/age age/age-keygen /usr/local/bin/
  rm -rf age "age-v${AGE_VERSION}-${OS}-${ARCH}.tar.gz"
fi

echo "✅ age installed: $(age --version)"
```

### scripts/keygen.sh — Generate & Store Keys

```bash
#!/bin/bash
set -e

KEY_DIR="${AGE_KEY_DIR:-$HOME/.config/age}"
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

KEY_FILE="$KEY_DIR/key.txt"
PUB_FILE="$KEY_DIR/pubkey.txt"

if [ -f "$KEY_FILE" ]; then
  echo "⚠️  Key already exists at $KEY_FILE"
  echo "   Public key: $(age-keygen -y "$KEY_FILE")"
  echo "   Use AGE_KEY_DIR to generate in a different location"
  exit 0
fi

echo "🔑 Generating new age key pair..."
age-keygen -o "$KEY_FILE" 2>&1
chmod 600 "$KEY_FILE"

age-keygen -y "$KEY_FILE" > "$PUB_FILE"
echo ""
echo "✅ Key pair generated!"
echo "   Private key: $KEY_FILE"
echo "   Public key:  $PUB_FILE"
echo "   Share your public key: $(cat "$PUB_FILE")"
echo ""
echo "⚠️  BACK UP your private key! If lost, encrypted files cannot be recovered."
```

### scripts/batch-encrypt.sh — Batch Encrypt Sensitive Files

```bash
#!/bin/bash
set -e

DIR="${1:-.}"
KEY_FILE="${AGE_KEY_FILE:-$HOME/.config/age/key.txt}"
PUB_FILE="${AGE_PUB_FILE:-$HOME/.config/age/pubkey.txt}"

if [ ! -f "$PUB_FILE" ]; then
  echo "❌ No public key found at $PUB_FILE"
  echo "   Run: bash scripts/keygen.sh"
  exit 1
fi

PUBKEY=$(cat "$PUB_FILE")
PATTERNS=("*.env" "*.pem" "*.key" "*.p12" "*.pfx" "*.jks" "*.secret" "*.credentials")
COUNT=0

echo "🔒 Scanning $DIR for sensitive files..."

for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r -d '' file; do
    # Skip already-encrypted files
    [[ "$file" == *.age ]] && continue

    OUTFILE="${file}.age"
    if [ -f "$OUTFILE" ]; then
      echo "   ⏭️  $file (already encrypted)"
      continue
    fi

    age -r "$PUBKEY" -o "$OUTFILE" "$file"
    echo "   ✅ $file → $OUTFILE"
    COUNT=$((COUNT + 1))
  done < <(find "$DIR" -name "$pattern" -type f -print0 2>/dev/null)
done

echo ""
echo "🔒 Encrypted $COUNT file(s)"
[ $COUNT -gt 0 ] && echo "   💡 Consider removing originals: find $DIR -name '*.env' -delete (etc.)"
```

### scripts/batch-decrypt.sh — Batch Decrypt

```bash
#!/bin/bash
set -e

DIR="${1:-.}"
KEY_FILE="${AGE_KEY_FILE:-$HOME/.config/age/key.txt}"

if [ ! -f "$KEY_FILE" ]; then
  echo "❌ No private key found at $KEY_FILE"
  echo "   Set AGE_KEY_FILE or place key at $KEY_FILE"
  exit 1
fi

COUNT=0

echo "🔓 Decrypting .age files in $DIR..."

while IFS= read -r -d '' file; do
  OUTFILE="${file%.age}"
  if [ -f "$OUTFILE" ]; then
    echo "   ⏭️  $file (decrypted file exists)"
    continue
  fi

  age -d -i "$KEY_FILE" -o "$OUTFILE" "$file"
  echo "   ✅ $file → $OUTFILE"
  COUNT=$((COUNT + 1))
done < <(find "$DIR" -name "*.age" -type f -print0 2>/dev/null)

echo ""
echo "🔓 Decrypted $COUNT file(s)"
```

## Configuration

### Environment Variables

```bash
# Custom key location (default: ~/.config/age/key.txt)
export AGE_KEY_FILE="$HOME/.config/age/key.txt"

# Custom public key location
export AGE_PUB_FILE="$HOME/.config/age/pubkey.txt"

# Key directory
export AGE_KEY_DIR="$HOME/.config/age"
```

### .gitignore Integration

Add to your project's `.gitignore`:

```gitignore
# Sensitive files (unencrypted)
*.env
*.pem
*.key
*.secret
*.credentials

# Keep encrypted versions
!*.age
```

## Troubleshooting

### Issue: "age: command not found"

**Fix:** Run `bash scripts/install.sh` or install manually for your OS.

### Issue: "no identity matched any of the recipients"

**Cause:** You're trying to decrypt with the wrong key.

**Fix:** Ensure you're using the private key that corresponds to the public key used for encryption:
```bash
# Check which public key your private key maps to
age-keygen -y ~/.config/age/key.txt
```

### Issue: Lost private key

**Unfortunately:** Files encrypted with a lost key cannot be recovered. This is by design — age has no key recovery mechanism.

**Prevention:** Always back up `~/.config/age/key.txt` to a secure location (password manager, USB drive, printed paper key).

### Issue: "permission denied" on key file

**Fix:**
```bash
chmod 600 ~/.config/age/key.txt
chmod 700 ~/.config/age/
```

## Why age Over GPG?

| Feature | age | GPG |
|---------|-----|-----|
| Setup time | 10 seconds | 10 minutes |
| Config files | None | ~/.gnupg/ (complex) |
| Key format | One line | Keyring + trust model |
| Learning curve | 3 commands | 50+ commands |
| SSH key support | ✅ Built-in | ❌ No |
| Passphrase mode | ✅ Simple | ✅ Complex |
| Security | Modern (X25519, ChaCha20) | Legacy + Modern |

## Key Principles

1. **Simple** — 3 commands: `age-keygen`, `age -e`, `age -d`
2. **No config** — No keyring, no trust model, no key servers
3. **Composable** — Pipes with tar, gzip, ssh, etc.
4. **SSH-compatible** — Use existing SSH keys for encryption
5. **Modern crypto** — X25519, ChaCha20-Poly1305, HKDF
