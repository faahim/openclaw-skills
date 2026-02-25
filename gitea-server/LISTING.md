# Listing Copy: Gitea Server Manager

## Metadata
- **Type:** Skill
- **Name:** gitea-server
- **Display Name:** Gitea Server Manager
- **Categories:** [dev-tools, automation]
- **Icon:** 🍵
- **Dependencies:** [bash, curl, git, sqlite3]

## Tagline
Self-hosted Git server — Install, manage repos, mirror GitHub, and automate backups with Gitea

## Description

Running your own Git server means full control over your code, no vendor lock-in, and private repos without monthly fees. But setting up Gitea manually means wrestling with binaries, systemd configs, database setup, and Nginx proxying.

Gitea Server Manager handles the entire lifecycle. One command installs Gitea with proper system user, directories, and systemd service. Manage repositories, users, webhooks, and mirrors through the CLI — no web UI needed. Schedule nightly backups with automatic rotation.

**What it does:**
- 🍵 One-command Gitea installation (auto-detects architecture)
- 📦 Create, list, delete, and mirror repositories via API
- 👥 User management — create admins, regular users, disable accounts
- 🔗 Webhook management for CI/CD integration
- 🪞 Mirror entire GitHub organizations automatically
- 💾 Automated backups with cron scheduling and rotation
- 🔄 One-command updates to latest version
- 🌐 Generate Nginx reverse proxy config with SSL support

Perfect for developers, teams, and self-hosters who want a lightweight GitHub alternative running on their own infrastructure.

## Core Capabilities

1. Automated installation — Downloads correct binary, creates system user, configures systemd
2. Repository management — Create, list, delete repos via CLI without web UI
3. GitHub mirroring — Mirror individual repos or entire orgs with sync intervals
4. User administration — Create admins and users, manage access
5. Webhook automation — Add webhooks for CI/CD, list and manage hooks
6. Scheduled backups — Nightly backups with configurable retention
7. One-click updates — Update Gitea to latest or specific version
8. Nginx proxy generation — SSL-ready reverse proxy configuration
9. Multi-database support — SQLite (simple) or PostgreSQL/MySQL (production)
10. Restore from backup — Full disaster recovery from backup archives
