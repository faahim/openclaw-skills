# Listing Copy: DNS & WHOIS Lookup

## Metadata
- **Type:** Skill
- **Name:** dns-whois-lookup
- **Display Name:** DNS & WHOIS Lookup Tool
- **Categories:** [dev-tools, data]
- **Price:** $8
- **Dependencies:** [dig, whois, host, jq, bash]
- **Icon:** 🌐

## Tagline
Query DNS records, check WHOIS data, and diagnose domain issues from the terminal.

## Description

Checking DNS records shouldn't require opening five browser tabs. When you're debugging email delivery, migrating nameservers, or just need to know when a domain expires, you need fast answers from the command line.

DNS & WHOIS Lookup gives your OpenClaw agent complete domain intelligence. Query any record type (A, AAAA, MX, TXT, CNAME, NS, SOA, CAA), pull WHOIS registration data with expiry warnings, check propagation across 8 global DNS servers, and run health checks that catch misconfigurations like missing DMARC or weak SPF records.

**What it does:**
- 🔍 Query all DNS record types with pretty or JSON output
- 📋 WHOIS lookup with expiry countdown and registrar details
- 🌍 Propagation check across 8 global nameservers
- 🏥 DNS health audit (SPF, DMARC, DKIM, CAA, TTL analysis)
- 📧 Email deliverability check (SPF + DKIM + DMARC validation)
- 🔄 Reverse DNS (PTR) lookups
- ⚖️ Compare records between two nameservers
- 📊 JSON output for scripting and automation

Perfect for developers, sysadmins, and anyone managing domains who wants DNS answers without leaving the terminal.

## Core Capabilities

1. Full DNS report — All record types in one command
2. WHOIS registration data — Registrar, dates, nameservers, expiry warning
3. Propagation checker — 8 global DNS servers, consistency report
4. Health audit — 9-point check covering A, AAAA, NS, MX, SPF, DMARC, CAA, SOA, TTL
5. Email deliverability — SPF validity, DKIM selectors, DMARC policy strength
6. Reverse DNS — PTR record lookups from IP
7. Nameserver comparison — Side-by-side diff for migrations
8. JSON output — Pipe to jq, store in files, use in scripts
9. Batch lookups — Process domain lists
10. Customizable servers — Use your preferred DNS resolvers
