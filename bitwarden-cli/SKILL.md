---
name: bitwarden-cli
description: >-
  Install and manage Bitwarden password vaults from the command line. Search, create, edit, generate passwords, and export vault data.
categories: [security, productivity]
dependencies: [npm, node]
---

# Bitwarden CLI Manager

## What This Does

Manage your Bitwarden password vault entirely from the command line. Search credentials, generate secure passwords, create/edit entries, export vault data, and check for breached passwords — all without opening a browser.

**Example:** "Find my AWS credentials, generate a 32-char password for the new database, and export my vault as encrypted JSON backup."

## Quick Start (5 minutes)

### 1. Install Bitwarden CLI

```bash
bash scripts/install.sh
```

### 2. Log In

```bash
# Interactive login
bw login

# Or with environment variables
export BW_CLIENTID="your-client-id"
export BW_CLIENTSECRET="your-client-secret"
bw login --apikey

# Unlock vault (required after login)
export BW_SESSION=$(bw unlock --raw)
```

### 3. First Search

```bash
# Search for an entry
bw list items --search "github" | jq '.[].name'
```

## Core Workflows

### Workflow 1: Search Credentials

**Use case:** Quickly find login credentials

```bash
# Search by name
bash scripts/bw-search.sh "aws"

# Search with full details (username + password)
bash scripts/bw-search.sh "aws" --show-password

# Search by URL
bw list items --url "github.com" | jq '.[0] | {name, login: {username: .login.username}}'
```

**Output:**
```
🔍 Found 2 items matching "aws":

1. AWS Console (Production)
   Username: admin@company.com
   URL: https://console.aws.amazon.com
   Last modified: 2026-02-15

2. AWS IAM (Dev)
   Username: dev@company.com
   URL: https://console.aws.amazon.com
   Last modified: 2026-01-20
```

### Workflow 2: Generate Secure Passwords

**Use case:** Generate passwords with specific requirements

```bash
# Generate a 32-character password
bash scripts/bw-generate.sh 32

# Generate with specific requirements
bash scripts/bw-generate.sh 24 --uppercase --lowercase --numbers --special

# Generate a passphrase (4 words)
bash scripts/bw-generate.sh --passphrase --words 4 --separator "-"

# Generate and copy to clipboard (if xclip/pbcopy available)
bash scripts/bw-generate.sh 20 --copy
```

**Output:**
```
🔐 Generated password: k#9Lm$Rq2vN!xP7wBfJ&3TzYa5Cs8Dh
   Length: 32 | Uppercase ✅ | Lowercase ✅ | Numbers ✅ | Special ✅
   Strength: Very Strong (128 bits entropy)
```

### Workflow 3: Create New Entry

**Use case:** Add a new credential to the vault

```bash
# Create a login item
bash scripts/bw-create.sh \
  --name "New Service" \
  --username "user@example.com" \
  --password "$(bw generate --length 24 --special)" \
  --url "https://newservice.com" \
  --folder "Work"

# Create a secure note
bash scripts/bw-create.sh \
  --type securenote \
  --name "Server SSH Key" \
  --notes "$(cat ~/.ssh/id_rsa.pub)"
```

### Workflow 4: Export Vault Backup

**Use case:** Create an encrypted backup of your vault

```bash
# Export as encrypted JSON (recommended)
bash scripts/bw-backup.sh --format encrypted_json --output ~/backups/

# Export as CSV (plaintext — use carefully!)
bash scripts/bw-backup.sh --format csv --output ~/backups/

# Automated backup with timestamp
bash scripts/bw-backup.sh --format encrypted_json --output ~/backups/ --timestamp
```

**Output:**
```
📦 Vault exported successfully
   Format: encrypted_json
   Items: 247
   Output: ~/backups/bw-export-2026-03-06T09-53.json
   ⚠️  Store this file securely — it contains all your passwords!
```

### Workflow 5: Check for Breached Passwords

**Use case:** Audit vault for compromised passwords

```bash
# Check all passwords against Have I Been Pwned
bash scripts/bw-audit.sh

# Check specific item
bash scripts/bw-audit.sh --item "GitHub Personal"
```

**Output:**
```
🔍 Auditing 247 vault items...

⚠️  3 items have breached passwords:
  1. Old Gmail Account — seen 1,203 times in breaches
  2. Forum Login — seen 47 times in breaches
  3. Legacy FTP — seen 8,901 times in breaches

✅ 244 items have no known breaches

💡 Recommendation: Rotate the 3 breached passwords immediately
```

### Workflow 6: Sync & Status

**Use case:** Sync vault and check status

```bash
# Sync vault with server
bw sync

# Check vault status
bash scripts/bw-status.sh
```

**Output:**
```
📊 Bitwarden Vault Status
   Status: Unlocked
   Email: user@example.com
   Server: https://vault.bitwarden.com
   Last sync: 2026-03-06 09:50:00 UTC
   Total items: 247
   Logins: 198 | Cards: 12 | Identities: 3 | Secure Notes: 34
   Folders: 8
```

## Configuration

### Environment Variables

```bash
# Required for API key login
export BW_CLIENTID="your-client-id"
export BW_CLIENTSECRET="your-client-secret"

# Session token (set after unlock)
export BW_SESSION="your-session-token"

# Optional: Self-hosted server
export BW_SERVER="https://your-bitwarden-server.com"

# Optional: Custom data directory
export BITWARDENCLI_APPDATA_DIR="$HOME/.config/bitwarden-cli"
```

### Self-Hosted Bitwarden/Vaultwarden

```bash
# Configure custom server
bw config server https://your-vault.example.com

# Verify
bw config server
```

## Advanced Usage

### Batch Operations

```bash
# List all items in a folder
bw list items --folderid $(bw list folders --search "Work" | jq -r '.[0].id')

# Move items between folders
bash scripts/bw-move.sh --from "Old Folder" --to "New Folder"

# Bulk password rotation report
bash scripts/bw-audit.sh --old-passwords --days 180
```

### Cron: Auto-Sync & Audit

```bash
# Sync vault daily and audit weekly
# Add to crontab:
0 6 * * * export BW_SESSION="..." && bw sync
0 6 * * 1 export BW_SESSION="..." && bash /path/to/scripts/bw-audit.sh >> /var/log/bw-audit.log
```

### Pipe-Friendly Output

```bash
# Get password for a specific item (pipe to clipboard)
bw get password "GitHub Personal" | xclip -selection clipboard

# Get TOTP code
bw get totp "GitHub Personal"

# Use in scripts
DB_PASS=$(bw get password "Production Database")
psql -h db.example.com -U admin -d myapp <<< "$DB_PASS"
```

## Troubleshooting

### Issue: "You are not logged in"

**Fix:**
```bash
bw login
export BW_SESSION=$(bw unlock --raw)
```

### Issue: "Session key is invalid"

**Fix:** Session expired. Re-unlock:
```bash
export BW_SESSION=$(bw unlock --raw)
```

### Issue: "Cannot find module" on install

**Fix:**
```bash
# Ensure Node.js 16+ is installed
node --version

# Reinstall
npm install -g @bitwarden/cli
```

### Issue: Self-hosted server certificate errors

**Fix:**
```bash
# Trust self-signed cert
export NODE_TLS_REJECT_UNAUTHORIZED=0
# Or add CA cert
export NODE_EXTRA_CA_CERTS="/path/to/ca.pem"
```

## Dependencies

- `node` (16+)
- `npm` (for installation)
- `jq` (JSON parsing)
- Optional: `xclip` or `pbcopy` (clipboard)
- Optional: `gpg` (encrypted exports)
