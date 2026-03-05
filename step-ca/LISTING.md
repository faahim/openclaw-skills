# Listing Copy: Step-CA Private Certificate Authority

## Metadata
- **Type:** Skill
- **Name:** step-ca
- **Display Name:** Step-CA — Private Certificate Authority
- **Categories:** [security, dev-tools]
- **Icon:** 🔐
- **Price:** $15
- **Dependencies:** [step-cli, step-ca, bash, curl, jq]

## Tagline

Run your own Certificate Authority — Issue TLS certs for internal services in minutes

## Description

### The Problem

Internal services running on plain HTTP. Self-signed certs that every browser screams about. Buying certs for `*.internal.lan` that no public CA will issue. You need real TLS for your homelab, dev environment, and internal APIs — without the pain.

### The Solution

Step-CA sets up a private Certificate Authority using Smallstep's battle-tested `step-ca`. Issue proper TLS certificates for any internal domain, auto-renew them, and even use standard ACME protocol so Caddy, Traefik, and certbot work out of the box with your private CA.

### Key Features

- 🔐 **Full private CA** — Issue certs for any domain, including internal and wildcard
- ⚡ **10-minute setup** — Install, init, start, issue. Done.
- 🔄 **Auto-renewal** — Cron-based cert renewal, never expire again
- 🌐 **ACME support** — Works with Caddy, Traefik, certbot, any ACME client
- 🤝 **mTLS** — Issue client certificates for service-to-service authentication
- 🖥️ **System trust** — One command to trust CA system-wide (Linux + macOS)
- 🔑 **SSH certificates** — Optional SSH CA for host and user certs
- 📦 **Systemd service** — Run as a proper daemon with auto-restart
- 📋 **Cert management** — Issue, renew, inspect, verify, revoke, list

### Who It's For

Developers, homelabbers, and sysadmins who need proper TLS for internal services without the cost and complexity of public CAs.

## Quick Start Preview

```bash
bash scripts/install.sh                              # Install step-cli + step-ca
bash scripts/setup-ca.sh --name "My CA" --dns localhost  # Initialize CA
bash scripts/manage.sh start                         # Start CA server
bash scripts/cert.sh issue myapp.internal.lan        # Issue first cert ✅
```

## Core Capabilities

1. **CA initialization** — Create root + intermediate CA with one command
2. **Certificate issuance** — Issue server certs with custom SANs, lifetimes, key types
3. **Client certificates** — mTLS for zero-trust service authentication
4. **ACME protocol** — Let's Encrypt-compatible provisioner for automated cert management
5. **Auto-renewal** — Cron-based renewal with configurable intervals
6. **System trust** — Install root CA on Linux (apt/yum/pacman) and macOS
7. **Systemd integration** — Install as daemon with proper service management
8. **SSH certificates** — Optional SSH CA for host and user authentication
9. **Certificate lifecycle** — Issue, renew, inspect, verify, revoke, list all certs
10. **Cross-platform** — Linux (amd64/arm64) and macOS (Homebrew)
