# Listing Copy: Private Docker Registry

## Metadata
- **Type:** Skill
- **Name:** docker-registry
- **Display Name:** Private Docker Registry
- **Categories:** [dev-tools, automation]
- **Price:** $15
- **Dependencies:** [docker, htpasswd, openssl]

## Tagline

Deploy a private Docker registry — push images without Hub rate limits or privacy concerns

## Description

Docker Hub's rate limits and privacy policies make self-hosting essential for serious development. But setting up a private registry with proper authentication, TLS, and garbage collection is tedious — certificate generation, htpasswd files, config YAML, storage backends.

Private Docker Registry automates the entire setup in under 5 minutes. One script deploys a production-ready registry with authentication, self-signed or custom TLS, and automatic garbage collection. A management script handles everything else — listing images, inspecting layers, deleting tags, user management, backups, and storage monitoring.

**What it does:**
- 🐳 One-command registry deployment with Docker
- 🔐 Authentication out of the box (htpasswd-based)
- 🔒 TLS with auto-generated self-signed certs or custom certificates
- 📦 List, inspect, delete, and manage images
- 🧹 Garbage collection with scheduled cleanup
- ☁️ S3-compatible backend storage support
- 🪞 Docker Hub pull-through cache mode
- 💾 Full backup and restore
- 👥 Multi-user management

## Core Capabilities

1. One-command deployment — Registry running with auth + TLS in 5 minutes
2. Image management — List repos, inspect layers, delete tags from CLI
3. Garbage collection — Reclaim space with dry-run and scheduled cleanup
4. Pull-through cache — Mirror Docker Hub locally, avoid rate limits
5. S3 storage backend — Store images in AWS S3 or compatible services
6. User management — Add, remove, list registry users
7. TLS certificates — Auto-generated self-signed or bring your own
8. Backup & restore — Full registry data backup to tar.gz
9. Health monitoring — Check registry status, storage usage, cert expiry
10. Production-ready — Auto-restart, proper logging, content-addressable storage

## Dependencies
- `docker` (container runtime)
- `htpasswd` (from apache2-utils or httpd-tools)
- `openssl` (TLS certificate generation)
- `python3` (JSON parsing in management scripts)

## Installation Time
**5 minutes** — Run setup script, start pushing images
