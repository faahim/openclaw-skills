---
name: sbom-generator
description: >-
  Generate Software Bill of Materials (SBOM) for projects and containers using Syft. Outputs SPDX, CycloneDX, or table formats.
categories: [security, dev-tools]
dependencies: [syft, curl]
---

# SBOM Generator

## What This Does

Generate a Software Bill of Materials (SBOM) for any project directory, container image, or archive. Uses [Syft](https://github.com/anchore/syft) to detect packages across 30+ ecosystems (npm, pip, go, cargo, maven, apt, apk, etc.) and output in industry-standard SPDX or CycloneDX formats.

**Example:** "Scan my Node.js project → get a full dependency list in CycloneDX JSON for compliance reporting."

## Quick Start (5 minutes)

### 1. Install Syft

```bash
bash scripts/install.sh
```

### 2. Scan a Project

```bash
# Scan current directory
bash scripts/run.sh --path .

# Scan a container image
bash scripts/run.sh --image node:20-alpine

# Output as CycloneDX JSON (for compliance)
bash scripts/run.sh --path . --format cyclonedx-json --output sbom.json
```

## Core Workflows

### Workflow 1: Scan a Local Project

**Use case:** Generate SBOM for your codebase before release

```bash
bash scripts/run.sh --path /path/to/project --format spdx-json --output project-sbom.json
```

**Output (table mode):**
```
NAME                  VERSION    TYPE
express               4.18.2     npm
lodash                4.17.21    npm
typescript            5.3.3      npm
@types/node           20.11.5    npm
...
Total: 847 packages detected
```

### Workflow 2: Scan a Container Image

**Use case:** Audit what's inside a Docker image

```bash
bash scripts/run.sh --image myapp:latest --format table
```

**Output:**
```
NAME                  VERSION        TYPE
alpine-baselayout     3.4.3-r1       apk
busybox               1.36.1-r15     apk
ca-certificates       20230506-r0    apk
node                  20.11.0        binary
express               4.18.2         npm
...
Total: 234 packages detected
```

### Workflow 3: Compare Two SBOMs

**Use case:** See what changed between releases

```bash
# Generate SBOMs for two versions
bash scripts/run.sh --path ./v1 --format cyclonedx-json --output v1-sbom.json
bash scripts/run.sh --path ./v2 --format cyclonedx-json --output v2-sbom.json

# Diff them
bash scripts/diff.sh v1-sbom.json v2-sbom.json
```

**Output:**
```
ADDED:
  + lodash 4.17.21 (npm)
  + axios 1.6.5 (npm)

REMOVED:
  - request 2.88.2 (npm)

CHANGED:
  ~ express 4.17.1 → 4.18.2 (npm)
  ~ typescript 5.2.0 → 5.3.3 (npm)
```

### Workflow 4: CI/CD Integration

**Use case:** Generate SBOM on every build

```bash
# In your CI pipeline
bash scripts/run.sh \
  --path . \
  --format spdx-json \
  --output sbom-$(date +%Y%m%d).json

# Upload to dependency tracking service
# (e.g., GitHub, OWASP Dependency-Track)
```

### Workflow 5: Scan and Check for Known Vulnerabilities

**Use case:** Combine SBOM with Grype for vulnerability scanning

```bash
# Generate SBOM then scan with grype (if installed)
bash scripts/run.sh --path . --format syft-json --output sbom.json
bash scripts/vuln-check.sh sbom.json
```

**Output:**
```
VULNERABILITY     SEVERITY   PACKAGE          VERSION    FIXED-IN
CVE-2024-1234     Critical   lodash           4.17.20    4.17.21
CVE-2024-5678     High       express          4.17.1     4.18.2
CVE-2024-9999     Medium     minimist         1.2.5      1.2.8

Summary: 1 Critical, 1 High, 1 Medium (3 total)
```

## Supported Formats

| Format | Flag | Use Case |
|--------|------|----------|
| `table` | `--format table` | Human-readable terminal output (default) |
| `spdx-json` | `--format spdx-json` | SPDX 2.3 JSON — industry standard |
| `spdx-tag-value` | `--format spdx-tag-value` | SPDX tag-value text format |
| `cyclonedx-json` | `--format cyclonedx-json` | CycloneDX 1.5 JSON — OWASP standard |
| `cyclonedx-xml` | `--format cyclonedx-xml` | CycloneDX 1.5 XML |
| `syft-json` | `--format syft-json` | Syft native JSON (for piping to Grype) |

## Supported Ecosystems

Syft detects packages from 30+ ecosystems including:

- **JavaScript:** npm, yarn, pnpm
- **Python:** pip, poetry, pipenv, conda
- **Go:** go modules
- **Rust:** cargo
- **Java:** maven, gradle
- **Ruby:** gem, bundler
- **PHP:** composer
- **C/C++:** conan
- **Linux:** apt/dpkg, apk, rpm, pacman
- **Containers:** Docker, OCI images

## Configuration

### Environment Variables

```bash
# Custom Syft binary path (if not in PATH)
export SYFT_BIN="/usr/local/bin/syft"

# Default output format
export SBOM_DEFAULT_FORMAT="cyclonedx-json"

# Default output directory
export SBOM_OUTPUT_DIR="./sbom-reports"
```

## Troubleshooting

### Issue: "syft: command not found"

**Fix:** Run the install script:
```bash
bash scripts/install.sh
```

Or install manually:
```bash
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
```

### Issue: Permission denied scanning Docker images

**Fix:** Ensure your user can access Docker:
```bash
sudo usermod -aG docker $USER
# Then log out and back in
```

### Issue: Slow scan on large monorepo

**Fix:** Scope the scan to a subdirectory:
```bash
bash scripts/run.sh --path ./packages/my-service --format table
```

## Dependencies

- `syft` (installed by scripts/install.sh)
- `curl` (for installation)
- `jq` (for SBOM diffing and vuln checks)
- Optional: `grype` (for vulnerability scanning)
- Optional: `docker` (for container image scanning)
