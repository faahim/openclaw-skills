---
name: act-runner
description: >-
  Run GitHub Actions workflows locally using nektos/act. Test CI/CD pipelines without pushing to GitHub.
categories: [dev-tools, automation]
dependencies: [docker, curl]
---

# Act Runner — Local GitHub Actions

## What This Does

Run your GitHub Actions workflows locally before pushing to GitHub. Uses [nektos/act](https://github.com/nektos/act) to simulate the GitHub Actions runner environment using Docker containers. Saves time, CI minutes, and prevents broken workflows from hitting your repo.

**Example:** "Test my deploy workflow locally, see if all steps pass, fix issues before pushing."

## Quick Start (5 minutes)

### 1. Install act

```bash
# Auto-detect OS and install
bash scripts/install.sh

# Verify
act --version
```

### 2. Run Your First Workflow

```bash
cd /path/to/your-repo

# List available workflows
act -l

# Run the default push event
act

# Run a specific event
act pull_request

# Run a specific job
act -j build
```

### 3. Run With Secrets

```bash
# From .env file
act --secret-file .env

# Inline secrets
act -s GITHUB_TOKEN="ghp_xxx" -s NPM_TOKEN="npm_xxx"

# From environment
act -s GITHUB_TOKEN
```

## Core Workflows

### Workflow 1: Test Push Workflows

**Use case:** Validate your CI pipeline before pushing

```bash
cd your-repo
act push

# Output:
# [build/build] 🚀 Start image=catthehacker/ubuntu:act-latest
# [build/build] ⭐ Run Main actions/checkout@v4
# [build/build] ✅ Success - Main actions/checkout@v4
# [build/build] ⭐ Run Main npm ci
# [build/build] ✅ Success - Main npm ci
# [build/build] ⭐ Run Main npm test
# [build/build] ✅ Success - Main npm test
```

### Workflow 2: Test a Specific Workflow File

**Use case:** You have multiple workflow files, test just one

```bash
# Run specific workflow file
act -W .github/workflows/deploy.yml

# Run specific job from specific workflow
act -W .github/workflows/ci.yml -j lint
```

### Workflow 3: Dry Run (List What Would Execute)

**Use case:** See the execution plan without running

```bash
act -l

# Output:
# Stage  Job ID   Job name   Workflow name  Workflow file  Events
# 0      lint     Lint       CI             ci.yml         push
# 0      test     Test       CI             ci.yml         push
# 1      deploy   Deploy     CI             ci.yml         push

# Graph view
act -g
```

### Workflow 4: Test with Custom Inputs (workflow_dispatch)

**Use case:** Test manually-triggered workflows

```bash
act workflow_dispatch --input environment=staging --input version=1.2.3
```

### Workflow 5: Use a Specific Runner Image

**Use case:** Match your GitHub runner environment more closely

```bash
# Use micro image (fast, minimal — good for most cases)
act -P ubuntu-latest=catthehacker/ubuntu:act-latest

# Use medium image (~1GB, includes more tools)
act -P ubuntu-latest=catthehacker/ubuntu:act-22.04

# Use full image (~12GB, closest to GitHub runners)
act -P ubuntu-latest=catthehacker/ubuntu:full-22.04
```

### Workflow 6: Debug a Failing Step

**Use case:** A step fails and you need to investigate

```bash
# Verbose output
act -v

# Extra verbose
act -v -v

# Reuse containers (faster iteration)
act --reuse
```

## Configuration

### Config File (~/.actrc)

```bash
# Default platform images
-P ubuntu-latest=catthehacker/ubuntu:act-latest
-P ubuntu-22.04=catthehacker/ubuntu:act-22.04
-P ubuntu-20.04=catthehacker/ubuntu:act-20.04

# Default secrets file
--secret-file .env

# Reuse containers for speed
--reuse
```

### Environment Variables

```bash
# GitHub token (for actions that need API access)
export GITHUB_TOKEN="ghp_your_token"

# Custom artifact server
export ACT_ARTIFACT_SERVER_ADDR="localhost"
export ACT_ARTIFACT_SERVER_PORT="34567"
```

### .actrc Per-Repo

Create `.actrc` in your repo root to set project-specific defaults:

```bash
# .actrc (in repo root)
-P ubuntu-latest=catthehacker/ubuntu:act-latest
--secret-file .env.local
--env-file .env.act
```

## Advanced Usage

### Matrix Builds

```bash
# Act handles matrix strategies automatically
# Given workflow with matrix: {node: [16, 18, 20]}
act push
# Runs all 3 matrix combinations
```

### Docker-in-Docker Workflows

```bash
# If your workflow uses Docker commands
act --privileged

# Bind Docker socket
act --container-daemon-socket /var/run/docker.sock
```

### Artifact Upload/Download

```bash
# Enable local artifact server
act --artifact-server-path /tmp/act-artifacts
```

### Event Payloads

```bash
# Custom event payload (e.g., simulate specific PR)
act pull_request -e event.json

# event.json:
# {
#   "pull_request": {
#     "number": 42,
#     "head": {"ref": "feature-branch"},
#     "base": {"ref": "main"}
#   }
# }
```

### Skip Specific Jobs

```bash
# Run only jobs matching a pattern
act -j "test"

# Use if conditions in workflow:
# if: ${{ !env.ACT }}  ← skips when running locally
```

## Troubleshooting

### Issue: "Cannot connect to the Docker daemon"

**Fix:**
```bash
# Start Docker
sudo systemctl start docker

# Or if using Docker Desktop, launch it first

# Check Docker is running
docker ps
```

### Issue: "act: command not found" after install

**Fix:**
```bash
# Add to PATH
export PATH="$HOME/.local/bin:$PATH"

# Or reinstall to /usr/local/bin
sudo cp ~/.local/bin/act /usr/local/bin/act
```

### Issue: Actions using unsupported features

**Known limitations:**
- `services:` (Docker services) — partial support, use `--privileged`
- `save-state` / `set-output` — use `$GITHUB_OUTPUT` / `$GITHUB_STATE` instead
- Some marketplace actions may not work (especially ones needing GitHub API)

**Fix for GitHub API actions:**
```bash
# Provide a GitHub token
act -s GITHUB_TOKEN="ghp_xxx"
```

### Issue: Slow first run (downloading images)

**Fix:** Pre-pull images:
```bash
docker pull catthehacker/ubuntu:act-latest
```

### Issue: "OCI runtime create failed" on ARM (Apple Silicon / ARM64)

**Fix:**
```bash
# Use ARM-compatible images
act -P ubuntu-latest=catthehacker/ubuntu:act-latest
# Or
act --container-architecture linux/amd64
```

## Comparison with GitHub Actions

| Feature | GitHub Actions | act (local) |
|---------|---------------|-------------|
| **Speed** | Queues + cold start | Instant (reuse containers) |
| **Cost** | Uses CI minutes | Free (local Docker) |
| **Debugging** | Limited (re-run) | Full verbose + reuse |
| **Secrets** | GitHub UI | .env file or inline |
| **Network** | GitHub runners | Your local network |
| **Fidelity** | 100% | ~95% (some features unsupported) |

## Key Principles

1. **Test locally first** — Save CI minutes, catch errors early
2. **Use micro images** — Default `act-latest` is fast; only use `full` if needed
3. **Reuse containers** — `--reuse` flag dramatically speeds up iteration
4. **Secret safety** — Never commit `.env` files; use `.gitignore`
5. **Know the limits** — Some GitHub-specific features won't work locally

## Dependencies

- `docker` (Docker Engine or Docker Desktop)
- `curl` (for installation)
- Optional: `gh` CLI (for GitHub token)
