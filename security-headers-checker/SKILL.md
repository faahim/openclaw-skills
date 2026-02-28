---
name: security-headers-checker
description: >-
  Audit HTTP security headers for any URL — get a security score, detailed analysis, and actionable fix recommendations.
categories: [security, dev-tools]
dependencies: [bash, curl, jq]
---

# Security Headers Checker

## What This Does

Scans any website's HTTP response headers and evaluates security posture. Checks for critical headers like Content-Security-Policy, Strict-Transport-Security, X-Frame-Options, and more. Produces a letter grade (A+ to F), detailed per-header analysis, and copy-paste fix configs for Nginx, Apache, and Cloudflare.

**Example:** "Scan https://mysite.com → Grade B (missing CSP and Permissions-Policy) → here's exactly what to add to your Nginx config."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# These are standard on most systems
which curl bash || echo "Install curl and bash"
```

### 2. Scan a URL

```bash
bash scripts/check-headers.sh https://example.com
```

### 3. Scan Multiple URLs

```bash
bash scripts/check-headers.sh https://site1.com https://site2.com https://site3.com
```

### 4. JSON Output (for automation)

```bash
bash scripts/check-headers.sh --json https://example.com
```

### 5. Generate Fix Config

```bash
bash scripts/check-headers.sh --fix nginx https://example.com
bash scripts/check-headers.sh --fix apache https://example.com
bash scripts/check-headers.sh --fix cloudflare https://example.com
```

## Core Workflows

### Workflow 1: Quick Security Audit

**Use case:** Check if your site has proper security headers

```bash
bash scripts/check-headers.sh https://yoursite.com
```

**Example output:**
```
╔══════════════════════════════════════════════════════╗
║  Security Headers Report: https://yoursite.com       ║
║  Grade: B (75/100)                                   ║
╚══════════════════════════════════════════════════════╝

✅ Strict-Transport-Security: max-age=31536000; includeSubDomains
   → HSTS enabled with 1-year max-age. Good.

✅ X-Content-Type-Options: nosniff
   → MIME sniffing prevention enabled. Good.

✅ X-Frame-Options: DENY
   → Clickjacking protection enabled. Good.

❌ Content-Security-Policy: MISSING
   → No CSP header found. This is the #1 defense against XSS attacks.
   → Recommended: Content-Security-Policy: default-src 'self'; script-src 'self'

⚠️  Referrer-Policy: no-referrer-when-downgrade
   → Acceptable but not optimal. Consider 'strict-origin-when-cross-origin'.

❌ Permissions-Policy: MISSING
   → No Permissions-Policy found. Browsers can access camera, mic, geolocation.
   → Recommended: Permissions-Policy: camera=(), microphone=(), geolocation=()

✅ X-XSS-Protection: 0
   → Correctly disabled (modern CSP replaces this; enabling can cause issues).

❌ Cross-Origin-Opener-Policy: MISSING
   → Missing COOP header. Recommended: same-origin

Summary: 4/8 headers present | 3 missing | 1 warning
```

### Workflow 2: Compare Multiple Sites

**Use case:** Audit all your properties at once

```bash
bash scripts/check-headers.sh \
  https://app.yoursite.com \
  https://api.yoursite.com \
  https://blog.yoursite.com
```

### Workflow 3: Generate Server Config

**Use case:** Get copy-paste config to fix missing headers

```bash
bash scripts/check-headers.sh --fix nginx https://yoursite.com
```

**Output:**
```
# Add to your Nginx server block:
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' https:; connect-src 'self' https:; frame-ancestors 'none'" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=(), interest-cohort=()" always;
add_header Cross-Origin-Opener-Policy "same-origin" always;
```

### Workflow 4: CI/CD Integration

**Use case:** Fail builds if security grade drops below threshold

```bash
GRADE=$(bash scripts/check-headers.sh --grade-only https://yoursite.com)
if [[ "$GRADE" < "B" ]]; then
  echo "Security headers grade $GRADE is below minimum B"
  exit 1
fi
```

### Workflow 5: JSON Report for Dashboards

```bash
bash scripts/check-headers.sh --json https://yoursite.com > report.json
```

**Output:**
```json
{
  "url": "https://yoursite.com",
  "timestamp": "2026-02-28T08:00:00Z",
  "grade": "B",
  "score": 75,
  "headers": {
    "strict-transport-security": {"present": true, "value": "max-age=31536000", "score": 10, "max": 10},
    "content-security-policy": {"present": false, "value": null, "score": 0, "max": 25},
    "x-content-type-options": {"present": true, "value": "nosniff", "score": 10, "max": 10},
    "x-frame-options": {"present": true, "value": "DENY", "score": 10, "max": 10},
    "referrer-policy": {"present": true, "value": "no-referrer-when-downgrade", "score": 5, "max": 10},
    "permissions-policy": {"present": false, "value": null, "score": 0, "max": 15},
    "cross-origin-opener-policy": {"present": false, "value": null, "score": 0, "max": 10},
    "x-xss-protection": {"present": true, "value": "0", "score": 5, "max": 5}
  },
  "missing": ["content-security-policy", "permissions-policy", "cross-origin-opener-policy"],
  "warnings": ["referrer-policy"],
  "recommendations": [
    "Add Content-Security-Policy header (highest impact)",
    "Add Permissions-Policy to restrict browser APIs",
    "Add Cross-Origin-Opener-Policy: same-origin"
  ]
}
```

## Headers Checked

| Header | Max Score | Why It Matters |
|--------|-----------|----------------|
| Content-Security-Policy | 25 | #1 XSS defense — controls which resources can load |
| Strict-Transport-Security | 15 | Forces HTTPS, prevents downgrade attacks |
| Permissions-Policy | 15 | Restricts browser APIs (camera, mic, location) |
| X-Content-Type-Options | 10 | Prevents MIME type sniffing attacks |
| X-Frame-Options | 10 | Prevents clickjacking via iframes |
| Referrer-Policy | 10 | Controls referrer info leakage |
| Cross-Origin-Opener-Policy | 10 | Isolates browsing context |
| X-XSS-Protection | 5 | Legacy XSS filter (should be 0 or absent) |

**Grading scale:** A+ (95-100) | A (85-94) | B (70-84) | C (55-69) | D (40-54) | F (0-39)

## Advanced Usage

### Check with Custom User-Agent

```bash
bash scripts/check-headers.sh --user-agent "Mozilla/5.0" https://example.com
```

### Follow Redirects

```bash
bash scripts/check-headers.sh --follow https://example.com
```

### Check Only Specific Headers

```bash
bash scripts/check-headers.sh --only csp,hsts,xfo https://example.com
```

### Timeout Configuration

```bash
bash scripts/check-headers.sh --timeout 10 https://example.com
```

## Troubleshooting

### Issue: "curl: (60) SSL certificate problem"

**Fix:** The site has SSL issues. Add `--insecure` flag (not recommended for production):
```bash
bash scripts/check-headers.sh --insecure https://example.com
```

### Issue: Redirect loop / different headers than expected

**Fix:** Use `--follow` to follow redirects, or check the final URL directly.

### Issue: CloudFlare/CDN adding headers

This is expected — CDNs like CloudFlare, Fastly, and AWS CloudFront may add their own security headers. The checker reports what the browser actually receives, which is what matters.

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests + header extraction)
- `jq` (optional — for JSON output formatting)
