---
name: nuclei-scanner
description: >-
  Install and run Nuclei vulnerability scanner to detect security issues in web applications, APIs, and infrastructure.
categories: [security, dev-tools]
dependencies: [bash, curl, unzip]
---

# Nuclei Vulnerability Scanner

## What This Does

Installs and manages [Nuclei](https://github.com/projectdiscovery/nuclei) by ProjectDiscovery — a fast, template-based vulnerability scanner used by security professionals worldwide. Scan websites, APIs, and network services for known vulnerabilities, misconfigurations, exposed panels, and more using 8000+ community templates.

**Example:** "Scan example.com for critical vulnerabilities, exposed admin panels, and security misconfigurations."

## Quick Start (5 minutes)

### 1. Install Nuclei

```bash
bash scripts/install.sh
```

This downloads the latest Nuclei binary and community templates. No Go compiler needed.

### 2. Run Your First Scan

```bash
# Basic scan against a target
nuclei -u https://example.com

# Scan with only critical/high severity templates
nuclei -u https://example.com -s critical,high
```

### 3. View Results

```
[2026-03-06] [ssl-issuer] [info] https://example.com
[2026-03-06] [tech-detect:nginx] [info] https://example.com
[2026-03-06] [missing-x-frame-options] [info] https://example.com
[2026-03-06] [exposed-gitconfig] [medium] https://example.com/.git/config
```

## Core Workflows

### Workflow 1: Full Security Scan

**Use case:** Comprehensive vulnerability assessment of a web application.

```bash
# Scan all templates (takes longer but thorough)
nuclei -u https://target.com -o results.txt

# With rate limiting to avoid blocking
nuclei -u https://target.com -rl 50 -c 10 -o results.txt
```

### Workflow 2: Scan for Critical Issues Only

**Use case:** Quick check for dangerous vulnerabilities.

```bash
nuclei -u https://target.com -s critical,high -o critical-findings.txt
```

**Output example:**
```
[CVE-2024-XXXX] [critical] https://target.com/vulnerable-endpoint
[exposed-admin-panel] [high] https://target.com/admin
[default-credentials] [high] https://target.com/login
```

### Workflow 3: Scan Multiple Targets

**Use case:** Audit multiple domains or subdomains at once.

```bash
# Create a targets file
cat > targets.txt << 'EOF'
https://app.example.com
https://api.example.com
https://staging.example.com
EOF

# Scan all targets
nuclei -l targets.txt -s critical,high,medium -o multi-scan.txt
```

### Workflow 4: Specific Vulnerability Category

**Use case:** Check only for specific types of issues.

```bash
# Check for exposed files and directories
nuclei -u https://target.com -t exposures/ -o exposed-files.txt

# Check for known CVEs
nuclei -u https://target.com -t cves/ -s critical,high -o cve-scan.txt

# Check for misconfigurations
nuclei -u https://target.com -t misconfiguration/ -o misconfig.txt

# Check for default credentials
nuclei -u https://target.com -t default-logins/ -o defaults.txt

# Technology detection
nuclei -u https://target.com -t technologies/ -o tech-stack.txt
```

### Workflow 5: API Security Scan

**Use case:** Test API endpoints for vulnerabilities.

```bash
# Scan API with custom headers
nuclei -u https://api.target.com \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -t http/vulnerabilities/ \
  -o api-scan.txt
```

### Workflow 6: Scheduled Security Audit

**Use case:** Run weekly security scans via cron.

```bash
# Add to crontab (weekly Sunday 2am)
(crontab -l 2>/dev/null; echo "0 2 * * 0 bash /path/to/scripts/scheduled-scan.sh") | crontab -

# Or use OpenClaw cron for agent-managed scans
```

The `scripts/scheduled-scan.sh` script runs a scan and outputs a summary report.

### Workflow 7: Update Templates

**Use case:** Get latest vulnerability templates from the community.

```bash
nuclei -update-templates
```

Templates are updated frequently — run this weekly to catch newly discovered vulnerabilities.

## Configuration

### Rate Limiting

```bash
# Limit requests per second (avoid WAF blocks)
nuclei -u https://target.com -rl 30    # 30 requests/sec
nuclei -u https://target.com -rl 10    # Slow and stealthy

# Limit concurrent connections
nuclei -u https://target.com -c 5      # 5 concurrent requests
```

### Output Formats

```bash
# Plain text (default)
nuclei -u https://target.com -o results.txt

# JSON output (for programmatic use)
nuclei -u https://target.com -jsonl -o results.jsonl

# Markdown report
nuclei -u https://target.com -me reports/  # Writes markdown to reports/

# SARIF format (for GitHub Security tab)
nuclei -u https://target.com -sarif -o results.sarif
```

### Severity Filtering

```bash
# Only critical and high
nuclei -u https://target.com -s critical,high

# Exclude info-level noise
nuclei -u https://target.com -es info

# Only medium findings
nuclei -u https://target.com -s medium
```

### Custom Headers & Auth

```bash
# Bearer token
nuclei -u https://target.com -H "Authorization: Bearer TOKEN"

# Cookie-based auth
nuclei -u https://target.com -H "Cookie: session=abc123"

# Multiple headers
nuclei -u https://target.com \
  -H "Authorization: Bearer TOKEN" \
  -H "X-Custom-Header: value"
```

## Advanced Usage

### Custom Templates

Create your own vulnerability checks:

```yaml
# my-template.yaml
id: custom-admin-check
info:
  name: Custom Admin Panel Check
  severity: high
  description: Checks for exposed admin panel at /admin

http:
  - method: GET
    path:
      - "{{BaseURL}}/admin"
    matchers:
      - type: status
        status:
          - 200
      - type: word
        words:
          - "admin"
          - "dashboard"
        condition: or
```

Run custom template:
```bash
nuclei -u https://target.com -t my-template.yaml
```

### Proxy Support

```bash
# Route through Burp Suite or OWASP ZAP
nuclei -u https://target.com -proxy http://127.0.0.1:8080

# SOCKS5 proxy
nuclei -u https://target.com -proxy socks5://127.0.0.1:1080
```

### Exclude Specific Templates

```bash
# Exclude noisy templates
nuclei -u https://target.com -et technologies/ -et dns/

# Exclude by ID
nuclei -u https://target.com -exclude-id tech-detect,waf-detect
```

## Troubleshooting

### Issue: "nuclei: command not found"

**Fix:** Run the install script or add to PATH:
```bash
bash scripts/install.sh
# Or manually:
export PATH="$HOME/.local/bin:$PATH"
```

### Issue: Too many info-level results

**Fix:** Filter by severity:
```bash
nuclei -u https://target.com -s critical,high,medium
```

### Issue: Getting rate-limited / blocked by WAF

**Fix:** Reduce rate and concurrency:
```bash
nuclei -u https://target.com -rl 10 -c 3 -timeout 10
```

### Issue: Old templates missing recent CVEs

**Fix:** Update templates:
```bash
nuclei -update-templates
```

## Security & Ethics

⚠️ **Only scan targets you own or have explicit permission to test.**

- Running Nuclei against unauthorized targets may violate computer fraud laws
- Always get written authorization before penetration testing
- Use rate limiting to avoid disrupting services
- Report vulnerabilities responsibly through proper disclosure channels

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `unzip` (for extraction)
- ~100MB disk space (binary + templates)
- No Go compiler needed (pre-built binary)
