# Listing Copy: ShellCheck Linter

## Metadata
- **Type:** Skill
- **Name:** shellcheck-linter
- **Display Name:** ShellCheck Linter
- **Categories:** [dev-tools, automation]
- **Icon:** 🐚
- **Dependencies:** [bash, curl]

## Tagline
Lint shell scripts automatically — catch bugs, security issues, and bad practices before production.

## Description

Shell scripts are everywhere — deployments, backups, cron jobs, CI pipelines. But bash is notoriously tricky. Unquoted variables, missing error handling, and subtle portability issues silently break things in production.

ShellCheck Linter installs [ShellCheck](https://github.com/koalaman/shellcheck) (60k+ GitHub stars, the gold standard for shell analysis) and gives your OpenClaw agent powerful workflows: lint single files, batch-check entire directories, generate CI-ready JSON reports, set up git pre-commit hooks, and even watch files for continuous linting.

**What you get:**
- 🔧 One-command install (auto-detects OS, architecture, package manager)
- 📋 Pretty terminal reports with severity levels (error/warning/info)
- 📁 Batch lint entire projects recursively
- 🔗 Git pre-commit hook — block bad scripts from being committed
- 📊 JSON/GCC/CheckStyle output for CI/CD integration
- 👀 Watch mode — re-lint automatically on file changes
- 🎛️ Filter by severity, exclude rules, force shell dialect
- ⚡ Works on Linux, macOS, ARM — wherever your agent runs

Perfect for developers, DevOps engineers, and anyone who writes shell scripts and wants to stop debugging mysterious failures at 3am.

## Core Capabilities

1. Auto-install ShellCheck — detects OS/arch, uses package manager or downloads binary
2. Single file linting — detailed per-line issue reports with fix suggestions
3. Directory batch checking — lint all .sh files recursively with summary
4. Severity filtering — focus on errors only, or include warnings/info/style
5. Multiple output formats — TTY (pretty), JSON, GCC, CheckStyle, diff
6. Git pre-commit hook — automatic linting on staged shell files
7. Watch mode — continuous re-linting on file changes
8. Rule exclusion — ignore specific SC codes project-wide or per-file
9. Shell dialect forcing — validate for sh, bash, dash, or ksh specifically
10. .shellcheckrc support — project-level configuration

## Installation Time
**2 minutes** — run install script, start linting
