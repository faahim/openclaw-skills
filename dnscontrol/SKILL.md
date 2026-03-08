---
name: dnscontrol
description: >-
  Manage DNS records as code across multiple providers. Version-controlled, auditable DNS changes with preview before apply.
categories: [dev-tools, automation]
dependencies: [bash, curl, jq]
---

# DNSControl — DNS as Code

## What This Does

Manage DNS records declaratively using DNSControl by Stack Overflow. Define your DNS zones in a JavaScript config file, preview changes before applying, and keep your DNS versioned in git. Supports 40+ providers including Cloudflare, AWS Route53, Google Cloud DNS, DigitalOcean, Hetzner, and more.

**Example:** "Define all DNS records in `dnsconfig.js`, run `dnscontrol preview` to see pending changes, then `dnscontrol push` to apply."

## Quick Start (5 minutes)

### 1. Install DNSControl

```bash
bash scripts/install.sh
```

### 2. Initialize a DNS Config

```bash
bash scripts/init.sh --provider cloudflare --domain example.com
```

This creates:
- `dnsconfig.js` — Your DNS zone definitions
- `creds.json` — Provider API credentials (gitignored)

### 3. Preview Changes

```bash
dnscontrol preview
```

Output:
```
******************** Domain: example.com
----- Getting nameservers from: cloudflare
----- DNS Provider: cloudflare...
#1: CREATE A example.com 203.0.113.1 ttl=300
#2: CREATE CNAME www.example.com example.com. ttl=300
#3: CREATE MX example.com 10 mail.example.com. ttl=300
Done. 3 corrections.
```

### 4. Apply Changes

```bash
dnscontrol push
```

## Core Workflows

### Workflow 1: Add DNS Records

Edit `dnsconfig.js`:

```javascript
D("example.com", REG_NONE, DnsProvider(DSP_CLOUDFLARE),
    A("@", "203.0.113.1"),
    A("@", "203.0.113.2"),
    CNAME("www", "@"),
    CNAME("blog", "@"),
    MX("@", 10, "mail.example.com."),
    MX("@", 20, "mail2.example.com."),
    TXT("@", "v=spf1 include:_spf.google.com ~all"),
    CAA("@", "issue", "letsencrypt.org"),
END);
```

Then preview and push:

```bash
dnscontrol preview
dnscontrol push
```

### Workflow 2: Manage Multiple Domains

```javascript
// dnsconfig.js
var DSP_CF = NewDnsProvider("cloudflare");
var DSP_R53 = NewDnsProvider("route53");

D("example.com", REG_NONE, DnsProvider(DSP_CF),
    A("@", "203.0.113.1"),
    CNAME("www", "@"),
END);

D("example.org", REG_NONE, DnsProvider(DSP_R53),
    A("@", "198.51.100.1"),
    CNAME("www", "@"),
END);
```

### Workflow 3: Import Existing DNS Records

```bash
# Fetch current records from your provider
dnscontrol get-zones --format js cloudflare - example.com >> dnsconfig.js
```

### Workflow 4: Audit DNS Changes

```bash
# Preview shows exact diff — nothing changes until you push
dnscontrol preview

# Keep config in git for full audit trail
git add dnsconfig.js
git commit -m "Add blog CNAME record"
git push
```

### Workflow 5: Check Zone Validity

```bash
# Validate config syntax without contacting providers
dnscontrol check
```

## Configuration

### Provider Credentials (`creds.json`)

```json
{
    "cloudflare": {
        "TYPE": "CLOUDFLAREAPI",
        "apitoken": "YOUR_CF_API_TOKEN"
    },
    "route53": {
        "TYPE": "ROUTE53",
        "KeyId": "YOUR_AWS_KEY_ID",
        "SecretKey": "YOUR_AWS_SECRET_KEY"
    },
    "gcloud": {
        "TYPE": "GCLOUD",
        "project": "my-project-id",
        "private_key": "-----BEGIN PRIVATE KEY-----\n..."
    },
    "digitalocean": {
        "TYPE": "DIGITALOCEAN",
        "token": "YOUR_DO_TOKEN"
    },
    "hetzner": {
        "TYPE": "HETZNER",
        "api_key": "YOUR_HETZNER_DNS_KEY"
    }
}
```

**Security:** Add `creds.json` to `.gitignore`. Never commit credentials.

### Environment Variables (Alternative)

```bash
export CLOUDFLARE_API_TOKEN="your-token"
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
```

Then in `creds.json`:
```json
{
    "cloudflare": {
        "TYPE": "CLOUDFLAREAPI",
        "apitoken": "$CLOUDFLARE_API_TOKEN"
    }
}
```

## Advanced Usage

### Macros for Common Patterns

```javascript
// Define reusable record sets
var GOOGLE_WORKSPACE_MX = [
    MX("@", 1, "aspmx.l.google.com."),
    MX("@", 5, "alt1.aspmx.l.google.com."),
    MX("@", 5, "alt2.aspmx.l.google.com."),
    MX("@", 10, "alt3.aspmx.l.google.com."),
    MX("@", 10, "alt4.aspmx.l.google.com."),
];

D("example.com", REG_NONE, DnsProvider(DSP_CF),
    A("@", "203.0.113.1"),
    GOOGLE_WORKSPACE_MX,
END);
```

### Conditional Records

```javascript
var defined_ip = "203.0.113.1";

D("example.com", REG_NONE, DnsProvider(DSP_CF),
    A("@", defined_ip),
    A("staging", defined_ip, TTL(60)),
    CNAME("www", "@"),
END);
```

### CI/CD Integration

```bash
# In your CI pipeline:
# 1. Preview on PR
dnscontrol preview 2>&1 | tee dns-preview.txt

# 2. Push on merge to main
dnscontrol push
```

### Run as Cron Audit

```bash
# Daily check: detect drift between config and live DNS
bash scripts/audit.sh
```

## Supported Providers

40+ providers including: Cloudflare, AWS Route53, Google Cloud DNS, Azure DNS, DigitalOcean, Hetzner, Vultr, Linode, Gandi, OVH, Namecheap, Name.com, NS1, DNSimple, PowerDNS, BIND, and more.

Full list: https://docs.dnscontrol.org/service-providers

## Troubleshooting

### Issue: "command not found: dnscontrol"

**Fix:** Re-run install script:
```bash
bash scripts/install.sh
```

### Issue: "authentication failed"

**Check:**
1. Credentials in `creds.json` are correct
2. API token has DNS edit permissions
3. For Cloudflare: use API Token (not Global API Key) with Zone:DNS:Edit scope

### Issue: "zone not found"

**Check:**
1. Domain is added to your provider account
2. Provider type matches in `creds.json`
3. Domain name is spelled correctly in `dnsconfig.js`

### Issue: Preview shows unexpected deletions

DNSControl is **authoritative** — it will delete records not in your config. To import existing records first:
```bash
dnscontrol get-zones --format js <provider> - <domain>
```

## Key Principles

1. **Preview before push** — Always run `preview` to see what will change
2. **Version control** — Keep `dnsconfig.js` in git
3. **Never commit creds** — Use `.gitignore` for `creds.json`
4. **Import first** — When managing existing domains, import records before pushing
5. **One source of truth** — All DNS changes go through `dnsconfig.js`

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `dnscontrol` (installed by `scripts/install.sh`)
- Provider API credentials
