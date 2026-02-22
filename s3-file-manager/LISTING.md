# Listing Copy: S3 File Manager

## Metadata
- **Type:** Skill
- **Name:** s3-file-manager
- **Display Name:** S3 File Manager
- **Categories:** [data, automation]
- **Price:** $12
- **Dependencies:** [aws-cli, bash, jq]

## Tagline

Manage S3 buckets and files — upload, sync, lifecycle policies, and storage reports

## Description

Manually managing files on AWS S3 through the console is slow and error-prone. Remembering aws-cli flags for sync, lifecycle policies, and pre-signed URLs wastes time every single day.

S3 File Manager wraps the AWS CLI into simple, memorable commands your OpenClaw agent can run instantly. Upload files, sync directories, set auto-deletion policies, generate temporary download links, and get storage reports — all without touching the AWS console.

**What it does:**
- 📤 Upload/download files and directories with progress tracking
- 🔄 Sync local ↔ S3 with exclude patterns and delete mirroring
- 📋 Lifecycle policies — auto-archive to Glacier, auto-delete old files
- 🔗 Pre-signed URLs for temporary secure sharing
- 📊 Storage reports across all buckets (size, object count, region)
- 🗑️ Safe deletes with dry-run support
- 🌐 Works with S3-compatible services (DigitalOcean Spaces, MinIO, Cloudflare R2)

Perfect for developers, DevOps engineers, and anyone who uses S3 for backups, static assets, or data storage.

## Core Capabilities

1. File upload — Single files or recursive directory uploads with ACL control
2. File download — Pull files or entire prefixes from S3 to local
3. Directory sync — Bidirectional sync with exclude patterns and delete mode
4. Bucket management — Create, delete, and inspect buckets
5. Lifecycle policies — Auto-expire, Glacier transition, abort incomplete uploads
6. Pre-signed URLs — Generate temporary secure download links
7. Storage reports — Cross-bucket usage dashboard with sizes and object counts
8. File search — Find files by pattern across bucket prefixes
9. Storage usage — Check size of any prefix (like `du` for S3)
10. S3-compatible — Works with DigitalOcean Spaces, MinIO, Cloudflare R2
11. Safe deletes — Dry-run mode before destructive operations
12. Auto-install — One-command AWS CLI setup for Linux and macOS

## Dependencies
- `aws-cli` (v2, auto-installed by install.sh)
- `bash` (4.0+)
- `jq` (JSON parsing)

## Installation Time
**5 minutes** — Run install.sh, configure credentials, start managing files
