# Listing Copy: mkcert Local SSL

## Metadata
- **Type:** Skill
- **Name:** mkcert-local-ssl
- **Display Name:** mkcert Local SSL
- **Categories:** [dev-tools, security]
- **Price:** $8
- **Dependencies:** [mkcert, bash, openssl]

## Tagline
Generate locally-trusted HTTPS certificates — no more browser SSL warnings in development

## Description

Every developer has clicked through "Your connection is not private" warnings in local development. Self-signed certs trigger browser warnings, break service workers, and make testing OAuth/WebRTC impossible. You need real trusted HTTPS locally.

mkcert Local SSL installs [mkcert](https://github.com/nicerloop/mkcert), creates a local Certificate Authority trusted by your OS and browsers, and generates certificates for any local domain — localhost, *.local.dev, custom hostnames. One command, zero warnings.

**What it does:**
- 🔐 Install mkcert and create a trusted local CA (one-time)
- 📜 Generate certs for any domain: localhost, wildcards, IPs
- 📋 List and manage all generated certificates
- 🔍 Show cert details: domains, expiry, CA status
- 🗑️ Remove certs and uninstall CA when done
- 💻 Works on Linux (apt/dnf/pacman/brew) and macOS (brew)

**Who it's for:** Developers who need HTTPS in local development — for testing OAuth flows, service workers, WebRTC, or any HTTPS-only API.

## Core Capabilities

1. Auto-install mkcert — detects OS/arch, installs binary + dependencies
2. Local CA setup — creates and trusts a root CA (system + browser)
3. Multi-domain certs — localhost, custom domains, wildcards, IP addresses
4. Certificate listing — shows all certs with domains and expiry dates
5. Custom output paths — generate certs directly into your project
6. Firefox support — installs certutil for Firefox trust (Linux)
7. Status dashboard — mkcert version, CA location, cert count
8. Clean removal — uninstall CA, remove individual certs
9. Integration examples — Node.js, Vite, Nginx, Caddy, Docker Compose

## Dependencies
- `bash` (4.0+)
- `curl` (for downloading mkcert)
- `openssl` (for cert inspection)
- Optional: `libnss3-tools` (Firefox trust on Linux)

## Installation Time
**3 minutes** — install mkcert, set up CA, generate first cert
