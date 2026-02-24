---
name: vaultwarden-server
description: >-
  Deploy and manage a self-hosted Vaultwarden (Bitwarden-compatible) password server with Docker, SSL, automated backups, and admin controls.
categories: [security, home]
dependencies: [docker, docker-compose, openssl, curl, jq]
---

# Vaultwarden Password Server

## What This Does

Deploy a self-hosted, Bitwarden-compatible password manager using Vaultwarden. Stores passwords, TOTP secrets, notes, and cards — accessible from any Bitwarden client (browser extension, mobile app, desktop). Includes automated backups, SSL setup, and admin panel management.

**Example:** "Set up a private password vault on your server, accessible at `https://vault.yourdomain.com`, with nightly encrypted backups to a local directory."

## Quick Start (10 minutes)

### 1. Check Dependencies

```bash
# Verify Docker is installed
bash scripts/install.sh check

# If Docker is missing, install it:
bash scripts/install.sh docker
```

### 2. Deploy Vaultwarden

```bash
# Basic deployment (HTTP only, for local/testing)
bash scripts/run.sh deploy --domain vault.local --port 8080

# Production deployment with SSL (requires domain pointing to this server)
bash scripts/run.sh deploy --domain vault.yourdomain.com --ssl --email admin@yourdomain.com
```

### 3. Access Your Vault

Open `https://vault.yourdomain.com` (or `http://localhost:8080` for local).
Create your first account and start storing passwords.

Use any Bitwarden client — set the server URL to your domain.

## Core Workflows

### Workflow 1: Deploy with Docker Compose

**Use case:** Production deployment with persistent data and auto-restart.

```bash
bash scripts/run.sh deploy \
  --domain vault.yourdomain.com \
  --ssl \
  --email admin@yourdomain.com \
  --admin-token "$(openssl rand -base64 48)"
```

**What happens:**
1. Creates `docker-compose.yml` with Vaultwarden + Caddy (SSL)
2. Generates secure admin token
3. Starts containers with auto-restart
4. SSL certificate auto-provisioned via Let's Encrypt

**Output:**
```
✅ Vaultwarden deployed at https://vault.yourdomain.com
🔑 Admin panel: https://vault.yourdomain.com/admin
📋 Admin token saved to: /opt/vaultwarden/.admin-token
🔒 SSL: Let's Encrypt via Caddy (auto-renew)
```

### Workflow 2: Backup Vault Data

**Use case:** Nightly encrypted backup of all vault data.

```bash
# One-time backup
bash scripts/run.sh backup --encrypt --passphrase "your-backup-passphrase"

# Schedule nightly backups (adds crontab entry)
bash scripts/run.sh backup --schedule --encrypt --passphrase "your-backup-passphrase" --keep 30
```

**Output:**
```
✅ Backup created: /opt/vaultwarden/backups/vw-backup-2026-02-24.tar.gz.enc
📦 Size: 2.3 MB (encrypted)
🗓️ Cron: 0 2 * * * (daily at 2 AM)
🧹 Retention: 30 days
```

### Workflow 3: Restore from Backup

**Use case:** Recover vault after server migration or failure.

```bash
bash scripts/run.sh restore \
  --from /opt/vaultwarden/backups/vw-backup-2026-02-24.tar.gz.enc \
  --passphrase "your-backup-passphrase"
```

### Workflow 4: Admin Panel Management

**Use case:** Invite users, disable registration, manage organizations.

```bash
# Get admin token
bash scripts/run.sh admin --show-token

# Disable public registration (admin-only invites)
bash scripts/run.sh admin --disable-signups

# Enable signups for specific domains only
bash scripts/run.sh admin --allowed-domains "yourdomain.com,company.com"

# View registered users
bash scripts/run.sh admin --list-users
```

### Workflow 5: Update Vaultwarden

**Use case:** Pull latest Vaultwarden image and restart.

```bash
bash scripts/run.sh update

# Output:
# 🔄 Pulling latest vaultwarden/server...
# ⏹️ Stopping containers...
# ▶️ Starting updated containers...
# ✅ Vaultwarden updated to v1.32.5
```

### Workflow 6: Health Check & Status

**Use case:** Verify vault is running and healthy.

```bash
bash scripts/run.sh status

# Output:
# ✅ Vaultwarden: running (up 47 days)
# ✅ Caddy (SSL proxy): running
# 🔒 SSL cert: valid until 2026-05-24 (89 days)
# 💾 Data size: 156 MB
# 📦 Last backup: 2026-02-24 02:00 (6 hours ago)
# 👥 Registered users: 3
# 🐳 Image: vaultwarden/server:1.32.5
```

## Configuration

### Environment Variables

```bash
# Required
export VW_DOMAIN="vault.yourdomain.com"

# Optional
export VW_PORT="8080"                    # HTTP port (default: 8080)
export VW_DATA_DIR="/opt/vaultwarden"    # Data directory
export VW_ADMIN_TOKEN=""                 # Admin panel token (auto-generated if empty)
export VW_SIGNUPS_ALLOWED="true"         # Allow public registration
export VW_SMTP_HOST=""                   # SMTP for email invites
export VW_SMTP_FROM=""                   # From address for emails
export VW_SMTP_PORT="587"               # SMTP port
export VW_SMTP_USER=""                   # SMTP username
export VW_SMTP_PASS=""                   # SMTP password
```

### Config File (YAML)

```yaml
# /opt/vaultwarden/config.yaml
domain: vault.yourdomain.com
ssl: true
email: admin@yourdomain.com
port: 8080
data_dir: /opt/vaultwarden
signups_allowed: false
allowed_domains:
  - yourdomain.com
smtp:
  host: smtp.gmail.com
  port: 587
  user: your@gmail.com
  pass: app-password
  from: vault@yourdomain.com
backup:
  enabled: true
  schedule: "0 2 * * *"
  encrypt: true
  keep_days: 30
```

## Advanced Usage

### Run Behind Existing Nginx

If you already have Nginx handling SSL:

```bash
bash scripts/run.sh deploy --domain vault.yourdomain.com --no-proxy --port 8080
```

Then add to your Nginx config:
```nginx
server {
    listen 443 ssl;
    server_name vault.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /notifications/hub {
        proxy_pass http://127.0.0.1:3012;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Email Notifications (SMTP)

```bash
bash scripts/run.sh config --smtp-host smtp.gmail.com --smtp-user you@gmail.com --smtp-pass "app-password"
```

### WebSocket Support (Live Sync)

Already included in the Docker Compose setup. Bitwarden clients will auto-sync when passwords change on other devices.

### Fail2Ban Integration

```bash
# Add Vaultwarden jail to fail2ban
bash scripts/run.sh security --fail2ban

# Enables: ban after 5 failed login attempts for 15 minutes
```

## Troubleshooting

### Issue: "Cannot connect to vault"

**Check:**
1. Container running: `docker ps | grep vaultwarden`
2. Port open: `curl -s http://localhost:8080/alive` (should return empty 200)
3. DNS pointing to server: `dig vault.yourdomain.com`
4. Firewall: `sudo ufw status` — ports 80, 443 must be open

### Issue: "SSL certificate not working"

**Check:**
1. Domain resolves to this server's IP
2. Ports 80 and 443 are open (Caddy needs both for ACME)
3. Caddy logs: `docker logs vaultwarden-caddy`

### Issue: "Admin panel not accessible"

**Check:**
1. Admin token is set: `bash scripts/run.sh admin --show-token`
2. Admin panel enabled: check `ADMIN_TOKEN` env var is not empty
3. Navigate to: `https://vault.yourdomain.com/admin`

### Issue: "Bitwarden app can't connect"

**Fix:**
1. In Bitwarden app → Settings → Self-hosted → Server URL
2. Enter: `https://vault.yourdomain.com` (no trailing slash)
3. Ensure WebSocket endpoint is reachable

## Security Notes

1. **Admin token** — Treat like a root password. Store securely.
2. **Backups** — Always encrypt. Contains all vault data.
3. **Updates** — Run `bash scripts/run.sh update` monthly for security patches.
4. **Fail2ban** — Recommended for public-facing instances.
5. **2FA** — Enable TOTP on your vault account immediately after setup.

## Dependencies

- `docker` (20.10+) with `docker compose` v2
- `openssl` (for backup encryption + token generation)
- `curl` (for health checks)
- `jq` (for JSON parsing)
- `cron` (for scheduled backups)
- Optional: `fail2ban` (brute-force protection)
