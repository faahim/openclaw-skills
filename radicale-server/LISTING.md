# Listing Copy: Radicale Calendar & Contacts Server

## Metadata
- **Type:** Skill
- **Name:** radicale-server
- **Display Name:** Radicale Calendar & Contacts Server
- **Categories:** [home, productivity]
- **Price:** $12
- **Dependencies:** [python3, pip]
- **Icon:** 🗓️

## Tagline

Self-hosted calendar & contacts server — sync all your devices without Google or iCloud

## Description

Tired of Google and Apple owning your calendar and contacts data? Radicale is a lightweight, privacy-first CalDAV/CardDAV server that runs on your own machine. Your data never leaves your control.

This skill installs and configures Radicale in under 5 minutes. It handles Python dependencies, bcrypt authentication, user management, automated backups, and optional HTTPS setup. Works with every calendar and contacts app — iOS, Android, Thunderbird, GNOME, macOS.

**What you get:**
- 🗓️ Full calendar sync (events, to-dos, journals) across all devices
- 👥 Contact sync (address books) via standard CardDAV
- 🔒 Bcrypt-secured user accounts with htpasswd auth
- 💾 Automated daily backups with configurable retention
- 🌐 Reverse proxy configs for Nginx and Caddy (HTTPS)
- 🖥️ Systemd service for auto-start on boot
- 📥 Import existing .ics calendars and .vcf contacts
- 📊 Status dashboard showing users, storage, uptime

Perfect for privacy-conscious users, self-hosters, families wanting shared calendars, or anyone tired of Big Tech controlling their schedule.

## Quick Start Preview

```bash
# Install Radicale
bash scripts/install.sh

# Create a user
bash scripts/manage-users.sh add myuser mypassword

# Connect your phone to http://your-server:5232 — done!
```

## Core Capabilities

1. One-command install — Python + Radicale + bcrypt in one script
2. User management — Add, remove, change passwords via CLI
3. CalDAV server — Sync calendars with any standard app
4. CardDAV server — Sync contacts across all devices
5. Web UI — Built-in browser interface for managing collections
6. Systemd integration — Auto-start on boot, managed restarts
7. Automated backups — Daily compressed backups with retention cleanup
8. HTTPS support — Self-signed certs or reverse proxy configs
9. Import tool — Bring existing .ics and .vcf files
10. Lightweight — ~10MB RAM, runs on a Raspberry Pi
