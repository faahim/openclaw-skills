# Listing Copy: MinIO Object Storage Manager

## Metadata
- **Type:** Skill
- **Name:** minio-storage
- **Display Name:** MinIO Object Storage Manager
- **Categories:** [data, dev-tools]
- **Icon:** 🗄️
- **Dependencies:** [bash, curl, wget]

## Tagline

Deploy self-hosted S3 storage — manage buckets, files, users & lifecycle from your agent

## Description

Setting up object storage shouldn't require a cloud account or a monthly bill. Whether you need backup storage, media hosting, or an S3-compatible API for your apps — you need something that runs on YOUR server.

MinIO Object Storage Manager lets your OpenClaw agent install, configure, and manage a full MinIO deployment. Create buckets, upload files, set access policies, manage users, and configure auto-expiry rules — all through simple bash commands. No web UI clicking required.

**What it does:**
- 🚀 One-command install (server + client CLI)
- 📦 Create and manage unlimited storage buckets
- 📤 Upload, download, and share files with presigned URLs
- 🔐 User management with fine-grained access policies
- ♻️ Lifecycle rules for automatic cleanup/expiry
- 🔄 Mirror buckets to AWS S3 or other MinIO instances
- 🖥️ Systemd service for auto-start on boot
- 📊 Disk usage monitoring and server health checks

Perfect for developers, self-hosters, and anyone who wants S3-compatible storage without the AWS bill.

## Core Capabilities

1. Automated installation — Downloads and installs MinIO server + client for your architecture
2. Server lifecycle — Start, stop, restart with credential management
3. Bucket operations — Create, delete, list, inspect storage buckets
4. File management — Upload, download, delete, recursive directory sync
5. Presigned URLs — Generate time-limited download links for sharing
6. Access policies — Public-read, private, custom JSON policies per bucket
7. User management — Create users, assign read/write/admin policies
8. Lifecycle rules — Auto-expire objects after N days
9. Systemd integration — Install as a boot service with one command
10. S3 compatibility — Works with any S3 SDK (boto3, aws-cli, etc.)
11. Data export/import — Full backup and restore of all buckets
12. Bucket mirroring — Sync data between MinIO instances or to AWS S3

## Dependencies
- `bash` (4.0+)
- `curl` or `wget`
- `openssl`

## Installation Time
**5 minutes** — Run install script, start server, create first bucket
