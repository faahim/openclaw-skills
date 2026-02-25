# Listing Copy: Authelia Authentication Gateway

## Metadata
- **Type:** Skill
- **Name:** authelia-gateway
- **Display Name:** Authelia Authentication Gateway
- **Categories:** [security, automation]
- **Price:** $15
- **Dependencies:** [docker, docker-compose]

## Tagline

Protect self-hosted services with SSO and 2FA — one login for everything.

## Description

Exposing self-hosted services to the internet without authentication is a security nightmare. Each service has its own login system (or worse, none at all), and managing access across Gitea, Grafana, Jellyfin, and more becomes a mess.

Authelia Authentication Gateway installs and configures Authelia as a reverse proxy companion that adds Single Sign-On (SSO), two-factor authentication (TOTP, WebAuthn, Duo), and fine-grained access control policies to every service behind your Nginx or Traefik proxy. One portal, one login, full control.

**What it does:**
- 🔐 Single Sign-On across all your self-hosted services
- 📱 Two-factor auth (TOTP apps, hardware keys via WebAuthn, Duo Push)
- 🛡️ Access control policies: bypass, one_factor, two_factor per domain/path/user/group
- 👥 User management with argon2id password hashing
- 📧 SMTP notifications for password resets and 2FA enrollment
- 🐳 Docker Compose deployment with Redis session store
- 📊 Auth event logging and failed login monitoring
- 💾 Backup and restore scripts for disaster recovery
- ⚡ Works with Nginx and Traefik (config snippets included)
- 🏠 Bypass auth for trusted local networks

Perfect for homelabbers, self-hosters, and anyone running services that need proper authentication without the complexity of Keycloak or Authentik.

## Core Capabilities

1. Automated setup — Generate full config, secrets, and Docker Compose in one command
2. User management — Add/remove users, reset passwords with argon2id hashing
3. 2FA enrollment — TOTP and WebAuthn (hardware keys) out of the box
4. Access policies — Fine-grained rules by domain, path, user, group, and network
5. Nginx integration — Copy-paste config snippets for auth_request
6. Traefik integration — Docker labels for forwardAuth middleware
7. SMTP configuration — Password reset emails and 2FA notifications
8. Auth log monitoring — Track successful/failed logins, detect attacks
9. Backup & restore — One-command backup including secrets and database
10. Health checks — Built-in Docker healthcheck and API endpoint

## Dependencies
- Docker (20.10+)
- Docker Compose (v2+)
- openssl (secret generation)

## Installation Time
**10 minutes** — Run setup, add user, start containers, configure proxy
