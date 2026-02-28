---
name: trivy-scanner
description: >-
  Scan containers, images, filesystems, and Git repos for vulnerabilities, misconfigurations, and secrets using Trivy.
categories: [security, dev-tools]
dependencies: [bash, curl, jq]
---

# Trivy Security Scanner

## What This Does

Installs and runs [Trivy](https://github.com/aquasecurity/trivy) — the most popular open-source vulnerability scanner. Scan Docker images, local filesystems, Git repos, and Kubernetes configs for CVEs, misconfigurations, exposed secrets, and license issues.

**Example:** "Scan my project directory for secrets and vulnerabilities, then get a summary of critical findings."

## Quick Start (5 minutes)

### 1. Install Trivy

```bash
bash scripts/install.sh
```

This auto-detects your OS (Linux/macOS) and architecture (amd64/arm64) and installs the latest Trivy binary.

### 2. Scan a Docker Image

```bash
bash scripts/scan.sh --image python:3.12-slim

# Output:
# 🔍 Scanning image: python:3.12-slim
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CRITICAL: 0 | HIGH: 2 | MEDIUM: 8 | LOW: 12
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# See full report: /tmp/trivy-report-python-3.12-slim.json
```

### 3. Scan a Local Directory

```bash
bash scripts/scan.sh --fs /path/to/project

# Scans for:
# - Vulnerable dependencies (package.json, requirements.txt, go.mod, etc.)
# - Exposed secrets (API keys, tokens, passwords)
# - Misconfigurations (Dockerfile, Terraform, Kubernetes YAML)
```

## Core Workflows

### Workflow 1: Scan Docker Image for CVEs

```bash
bash scripts/scan.sh --image nginx:latest --severity CRITICAL,HIGH
```

**Output:**
```
🔍 Scanning image: nginx:latest
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CRITICAL: 1 | HIGH: 3
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CVE-2024-XXXXX (CRITICAL) — openssl 3.0.13
  Fixed in: 3.0.14
  Description: Buffer overflow in X.509 certificate verification

CVE-2024-YYYYY (HIGH) — curl 8.5.0
  Fixed in: 8.6.0
  Description: HTTP/2 stream cancellation attack
```

### Workflow 2: Scan Project for Secrets

```bash
bash scripts/scan.sh --fs . --scanners secret
```

**Output:**
```
🔍 Scanning filesystem: .
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Secrets found: 3
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

HIGH — AWS Access Key ID
  File: src/config.js:42
  Match: AKIA...EXAMPLE

HIGH — GitHub Personal Access Token
  File: .env.local:7
  Match: ghp_...REDACTED

MEDIUM — Generic Password
  File: docker-compose.yml:15
  Match: password: "admin123"
```

### Workflow 3: Scan Git Repository

```bash
bash scripts/scan.sh --repo https://github.com/user/project
```

### Workflow 4: Scan Kubernetes Manifests

```bash
bash scripts/scan.sh --fs ./k8s/ --scanners misconfig
```

**Output:**
```
🔍 Scanning filesystem: ./k8s/
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Misconfigurations: 5
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CRITICAL — Container running as root
  File: deployment.yaml
  Fix: Add securityContext.runAsNonRoot: true

HIGH — No resource limits set
  File: deployment.yaml
  Fix: Add resources.limits.cpu and resources.limits.memory
```

### Workflow 5: Generate JSON Report

```bash
bash scripts/scan.sh --image myapp:latest --format json --output report.json
```

### Workflow 6: CI/CD Gate (exit non-zero on findings)

```bash
bash scripts/scan.sh --image myapp:latest --severity CRITICAL --exit-code 1

# Exit code 0 = no critical vulnerabilities
# Exit code 1 = critical vulnerabilities found (fails CI pipeline)
```

## Configuration

### Environment Variables

```bash
# Cache directory (default: ~/.cache/trivy)
export TRIVY_CACHE_DIR="$HOME/.cache/trivy"

# Skip update check
export TRIVY_SKIP_UPDATE=true

# GitHub token for scanning private repos
export GITHUB_TOKEN="ghp_..."

# Custom severity threshold
export TRIVY_SEVERITY="CRITICAL,HIGH"
```

### Scan Types

| Flag | What It Scans |
|------|---------------|
| `--image <name>` | Docker/OCI image (pulls if needed) |
| `--fs <path>` | Local filesystem (deps + secrets + misconfig) |
| `--repo <url>` | Remote Git repository |
| `--scanners vuln` | Only vulnerabilities (CVEs) |
| `--scanners secret` | Only exposed secrets |
| `--scanners misconfig` | Only misconfigurations |
| `--scanners vuln,secret,misconfig` | All (default) |

## Advanced Usage

### Scan with .trivyignore

Create `.trivyignore` to suppress known false positives:

```
# Ignore specific CVEs
CVE-2023-12345
CVE-2024-67890

# Ignore by package
pkg:npm/lodash@4.17.21
```

### Compare Two Images

```bash
# Scan both, diff the results
bash scripts/scan.sh --image myapp:v1 --format json --output v1.json
bash scripts/scan.sh --image myapp:v2 --format json --output v2.json
bash scripts/diff.sh v1.json v2.json
```

### Schedule Regular Scans

```bash
# Add to crontab — scan daily at 2am
0 2 * * * cd /path/to/skill && bash scripts/scan.sh --image myapp:latest --severity CRITICAL,HIGH --alert telegram >> /var/log/trivy-scan.log 2>&1
```

## Troubleshooting

### Issue: "trivy: command not found"

```bash
bash scripts/install.sh
# Or add to PATH:
export PATH="$HOME/.local/bin:$PATH"
```

### Issue: Slow first scan

Trivy downloads its vulnerability database on first run (~30MB). Subsequent scans use the cache.

```bash
# Pre-download database
trivy image --download-db-only
```

### Issue: "failed to initialize a scanner"

Clear the cache and retry:
```bash
trivy clean --all
```

### Issue: Permission denied scanning Docker images

```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Or run with sudo
sudo bash scripts/scan.sh --image nginx:latest
```

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `jq` (for JSON report parsing)
- `docker` (optional — only for image scanning)
- Internet connection (for vulnerability DB updates)

## What Gets Installed

- `trivy` binary at `~/.local/bin/trivy` (~50MB)
- Vulnerability database at `~/.cache/trivy/` (~30MB, auto-updated)
