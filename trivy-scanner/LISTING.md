# Listing Copy: Trivy Security Scanner

## Metadata
- **Type:** Skill
- **Name:** trivy-scanner
- **Display Name:** Trivy Security Scanner
- **Categories:** [security, dev-tools]
- **Price:** $12
- **Dependencies:** [bash, curl, jq]
- **Icon:** 🛡️

## Tagline

Scan containers, code, and configs for vulnerabilities, secrets, and misconfigurations

## Description

You're shipping code, but are you shipping vulnerabilities with it? Exposed API keys in your repo, unpatched CVEs in your Docker base image, Kubernetes manifests running containers as root — these are the things that turn a good deploy into a bad day.

Trivy Security Scanner brings the most popular open-source vulnerability scanner directly into your OpenClaw agent. Auto-install Trivy, scan Docker images for CVEs, sweep your project for exposed secrets, and audit infrastructure configs for misconfigurations — all from simple bash commands.

**What it does:**
- 🐳 Scan Docker/OCI images for known CVEs
- 🔑 Detect exposed secrets (API keys, tokens, passwords) in codebases
- ⚙️ Audit Dockerfiles, Terraform, and Kubernetes YAML for misconfigurations
- 📊 Generate JSON/SARIF reports for CI/CD integration
- 🔔 Send Telegram alerts when critical vulnerabilities are found
- 📈 Compare reports to track new vs. fixed vulnerabilities over time
- 🚦 CI/CD gate — fail builds on critical findings

Perfect for developers, DevOps engineers, and security-conscious teams who want vulnerability scanning without the complexity of enterprise tools.

## Core Capabilities

1. Auto-install — Detects OS/arch, downloads correct Trivy binary
2. Image scanning — Scan any Docker image for CVE vulnerabilities
3. Filesystem scanning — Check project dependencies for known issues
4. Secret detection — Find exposed API keys, tokens, and passwords
5. Misconfig auditing — Audit Dockerfiles, Terraform, K8s manifests
6. Git repo scanning — Scan remote repositories without cloning
7. Severity filtering — Focus on CRITICAL/HIGH or see everything
8. JSON/SARIF reports — Machine-readable output for automation
9. Report diffing — Compare scans to track improvement over time
10. Telegram alerts — Get notified when critical issues are found
11. CI/CD ready — Exit codes for pipeline gating
12. .trivyignore — Suppress known false positives

## Installation Time
**5 minutes** — Run install script, start scanning
