# Listing Copy: SBOM Generator

## Metadata
- **Type:** Skill
- **Name:** sbom-generator
- **Display Name:** SBOM Generator
- **Categories:** [security, dev-tools]
- **Price:** $12
- **Icon:** 📋
- **Dependencies:** [syft, curl, jq]

## Tagline

Generate Software Bill of Materials — Know every dependency in your project

## Description

Most developers have no idea what's actually in their projects. Transitive dependencies, container base image packages, vendored libraries — they add up fast. When a CVE drops, you're scrambling to figure out if you're affected.

**SBOM Generator** uses Anchore's Syft to scan any project directory, container image, or archive and produce a complete inventory of every package, library, and dependency. Output in industry-standard SPDX or CycloneDX formats for compliance, or simple table format for quick checks.

**What it does:**
- 📋 Scan projects across 30+ ecosystems (npm, pip, go, cargo, maven, apt, apk, etc.)
- 🐳 Scan Docker/OCI container images
- 📊 Output in SPDX, CycloneDX, or human-readable table format
- 🔄 Diff two SBOMs to see what changed between releases
- 🛡️ Optional vulnerability scanning with Grype integration
- ⚡ One-command install, 5-minute setup

**Perfect for:** Developers shipping software, DevOps teams managing containers, anyone who needs supply chain visibility or compliance reporting (SOC 2, FedRAMP, EU CRA).

## Quick Start Preview

```bash
# Install
bash scripts/install.sh

# Scan your project
bash scripts/run.sh --path . --format table

# Generate compliance SBOM
bash scripts/run.sh --path . --format cyclonedx-json --output sbom.json
```

## Core Capabilities

1. Project scanning — Detect all packages in any codebase directory
2. Container scanning — Inventory every package in Docker/OCI images
3. Multi-format output — SPDX JSON, CycloneDX JSON/XML, table, syft-json
4. 30+ ecosystems — npm, pip, go, cargo, maven, gem, composer, apt, apk, rpm
5. SBOM diffing — Compare two SBOMs to see added/removed/changed packages
6. Vulnerability scanning — Pipe to Grype for CVE detection
7. CI/CD ready — Non-interactive mode for pipeline integration
8. One-click install — Cross-platform installer (Linux, macOS, ARM)
9. Lightweight — Single binary, no runtime dependencies
10. Compliance formats — SPDX 2.3 and CycloneDX 1.5 for regulatory requirements

## Dependencies
- `syft` (installed by scripts/install.sh)
- `curl` (for installation)
- `jq` (for diffing and analysis)
- Optional: `grype` (vulnerability scanning)
- Optional: `docker` (container image scanning)

## Installation Time
**5 minutes** — Run install script, start scanning
