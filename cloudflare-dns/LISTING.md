# Listing Copy: Cloudflare DNS Manager

## Metadata
- **Type:** Skill
- **Name:** cloudflare-dns
- **Display Name:** Cloudflare DNS Manager
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [curl, jq]
- **Icon:** 🌐

## Tagline
Manage Cloudflare DNS records, cache, and zones from the command line

## Description

Updating DNS records through the Cloudflare dashboard is slow and error-prone — especially when you're managing multiple zones or need quick changes during deployments. One wrong click and your site is down.

Cloudflare DNS Manager gives your OpenClaw agent full control over your DNS. List zones, add/update/delete records (A, AAAA, CNAME, MX, TXT), purge cache, check propagation across global DNS servers, and even set up dynamic DNS for home servers — all from a single bash script.

**What it does:**
- 🌐 List and manage all your Cloudflare zones
- ➕ Add, update, delete any DNS record type
- 🚀 Purge cache (all, by URL, or by tag)
- 🔍 Check DNS propagation across Google, Cloudflare, OpenDNS, Quad9
- 🏠 Dynamic DNS — auto-update A records with your current IP
- 📦 Export/import records (JSON or BIND format) for backup/migration
- 📊 Zone analytics — requests, bandwidth, threats

**Who it's for:** Developers, sysadmins, and anyone managing websites on Cloudflare who wants fast, scriptable DNS management without touching the dashboard.

## Core Capabilities

1. Zone management — List all zones, check status
2. DNS CRUD — Add, update, delete A/AAAA/CNAME/MX/TXT/SRV/CAA records
3. Proxy toggle — Enable/disable Cloudflare proxy per record
4. Cache purge — Purge everything, specific URLs, or cache tags
5. DNS propagation — Check records across 4 major public DNS servers
6. Dynamic DNS — Auto-update records with current public IP
7. Export/Import — Backup and restore DNS configs (JSON + BIND)
8. Zone analytics — View request counts, bandwidth, and threat data
9. Batch operations — Pipe record files for bulk changes
10. MX priority — Set mail server priority for MX records

## Dependencies
- `bash` (4.0+)
- `curl`
- `jq`
- `dig` (optional, for propagation checks)

## Installation Time
**2 minutes** — Set API token, run first command
