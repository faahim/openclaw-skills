---
name: ssh-key-manager
description: >-
  Generate, manage, and configure SSH keys, known hosts, and SSH config entries from the terminal.
categories: [security, dev-tools]
dependencies: [bash, ssh-keygen, ssh]
---

# SSH Key Manager

## What This Does

Automates SSH key lifecycle: generate keys with best-practice algorithms, manage `~/.ssh/config` entries for quick host access, test connections, rotate keys, audit permissions, and back up your SSH directory. Handles the fiddly parts (file permissions, config syntax, agent forwarding) so you don't have to.

**Example:** "Generate an Ed25519 key for GitHub, add config entry, test connection, and set up agent forwarding — all in one go."

## Quick Start (2 minutes)

### 1. Check Prerequisites

```bash
# These are pre-installed on virtually every Linux/Mac system
which ssh-keygen ssh ssh-agent || echo "Install openssh-client"
```

### 2. Initialize SSH Directory

```bash
bash scripts/ssh-manager.sh init
# Output:
# ✅ ~/.ssh directory exists (permissions: 700)
# ✅ ~/.ssh/config exists (permissions: 600)
# ✅ SSH agent is running
```

### 3. Generate Your First Key

```bash
bash scripts/ssh-manager.sh generate --name github --email you@example.com
# Output:
# 🔑 Generated Ed25519 key: ~/.ssh/github
# 📋 Public key (copy to GitHub):
# ssh-ed25519 AAAAC3Nz... you@example.com
```

## Core Workflows

### Workflow 1: Generate SSH Key

**Use case:** Create a new SSH key pair with best-practice defaults (Ed25519).

```bash
# Basic (Ed25519, default)
bash scripts/ssh-manager.sh generate --name myserver --email user@example.com

# RSA 4096 (for legacy systems)
bash scripts/ssh-manager.sh generate --name legacy --email user@example.com --type rsa --bits 4096

# With custom comment
bash scripts/ssh-manager.sh generate --name deploy --comment "deploy-key-prod-2026"
```

**Output:**
```
🔑 Generated Ed25519 key: ~/.ssh/myserver
📋 Public key:
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@example.com
💾 Key fingerprint: SHA256:xR3j9K...
```

### Workflow 2: Add SSH Config Entry

**Use case:** Set up quick-connect aliases in `~/.ssh/config`.

```bash
bash scripts/ssh-manager.sh config-add \
  --alias prod \
  --host 192.168.1.100 \
  --user deploy \
  --key ~/.ssh/deploy \
  --port 22

# Now you can just: ssh prod
```

**Generated config:**
```
Host prod
    HostName 192.168.1.100
    User deploy
    IdentityFile ~/.ssh/deploy
    Port 22
    IdentitiesOnly yes
```

### Workflow 3: Test Connection

**Use case:** Verify SSH connectivity to a host.

```bash
bash scripts/ssh-manager.sh test --alias prod
# Output:
# 🔍 Testing connection to prod (192.168.1.100)...
# ✅ Connection successful (user: deploy, auth: publickey)

bash scripts/ssh-manager.sh test --host github.com
# Output:
# 🔍 Testing connection to github.com...
# ✅ GitHub authenticated as: yourusername
```

### Workflow 4: List All Keys

**Use case:** Audit your SSH keys and their usage.

```bash
bash scripts/ssh-manager.sh list
# Output:
# 🔑 SSH Keys in ~/.ssh:
#
# Name          Type      Bits  Fingerprint                      Config Entries
# ─────────────────────────────────────────────────────────────────────────────
# github        ed25519   256   SHA256:xR3j9K...                 github.com
# deploy        ed25519   256   SHA256:pQ7m2L...                 prod, staging
# legacy        rsa       4096  SHA256:kW5n8J...                 oldserver
```

### Workflow 5: Audit Permissions

**Use case:** Find and fix insecure file permissions.

```bash
bash scripts/ssh-manager.sh audit
# Output:
# 🔍 SSH Security Audit:
#
# ✅ ~/.ssh (drwx------)
# ✅ ~/.ssh/config (-rw-------)
# ✅ ~/.ssh/github (-rw-------)
# ⚠️  ~/.ssh/legacy (-rw-r--r--) — FIXING → -rw-------
# ✅ ~/.ssh/authorized_keys (-rw-------)
#
# Fixed 1 permission issue.
```

### Workflow 6: Backup SSH Directory

**Use case:** Create an encrypted backup of your SSH keys.

```bash
bash scripts/ssh-manager.sh backup --output ~/ssh-backup.tar.gz.enc
# Output:
# 📦 Backing up ~/.ssh...
# 🔐 Encrypting with passphrase...
# ✅ Backup saved: ~/ssh-backup.tar.gz.enc (2.4 KB)

# Restore:
bash scripts/ssh-manager.sh restore --input ~/ssh-backup.tar.gz.enc
```

### Workflow 7: Copy Public Key to Server

**Use case:** Install your public key on a remote server.

```bash
bash scripts/ssh-manager.sh copy-id --key ~/.ssh/deploy --host 192.168.1.100 --user deploy
# Output:
# 📤 Copying public key to deploy@192.168.1.100...
# ✅ Key installed. You can now: ssh deploy@192.168.1.100
```

### Workflow 8: Enable Agent Forwarding

**Use case:** Forward your SSH keys through jump hosts.

```bash
bash scripts/ssh-manager.sh config-add \
  --alias jump \
  --host bastion.example.com \
  --user admin \
  --key ~/.ssh/admin \
  --forward-agent

# Adds: ForwardAgent yes
```

## Configuration

### SSH Config Defaults

The manager sets these security defaults for new entries:

```
# Applied to all new config entries
IdentitiesOnly yes          # Only use specified key
AddKeysToAgent yes          # Auto-add to agent on first use
ServerAliveInterval 60      # Keep connections alive
ServerAliveCountMax 3       # Disconnect after 3 missed pings
```

### Environment Variables

```bash
# Override default key type (default: ed25519)
export SSH_KEY_TYPE="ed25519"

# Override default SSH directory
export SSH_DIR="$HOME/.ssh"

# Backup encryption (default: aes-256-cbc)
export SSH_BACKUP_CIPHER="aes-256-cbc"
```

## Advanced Usage

### Key Rotation

```bash
# Rotate a key (generates new, archives old, updates config)
bash scripts/ssh-manager.sh rotate --name deploy
# Output:
# 🔄 Rotating key: deploy
# 📦 Archived old key: ~/.ssh/archive/deploy.2026-02-22
# 🔑 Generated new key: ~/.ssh/deploy
# 📋 New public key:
# ssh-ed25519 AAAAC3Nz... (new)
# ⚠️  Remember to update this key on remote servers!
```

### Bulk Operations

```bash
# Audit all keys and fix permissions
bash scripts/ssh-manager.sh audit --fix

# List config entries
bash scripts/ssh-manager.sh config-list

# Remove a config entry
bash scripts/ssh-manager.sh config-remove --alias oldserver
```

### Known Hosts Management

```bash
# Add a host fingerprint
bash scripts/ssh-manager.sh known-hosts-add --host github.com

# Remove a stale host
bash scripts/ssh-manager.sh known-hosts-remove --host oldserver.example.com

# Verify known hosts
bash scripts/ssh-manager.sh known-hosts-verify
```

## Troubleshooting

### Issue: "Permission denied (publickey)"

**Fix:**
```bash
# Check permissions
bash scripts/ssh-manager.sh audit --fix

# Verify correct key is being used
ssh -vT git@github.com 2>&1 | grep "Offering"

# Ensure key is added to agent
ssh-add ~/.ssh/github
```

### Issue: "WARNING: UNPROTECTED PRIVATE KEY FILE"

**Fix:**
```bash
bash scripts/ssh-manager.sh audit --fix
# Automatically sets correct permissions (600 for private keys)
```

### Issue: SSH agent not running

**Fix:**
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/github
```

### Issue: Too many authentication failures

**Fix:** Add `IdentitiesOnly yes` to your config entry:
```bash
bash scripts/ssh-manager.sh config-add --alias myhost --host example.com --user me --key ~/.ssh/mykey
# IdentitiesOnly yes is added by default
```

## Key Principles

1. **Ed25519 by default** — Faster, smaller, more secure than RSA
2. **Strict permissions** — Private keys 600, directory 700, config 600
3. **IdentitiesOnly** — Prevent SSH from trying every key
4. **Backup before changes** — Key rotation archives the old key
5. **No secrets in scripts** — Passphrases are prompted interactively

## Dependencies

- `bash` (4.0+)
- `ssh-keygen` (OpenSSH)
- `ssh` / `ssh-agent` / `ssh-add`
- `openssl` (for encrypted backups)
- Optional: `ssh-copy-id` (for remote key installation)
