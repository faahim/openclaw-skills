# QA Report: Certificate Watcher

## Test Date
2026-02-25T11:55:00Z

## Quick Start Test
**Ran:** `bash scripts/certwatch.sh check google.com`
**Result:** ✅ Pass — Shows valid cert with days left, expiry date, issuer

## Core Workflows

### Single Domain Check
**Command:** `bash scripts/certwatch.sh check google.com`
**Output:** `✅ google.com — Valid 53 days (expires 2026-04-20) — WR2`
**Result:** ✅ Pass

### Verbose Check
**Command:** `bash scripts/certwatch.sh check --verbose google.com`
**Output:** Full report with subject, issuer, dates, serial, SANs, status
**Result:** ✅ Pass

### Multi-Domain Scan
**Command:** `bash scripts/certwatch.sh scan google.com github.com cloudflare.com`
**Output:** 3 domains scanned, summary line with counts
**Result:** ✅ Pass

### JSON Output
**Command:** `bash scripts/certwatch.sh scan --format json google.com github.com`
**Output:** Valid JSON array with domain objects
**Result:** ✅ Pass

## Documentation Check
- [x] SKILL.md has working Quick Start
- [x] All example commands are copy-paste ready
- [x] Dependencies are listed correctly
- [x] Troubleshooting section covers common issues

## Security Check
- [x] No hardcoded secrets
- [x] API tokens read from environment variables
- [x] Scripts use `set -euo pipefail`
- [x] Input validation for domains

## Final Verdict
**Ship:** ✅ Yes
