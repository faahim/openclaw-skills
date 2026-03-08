# Listing Copy: DNSControl

## Metadata
- **Type:** Skill
- **Name:** dnscontrol
- **Display Name:** DNSControl — DNS as Code
- **Categories:** [dev-tools, automation]
- **Icon:** 🌐
- **Dependencies:** [bash, curl]

## Tagline

"Manage DNS records as code — preview changes before applying across 40+ providers"

## Description

Manually editing DNS records through web dashboards is error-prone and impossible to audit. One wrong click can take down your email or website, and there's no version history to roll back.

DNSControl by Stack Overflow lets you define all DNS records in a simple JavaScript config file. Preview exactly what will change before applying, keep your DNS version-controlled in git, and manage multiple domains across different providers from one place.

**What it does:**
- 🌐 Define DNS records declaratively in `dnsconfig.js`
- 👀 Preview changes before applying (no surprises)
- 🚀 Push changes to 40+ DNS providers (Cloudflare, Route53, Google, Hetzner, etc.)
- 📥 Import existing records from your provider
- 🔍 Audit for drift between config and live DNS
- 📦 Multi-domain, multi-provider support in one config
- 🔄 CI/CD ready — preview on PR, push on merge
- 📝 Full git history of every DNS change

Perfect for developers, DevOps engineers, and anyone managing DNS for multiple domains who wants reliability, auditability, and infrastructure-as-code for their DNS.

## Quick Start Preview

```bash
# Install DNSControl
bash scripts/install.sh

# Initialize for your domain
bash scripts/init.sh --provider cloudflare --domain example.com

# Edit dnsconfig.js, then:
dnscontrol preview   # See what will change
dnscontrol push      # Apply changes
```

## Core Capabilities

1. Declarative DNS config — Define records in JavaScript, not web UIs
2. Preview before push — See exact diff of pending changes
3. 40+ provider support — Cloudflare, Route53, Google, Azure, Hetzner, DigitalOcean, more
4. Record import — Pull existing records into config with one command
5. Multi-domain management — All domains in one config file
6. Drift detection — Audit script detects unauthorized changes
7. Git-friendly — Version control every DNS change
8. CI/CD integration — Automate DNS updates in your pipeline
9. Macro support — Reusable record templates (Google Workspace MX, etc.)
10. Cross-platform — Works on Linux, macOS, arm64/amd64
