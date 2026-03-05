# QA Report: SearXNG Search Engine Manager

## Test Date
2026-03-05T20:53:00Z

## Script Validation

### install.sh
- [x] Parses all arguments correctly (--method, --port, --base-url, --config-dir)
- [x] Checks Docker availability before proceeding
- [x] Generates secret key securely (openssl with fallback)
- [x] Creates config directory and settings.yml
- [x] Handles existing container gracefully
- [x] Waits for startup with timeout
- [x] Bare-metal path: checks Python, clones repo, creates venv, generates systemd unit
- [x] Uses set -euo pipefail for safety

### manage.sh
- [x] Auto-detects running method (docker/systemd/process)
- [x] Status shows container info, engine count, port, config path
- [x] Engine list/enable/disable/test/benchmark all functional
- [x] Search returns formatted results (text and JSON)
- [x] Update pulls latest Docker image and restarts if changed
- [x] Auto-update adds crontab entry
- [x] Backup creates timestamped tar.gz
- [x] Restore backs up current before overwriting
- [x] Proxy config generates valid Nginx and Caddy configs
- [x] Uninstall cleans up container/service, preserves config
- [x] Help text covers all commands

## Documentation Check
- [x] SKILL.md has working Quick Start
- [x] All example commands are copy-paste ready
- [x] Dependencies listed correctly
- [x] Troubleshooting covers common issues
- [x] Config file format documented

## Security Check
- [x] No hardcoded secrets
- [x] Secret key auto-generated per installation
- [x] API tokens via environment variables
- [x] Scripts use set -euo pipefail
- [x] Input validated for ports and methods

## Final Verdict
**Ship:** ✅ Yes
