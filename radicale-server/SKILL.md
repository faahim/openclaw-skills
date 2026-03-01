---
name: radicale-server
description: >-
  Self-hosted calendar and contacts server (CalDAV/CardDAV) — sync across all your devices without Google or iCloud.
categories: [home, productivity]
dependencies: [python3, pip]
---

# Radicale Calendar & Contacts Server

## What This Does

Run your own calendar and contacts server in minutes. Radicale is a lightweight CalDAV/CardDAV server that syncs calendars, to-dos, and contacts across all your devices — phones, laptops, tablets. No Google, no iCloud, no monthly fees. Your data stays on your machine.

**Example:** "Install Radicale, create users, sync your iPhone/Android calendar and contacts to your own server."

## Quick Start (5 minutes)

### 1. Install & Configure

```bash
bash scripts/install.sh
```

This installs Radicale, creates a config, sets up authentication, and starts the server.

### 2. Create Your First User

```bash
bash scripts/manage-users.sh add myuser mypassword
```

### 3. Access the Web Interface

Open `http://localhost:5232` in your browser. Log in with your credentials. Create calendars and address books from the web UI.

### 4. Connect Your Devices

**iPhone/iPad:**
1. Settings → Calendar → Accounts → Add Account → Other
2. Add CalDAV Account:
   - Server: `your-server-ip:5232`
   - User: `myuser`
   - Password: `mypassword`

**Android (DAVx⁵ app):**
1. Install DAVx⁵ from F-Droid or Play Store
2. Add account → Login with URL and user name
3. Base URL: `http://your-server-ip:5232`

**Thunderbird:**
1. Calendar → New Calendar → On the Network
2. Location: `http://your-server-ip:5232/myuser/calendar.ics/`

## Core Workflows

### Workflow 1: Personal Calendar + Contacts

**Use case:** Replace Google Calendar and Google Contacts

```bash
# Install and start
bash scripts/install.sh

# Create user
bash scripts/manage-users.sh add john secretpass

# Server is running at http://localhost:5232
# Connect all your devices using the credentials above
```

### Workflow 2: Family/Team Shared Calendars

**Use case:** Share calendars between family members or a small team

```bash
# Create multiple users
bash scripts/manage-users.sh add alice pass1
bash scripts/manage-users.sh add bob pass2

# Each user creates their own calendars via web UI
# Share calendars by granting read/write access in Radicale's rights config
```

Edit `~/.config/radicale/rights` to allow sharing:
```ini
[shared]
user: .+
collection: shared/{collection}
permissions: rw
```

### Workflow 3: Run Behind Reverse Proxy (HTTPS)

**Use case:** Secure access over the internet

```bash
# Configure for reverse proxy mode
bash scripts/configure-proxy.sh --domain cal.example.com

# Then in your Nginx/Caddy config, proxy to localhost:5232
# Example Caddy:
# cal.example.com {
#   reverse_proxy localhost:5232
# }
```

### Workflow 4: Automated Backup

**Use case:** Back up all calendar and contact data

```bash
# One-time backup
bash scripts/backup.sh

# Output: ~/radicale-backups/radicale-backup-2026-03-01.tar.gz

# Schedule daily backup via cron
bash scripts/backup.sh --cron
# Adds: 0 2 * * * /path/to/scripts/backup.sh >> /var/log/radicale-backup.log 2>&1
```

## Configuration

### Server Config (`~/.config/radicale/config`)

```ini
[server]
hosts = 0.0.0.0:5232

[auth]
type = htpasswd
htpasswd_filename = ~/.config/radicale/users
htpasswd_encryption = bcrypt

[storage]
filesystem_folder = ~/.local/share/radicale/collections

[logging]
level = warning
```

### Key Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `hosts` | `localhost:5232` | Bind address (use `0.0.0.0:5232` for network access) |
| `htpasswd_encryption` | `bcrypt` | Password hashing (bcrypt recommended) |
| `filesystem_folder` | `~/.local/share/radicale/collections` | Where data is stored |
| `max_content_length` | `100000000` | Max upload size (100MB) |

### Environment Variables

```bash
# Override config location
export RADICALE_CONFIG=~/.config/radicale/config

# Override storage location
export RADICALE_STORAGE_FOLDER=/path/to/data
```

## Advanced Usage

### Run as Systemd Service

```bash
bash scripts/install.sh --systemd

# This creates and enables a systemd user service
# Starts automatically on boot
# Manage with:
systemctl --user status radicale
systemctl --user restart radicale
systemctl --user stop radicale
```

### User Management

```bash
# Add user
bash scripts/manage-users.sh add username password

# Remove user
bash scripts/manage-users.sh remove username

# Change password
bash scripts/manage-users.sh passwd username newpassword

# List users
bash scripts/manage-users.sh list
```

### Import Existing Data

```bash
# Import .ics calendar file
bash scripts/import.sh --user myuser --type calendar --file exported-calendar.ics

# Import .vcf contacts file
bash scripts/import.sh --user myuser --type contacts --file contacts.vcf
```

### Storage Info

```bash
# Show storage stats
bash scripts/status.sh

# Output:
# Radicale Server Status
# ─────────────────────
# Status:     Running (PID 12345)
# Address:    http://0.0.0.0:5232
# Users:      3
# Calendars:  5
# Contacts:   2 address books
# Storage:    12.4 MB in ~/.local/share/radicale/collections
# Uptime:     3 days, 14 hours
```

## Troubleshooting

### Issue: "Connection refused" from other devices

**Fix:** Radicale defaults to localhost only. Change bind address:
```bash
# Edit config
sed -i 's/hosts = localhost:5232/hosts = 0.0.0.0:5232/' ~/.config/radicale/config
# Restart
bash scripts/install.sh --restart
```

Also check firewall:
```bash
sudo ufw allow 5232/tcp
```

### Issue: "Authentication failed"

**Check:**
1. User exists: `bash scripts/manage-users.sh list`
2. Password is correct: re-set with `bash scripts/manage-users.sh passwd user newpass`
3. bcrypt is installed: `python3 -c "import bcrypt; print('OK')"`

### Issue: Calendar not syncing on mobile

**Check:**
1. Use the full URL: `http://server:5232/username/calendar-name.ics/`
2. DAVx⁵ on Android: use base URL `http://server:5232` and let it discover
3. iOS: ensure CalDAV (not CardDAV) account type for calendars

### Issue: Want HTTPS without reverse proxy

```bash
# Generate self-signed cert (for testing)
bash scripts/configure-proxy.sh --self-signed

# Or use Let's Encrypt cert paths in config
bash scripts/configure-proxy.sh --cert /etc/letsencrypt/live/example.com/fullchain.pem \
                                 --key /etc/letsencrypt/live/example.com/privkey.pem
```

## Key Principles

1. **Privacy first** — Your data never leaves your server
2. **Lightweight** — Uses ~10MB RAM, runs on a Raspberry Pi
3. **Standard protocols** — CalDAV/CardDAV work with every calendar/contacts app
4. **Simple storage** — Plain files on disk (easy to back up, move, inspect)
5. **No database** — No MySQL/Postgres required

## Dependencies

- `python3` (3.8+)
- `pip` (for installing Radicale)
- `bcrypt` Python package (for password hashing)
- Optional: `systemd` (for auto-start service)
- Optional: Nginx/Caddy (for HTTPS reverse proxy)
