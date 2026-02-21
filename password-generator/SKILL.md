---
name: password-generator
description: >-
  Generate secure passwords, PINs, passphrases, and check password strength — all from the command line.
categories: [security, productivity]
dependencies: [bash, openssl]
---

# Password Generator

## What This Does

Generate cryptographically secure passwords, memorable passwords, numeric PINs, and diceware-style passphrases. Also checks existing password strength with entropy estimation. Zero external services — uses OpenSSL/urandom for randomness.

**Example:** "Generate 5 strong 32-character passwords, or a 6-word passphrase, or check if your current password is any good."

## Quick Start (1 minute)

### Generate a Password

```bash
bash scripts/passgen.sh
# Output: Kj$8mP!nQ2xL@vR5wT9z
```

### Generate Multiple Passwords

```bash
bash scripts/passgen.sh -l 32 -c 5
# [1] aK$9mPn!Q2xL@vR5wT9zBf#7jH&eY4s
# [2] ...
```

### Check Password Strength

```bash
bash scripts/passgen.sh --check "MyP@ssw0rd123"
# Password: MyP***********123
# Length:   13 characters
# Entropy:  ~85 bits
# Rating:   🟢 Strong
```

## Core Workflows

### Workflow 1: Strong Random Password

```bash
# Default: 20 chars, all character types
bash scripts/passgen.sh

# Custom length
bash scripts/passgen.sh -l 32

# No ambiguous characters (avoid 0/O, 1/l/I confusion)
bash scripts/passgen.sh --no-ambiguous -l 24

# Exclude specific characters
bash scripts/passgen.sh --exclude "{}[]" -l 20
```

### Workflow 2: Memorable Password

```bash
# Pronounceable password (alternating consonants/vowels)
bash scripts/passgen.sh --memorable -l 16
# Output: Buxohef4Razi!
```

### Workflow 3: Numeric PIN

```bash
# 4-digit PIN
bash scripts/passgen.sh --pin -l 4
# Output: 7283

# 6-digit PIN
bash scripts/passgen.sh --pin -l 6
# Output: 941026
```

### Workflow 4: Passphrase (Diceware-style)

```bash
# 4-word passphrase (default)
bash scripts/passgen.sh --passphrase
# Output: cedar-flame-orbit-whale

# 6-word passphrase with custom separator
bash scripts/passgen.sh --passphrase --words 6 --separator "."
# Output: brisk.haven.mango.quest.solar.waltz
```

### Workflow 5: Batch Generation

```bash
# 10 passwords for a team
bash scripts/passgen.sh -c 10 -l 16

# Quiet mode (no labels, pipe-friendly)
bash scripts/passgen.sh -c 5 -q | head -1
```

### Workflow 6: Copy to Clipboard

```bash
# Generate and copy to clipboard
bash scripts/passgen.sh --copy
# 📋 Copied to clipboard
```

### Workflow 7: Password Audit

```bash
# Check any password
bash scripts/passgen.sh --check "password123"
# Rating: 🔴 Weak
# Suggestions:
#   ⚠️  Missing special characters
#   ⚠️  Contains common password pattern

bash scripts/passgen.sh --check "Kj\$8mP!nQ2xL@vR5wT9z"
# Rating: 🟢 Very Strong
```

## Character Set Options

| Option | Characters | Use Case |
|--------|-----------|----------|
| `--charset all` | a-z, A-Z, 0-9, symbols | Maximum security (default) |
| `--charset alpha` | a-z, A-Z | Systems that don't allow numbers/symbols |
| `--charset alnum` | a-z, A-Z, 0-9 | Alphanumeric-only requirements |
| `--charset hex` | 0-9, a-f | Hex keys, tokens |

## Integration with OpenClaw

### As a Cron Job (Rotate passwords periodically)

```bash
# Generate new password weekly
bash scripts/passgen.sh -l 32 -q >> ~/password-log.txt
```

### Pipe to Other Tools

```bash
# Generate and use immediately
NEW_PW=$(bash scripts/passgen.sh -l 24 -q)
echo "New password: $NEW_PW"
```

## Troubleshooting

### "openssl: command not found"

Falls back to `/dev/urandom` automatically. Install OpenSSL via your package manager if missing.

### "No clipboard tool found"

Install `xclip` or `xsel` via your package manager. macOS has `pbcopy` built-in.

## Dependencies

- `bash` (4.0+)
- `openssl` (recommended, falls back to /dev/urandom)
- `python3` (for entropy calculation in --check mode)
- Optional: `xclip`/`pbcopy` (for --copy)
