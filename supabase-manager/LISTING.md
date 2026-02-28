# Listing Copy: Supabase Manager

## Metadata
- **Type:** Skill
- **Name:** supabase-manager
- **Display Name:** Supabase Manager
- **Categories:** [dev-tools, data]
- **Price:** $12
- **Dependencies:** [docker, supabase-cli]
- **Icon:** 🟢

## Tagline

Manage Supabase projects from CLI — migrations, edge functions, secrets, and deployment

## Description

Setting up and managing Supabase projects through the web dashboard gets tedious fast — especially when you're juggling multiple projects, need repeatable deployments, or want CI/CD integration. You need command-line control.

Supabase Manager gives your OpenClaw agent full control over Supabase projects. Initialize projects, create and run database migrations with RLS policies, deploy edge functions, manage secrets, generate TypeScript types, seed test data, and push to production — all from the terminal. No dashboard clicking required.

**What it does:**
- 🚀 Initialize and start local Supabase stack (Postgres, Auth, Storage, Edge Functions)
- 📝 Create and manage database migrations with version control
- ⚡ Deploy Deno edge functions locally and to production
- 🔑 Manage secrets and environment variables
- 🔄 Generate TypeScript types from your schema
- 🌱 Seed databases with test data
- 🔍 Health checks and debugging tools
- 🏗️ CI/CD pipeline integration ready

Perfect for developers building with Supabase who want automated, repeatable project management without leaving the terminal.

## Quick Start Preview

```bash
# Install Supabase CLI
bash scripts/install.sh

# Initialize and start local dev
supabase init && supabase start

# Create a migration
supabase migration new create_users_table

# Deploy edge function
supabase functions deploy hello-world
```

## Core Capabilities

1. **Local dev stack** — Spin up Postgres, Auth, Storage, Realtime, Studio locally via Docker
2. **Migration management** — Create, apply, diff, and push database migrations
3. **Edge functions** — Create, test, and deploy Deno serverless functions
4. **Type generation** — Auto-generate TypeScript types from database schema
5. **Secret management** — Set, list, and remove environment variables for functions
6. **Database seeding** — Populate dev databases with consistent test data
7. **Schema diffing** — Capture UI changes as versioned migration files
8. **Health checks** — Verify CLI, Docker, project status, and container health
9. **CI/CD ready** — Scripts for automated deployment pipelines
10. **Multi-project** — Manage multiple Supabase projects from one machine

## Dependencies
- `docker` (20.10+)
- `supabase` CLI (auto-installed by scripts/install.sh)
- `jq` (optional, for JSON parsing)

## Installation Time
**10 minutes** — Install CLI, start Docker, init project
