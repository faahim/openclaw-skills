# Listing Copy: Act Runner

## Metadata
- **Type:** Skill
- **Name:** act-runner
- **Display Name:** Act Runner — Local GitHub Actions
- **Categories:** [dev-tools, automation]
- **Icon:** 🎬
- **Dependencies:** [docker, curl]

## Tagline

Run GitHub Actions workflows locally — Test CI/CD before pushing

## Description

Tired of pushing commits just to see if your GitHub Actions workflow works? Every failed run wastes CI minutes and clutters your commit history with "fix CI" messages.

Act Runner installs and configures [nektos/act](https://github.com/nektos/act) — the leading tool for running GitHub Actions locally using Docker. Test your workflows on your machine in seconds, with full support for secrets, matrix builds, and custom runner images.

**What it does:**
- 🚀 Install act with one command (auto-detects OS/arch)
- ▶️ Run any GitHub Actions workflow locally
- 🔐 Manage secrets via .env files or environment variables
- 📋 List and inspect all workflows and jobs
- 🐛 Debug failing steps with verbose output and container reuse
- 🏗️ Support matrix builds, Docker-in-Docker, and custom events
- ⚡ Pre-configured with sensible defaults (~/.actrc)

**Who it's for:** Developers who use GitHub Actions and want faster feedback loops. Stop waiting for CI — test locally first.

## Quick Start Preview

```bash
# Install act
bash scripts/install.sh

# List workflows
cd your-repo && act -l

# Run push event
act push

# Run specific job with secrets
act -j build -s GITHUB_TOKEN=ghp_xxx
```

## Core Capabilities

1. One-command installation — Auto-detects Linux/macOS, x86/ARM
2. Run any event — push, pull_request, workflow_dispatch, schedule
3. Job targeting — Run specific jobs without the full pipeline
4. Secret management — .env files, inline, or environment variables
5. Dry run mode — See execution plan without running anything
6. Container reuse — Dramatically faster iteration with --reuse
7. Multiple runner images — Micro (fast) to full (GitHub-identical)
8. Custom event payloads — Simulate specific PRs, issues, etc.
9. Docker-in-Docker — Test workflows that build containers
10. Per-repo config — .actrc for project-specific defaults
