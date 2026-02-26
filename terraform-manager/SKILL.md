---
name: terraform-manager
description: >-
  Install, configure, and manage Terraform infrastructure — workspaces, plan/apply, state management, and drift detection.
categories: [dev-tools, automation]
dependencies: [bash, curl, unzip, jq]
---

# Terraform Manager

## What This Does

Automates Terraform infrastructure management from your OpenClaw agent. Install Terraform, manage workspaces, run plan/apply/destroy cycles, configure state backends (local, S3, GCS), and detect configuration drift — all without leaving your agent.

**Example:** "Install Terraform 1.9, init my AWS project, run plan, and alert me if there's drift from last apply."

## Quick Start (5 minutes)

### 1. Install Terraform

```bash
bash scripts/install.sh
# Detects OS/arch, downloads latest stable Terraform, installs to /usr/local/bin
# Output: ✅ Terraform v1.9.8 installed successfully
```

### 2. Initialize a Project

```bash
bash scripts/run.sh init --dir /path/to/terraform/project
# Runs terraform init, downloads providers, sets up backend
```

### 3. Run Plan

```bash
bash scripts/run.sh plan --dir /path/to/terraform/project
# Shows what would change without applying
```

### 4. Apply Changes

```bash
bash scripts/run.sh apply --dir /path/to/terraform/project
# Applies the plan (requires confirmation or --auto-approve)
```

## Core Workflows

### Workflow 1: Install or Upgrade Terraform

```bash
# Install latest
bash scripts/install.sh

# Install specific version
bash scripts/install.sh --version 1.8.5

# Check current version
bash scripts/run.sh version
```

**Output:**
```
📦 Downloading Terraform v1.9.8 for linux_arm64...
✅ Terraform v1.9.8 installed to /usr/local/bin/terraform
```

### Workflow 2: Full Plan → Apply Cycle

```bash
# Initialize
bash scripts/run.sh init --dir ./infra

# Format check
bash scripts/run.sh fmt --dir ./infra --check

# Validate config
bash scripts/run.sh validate --dir ./infra

# Plan (saves plan file)
bash scripts/run.sh plan --dir ./infra --out plan.tfplan

# Apply saved plan
bash scripts/run.sh apply --dir ./infra --plan plan.tfplan
```

**Output:**
```
[2026-02-26 08:00:00] 🔍 Running terraform plan...
Plan: 3 to add, 1 to change, 0 to destroy.

[2026-02-26 08:01:00] ✅ Apply complete! Resources: 3 added, 1 changed, 0 destroyed.
```

### Workflow 3: Workspace Management

```bash
# List workspaces
bash scripts/run.sh workspace list --dir ./infra

# Create new workspace
bash scripts/run.sh workspace new staging --dir ./infra

# Switch workspace
bash scripts/run.sh workspace select production --dir ./infra

# Delete workspace
bash scripts/run.sh workspace delete old-test --dir ./infra
```

### Workflow 4: Drift Detection

```bash
# Check for drift (compares state to actual infrastructure)
bash scripts/run.sh drift --dir ./infra

# Output:
# [2026-02-26 12:00:00] 🔍 Checking for drift...
# ⚠️ DRIFT DETECTED in 2 resources:
#   - aws_instance.web: instance_type changed (t3.micro → t3.small)
#   - aws_s3_bucket.data: tags modified externally
```

### Workflow 5: State Management

```bash
# List resources in state
bash scripts/run.sh state list --dir ./infra

# Show specific resource
bash scripts/run.sh state show aws_instance.web --dir ./infra

# Remove resource from state (without destroying)
bash scripts/run.sh state rm aws_instance.old --dir ./infra

# Move resource in state
bash scripts/run.sh state mv aws_instance.old aws_instance.new --dir ./infra

# Pull remote state
bash scripts/run.sh state pull --dir ./infra > state-backup.json
```

### Workflow 6: Destroy Infrastructure

```bash
# Preview destruction
bash scripts/run.sh plan --dir ./infra --destroy

# Destroy (requires confirmation)
bash scripts/run.sh destroy --dir ./infra

# Destroy with auto-approve (dangerous!)
bash scripts/run.sh destroy --dir ./infra --auto-approve
```

## Configuration

### Environment Variables

```bash
# AWS Provider
export AWS_ACCESS_KEY_ID="<key>"
export AWS_SECRET_ACCESS_KEY="<secret>"
export AWS_REGION="us-east-1"

# GCP Provider
export GOOGLE_CREDENTIALS="/path/to/service-account.json"
export GOOGLE_PROJECT="my-project"

# Azure Provider
export ARM_CLIENT_ID="<client-id>"
export ARM_CLIENT_SECRET="<secret>"
export ARM_SUBSCRIPTION_ID="<sub-id>"
export ARM_TENANT_ID="<tenant-id>"

# Terraform Cloud / Enterprise
export TF_TOKEN_app_terraform_io="<token>"
```

### Backend Configuration (S3 Example)

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## Advanced Usage

### Run as Drift Detection Cron

```bash
# Check for drift every 6 hours
0 */6 * * * cd /path/to/infra && bash /path/to/scripts/run.sh drift --dir . --alert telegram 2>&1 >> /var/log/terraform-drift.log
```

### Multi-Environment Deployment

```bash
# Deploy to staging first
bash scripts/run.sh workspace select staging --dir ./infra
bash scripts/run.sh apply --dir ./infra --auto-approve

# Then production
bash scripts/run.sh workspace select production --dir ./infra
bash scripts/run.sh plan --dir ./infra
# Review plan, then:
bash scripts/run.sh apply --dir ./infra
```

### Generate Resource Graph

```bash
bash scripts/run.sh graph --dir ./infra > infra.dot
# Convert to PNG (requires graphviz)
dot -Tpng infra.dot -o infra.png
```

### Import Existing Resources

```bash
bash scripts/run.sh import --dir ./infra aws_instance.web i-1234567890abcdef0
```

## Troubleshooting

### Issue: "terraform: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or add to PATH: export PATH=$PATH:/usr/local/bin
```

### Issue: "Error acquiring the state lock"

**Fix:**
```bash
# Force unlock (use with caution)
bash scripts/run.sh force-unlock <LOCK_ID> --dir ./infra
```

### Issue: Provider authentication errors

**Check:**
1. Environment variables are set: `env | grep AWS_`
2. Credentials are valid: `aws sts get-caller-identity`
3. Provider version is compatible: check `required_providers` in config

### Issue: State file corruption

**Fix:**
```bash
# Pull state backup
bash scripts/run.sh state pull --dir ./infra > state-backup.json

# If needed, push corrected state
bash scripts/run.sh state push --dir ./infra state-fixed.json
```

## Key Principles

1. **Always plan before apply** — Never apply without reviewing the plan
2. **Use workspaces** — Separate state per environment (dev/staging/prod)
3. **Lock state** — Use DynamoDB/GCS locking to prevent concurrent modifications
4. **Encrypt state** — State files contain secrets; always enable encryption
5. **Drift detection** — Schedule regular drift checks to catch manual changes
6. **Version pin** — Pin Terraform and provider versions in `required_version`

## Dependencies

- `bash` (4.0+)
- `curl` (for downloading Terraform)
- `unzip` (for extracting binary)
- `jq` (for JSON output parsing)
- Optional: `graphviz` (for resource graph visualization)
- Optional: cloud CLI tools (`aws`, `gcloud`, `az`) for provider auth
