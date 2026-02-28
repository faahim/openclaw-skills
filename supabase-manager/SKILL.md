---
name: supabase-manager
description: >-
  Install, configure, and manage Supabase projects — local dev, migrations, database management, edge functions, and production deployment from the CLI.
categories: [dev-tools, data]
dependencies: [docker, supabase-cli]
---

# Supabase Manager

## What This Does

Manage Supabase projects entirely from the command line. Start local dev environments, run database migrations, deploy edge functions, manage secrets, seed data, and monitor your Supabase instance — all without touching the dashboard.

**Example:** "Spin up a local Supabase stack, create a migration for a users table, test edge functions locally, then deploy everything to production."

## Quick Start (10 minutes)

### 1. Install Supabase CLI

```bash
# Check if already installed
which supabase && supabase --version

# Install via npm (recommended)
npm install -g supabase

# Or via Homebrew (macOS/Linux)
brew install supabase/tap/supabase

# Or direct binary (Linux amd64)
curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz | tar xzf - -C /usr/local/bin supabase

# For arm64 (e.g., Raspberry Pi, Oracle ARM)
curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase_linux_arm64.tar.gz | tar xzf - -C /usr/local/bin supabase
```

### 2. Verify Docker is Running

```bash
# Supabase local dev requires Docker
docker info > /dev/null 2>&1 && echo "Docker OK" || echo "Docker not running — start it first"
```

### 3. Initialize a Project

```bash
# Create project directory
mkdir my-project && cd my-project

# Initialize Supabase
supabase init

# Start local Supabase stack (Postgres, Auth, Storage, Edge Functions, Studio)
supabase start

# Output shows:
#   API URL: http://127.0.0.1:54321
#   GraphQL URL: http://127.0.0.1:54321/graphql/v1
#   S3 Storage URL: http://127.0.0.1:54321/storage/v1/s3
#   DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
#   Studio URL: http://127.0.0.1:54323
#   Inbucket URL: http://127.0.0.1:54324
#   anon key: <key>
#   service_role key: <key>
```

### 4. Link to Remote Project

```bash
# Login to Supabase
supabase login

# Link to existing project (get project ref from dashboard URL)
supabase link --project-ref <your-project-ref>

# Pull remote schema
supabase db pull
```

## Core Workflows

### Workflow 1: Create & Run Database Migrations

**Use case:** Add tables, indexes, RLS policies to your database with version control.

```bash
# Create a new migration
supabase migration new create_users_table

# Edit the migration file (created in supabase/migrations/)
cat > supabase/migrations/$(ls -t supabase/migrations/ | head -1) << 'SQL'
CREATE TABLE public.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Policy: users can read their own data
CREATE POLICY "Users can read own data"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

-- Policy: users can update their own data
CREATE POLICY "Users can update own data"
  ON public.users FOR UPDATE
  USING (auth.uid() = id);
SQL

# Apply migration locally
supabase db reset

# Push migration to production
supabase db push
```

### Workflow 2: Manage Edge Functions

**Use case:** Deploy serverless functions that run on Deno.

```bash
# Create a new edge function
supabase functions new hello-world

# Edit the function
cat > supabase/functions/hello-world/index.ts << 'TS'
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"

serve(async (req) => {
  const { name } = await req.json()
  return new Response(
    JSON.stringify({ message: `Hello ${name}!` }),
    { headers: { "Content-Type": "application/json" } },
  )
})
TS

# Test locally
supabase functions serve hello-world

# In another terminal:
curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/hello-world' \
  --header 'Authorization: Bearer <anon-key>' \
  --header 'Content-Type: application/json' \
  --data '{"name":"World"}'

# Deploy to production
supabase functions deploy hello-world
```

### Workflow 3: Seed Database with Test Data

**Use case:** Populate your local dev database with sample data.

```bash
# Create seed file
cat > supabase/seed.sql << 'SQL'
-- Insert test users
INSERT INTO public.users (email, display_name) VALUES
  ('alice@example.com', 'Alice'),
  ('bob@example.com', 'Bob'),
  ('charlie@example.com', 'Charlie');
SQL

# Apply seed data (runs after migrations on db reset)
supabase db reset
```

### Workflow 4: Manage Secrets & Environment Variables

**Use case:** Set API keys and secrets for edge functions.

```bash
# Set secrets for edge functions
supabase secrets set MY_API_KEY=sk-1234567890 WEBHOOK_URL=https://hooks.example.com/notify

# List current secrets
supabase secrets list

# Unset a secret
supabase secrets unset MY_API_KEY
```

### Workflow 5: Database Diff & Schema Changes

**Use case:** Make changes in Studio UI, then capture as migration.

```bash
# After making changes in local Studio (http://127.0.0.1:54323):
supabase db diff --use-migra -f add_posts_table

# This creates a migration file with the SQL diff
cat supabase/migrations/$(ls -t supabase/migrations/ | head -1)

# Review and push to production
supabase db push
```

### Workflow 6: Generate TypeScript Types

**Use case:** Get type-safe database types for your frontend.

```bash
# Generate types from local database
supabase gen types typescript --local > types/supabase.ts

# Or from remote project
supabase gen types typescript --linked > types/supabase.ts

# Use in your app:
# import { Database } from './types/supabase'
# const supabase = createClient<Database>(url, key)
```

### Workflow 7: Inspect & Debug

**Use case:** Check database status, running services, logs.

```bash
# Check local stack status
supabase status

# View database logs
supabase db logs

# View edge function logs (production)
supabase functions logs hello-world

# List all migrations
supabase migration list

# Open Studio in browser
echo "http://127.0.0.1:54323"
```

### Workflow 8: Branching (Preview Environments)

**Use case:** Test schema changes in isolated branches.

```bash
# Create a database branch (requires paid plan)
supabase branches create feature-new-schema

# Switch to branch
supabase branches switch feature-new-schema

# Make changes, test, then merge or delete
supabase branches delete feature-new-schema
```

## Configuration

### Project Config (supabase/config.toml)

```toml
[project]
id = "your-project-ref"

[api]
enabled = true
port = 54321
schemas = ["public", "graphql_public"]

[db]
port = 54322
major_version = 15

[studio]
enabled = true
port = 54323

[auth]
enabled = true
site_url = "http://localhost:3000"

[auth.external.google]
enabled = false
client_id = ""
secret = ""
```

### Environment Variables

```bash
# Supabase access token (from supabase login)
export SUPABASE_ACCESS_TOKEN="sbp_..."

# For CI/CD pipelines
export SUPABASE_DB_PASSWORD="your-db-password"
export SUPABASE_PROJECT_REF="your-project-ref"
```

## Advanced Usage

### CI/CD Pipeline Integration

```bash
# In GitHub Actions / CI:
supabase link --project-ref $SUPABASE_PROJECT_REF
supabase db push
supabase functions deploy --all
```

### Backup Database

```bash
# Dump production database
pg_dump $(supabase status -o json | jq -r '.DB_URL') > backup.sql

# Or for local
pg_dump postgresql://postgres:postgres@127.0.0.1:54322/postgres > backup.sql
```

### Reset Everything

```bash
# Stop and remove all local containers + data
supabase stop --no-backup

# Fresh start
supabase start
```

### Multiple Projects

```bash
# Each directory is its own project
cd ~/project-a && supabase start
cd ~/project-b && supabase start  # Uses different ports automatically
```

## Troubleshooting

### Issue: "Cannot connect to Docker daemon"

**Fix:**
```bash
# Start Docker
sudo systemctl start docker
# Or on macOS: open Docker Desktop

# Verify
docker ps
```

### Issue: "Port already in use"

**Fix:**
```bash
# Stop existing Supabase instance
supabase stop

# Or change ports in supabase/config.toml
```

### Issue: Migration conflicts

**Fix:**
```bash
# List applied migrations
supabase migration list

# Repair migration history (mark as applied without running)
supabase migration repair --status applied <version>

# Or reverted
supabase migration repair --status reverted <version>
```

### Issue: "supabase start" hangs

**Fix:**
```bash
# Pull images manually first
docker pull supabase/postgres:15.6.1.143
docker pull supabase/gotrue:v2.158.1
docker pull supabase/realtime:v2.33.58
docker pull supabase/storage-api:v1.11.13
docker pull supabase/edge-runtime:v1.62.2

# Then retry
supabase start
```

### Issue: Edge function deployment fails

**Fix:**
```bash
# Check function locally first
supabase functions serve my-function --debug

# Verify imports use pinned versions
# Bad:  import { serve } from "https://deno.land/std/http/server.ts"
# Good: import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
```

## Dependencies

- `docker` (20.10+) — required for local dev stack
- `supabase` CLI (1.100+) — main tool
- `pg_dump` (optional) — for database backups
- `jq` (optional) — for parsing JSON output

## Key Principles

1. **Migrations are king** — Never modify production DB directly; use migrations
2. **Local first** — Always test locally before pushing to production
3. **Type safety** — Generate TypeScript types after every schema change
4. **RLS always** — Enable Row Level Security on every table
5. **Seed data** — Keep seed.sql updated for consistent dev environments
