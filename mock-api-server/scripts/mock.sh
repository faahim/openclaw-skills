#!/bin/bash
# Mock API Server — Main CLI
# Usage: bash mock.sh <command> [options]

set -euo pipefail

MOCK_DIR="${MOCK_API_DIR:-$HOME/.mock-api-server}"
DEFAULT_PORT=3100
PID_DIR="$MOCK_DIR/pids"
LOG_DIR="$MOCK_DIR/logs"
DATA_DIR="$MOCK_DIR/data"

mkdir -p "$PID_DIR" "$LOG_DIR" "$DATA_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1" >&2; }

usage() {
    cat << 'EOF'
Mock API Server — Instant REST APIs for development

USAGE:
  mock.sh <command> [arguments] [options]

COMMANDS:
  init <name>                    Create a new mock API project
  start <name>                   Start a named mock project
  start-json <file> [options]    Start from a JSON data file
  start-openapi <spec> [options] Start from OpenAPI/Swagger spec
  scaffold <template> [options]  Quick-start from a template
  generate <resource> <count>    Generate mock data
  stop [name]                    Stop mock server(s)
  restart [name]                 Restart mock server(s)
  status                         Show running mock servers
  logs [name]                    View server logs
  list                           List all mock projects

OPTIONS:
  --port <port>      Port to listen on (default: 3100)
  --host <host>      Host to bind to (default: localhost)
  --delay <ms>       Add response delay in milliseconds
  --cors <origins>   CORS allowed origins (default: *)
  --routes <file>    Custom routes file (JSON)
  --daemon           Run in background
  --name <name>      Name for daemon process

TEMPLATES (scaffold):
  ecommerce          Users, products, orders, reviews
  blog               Posts, comments, authors, tags
  social             Users, posts, followers, likes, messages
  project            Projects, tasks, teams, sprints

EXAMPLES:
  mock.sh init my-api
  mock.sh start my-api --port 8080
  mock.sh start-json db.json --daemon --name api
  mock.sh scaffold ecommerce --port 3100
  mock.sh generate users 50 --fields "name:name,email:email"
  mock.sh status
  mock.sh stop api
EOF
}

# ─── INIT ────────────────────────────────────────────────────
cmd_init() {
    local name="${1:?Usage: mock.sh init <name>}"
    local dir="$DATA_DIR/$name"

    if [ -d "$dir" ]; then
        error "Project '$name' already exists at $dir"
        exit 1
    fi

    mkdir -p "$dir"
    cat > "$dir/db.json" << 'DBEOF'
{
  "users": [
    {"id": 1, "name": "Alice Johnson", "email": "alice@example.com", "role": "admin", "createdAt": "2026-01-15T10:30:00Z"},
    {"id": 2, "name": "Bob Smith", "email": "bob@example.com", "role": "user", "createdAt": "2026-01-20T14:22:00Z"},
    {"id": 3, "name": "Carol Davis", "email": "carol@example.com", "role": "user", "createdAt": "2026-02-01T09:15:00Z"}
  ],
  "posts": [
    {"id": 1, "title": "Getting Started", "body": "Welcome to the API!", "userId": 1, "published": true, "createdAt": "2026-02-10T11:00:00Z"},
    {"id": 2, "title": "Advanced Usage", "body": "Here are some tips...", "userId": 2, "published": false, "createdAt": "2026-02-15T16:30:00Z"}
  ],
  "comments": [
    {"id": 1, "body": "Great post!", "postId": 1, "userId": 2, "createdAt": "2026-02-10T12:00:00Z"},
    {"id": 2, "body": "Very helpful", "postId": 1, "userId": 3, "createdAt": "2026-02-11T08:45:00Z"}
  ]
}
DBEOF

    cat > "$dir/routes.json" << 'RTEOF'
{
  "/api/v1/*": "/$1"
}
RTEOF

    info "Created mock project: $name"
    echo "  📁 $dir/db.json    — Edit this to define your API data"
    echo "  🔀 $dir/routes.json — Edit this to add URL rewrites"
    echo ""
    echo "  Start: bash scripts/mock.sh start $name"
}

# ─── START (named project) ───────────────────────────────────
cmd_start() {
    local name="${1:?Usage: mock.sh start <name>}"
    shift
    local dir="$DATA_DIR/$name"

    if [ ! -d "$dir" ]; then
        error "Project '$name' not found. Run: mock.sh init $name"
        exit 1
    fi

    local args=("$dir/db.json")
    if [ -f "$dir/routes.json" ]; then
        args+=(--routes "$dir/routes.json")
    fi
    args+=(--name "$name")

    cmd_start_json "${args[@]}" "$@"
}

# ─── START-JSON ──────────────────────────────────────────────
cmd_start_json() {
    local file="${1:?Usage: mock.sh start-json <file> [options]}"
    shift

    if [ ! -f "$file" ]; then
        error "File not found: $file"
        exit 1
    fi

    # Parse options
    local port=$DEFAULT_PORT
    local host="localhost"
    local delay=0
    local cors="*"
    local routes=""
    local daemon=false
    local name="mock-$$"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)   port="$2"; shift 2 ;;
            --host)   host="$2"; shift 2 ;;
            --delay)  delay="$2"; shift 2 ;;
            --cors)   cors="$2"; shift 2 ;;
            --routes) routes="$2"; shift 2 ;;
            --daemon) daemon=true; shift ;;
            --name)   name="$2"; shift 2 ;;
            *) warn "Unknown option: $1"; shift ;;
        esac
    done

    # Check if port is in use
    if lsof -i ":$port" &>/dev/null 2>&1; then
        error "Port $port is already in use"
        echo "  Use --port <other-port> or stop the existing server"
        exit 1
    fi

    # Build json-server command
    local cmd="json-server"
    local args=(--watch "$file" --port "$port" --host "$host")

    if [ "$delay" -gt 0 ]; then
        args+=(--delay "$delay")
    fi

    if [ -n "$routes" ] && [ -f "$routes" ]; then
        args+=(--routes "$routes")
    fi

    # Print endpoints
    echo ""
    echo -e "🚀 ${CYAN}Mock API Server${NC} starting..."
    echo -e "   📍 http://${host}:${port}"
    echo ""

    # Extract resource names from JSON
    local resources
    resources=$(python3 -c "
import json, sys
with open('$file') as f:
    data = json.load(f)
for key in data:
    count = len(data[key]) if isinstance(data[key], list) else 1
    print(f'  {key} ({count} records)')
" 2>/dev/null || echo "  (couldn't parse resources)")

    echo "   Available resources:"
    echo "$resources"
    echo ""
    echo "   Each resource supports: GET, POST, PUT, PATCH, DELETE"
    echo "   Filtering: ?field=value  Pagination: ?_page=1&_limit=10"
    echo "   Sorting: ?_sort=field&_order=asc  Search: ?q=term"
    echo ""

    if [ "$daemon" = true ]; then
        nohup $cmd "${args[@]}" > "$LOG_DIR/$name.log" 2>&1 &
        local pid=$!
        echo "$pid" > "$PID_DIR/$name.pid"
        echo "$port" > "$PID_DIR/$name.port"
        info "Running in background (PID: $pid, name: $name)"
        echo "  Logs: bash scripts/mock.sh logs $name"
        echo "  Stop: bash scripts/mock.sh stop $name"
    else
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
        echo ""
        $cmd "${args[@]}"
    fi
}

# ─── START-OPENAPI ───────────────────────────────────────────
cmd_start_openapi() {
    local spec="${1:?Usage: mock.sh start-openapi <spec-file-or-url> [options]}"
    shift

    if ! command -v prism &>/dev/null; then
        error "Prism not installed. Run: npm install -g @stoplight/prism-cli"
        exit 1
    fi

    local port=4010
    local host="127.0.0.1"
    local daemon=false
    local name="prism-$$"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)   port="$2"; shift 2 ;;
            --host)   host="$2"; shift 2 ;;
            --daemon) daemon=true; shift ;;
            --name)   name="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    echo ""
    echo -e "🚀 ${CYAN}OpenAPI Mock Server (Prism)${NC} starting..."
    echo -e "   📍 http://${host}:${port}"
    echo -e "   📄 Spec: $spec"
    echo ""

    if [ "$daemon" = true ]; then
        nohup prism mock "$spec" --port "$port" --host "$host" > "$LOG_DIR/$name.log" 2>&1 &
        local pid=$!
        echo "$pid" > "$PID_DIR/$name.pid"
        echo "$port" > "$PID_DIR/$name.port"
        info "Running in background (PID: $pid, name: $name)"
    else
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
        echo ""
        prism mock "$spec" --port "$port" --host "$host"
    fi
}

# ─── SCAFFOLD ────────────────────────────────────────────────
cmd_scaffold() {
    local template="${1:?Usage: mock.sh scaffold <template> [options]}"
    shift

    local port=$DEFAULT_PORT
    local daemon=false
    local name="scaffold-$template"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)   port="$2"; shift 2 ;;
            --daemon) daemon=true; shift ;;
            --name)   name="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local dbfile="$DATA_DIR/${template}-scaffold.json"

    case $template in
        ecommerce)
            cat > "$dbfile" << 'EOF'
{
  "users": [
    {"id": 1, "name": "Alice Johnson", "email": "alice@shop.com", "address": "123 Main St", "createdAt": "2026-01-10"},
    {"id": 2, "name": "Bob Smith", "email": "bob@shop.com", "address": "456 Oak Ave", "createdAt": "2026-01-15"},
    {"id": 3, "name": "Carol Lee", "email": "carol@shop.com", "address": "789 Pine Rd", "createdAt": "2026-02-01"}
  ],
  "products": [
    {"id": 1, "name": "Wireless Headphones", "price": 79.99, "category": "electronics", "stock": 150, "rating": 4.5},
    {"id": 2, "name": "Coffee Maker", "price": 49.99, "category": "kitchen", "stock": 80, "rating": 4.2},
    {"id": 3, "name": "Running Shoes", "price": 119.99, "category": "sports", "stock": 200, "rating": 4.8},
    {"id": 4, "name": "Desk Lamp", "price": 34.99, "category": "home", "stock": 120, "rating": 4.0},
    {"id": 5, "name": "Backpack", "price": 59.99, "category": "travel", "stock": 90, "rating": 4.6}
  ],
  "orders": [
    {"id": 1, "userId": 1, "products": [{"productId": 1, "quantity": 1}, {"productId": 3, "quantity": 1}], "total": 199.98, "status": "delivered", "createdAt": "2026-02-05"},
    {"id": 2, "userId": 2, "products": [{"productId": 2, "quantity": 2}], "total": 99.98, "status": "shipped", "createdAt": "2026-02-20"},
    {"id": 3, "userId": 3, "products": [{"productId": 5, "quantity": 1}], "total": 59.99, "status": "processing", "createdAt": "2026-03-01"}
  ],
  "reviews": [
    {"id": 1, "productId": 1, "userId": 2, "rating": 5, "comment": "Great sound quality!", "createdAt": "2026-02-10"},
    {"id": 2, "productId": 3, "userId": 1, "rating": 4, "comment": "Very comfortable", "createdAt": "2026-02-12"},
    {"id": 3, "productId": 2, "userId": 3, "rating": 4, "comment": "Makes great coffee", "createdAt": "2026-02-25"}
  ]
}
EOF
            ;;
        blog)
            cat > "$dbfile" << 'EOF'
{
  "authors": [
    {"id": 1, "name": "Jane Doe", "bio": "Tech writer and developer", "avatar": "https://i.pravatar.cc/150?u=jane"},
    {"id": 2, "name": "John Smith", "bio": "Open source enthusiast", "avatar": "https://i.pravatar.cc/150?u=john"}
  ],
  "posts": [
    {"id": 1, "title": "Introduction to REST APIs", "body": "REST APIs are the backbone of modern web development...", "authorId": 1, "published": true, "tags": ["api", "rest", "tutorial"], "createdAt": "2026-02-01"},
    {"id": 2, "title": "Docker for Beginners", "body": "Docker containers simplify deployment...", "authorId": 2, "published": true, "tags": ["docker", "devops", "tutorial"], "createdAt": "2026-02-10"},
    {"id": 3, "title": "Advanced TypeScript Patterns", "body": "Let's explore some advanced TypeScript patterns...", "authorId": 1, "published": false, "tags": ["typescript", "advanced"], "createdAt": "2026-02-20"}
  ],
  "comments": [
    {"id": 1, "postId": 1, "author": "Reader1", "body": "Very helpful, thanks!", "createdAt": "2026-02-02"},
    {"id": 2, "postId": 1, "author": "DevGuy", "body": "Great explanation", "createdAt": "2026-02-03"},
    {"id": 3, "postId": 2, "author": "NewbieDev", "body": "Finally understand Docker!", "createdAt": "2026-02-11"}
  ],
  "tags": [
    {"id": 1, "name": "api", "count": 1},
    {"id": 2, "name": "rest", "count": 1},
    {"id": 3, "name": "docker", "count": 1},
    {"id": 4, "name": "typescript", "count": 1},
    {"id": 5, "name": "tutorial", "count": 2}
  ]
}
EOF
            ;;
        social)
            cat > "$dbfile" << 'EOF'
{
  "users": [
    {"id": 1, "username": "alice_dev", "name": "Alice", "bio": "Building cool things", "followers": 1200, "following": 340},
    {"id": 2, "username": "bob_codes", "name": "Bob", "bio": "Open source contributor", "followers": 890, "following": 150},
    {"id": 3, "username": "carol_tech", "name": "Carol", "bio": "DevOps engineer", "followers": 2100, "following": 420}
  ],
  "posts": [
    {"id": 1, "userId": 1, "content": "Just shipped a new feature! 🚀", "likes": 42, "reposts": 5, "createdAt": "2026-03-01T10:00:00Z"},
    {"id": 2, "userId": 2, "content": "Working on something exciting...", "likes": 28, "reposts": 3, "createdAt": "2026-03-02T14:30:00Z"},
    {"id": 3, "userId": 3, "content": "Kubernetes tips thread 🧵", "likes": 156, "reposts": 45, "createdAt": "2026-03-03T09:15:00Z"}
  ],
  "messages": [
    {"id": 1, "fromId": 1, "toId": 2, "text": "Hey, great PR!", "read": true, "createdAt": "2026-03-01T11:00:00Z"},
    {"id": 2, "fromId": 2, "toId": 1, "text": "Thanks! Let's collab", "read": false, "createdAt": "2026-03-01T11:05:00Z"}
  ],
  "followers": [
    {"id": 1, "userId": 1, "followerId": 2},
    {"id": 2, "userId": 1, "followerId": 3},
    {"id": 3, "userId": 3, "followerId": 1}
  ]
}
EOF
            ;;
        project)
            cat > "$dbfile" << 'EOF'
{
  "teams": [
    {"id": 1, "name": "Frontend", "lead": "Alice"},
    {"id": 2, "name": "Backend", "lead": "Bob"}
  ],
  "projects": [
    {"id": 1, "name": "Web App Redesign", "teamId": 1, "status": "active", "startDate": "2026-01-15", "dueDate": "2026-04-30"},
    {"id": 2, "name": "API v2", "teamId": 2, "status": "planning", "startDate": "2026-03-01", "dueDate": "2026-06-15"}
  ],
  "sprints": [
    {"id": 1, "projectId": 1, "name": "Sprint 5", "startDate": "2026-02-24", "endDate": "2026-03-07", "status": "active"},
    {"id": 2, "projectId": 1, "name": "Sprint 6", "startDate": "2026-03-10", "endDate": "2026-03-21", "status": "planned"}
  ],
  "tasks": [
    {"id": 1, "sprintId": 1, "title": "Update navigation", "assignee": "Alice", "status": "done", "priority": "high", "points": 5},
    {"id": 2, "sprintId": 1, "title": "Fix login bug", "assignee": "Carol", "status": "in-progress", "priority": "critical", "points": 3},
    {"id": 3, "sprintId": 1, "title": "Add dark mode", "assignee": "Dave", "status": "todo", "priority": "medium", "points": 8},
    {"id": 4, "sprintId": 2, "title": "Performance audit", "assignee": "Alice", "status": "todo", "priority": "high", "points": 5}
  ]
}
EOF
            ;;
        *)
            error "Unknown template: $template"
            echo "Available: ecommerce, blog, social, project"
            exit 1
            ;;
    esac

    info "Scaffolded '$template' API → $dbfile"

    local args=("$dbfile" --port "$port" --name "$name")
    [ "$daemon" = true ] && args+=(--daemon)
    cmd_start_json "${args[@]}"
}

# ─── GENERATE ────────────────────────────────────────────────
cmd_generate() {
    local resource="${1:?Usage: mock.sh generate <resource> <count> [--fields spec]}"
    local count="${2:?Usage: mock.sh generate <resource> <count>}"
    shift 2

    local fields=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fields) fields="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    python3 -c "
import json, random, string, sys

count = $count
resource = '$resource'
fields = '$fields'

# Name pools
first_names = ['Alice', 'Bob', 'Carol', 'Dave', 'Eve', 'Frank', 'Grace', 'Hank', 'Ivy', 'Jack',
               'Kate', 'Leo', 'Mia', 'Noah', 'Olivia', 'Pete', 'Quinn', 'Rose', 'Sam', 'Tina']
last_names = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis',
              'Rodriguez', 'Martinez', 'Wilson', 'Anderson', 'Taylor', 'Thomas', 'Moore']
domains = ['gmail.com', 'outlook.com', 'company.com', 'test.io', 'example.com']

def gen_name():
    return random.choice(first_names) + ' ' + random.choice(last_names)

def gen_email(name=''):
    if name:
        parts = name.lower().split()
        return parts[0] + '.' + parts[-1] + '@' + random.choice(domains)
    return ''.join(random.choices(string.ascii_lowercase, k=8)) + '@' + random.choice(domains)

def gen_field(ftype):
    parts = ftype.split(':')
    kind = parts[0]
    if kind == 'name': return gen_name()
    if kind == 'email': return gen_email()
    if kind == 'int':
        lo, hi = (int(parts[1]), int(parts[2])) if len(parts) >= 3 else (1, 1000)
        return random.randint(lo, hi)
    if kind == 'float':
        lo, hi = (float(parts[1]), float(parts[2])) if len(parts) >= 3 else (0.0, 100.0)
        return round(random.uniform(lo, hi), 2)
    if kind == 'bool': return random.choice([True, False])
    if kind == 'enum':
        options = parts[1].split('|') if len(parts) > 1 else ['a', 'b', 'c']
        return random.choice(options)
    if kind == 'string':
        length = int(parts[1]) if len(parts) > 1 else 10
        return ''.join(random.choices(string.ascii_lowercase + ' ', k=length)).strip()
    return kind

records = []
if fields:
    field_specs = [f.split(':', 1) for f in fields.split(',')]
    for i in range(count):
        record = {'id': i + 1}
        for fname, ftype in field_specs:
            record[fname] = gen_field(ftype)
        records.append(record)
else:
    for i in range(count):
        name = gen_name()
        records.append({'id': i + 1, 'name': name, 'email': gen_email(name)})

output = {resource: records}
print(json.dumps(output, indent=2))
"
}

# ─── STATUS ──────────────────────────────────────────────────
cmd_status() {
    echo -e "${CYAN}Mock API Server — Running Instances${NC}"
    echo ""

    local found=false
    for pidfile in "$PID_DIR"/*.pid; do
        [ -f "$pidfile" ] || continue
        local name
        name=$(basename "$pidfile" .pid)
        local pid
        pid=$(cat "$pidfile")
        local port="?"
        [ -f "$PID_DIR/$name.port" ] && port=$(cat "$PID_DIR/$name.port")

        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  ${GREEN}●${NC} $name — PID $pid — Port $port"
            found=true
        else
            echo -e "  ${RED}●${NC} $name — STOPPED (stale PID $pid)"
            rm -f "$pidfile" "$PID_DIR/$name.port"
        fi
    done

    if [ "$found" = false ]; then
        echo "  No mock servers running"
    fi
    echo ""
}

# ─── STOP ────────────────────────────────────────────────────
cmd_stop() {
    local name="${1:-}"

    if [ -z "$name" ]; then
        # Stop all
        for pidfile in "$PID_DIR"/*.pid; do
            [ -f "$pidfile" ] || continue
            local n
            n=$(basename "$pidfile" .pid)
            local pid
            pid=$(cat "$pidfile")
            if kill "$pid" 2>/dev/null; then
                info "Stopped $n (PID $pid)"
            fi
            rm -f "$pidfile" "$PID_DIR/$n.port"
        done
    else
        local pidfile="$PID_DIR/$name.pid"
        if [ ! -f "$pidfile" ]; then
            error "No running server named '$name'"
            exit 1
        fi
        local pid
        pid=$(cat "$pidfile")
        if kill "$pid" 2>/dev/null; then
            info "Stopped $name (PID $pid)"
        fi
        rm -f "$pidfile" "$PID_DIR/$name.port"
    fi
}

# ─── RESTART ─────────────────────────────────────────────────
cmd_restart() {
    local name="${1:?Usage: mock.sh restart <name>}"
    warn "Restart not yet implemented — stop and start manually"
}

# ─── LOGS ────────────────────────────────────────────────────
cmd_logs() {
    local name="${1:-}"

    if [ -z "$name" ]; then
        ls "$LOG_DIR"/*.log 2>/dev/null || echo "No logs found"
    else
        local logfile="$LOG_DIR/$name.log"
        if [ -f "$logfile" ]; then
            tail -50 "$logfile"
        else
            error "No logs for '$name'"
        fi
    fi
}

# ─── LIST ────────────────────────────────────────────────────
cmd_list() {
    echo -e "${CYAN}Mock API Projects${NC}"
    echo ""

    for dir in "$DATA_DIR"/*/; do
        [ -d "$dir" ] || continue
        local name
        name=$(basename "$dir")
        local dbfile="$dir/db.json"
        if [ -f "$dbfile" ]; then
            local resources
            resources=$(python3 -c "
import json
with open('$dbfile') as f:
    data = json.load(f)
print(', '.join(data.keys()))
" 2>/dev/null || echo "?")
            echo "  📁 $name — Resources: $resources"
        fi
    done

    # Also list scaffold files
    for f in "$DATA_DIR"/*-scaffold.json; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f" .json)
        echo "  📄 $name (scaffold)"
    done

    echo ""
}

# ─── MAIN ────────────────────────────────────────────────────
cmd="${1:-help}"
shift 2>/dev/null || true

case $cmd in
    init)          cmd_init "$@" ;;
    start)         cmd_start "$@" ;;
    start-json)    cmd_start_json "$@" ;;
    start-openapi) cmd_start_openapi "$@" ;;
    scaffold)      cmd_scaffold "$@" ;;
    generate)      cmd_generate "$@" ;;
    stop)          cmd_stop "$@" ;;
    restart)       cmd_restart "$@" ;;
    status)        cmd_status ;;
    logs)          cmd_logs "$@" ;;
    list)          cmd_list ;;
    help|--help|-h) usage ;;
    *)             error "Unknown command: $cmd"; usage; exit 1 ;;
esac
