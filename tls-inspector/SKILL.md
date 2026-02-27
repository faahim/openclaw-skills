---
name: tls-inspector
description: >-
  Scan domains for SSL/TLS security issues — grades configuration, checks protocols, ciphers, HSTS, OCSP, and certificate health.
categories: [security, dev-tools]
dependencies: [openssl, curl, bash]
---

# TLS Inspector

## What This Does

Deep-scan any domain's SSL/TLS configuration and get an instant security grade (A+ to F). Checks protocol support, cipher negotiation, certificate health, HSTS headers, OCSP stapling, and HTTP→HTTPS redirects. Like SSL Labs, but runs locally from your terminal — no rate limits, no waiting.

**Example:** "Scan 20 domains, get security grades + actionable fixes in 30 seconds."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# These are pre-installed on most Linux/Mac systems
which openssl curl bash
```

### 2. Scan a Domain

```bash
bash scripts/tls-inspect.sh example.com
```

**Output:**
```
═══════════════════════════════════════════════════
  TLS Inspector — example.com
═══════════════════════════════════════════════════

  Grade: A (90/100)

  📜 Certificate
     Subject:    CN = example.com
     Issuer:     C = US, O = DigiCert Inc, CN = DigiCert TLS RSA SHA256 2020 CA1
     Expires:    Mar 14 23:59:59 2026 GMT (380 days left)
     Key Size:   2048 bit
     Signature:  sha256WithRSAEncryption

  🔐 Protocols
     ✓ TLS 1.3
     ✓ TLS 1.2
     ✓ TLS 1.1 (disabled)
     ✓ TLS 1.0 (disabled)
     ✓ SSLv3 (disabled)

  🔑 Cipher
     Negotiated: TLS_AES_256_GCM_SHA384

  🛡️  Security
     ✗ HSTS: Disabled
     ✓ HTTP→HTTPS redirect: YES (301)
     ✗ OCSP Stapling: No

  📋 Deductions
     • No HSTS (-10)
     • No OCSP stapling (-5)
```

## Core Workflows

### Workflow 1: Scan Single Domain

```bash
bash scripts/tls-inspect.sh yoursite.com
```

### Workflow 2: Scan Multiple Domains

```bash
bash scripts/tls-inspect.sh google.com github.com cloudflare.com
```

### Workflow 3: Batch Scan from File

```bash
# Create domains.txt (one domain per line)
cat > domains.txt <<EOF
google.com
github.com
example.com
# Comments are ignored
EOF

bash scripts/tls-inspect.sh --batch domains.txt
```

### Workflow 4: JSON Output for Automation

```bash
# Single domain
bash scripts/tls-inspect.sh --json example.com

# Multiple domains → JSON array
bash scripts/tls-inspect.sh --json google.com github.com
```

**JSON output:**
```json
{
  "domain": "example.com",
  "grade": "A",
  "score": 90,
  "certificate": {
    "subject": "CN = example.com",
    "issuer": "C = US, O = DigiCert Inc",
    "expires": "Mar 14 23:59:59 2026 GMT",
    "days_left": 380,
    "key_size": 2048,
    "signature": "sha256WithRSAEncryption"
  },
  "protocols": {
    "tls_1_3": true,
    "tls_1_2": true,
    "tls_1_1": false,
    "tls_1_0": false,
    "ssl_3": false
  },
  "hsts": "ENABLED max-age=31536000 includeSubDomains=yes preload=yes",
  "ocsp_stapling": "YES"
}
```

### Workflow 5: Verbose Mode (with SANs)

```bash
bash scripts/tls-inspect.sh --verbose yoursite.com
```

### Workflow 6: Scheduled Security Audit

```bash
# Add to crontab — weekly scan, save report
0 9 * * 1 cd /path/to/skill && bash scripts/tls-inspect.sh --json --batch domains.txt > reports/$(date +\%Y-\%W).json
```

## Grading System

| Grade | Score | Meaning |
|-------|-------|---------|
| A+    | 95-100| Perfect — modern protocols, strong config, all headers |
| A     | 90-94 | Excellent — minor improvements possible |
| B     | 80-89 | Good — some deprecated protocols or missing headers |
| C     | 70-79 | Fair — security concerns need attention |
| D     | 60-69 | Poor — significant vulnerabilities |
| F     | 0-59  | Failing — critical issues (expired cert, SSLv3, etc.) |

### Scoring Deductions

| Issue | Penalty | Why |
|-------|---------|-----|
| SSLv3 enabled | -40 | POODLE vulnerability |
| TLS 1.0 enabled | -15 | Deprecated, known weaknesses |
| TLS 1.1 enabled | -10 | Deprecated since 2021 |
| No TLS 1.3 support | -5 | Missing modern protocol |
| No TLS 1.2 or 1.3 | -30 | Critical — no secure protocol |
| Certificate expired | -100 | Instant F |
| Expires in <7 days | -30 | Urgent renewal needed |
| Expires in <30 days | -15 | Renewal recommended |
| Key size <2048 bit | -20 | Weak cryptography |
| SHA-1 signature | -20 | Deprecated algorithm |
| No HSTS header | -10 | Missing transport security |
| No HTTP→HTTPS redirect | -5 | Allows insecure access |
| No OCSP stapling | -5 | Slower revocation checks |

## What Gets Checked

1. **Certificate health** — Subject, issuer, expiry, key size, signature algorithm, SANs
2. **Protocol support** — TLS 1.3, 1.2, 1.1, 1.0, SSLv3
3. **Cipher negotiation** — Which cipher suite is negotiated
4. **HSTS** — Strict-Transport-Security header, max-age, includeSubDomains, preload
5. **HTTP→HTTPS redirect** — Whether port 80 redirects to 443
6. **OCSP stapling** — Certificate revocation check optimization
7. **Certificate chain** — Chain depth and validation

## Troubleshooting

### Issue: "Connection failed"

The domain might not have port 443 open, or DNS resolution failed.

```bash
# Check DNS
dig +short example.com

# Check port
nc -zv example.com 443
```

### Issue: TLS 1.3 shows as not supported

Some older OpenSSL versions don't support TLS 1.3 checks.

```bash
# Check OpenSSL version (needs 1.1.1+)
openssl version
```

### Issue: Timeouts on slow connections

```bash
bash scripts/tls-inspect.sh --timeout 30 slow-server.com
```

## Dependencies

- `bash` (4.0+)
- `openssl` (1.1.1+ recommended for TLS 1.3)
- `curl` (for HSTS/redirect checks)
- `grep`, `sed`, `awk` (standard Unix tools)
