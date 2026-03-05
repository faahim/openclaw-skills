---
name: cloudflare-workers
description: >-
  Deploy, manage, and monitor Cloudflare Workers serverless functions from the command line.
categories: [dev-tools, automation]
dependencies: [node, npm, wrangler]
---

# Cloudflare Workers Deployer

## What This Does

Deploy serverless JavaScript/TypeScript functions to Cloudflare's global edge network. Create workers, manage KV storage, set secrets, configure cron triggers, tail logs — all from the CLI. No servers to manage, runs in 300+ data centers worldwide.

**Example:** "Deploy a URL shortener worker, bind it to a KV namespace, set API secrets, and configure a cron to clean expired links every hour."

## Quick Start (5 minutes)

### 1. Install Wrangler CLI

```bash
bash scripts/install.sh
```

This installs `wrangler` (Cloudflare's official CLI) globally via npm.

### 2. Authenticate

```bash
# Interactive login (opens browser)
wrangler login

# OR use API token (headless/CI)
export CLOUDFLARE_API_TOKEN="your-api-token"
export CLOUDFLARE_ACCOUNT_ID="your-account-id"
```

To create an API token: Cloudflare Dashboard → My Profile → API Tokens → Create Token → "Edit Cloudflare Workers" template.

### 3. Create & Deploy Your First Worker

```bash
# Create a new worker project
bash scripts/run.sh create my-first-worker

# Deploy it
bash scripts/run.sh deploy my-first-worker
```

Output:
```
✅ Worker "my-first-worker" deployed successfully
🌐 URL: https://my-first-worker.<your-subdomain>.workers.dev
📍 Running in 300+ edge locations worldwide
```

## Core Workflows

### Workflow 1: Create a New Worker

```bash
bash scripts/run.sh create <worker-name> [--template <template>]
```

**Templates available:**
- `hello-world` (default) — Simple HTTP response
- `router` — URL routing with itty-router
- `kv-api` — CRUD API backed by KV storage
- `cron` — Scheduled worker with cron triggers
- `proxy` — Reverse proxy / API gateway

**Example:**
```bash
bash scripts/run.sh create url-shortener --template kv-api
```

### Workflow 2: Deploy a Worker

```bash
# Deploy from project directory
bash scripts/run.sh deploy <worker-name>

# Deploy with environment
bash scripts/run.sh deploy <worker-name> --env staging
bash scripts/run.sh deploy <worker-name> --env production
```

**Output:**
```
📦 Building worker...
✅ Deployed to https://url-shortener.your-sub.workers.dev
⏱️  Build time: 1.2s
📊 Size: 3.4 KB (limit: 1 MB free, 10 MB paid)
```

### Workflow 3: Manage KV Namespaces

```bash
# Create a KV namespace
bash scripts/run.sh kv create <namespace-name>

# List all KV namespaces
bash scripts/run.sh kv list

# Put a value
bash scripts/run.sh kv put <namespace> <key> <value>

# Get a value
bash scripts/run.sh kv get <namespace> <key>

# Delete a key
bash scripts/run.sh kv delete <namespace> <key>

# Bulk upload from JSON
bash scripts/run.sh kv bulk-put <namespace> data.json
```

### Workflow 4: Set Secrets

```bash
# Set a secret (prompted for value)
bash scripts/run.sh secret set <worker-name> <SECRET_NAME>

# Set from env var
echo "$API_KEY" | bash scripts/run.sh secret set <worker-name> API_KEY --stdin

# List secrets
bash scripts/run.sh secret list <worker-name>

# Delete a secret
bash scripts/run.sh secret delete <worker-name> <SECRET_NAME>
```

### Workflow 5: Tail Logs (Real-time)

```bash
# Stream live logs from a deployed worker
bash scripts/run.sh logs <worker-name>

# Filter by status
bash scripts/run.sh logs <worker-name> --status error

# Filter by search term
bash scripts/run.sh logs <worker-name> --search "timeout"
```

**Output:**
```
[2026-03-05 08:30:00] GET /api/links - 200 OK (12ms)
[2026-03-05 08:30:01] POST /api/links - 201 Created (8ms)
[2026-03-05 08:30:05] GET /api/links/abc123 - 404 Not Found (3ms)
```

### Workflow 6: Configure Cron Triggers

```bash
# Add a cron trigger
bash scripts/run.sh cron set <worker-name> "*/5 * * * *"

# List cron triggers
bash scripts/run.sh cron list <worker-name>

# Remove cron trigger
bash scripts/run.sh cron remove <worker-name>
```

### Workflow 7: Custom Domains

```bash
# Add a custom domain route
bash scripts/run.sh route add <worker-name> "api.example.com/*"

# List routes
bash scripts/run.sh route list <worker-name>

# Remove route
bash scripts/run.sh route remove <worker-name> <route-id>
```

### Workflow 8: List & Delete Workers

```bash
# List all deployed workers
bash scripts/run.sh list

# Get worker details
bash scripts/run.sh info <worker-name>

# Delete a worker
bash scripts/run.sh delete <worker-name>
```

## Configuration

### Environment Variables

```bash
# Required for headless/CI usage
export CLOUDFLARE_API_TOKEN="your-api-token"
export CLOUDFLARE_ACCOUNT_ID="your-account-id"

# Optional
export CF_WORKERS_SUBDOMAIN="your-subdomain"  # Custom workers.dev subdomain
```

### wrangler.toml (per-project config)

```toml
name = "my-worker"
main = "src/index.js"
compatibility_date = "2026-03-01"

# KV namespace bindings
[[kv_namespaces]]
binding = "MY_KV"
id = "abc123"

# Environment variables (non-secret)
[vars]
ENVIRONMENT = "production"
API_VERSION = "v2"

# Cron triggers
[triggers]
crons = ["*/5 * * * *"]

# Custom domain routes
routes = [
  { pattern = "api.example.com/*", zone_name = "example.com" }
]

# Staging environment
[env.staging]
name = "my-worker-staging"
vars = { ENVIRONMENT = "staging" }
```

## Advanced Usage

### Deploy from GitHub (CI/CD)

```bash
# In GitHub Actions workflow:
# 1. Set CLOUDFLARE_API_TOKEN as repo secret
# 2. Set CLOUDFLARE_ACCOUNT_ID as repo secret
# 3. Add step:
bash scripts/run.sh deploy <worker-name> --ci
```

### Multi-environment Deployments

```bash
# Deploy to staging
bash scripts/run.sh deploy my-api --env staging

# Run tests against staging
curl https://my-api-staging.your-sub.workers.dev/health

# Promote to production
bash scripts/run.sh deploy my-api --env production
```

### Worker Size Analysis

```bash
# Check bundle size breakdown
bash scripts/run.sh size <worker-name>
```

**Output:**
```
📦 Bundle Analysis: my-worker
   Total: 45.2 KB (limit: 1 MB free tier)
   ├── src/index.js      2.1 KB
   ├── src/router.js     1.8 KB
   └── node_modules/    41.3 KB
       ├── itty-router   3.2 KB
       └── ...
```

## Templates

### Hello World (default)

```javascript
export default {
  async fetch(request, env) {
    return new Response("Hello from Cloudflare Workers!", {
      headers: { "content-type": "text/plain" },
    });
  },
};
```

### KV-backed API

```javascript
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const key = url.pathname.slice(1);

    if (request.method === "GET") {
      const value = await env.MY_KV.get(key);
      if (!value) return new Response("Not found", { status: 404 });
      return new Response(value, {
        headers: { "content-type": "application/json" },
      });
    }

    if (request.method === "PUT") {
      const body = await request.text();
      await env.MY_KV.put(key, body);
      return new Response("Created", { status: 201 });
    }

    return new Response("Method not allowed", { status: 405 });
  },
};
```

### Cron Worker

```javascript
export default {
  async scheduled(event, env, ctx) {
    // Runs on schedule defined in wrangler.toml
    console.log(`Cron triggered at ${new Date().toISOString()}`);
    // Your scheduled task here
  },

  async fetch(request, env) {
    return new Response("Cron worker active");
  },
};
```

## Troubleshooting

### Issue: "Authentication error"

**Fix:**
```bash
# Re-authenticate
wrangler login

# Or check API token
echo $CLOUDFLARE_API_TOKEN | wrangler whoami
```

### Issue: "Worker size exceeds limit"

**Fix:**
```bash
# Check what's taking space
bash scripts/run.sh size <worker-name>

# Use --minify flag
wrangler deploy --minify
```

Free tier limit: 1 MB. Paid plan: 10 MB.

### Issue: "KV namespace not found"

**Fix:**
```bash
# List available namespaces
bash scripts/run.sh kv list

# Make sure wrangler.toml has correct namespace ID
```

### Issue: "Cron not firing"

**Check:**
1. Worker is deployed: `bash scripts/run.sh info <worker-name>`
2. Cron is set: `bash scripts/run.sh cron list <worker-name>`
3. Check logs: `bash scripts/run.sh logs <worker-name>`

## Free Tier Limits

- **Requests:** 100,000/day
- **Worker size:** 1 MB
- **KV reads:** 100,000/day
- **KV writes:** 1,000/day
- **KV storage:** 1 GB
- **Cron triggers:** 5 per worker
- **CPU time:** 10ms per invocation

## Dependencies

- `node` (18+)
- `npm`
- `wrangler` (installed by scripts/install.sh)
- Cloudflare account (free tier available)
