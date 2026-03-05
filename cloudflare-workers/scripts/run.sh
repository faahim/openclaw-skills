#!/bin/bash
# Cloudflare Workers Deployer — Main Script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
WORKERS_DIR="${CF_WORKERS_DIR:-$HOME/cloudflare-workers}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_ok() { echo -e "${GREEN}✅ $1${NC}"; }
log_err() { echo -e "${RED}❌ $1${NC}"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

check_wrangler() {
    if ! command -v wrangler &>/dev/null; then
        log_err "Wrangler not installed. Run: bash scripts/install.sh"
        exit 1
    fi
}

check_auth() {
    if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
        # Try wrangler whoami
        if ! wrangler whoami &>/dev/null 2>&1; then
            log_err "Not authenticated. Run 'wrangler login' or set CLOUDFLARE_API_TOKEN"
            exit 1
        fi
    fi
}

cmd_create() {
    local name="$1"
    local template="${2:-hello-world}"
    
    if [ -z "$name" ]; then
        log_err "Usage: run.sh create <worker-name> [--template <template>]"
        echo "Templates: hello-world, router, kv-api, cron, proxy"
        exit 1
    fi
    
    mkdir -p "$WORKERS_DIR"
    local project_dir="$WORKERS_DIR/$name"
    
    if [ -d "$project_dir" ]; then
        log_err "Worker '$name' already exists at $project_dir"
        exit 1
    fi
    
    mkdir -p "$project_dir/src"
    
    # Generate wrangler.toml
    cat > "$project_dir/wrangler.toml" <<EOF
name = "$name"
main = "src/index.js"
compatibility_date = "$(date +%Y-%m-%d)"
EOF
    
    # Generate worker from template
    case "$template" in
        hello-world)
            cat > "$project_dir/src/index.js" <<'WORKER'
export default {
  async fetch(request, env) {
    return new Response("Hello from Cloudflare Workers!", {
      headers: { "content-type": "text/plain" },
    });
  },
};
WORKER
            ;;
        router)
            cat > "$project_dir/src/index.js" <<'WORKER'
// Simple router without dependencies
const routes = {
  GET: {},
  POST: {},
  PUT: {},
  DELETE: {},
};

function get(path, handler) { routes.GET[path] = handler; }
function post(path, handler) { routes.POST[path] = handler; }

// Define routes
get("/", (req, env) => new Response("API v1"));
get("/health", (req, env) => new Response(JSON.stringify({ status: "ok", time: new Date().toISOString() }), {
  headers: { "content-type": "application/json" },
}));
get("/hello/:name", (req, env, params) => new Response(`Hello, ${params.name}!`));

function matchRoute(method, pathname) {
  const methodRoutes = routes[method] || {};
  for (const [pattern, handler] of Object.entries(methodRoutes)) {
    const paramNames = [];
    const regex = pattern.replace(/:(\w+)/g, (_, name) => {
      paramNames.push(name);
      return "([^/]+)";
    });
    const match = pathname.match(new RegExp(`^${regex}$`));
    if (match) {
      const params = {};
      paramNames.forEach((name, i) => params[name] = match[i + 1]);
      return { handler, params };
    }
  }
  return null;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const route = matchRoute(request.method, url.pathname);
    if (route) return route.handler(request, env, route.params);
    return new Response("Not Found", { status: 404 });
  },
};
WORKER
            ;;
        kv-api)
            cat > "$project_dir/wrangler.toml" <<EOF
name = "$name"
main = "src/index.js"
compatibility_date = "$(date +%Y-%m-%d)"

# Create KV namespace: wrangler kv:namespace create "DATA"
# Then paste the binding below:
# [[kv_namespaces]]
# binding = "DATA"
# id = "<your-namespace-id>"
EOF
            cat > "$project_dir/src/index.js" <<'WORKER'
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const key = url.pathname.slice(1);
    
    if (!key) {
      // List all keys
      const list = await env.DATA.list();
      return Response.json(list.keys.map(k => k.name));
    }

    switch (request.method) {
      case "GET": {
        const value = await env.DATA.get(key);
        if (!value) return new Response("Not found", { status: 404 });
        return new Response(value, { headers: { "content-type": "application/json" } });
      }
      case "PUT": {
        const body = await request.text();
        await env.DATA.put(key, body);
        return new Response("Created", { status: 201 });
      }
      case "DELETE": {
        await env.DATA.delete(key);
        return new Response("Deleted", { status: 200 });
      }
      default:
        return new Response("Method not allowed", { status: 405 });
    }
  },
};
WORKER
            ;;
        cron)
            cat > "$project_dir/wrangler.toml" <<EOF
name = "$name"
main = "src/index.js"
compatibility_date = "$(date +%Y-%m-%d)"

[triggers]
crons = ["*/5 * * * *"]
EOF
            cat > "$project_dir/src/index.js" <<'WORKER'
export default {
  async scheduled(event, env, ctx) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Cron triggered: ${event.cron}`);
    
    // Your scheduled task here
    // Examples:
    // - Clean up expired data
    // - Send periodic reports
    // - Sync data between services
    // - Health check external APIs
    
    console.log(`[${timestamp}] Cron completed`);
  },

  async fetch(request, env) {
    return Response.json({
      status: "active",
      message: "Cron worker running",
      time: new Date().toISOString(),
    });
  },
};
WORKER
            ;;
        proxy)
            cat > "$project_dir/src/index.js" <<'WORKER'
const UPSTREAM = "https://api.example.com";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const upstream = new URL(url.pathname + url.search, UPSTREAM);
    
    // Clone request with new URL
    const proxyRequest = new Request(upstream, {
      method: request.method,
      headers: request.headers,
      body: request.body,
    });
    
    // Add custom headers
    proxyRequest.headers.set("X-Forwarded-For", request.headers.get("CF-Connecting-IP") || "");
    proxyRequest.headers.set("X-Proxy", "cloudflare-worker");
    
    const response = await fetch(proxyRequest);
    
    // Clone response and add CORS headers
    const proxyResponse = new Response(response.body, response);
    proxyResponse.headers.set("Access-Control-Allow-Origin", "*");
    proxyResponse.headers.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    
    return proxyResponse;
  },
};
WORKER
            ;;
        *)
            log_err "Unknown template: $template"
            echo "Available: hello-world, router, kv-api, cron, proxy"
            exit 1
            ;;
    esac
    
    # Generate package.json
    cat > "$project_dir/package.json" <<EOF
{
  "name": "$name",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "tail": "wrangler tail"
  }
}
EOF
    
    log_ok "Worker '$name' created at $project_dir"
    echo "   Template: $template"
    echo ""
    echo "   Next steps:"
    echo "   cd $project_dir"
    echo "   wrangler dev          # Local development"
    echo "   wrangler deploy       # Deploy to Cloudflare"
}

cmd_deploy() {
    local name="$1"
    shift || true
    local extra_args="$*"
    
    if [ -z "$name" ]; then
        log_err "Usage: run.sh deploy <worker-name> [--env <environment>] [--ci]"
        exit 1
    fi
    
    local project_dir="$WORKERS_DIR/$name"
    if [ ! -d "$project_dir" ]; then
        log_err "Worker '$name' not found at $project_dir"
        exit 1
    fi
    
    check_auth
    
    log_info "Deploying '$name'..."
    cd "$project_dir"
    
    local deploy_args=""
    if echo "$extra_args" | grep -q "\-\-minify"; then
        deploy_args="$deploy_args --minify"
    fi
    
    if echo "$extra_args" | grep -q "\-\-env"; then
        local env_name=$(echo "$extra_args" | grep -oP '(?<=--env\s)\S+')
        deploy_args="$deploy_args --env $env_name"
    fi
    
    wrangler deploy $deploy_args
    
    log_ok "Worker '$name' deployed successfully"
}

cmd_list() {
    check_auth
    log_info "Listing deployed workers..."
    wrangler deployments list 2>/dev/null || wrangler whoami
    echo ""
    
    # Also list local workers
    if [ -d "$WORKERS_DIR" ]; then
        echo "Local worker projects:"
        for d in "$WORKERS_DIR"/*/; do
            if [ -f "$d/wrangler.toml" ]; then
                local wname=$(basename "$d")
                echo "  📦 $wname ($d)"
            fi
        done
    fi
}

cmd_info() {
    local name="$1"
    if [ -z "$name" ]; then
        log_err "Usage: run.sh info <worker-name>"
        exit 1
    fi
    
    local project_dir="$WORKERS_DIR/$name"
    if [ -f "$project_dir/wrangler.toml" ]; then
        echo "📦 Worker: $name"
        echo "📁 Path: $project_dir"
        echo ""
        echo "=== wrangler.toml ==="
        cat "$project_dir/wrangler.toml"
    else
        log_err "Worker '$name' not found locally"
    fi
}

cmd_delete() {
    local name="$1"
    if [ -z "$name" ]; then
        log_err "Usage: run.sh delete <worker-name>"
        exit 1
    fi
    
    check_auth
    
    log_warn "Deleting worker '$name' from Cloudflare..."
    wrangler delete --name "$name"
    
    # Optionally remove local directory
    local project_dir="$WORKERS_DIR/$name"
    if [ -d "$project_dir" ]; then
        read -p "Also remove local files at $project_dir? [y/N] " confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            rm -rf "$project_dir"
            log_ok "Local files removed"
        fi
    fi
    
    log_ok "Worker '$name' deleted"
}

cmd_logs() {
    local name="$1"
    shift || true
    
    if [ -z "$name" ]; then
        log_err "Usage: run.sh logs <worker-name> [--status error] [--search <term>]"
        exit 1
    fi
    
    check_auth
    
    log_info "Tailing logs for '$name'... (Ctrl+C to stop)"
    
    local tail_args="--name $name"
    
    if echo "$*" | grep -q "\-\-status"; then
        local status=$(echo "$*" | grep -oP '(?<=--status\s)\S+')
        tail_args="$tail_args --status $status"
    fi
    
    if echo "$*" | grep -q "\-\-search"; then
        local search=$(echo "$*" | grep -oP '(?<=--search\s)\S+')
        tail_args="$tail_args --search $search"
    fi
    
    wrangler tail $tail_args
}

cmd_kv() {
    local subcmd="$1"
    shift || true
    
    check_auth
    
    case "$subcmd" in
        create)
            local ns_name="$1"
            if [ -z "$ns_name" ]; then
                log_err "Usage: run.sh kv create <namespace-name>"
                exit 1
            fi
            wrangler kv:namespace create "$ns_name"
            log_ok "KV namespace '$ns_name' created"
            ;;
        list)
            wrangler kv:namespace list
            ;;
        put)
            local ns="$1" key="$2" value="$3"
            if [ -z "$ns" ] || [ -z "$key" ] || [ -z "$value" ]; then
                log_err "Usage: run.sh kv put <namespace-id> <key> <value>"
                exit 1
            fi
            wrangler kv:key put --namespace-id="$ns" "$key" "$value"
            log_ok "Set $key in namespace $ns"
            ;;
        get)
            local ns="$1" key="$2"
            if [ -z "$ns" ] || [ -z "$key" ]; then
                log_err "Usage: run.sh kv get <namespace-id> <key>"
                exit 1
            fi
            wrangler kv:key get --namespace-id="$ns" "$key"
            ;;
        delete)
            local ns="$1" key="$2"
            if [ -z "$ns" ] || [ -z "$key" ]; then
                log_err "Usage: run.sh kv delete <namespace-id> <key>"
                exit 1
            fi
            wrangler kv:key delete --namespace-id="$ns" "$key"
            log_ok "Deleted $key from namespace $ns"
            ;;
        bulk-put)
            local ns="$1" file="$2"
            if [ -z "$ns" ] || [ -z "$file" ]; then
                log_err "Usage: run.sh kv bulk-put <namespace-id> <json-file>"
                exit 1
            fi
            wrangler kv:bulk put --namespace-id="$ns" "$file"
            log_ok "Bulk upload complete"
            ;;
        *)
            log_err "Usage: run.sh kv <create|list|put|get|delete|bulk-put>"
            exit 1
            ;;
    esac
}

cmd_secret() {
    local subcmd="$1"
    shift || true
    
    check_auth
    
    case "$subcmd" in
        set)
            local name="$1" secret_name="$2"
            if [ -z "$name" ] || [ -z "$secret_name" ]; then
                log_err "Usage: run.sh secret set <worker-name> <SECRET_NAME>"
                exit 1
            fi
            local project_dir="$WORKERS_DIR/$name"
            if [ -d "$project_dir" ]; then
                cd "$project_dir"
            fi
            if echo "$*" | grep -q "\-\-stdin"; then
                wrangler secret put "$secret_name"
            else
                wrangler secret put "$secret_name"
            fi
            ;;
        list)
            local name="$1"
            if [ -z "$name" ]; then
                log_err "Usage: run.sh secret list <worker-name>"
                exit 1
            fi
            local project_dir="$WORKERS_DIR/$name"
            if [ -d "$project_dir" ]; then
                cd "$project_dir"
            fi
            wrangler secret list
            ;;
        delete)
            local name="$1" secret_name="$2"
            if [ -z "$name" ] || [ -z "$secret_name" ]; then
                log_err "Usage: run.sh secret delete <worker-name> <SECRET_NAME>"
                exit 1
            fi
            local project_dir="$WORKERS_DIR/$name"
            if [ -d "$project_dir" ]; then
                cd "$project_dir"
            fi
            wrangler secret delete "$secret_name"
            ;;
        *)
            log_err "Usage: run.sh secret <set|list|delete>"
            exit 1
            ;;
    esac
}

cmd_cron() {
    local subcmd="$1"
    shift || true
    
    case "$subcmd" in
        set)
            local name="$1" expr="$2"
            if [ -z "$name" ] || [ -z "$expr" ]; then
                log_err "Usage: run.sh cron set <worker-name> '<cron-expression>'"
                exit 1
            fi
            local project_dir="$WORKERS_DIR/$name"
            local toml="$project_dir/wrangler.toml"
            if [ ! -f "$toml" ]; then
                log_err "Worker '$name' not found"
                exit 1
            fi
            # Add/update cron trigger in wrangler.toml
            if grep -q "\[triggers\]" "$toml"; then
                sed -i "s|crons = \[.*\]|crons = [\"$expr\"]|" "$toml"
            else
                echo "" >> "$toml"
                echo "[triggers]" >> "$toml"
                echo "crons = [\"$expr\"]" >> "$toml"
            fi
            log_ok "Cron set to '$expr' for worker '$name'"
            echo "   Re-deploy to activate: bash scripts/run.sh deploy $name"
            ;;
        list)
            local name="$1"
            if [ -z "$name" ]; then
                log_err "Usage: run.sh cron list <worker-name>"
                exit 1
            fi
            local toml="$WORKERS_DIR/$name/wrangler.toml"
            if [ -f "$toml" ]; then
                grep -A1 "\[triggers\]" "$toml" 2>/dev/null || echo "No cron triggers configured"
            fi
            ;;
        remove)
            local name="$1"
            if [ -z "$name" ]; then
                log_err "Usage: run.sh cron remove <worker-name>"
                exit 1
            fi
            local toml="$WORKERS_DIR/$name/wrangler.toml"
            if [ -f "$toml" ]; then
                sed -i '/\[triggers\]/,/^$/d' "$toml"
                log_ok "Cron triggers removed from '$name'"
            fi
            ;;
        *)
            log_err "Usage: run.sh cron <set|list|remove>"
            exit 1
            ;;
    esac
}

cmd_route() {
    local subcmd="$1"
    shift || true
    check_auth
    
    case "$subcmd" in
        add)
            local name="$1" pattern="$2"
            if [ -z "$name" ] || [ -z "$pattern" ]; then
                log_err "Usage: run.sh route add <worker-name> '<pattern>'"
                exit 1
            fi
            log_info "Adding route '$pattern' for worker '$name'"
            wrangler routes add --name "$name" --pattern "$pattern" 2>/dev/null || \
                log_warn "Add the route manually in wrangler.toml under [[routes]]"
            ;;
        list)
            local name="$1"
            if [ -n "$name" ]; then
                local toml="$WORKERS_DIR/$name/wrangler.toml"
                if [ -f "$toml" ]; then
                    grep -A2 "routes" "$toml" 2>/dev/null || echo "No routes configured"
                fi
            fi
            ;;
        *)
            log_err "Usage: run.sh route <add|list>"
            exit 1
            ;;
    esac
}

cmd_size() {
    local name="$1"
    if [ -z "$name" ]; then
        log_err "Usage: run.sh size <worker-name>"
        exit 1
    fi
    
    local project_dir="$WORKERS_DIR/$name"
    if [ ! -d "$project_dir" ]; then
        log_err "Worker '$name' not found"
        exit 1
    fi
    
    echo "📦 Bundle Analysis: $name"
    echo ""
    
    # Show file sizes
    find "$project_dir/src" -type f -exec du -sh {} \; 2>/dev/null | sort -rh
    
    if [ -d "$project_dir/node_modules" ]; then
        echo ""
        echo "node_modules:"
        du -sh "$project_dir/node_modules" 2>/dev/null
    fi
    
    echo ""
    echo "Total project size:"
    du -sh "$project_dir" 2>/dev/null
}

# Main dispatcher
check_wrangler

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    create)
        # Parse --template flag
        name="$1"
        shift || true
        template="hello-world"
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --template) template="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        cmd_create "$name" "$template"
        ;;
    deploy)   cmd_deploy "$@" ;;
    list)     cmd_list ;;
    info)     cmd_info "$@" ;;
    delete)   cmd_delete "$@" ;;
    logs)     cmd_logs "$@" ;;
    kv)       cmd_kv "$@" ;;
    secret)   cmd_secret "$@" ;;
    cron)     cmd_cron "$@" ;;
    route)    cmd_route "$@" ;;
    size)     cmd_size "$@" ;;
    help|--help|-h)
        echo "Cloudflare Workers Deployer"
        echo ""
        echo "Usage: run.sh <command> [options]"
        echo ""
        echo "Commands:"
        echo "  create <name> [--template <t>]  Create a new worker project"
        echo "  deploy <name> [--env <env>]     Deploy a worker to Cloudflare"
        echo "  list                            List all workers"
        echo "  info <name>                     Show worker details"
        echo "  delete <name>                   Delete a worker"
        echo "  logs <name>                     Tail live logs"
        echo "  kv <create|list|put|get|delete> Manage KV namespaces"
        echo "  secret <set|list|delete>        Manage worker secrets"
        echo "  cron <set|list|remove>          Manage cron triggers"
        echo "  route <add|list>                Manage custom domain routes"
        echo "  size <name>                     Analyze bundle size"
        echo ""
        echo "Templates: hello-world, router, kv-api, cron, proxy"
        ;;
    *)
        log_err "Unknown command: $COMMAND"
        echo "Run 'run.sh help' for usage"
        exit 1
        ;;
esac
