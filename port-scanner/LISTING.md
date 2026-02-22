# Listing Copy: Port Scanner & Security Auditor

## Metadata
- **Type:** Skill
- **Name:** port-scanner
- **Display Name:** Port Scanner & Security Auditor
- **Categories:** [security, dev-tools]
- **Price:** $12
- **Dependencies:** [nmap, jq, bash]
- **Icon:** 🔒

## Tagline
Scan ports, detect services, and audit your server's security posture in minutes.

## Description

Manually checking which ports are open on your servers is tedious and error-prone. Worse, a single exposed database port can lead to a full data breach. You need automated, repeatable security scanning.

Port Scanner & Security Auditor wraps nmap — the industry-standard network scanner — in an easy-to-use skill with built-in security intelligence. Scan hosts, detect services and versions, flag dangerous exposures (like Redis or MongoDB open to the internet), and generate structured reports. No external services, no monthly fees.

**What it does:**
- 🔍 Scan single hosts, IP ranges, or entire subnets
- 🛡️ Flag critical exposures (databases, caches, Docker API open to internet)
- 📊 JSON + text reports for automation or human review
- 🔄 Compare scans over time to detect drift (new ports opening)
- 🔔 Alert via Telegram or email on critical findings
- ⏰ Schedule weekly audits via cron
- 🎯 Customizable security rules (define what's critical for YOUR setup)
- 📡 Network discovery mode to map all hosts on a subnet

Perfect for developers, sysadmins, and security-conscious teams who want automated port auditing without enterprise tool complexity.

## Core Capabilities
1. Quick scan — Top 1000 ports in ~30 seconds
2. Full audit — All 65535 ports with service/OS detection
3. Subnet discovery — Find all live hosts on a network
4. Security analysis — Auto-flag dangerous port exposures
5. Drift detection — Compare scans, alert on changes
6. JSON output — Pipe to jq or feed into automation
7. Telegram/email alerts — Get notified on critical findings
8. Custom rules — Define your own critical/warning port lists
9. Multi-target — Scan from a file of hosts
10. Cron-ready — Schedule recurring security audits
