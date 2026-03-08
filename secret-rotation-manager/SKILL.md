---
name: secret-rotation-manager
description: >-
  Track, rotate, and audit API keys, tokens, and credentials with expiry alerts and automated renewal.
categories: [security, automation]
dependencies: [bash, openssl, jq]
---

# Secret Rotation Manager

## What This Does

Manages the lifecycle of API keys, tokens, passwords, and other secrets. Tracks expiry dates, alerts before credentials expire, generates secure replacements, and updates config files automatically. Keeps a full audit log of every rotation.

**Example:** "Track 20 API keys across 5 services, get alerts 14 days before expiry, auto-rotate database passwords, and maintain a full audit trail."

## Quick Start (5 minutes)

### 1. Install

```bash
# Create directories
mkdir -p ~/.secret-rotation/{secrets,logs,backups}
chmod 700 ~/.secret-rotation

# Copy scripts
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SKILL_DIR/scripts/rotate.sh" ~/.secret-rotation/rotate.sh
chmod +x ~/.secret-rotation/rotate.sh

# Initialize secrets database
echo '{"secrets":[],"rotations":[]}' > ~/.secret-rotation/secrets/vault.json
chmod 600 ~/.secret-rotation/secrets/vault.json
```

### 2. Add Your First Secret

```bash
bash ~/.secret-rotation/rotate.sh add \
  --name "github-token" \
  --service "github" \
  --type "api-key" \
  --value "ghp_xxxxxxxxxxxx" \
  --expires "2026-06-15" \
  --warn-days 14
```

### 3. Check Secret Health

```bash
bash ~/.secret-rotation/rotate.sh status

# Output:
# ┌─────────────────┬──────────┬────────────┬──────────────┬──────────┐
# │ Name            │ Service  │ Type       │ Expires      │ Status   │
# ├─────────────────┼──────────┼────────────┼──────────────┼──────────┤
# │ github-token    │ github   │ api-key    │ 2026-06-15   │ ✅ OK    │
# │ db-password     │ postgres │ password   │ 2026-03-20   │ ⚠️ 12d   │
# │ aws-access-key  │ aws      │ api-key    │ 2026-03-01   │ ❌ EXPIRED│
# └─────────────────┴──────────┴────────────┴──────────────┴──────────┘
```

## Core Workflows

### Workflow 1: Add and Track a Secret

```bash
# Add an API key with expiry
bash ~/.secret-rotation/rotate.sh add \
  --name "stripe-key" \
  --service "stripe" \
  --type "api-key" \
  --value "sk_live_xxxxx" \
  --expires "2026-12-31" \
  --warn-days 30 \
  --env-var "STRIPE_SECRET_KEY" \
  --env-file "/home/user/.env"
```

### Workflow 2: Check for Expiring Secrets

```bash
# Show only secrets expiring within 30 days
bash ~/.secret-rotation/rotate.sh check --warn-days 30

# Output:
# ⚠️  db-password (postgres) expires in 12 days (2026-03-20)
# ❌  aws-access-key (aws) EXPIRED 7 days ago (2026-03-01)
```

### Workflow 3: Rotate a Password

```bash
# Generate a new secure password and update the secret
bash ~/.secret-rotation/rotate.sh rotate \
  --name "db-password" \
  --length 32 \
  --chars "A-Za-z0-9!@#$%"

# Output:
# 🔄 Rotated db-password
#    Old value backed up to ~/.secret-rotation/backups/db-password.2026-03-08.enc
#    New value generated (32 chars)
#    Updated ~/.env (POSTGRES_PASSWORD)
#    New expiry: 2026-06-08 (90 days)
#    Audit logged
```

### Workflow 4: Auto-Rotate with Cron

```bash
# Check daily for expiring secrets, alert via environment
# Add to crontab:
0 9 * * * bash ~/.secret-rotation/rotate.sh check --warn-days 14 --alert webhook --webhook-url "https://hooks.example.com/alerts"
```

### Workflow 5: Audit Trail

```bash
# View rotation history
bash ~/.secret-rotation/rotate.sh audit --name "db-password"

# Output:
# 2026-01-08 09:15:00 | CREATED  | db-password | expires 2026-03-08
# 2026-02-20 10:00:00 | ROTATED  | db-password | new expiry 2026-05-20
# 2026-03-08 09:00:00 | ROTATED  | db-password | new expiry 2026-06-08

# Full audit log
bash ~/.secret-rotation/rotate.sh audit --all --format json
```

### Workflow 6: Export Secrets Report

```bash
# Generate a secrets inventory report (values redacted)
bash ~/.secret-rotation/rotate.sh report --format markdown > secrets-report.md

# Generate CSV for spreadsheet
bash ~/.secret-rotation/rotate.sh report --format csv > secrets-inventory.csv
```

## Configuration

### Environment Variables

```bash
# Alert webhook (Slack, Discord, Telegram, etc.)
export SECRET_ROTATION_WEBHOOK="https://hooks.slack.com/services/xxx"

# Telegram alerts
export SECRET_ROTATION_TELEGRAM_TOKEN="bot123:xxx"
export SECRET_ROTATION_TELEGRAM_CHAT="123456"

# Default expiry (days) for new rotations
export SECRET_ROTATION_DEFAULT_EXPIRY=90

# Default password length
export SECRET_ROTATION_DEFAULT_LENGTH=32

# Encryption key for backups (auto-generated if not set)
export SECRET_ROTATION_ENCRYPT_KEY="your-encryption-passphrase"
```

### Secret Types

| Type | Description | Auto-Rotate |
|------|-------------|-------------|
| `api-key` | API keys and tokens | Manual |
| `password` | Database/service passwords | ✅ Auto-generate |
| `ssh-key` | SSH key pairs | ✅ Auto-generate |
| `certificate` | TLS/SSL certificates | Manual (use certbot) |
| `oauth-token` | OAuth refresh tokens | Manual |
| `webhook-secret` | Webhook signing secrets | ✅ Auto-generate |

## Advanced Usage

### Encrypt All Backups

```bash
# Old values are encrypted with AES-256 before storage
bash ~/.secret-rotation/rotate.sh config --encrypt-backups on

# Decrypt a backup (requires encryption key)
bash ~/.secret-rotation/rotate.sh decrypt-backup \
  --file ~/.secret-rotation/backups/db-password.2026-03-08.enc
```

### Update Config Files on Rotation

```bash
# When rotating, automatically update .env files
bash ~/.secret-rotation/rotate.sh add \
  --name "redis-password" \
  --service "redis" \
  --type "password" \
  --value "oldpass123" \
  --expires "2026-06-01" \
  --env-var "REDIS_PASSWORD" \
  --env-file "/app/.env" \
  --env-file "/app/docker/.env"

# On rotation, both .env files are updated automatically
bash ~/.secret-rotation/rotate.sh rotate --name "redis-password"
```

### Bulk Import from .env

```bash
# Import secrets from an existing .env file
bash ~/.secret-rotation/rotate.sh import \
  --env-file "/app/.env" \
  --service "myapp" \
  --default-expiry 90
```

### JSON Output for Automation

```bash
# Get status as JSON for scripting
bash ~/.secret-rotation/rotate.sh status --format json | jq '.secrets[] | select(.status == "expired")'
```

## Troubleshooting

### Issue: "Permission denied" on vault.json

**Fix:** Ensure correct permissions:
```bash
chmod 700 ~/.secret-rotation
chmod 600 ~/.secret-rotation/secrets/vault.json
```

### Issue: Webhook alerts not sending

**Check:**
1. Webhook URL is reachable: `curl -s -o /dev/null -w "%{http_code}" "$SECRET_ROTATION_WEBHOOK"`
2. Firewall allows outbound HTTPS
3. Check logs: `cat ~/.secret-rotation/logs/rotation.log`

### Issue: Backup decryption fails

**Fix:** Ensure `SECRET_ROTATION_ENCRYPT_KEY` matches the key used during encryption.
```bash
export SECRET_ROTATION_ENCRYPT_KEY="original-passphrase"
bash ~/.secret-rotation/rotate.sh decrypt-backup --file <backup-file>
```

## Security Notes

1. **Vault file** is stored with 600 permissions (owner read/write only)
2. **Old values** are encrypted with AES-256-CBC before backup
3. **Audit logs** never contain secret values, only metadata
4. **Generated passwords** use `/dev/urandom` via `openssl rand`
5. **No network calls** except for webhook alerts — fully offline capable

## Dependencies

- `bash` (4.0+)
- `openssl` (for encryption and password generation)
- `jq` (for JSON manipulation)
- `curl` (optional, for webhook alerts)
- `date` (GNU coreutils)
