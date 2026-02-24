# Listing Copy: Semgrep Code Scanner

## Metadata
- **Type:** Skill
- **Name:** semgrep-scanner
- **Display Name:** Semgrep Code Scanner
- **Categories:** [security, dev-tools]
- **Price:** $12
- **Dependencies:** [python3, pip]
- **Icon:** 🛡️

## Tagline

Scan code for vulnerabilities, secrets, and bugs — automated static analysis with Semgrep

## Description

Finding security vulnerabilities by reading code manually is slow, error-prone, and doesn't scale. By the time you spot a hardcoded API key or SQL injection, it's already in production.

Semgrep Code Scanner runs automated static analysis on your entire codebase in minutes. It checks for OWASP Top 10 vulnerabilities, hardcoded secrets, language-specific anti-patterns, and more — across 30+ languages including Python, JavaScript, Go, Java, and Ruby. No code leaves your machine.

**What it does:**
- 🔍 Scan entire projects for security vulnerabilities in <2 minutes
- 🔑 Detect hardcoded API keys, passwords, and tokens
- 📊 Prioritized findings with severity levels and fix suggestions
- 🏗️ CI/CD ready — fail builds on high-severity issues
- 📝 Export reports as JSON, SARIF (GitHub Security), or Markdown
- 🔄 Diff mode — scan only changed files before committing

Perfect for developers, security engineers, and DevOps teams who want automated security scanning without expensive SaaS tools.

## Core Capabilities

1. Security audit — OWASP Top 10, injection, XSS, CSRF detection
2. Secrets detection — API keys, passwords, tokens, private keys
3. Multi-language — Python, JS/TS, Go, Java, Ruby, PHP, and 25+ more
4. Severity filtering — Focus on HIGH/MEDIUM findings only
5. Multiple rulesets — security, owasp, secrets, language-specific, Docker, Terraform
6. Git diff mode — Scan only changed files for fast pre-commit checks
7. CI/CD integration — Exit code 1 on findings for build pipelines
8. Report export — JSON, SARIF, Markdown, or plain text
9. Custom rules — Write your own Semgrep patterns
10. Offline scanning — All analysis runs locally, zero data exfiltration
11. Baseline comparison — Show only new findings vs previous scan
12. Auto-install — One-command setup with dependency checking
