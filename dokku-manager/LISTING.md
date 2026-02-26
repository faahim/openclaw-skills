# Listing Copy: Dokku Manager

## Metadata
- **Type:** Skill
- **Name:** dokku-manager
- **Display Name:** Dokku Manager
- **Categories:** [dev-tools, automation]
- **Icon:** 🚀
- **Dependencies:** [bash, curl, docker, git]

## Tagline

Deploy apps with git push — install and manage your own Heroku on any server

## Description

Tired of paying $25/month per dyno on Heroku? Want the simplicity of `git push` deploys on your own $5 VPS? Dokku Manager sets up and manages Dokku — the open-source, self-hosted PaaS that gives you Heroku-like deploys on any Ubuntu/Debian server.

This skill handles the full lifecycle: install Dokku, create apps, attach databases (Postgres, Redis, MySQL, MongoDB), configure custom domains, auto-provision SSL with Let's Encrypt, scale processes, and manage deployments. Everything through simple commands your OpenClaw agent can run.

**What it does:**
- 🚀 One-command Dokku installation with Docker setup
- 📦 Create and manage unlimited apps
- 🗄️ Attach databases with one command (Postgres, Redis, MySQL, MongoDB)
- 🔐 Auto SSL via Let's Encrypt with cron-based renewal
- ⚡ Zero-downtime deploys with health checks
- 📊 Process scaling, log viewing, and status reports
- 🔧 Plugin management for 12+ official Dokku plugins
- 💾 Database backup and restore

Perfect for indie hackers, developers, and small teams who want Heroku simplicity without Heroku pricing. Deploy Node.js, Python, Ruby, Go, or any Dockerized app.

## Core Capabilities

1. Automated installation — Install Dokku + Docker with a single script
2. App lifecycle — Create, deploy, scale, restart, destroy apps
3. Database provisioning — Postgres, Redis, MySQL, MongoDB, Elasticsearch, and more
4. SSL automation — Let's Encrypt provisioning and auto-renewal via cron
5. Domain management — Custom domains, vhost routing, global domains
6. Zero-downtime deploys — Rolling deploys with configurable health checks
7. Environment config — Set/unset env vars, auto-restart on changes
8. Process scaling — Scale web workers, background jobs independently
9. Persistent storage — Mount host volumes into app containers
10. Docker options — Memory limits, CPU constraints, custom flags
11. Buildpack support — Heroku buildpacks, Dockerfiles, Cloud Native Buildpacks
12. Plugin ecosystem — Install 12+ official plugins for databases, caching, SSL
