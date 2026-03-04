---
name: bun-manager
description: >-
  Install, update, and manage the Bun JavaScript runtime. Switch versions, migrate projects from npm/yarn/pnpm, and optimize workflows.
categories: [dev-tools, automation]
dependencies: [curl, bash]
---

# Bun Runtime Manager

## What This Does

Installs and manages the [Bun](https://bun.sh) JavaScript/TypeScript runtime — the fast all-in-one toolkit that replaces Node.js, npm, yarn, and more. This skill handles installation, version management, project migration from npm/yarn/pnpm, and common Bun workflows.

**Example:** "Install Bun, switch to version 1.2, migrate my project from npm to Bun, and set up a dev script."

## Quick Start (2 minutes)

### 1. Install Bun

```bash
bash scripts/install.sh
```

This installs Bun to `~/.bun` and adds it to your PATH.

### 2. Verify Installation

```bash
bun --version
```

### 3. Create a New Project

```bash
bun init my-app
cd my-app
bun run index.ts
```

## Core Workflows

### Workflow 1: Install or Update Bun

```bash
# Install latest
bash scripts/install.sh

# Install specific version
bash scripts/install.sh --version 1.2.0

# Update to latest
bash scripts/install.sh --update

# Check current version
bun --version
```

### Workflow 2: Migrate Project from npm/yarn/pnpm to Bun

```bash
# Run migration (converts lockfile, removes node_modules, reinstalls)
bash scripts/migrate.sh /path/to/project

# What it does:
# 1. Detects current package manager (npm/yarn/pnpm)
# 2. Removes old lockfile (package-lock.json / yarn.lock / pnpm-lock.yaml)
# 3. Removes node_modules
# 4. Runs `bun install` to generate bun.lockb
# 5. Tests that `bun run build` works (if build script exists)
# 6. Reports any incompatible dependencies
```

**Output:**
```
🔍 Detected: npm (package-lock.json)
🗑️  Removed package-lock.json
🗑️  Removed node_modules/
📦 Running bun install...
   Installed 847 packages in 2.3s (was ~45s with npm)
✅ Migration complete!
⚡ Speed improvement: ~20x faster installs
⚠️  Check these packages for Bun compatibility:
   - node-sass (use sass instead)
```

### Workflow 3: Version Management

```bash
# List available versions
bash scripts/version.sh list

# Install and switch to a specific version
bash scripts/version.sh use 1.2.0

# Show current version + path
bash scripts/version.sh current
```

### Workflow 4: Project Setup with Bun

```bash
# Create new project
bun init my-project

# Create with specific template
bun create next-app my-next-app
bun create elysia my-api
bun create hono my-hono-app

# Add TypeScript (built-in, no config needed)
echo 'console.log("Hello!")' > index.ts
bun run index.ts
```

### Workflow 5: Script Runner (Replace npx)

```bash
# Run any package without installing
bunx create-react-app my-app
bunx prisma generate
bunx tsc --init

# Run project scripts
bun run dev
bun run build
bun run test
```

### Workflow 6: Dependency Management

```bash
# Add dependencies
bun add express hono zod

# Add dev dependencies
bun add -d typescript @types/node vitest

# Remove dependencies
bun remove express

# Update all dependencies
bun update

# Show outdated packages
bun outdated
```

## Configuration

### Environment Variables

```bash
# Custom install directory (default: ~/.bun)
export BUN_INSTALL="$HOME/.bun"

# Add to PATH (usually done by installer)
export PATH="$BUN_INSTALL/bin:$PATH"

# Set default registry (for private registries)
export BUN_CONFIG_REGISTRY="https://registry.npmjs.org"

# Set auth token for private packages
export BUN_CONFIG_TOKEN="npm_xxxxx"
```

### bunfig.toml (Project Config)

```toml
# bunfig.toml — place in project root

[install]
# Use exact versions by default
exact = true

# Peer dependency handling
peer = false

[install.scopes]
# Private registry for scoped packages
"@mycompany" = { token = "$NPM_TOKEN", url = "https://npm.mycompany.com/" }

[run]
# Shell to use for scripts
shell = "bash"
```

## Advanced Usage

### Run as HTTP Server (Built-in)

```bash
# Bun has a built-in HTTP server — no Express needed
cat > server.ts << 'EOF'
const server = Bun.serve({
  port: 3000,
  fetch(req) {
    return new Response("Hello from Bun!");
  },
});
console.log(`Listening on http://localhost:${server.port}`);
EOF

bun run server.ts
```

### Build & Bundle (Built-in Bundler)

```bash
# Bundle for production
bun build ./src/index.ts --outdir ./dist --minify

# Bundle as single executable
bun build ./src/cli.ts --compile --outfile myapp
```

### SQLite (Built-in)

```bash
cat > db.ts << 'EOF'
import { Database } from "bun:sqlite";
const db = new Database("mydb.sqlite");
db.run("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)");
db.run("INSERT INTO users (name) VALUES (?)", ["Alice"]);
console.log(db.query("SELECT * FROM users").all());
EOF

bun run db.ts
```

### Testing (Built-in Test Runner)

```bash
# Create test file
cat > math.test.ts << 'EOF'
import { expect, test } from "bun:test";
test("2 + 2 = 4", () => {
  expect(2 + 2).toBe(4);
});
EOF

# Run tests
bun test
```

## Troubleshooting

### Issue: "bun: command not found"

**Fix:**
```bash
# Re-run installer
bash scripts/install.sh

# Or manually add to PATH
export PATH="$HOME/.bun/bin:$PATH"
echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: Package incompatible with Bun

**Check:** Some Node.js packages use native addons that may not work with Bun yet.

```bash
# Check compatibility
bun pm ls | grep -i native

# Common replacements:
# node-sass → sass
# bcrypt → @node-rs/bcrypt
# sharp → @napi-rs/image (or use sharp — now supported)
```

### Issue: Scripts not running

**Fix:** Bun uses its own script runner. If a script needs Node.js specifically:

```json
{
  "scripts": {
    "dev": "bun run --bun vite",
    "node-only": "node scripts/legacy.js"
  }
}
```

### Issue: Lockfile conflicts in CI

**Fix:** Use `bun install --frozen-lockfile` in CI:

```bash
# CI pipeline
bun install --frozen-lockfile
bun test
bun run build
```

## Key Principles

1. **Fast** — Bun is 10-30x faster than npm for installs
2. **All-in-one** — Runtime, bundler, test runner, package manager
3. **Node-compatible** — Runs most Node.js code unmodified
4. **TypeScript native** — No need for ts-node or tsx
5. **Built-in tools** — SQLite, HTTP server, WebSocket, test runner

## Dependencies

- `curl` (for installation)
- `bash` (4.0+)
- `unzip` (usually pre-installed)
- Linux (x64/arm64) or macOS (x64/arm64)
