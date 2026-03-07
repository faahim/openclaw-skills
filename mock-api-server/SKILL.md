---
name: mock-api-server
description: >-
  Spin up local mock API servers from JSON files or OpenAPI specs — perfect for frontend development, testing, and demos.
categories: [dev-tools, automation]
dependencies: [node, npm, bash]
---

# Mock API Server

## What This Does

Creates instant, realistic mock API servers from simple JSON files or OpenAPI/Swagger specs. Perfect for frontend developers who need a backend before it's built, QA testing with predictable responses, and demos that don't depend on production APIs.

**Example:** "Define 5 API endpoints in a JSON file, get a running REST server with CRUD operations in 30 seconds."

## Quick Start (2 minutes)

### 1. Install

```bash
bash scripts/install.sh
```

This installs `json-server` (lightweight mock REST API) and `prism` (OpenAPI mock server).

### 2. Create a Simple Mock API

```bash
# Generate a sample API definition
bash scripts/mock.sh init my-api

# This creates my-api/db.json with sample data
# Edit it to match your needs, then:
bash scripts/mock.sh start my-api

# Output:
# 🚀 Mock API running at http://localhost:3100
# 
# Available endpoints:
#   GET    /users        - List all users
#   GET    /users/:id    - Get user by ID
#   POST   /users        - Create user
#   PUT    /users/:id    - Update user
#   DELETE /users/:id    - Delete user
#   GET    /posts        - List all posts
#   GET    /posts/:id    - Get post by ID
```

### 3. Test It

```bash
# List users
curl http://localhost:3100/users

# Create a user
curl -X POST http://localhost:3100/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com"}'

# Full CRUD works out of the box!
```

## Core Workflows

### Workflow 1: Mock from JSON (json-server)

**Use case:** Quick REST API from a data file

```bash
# Create the data file
cat > db.json << 'EOF'
{
  "users": [
    {"id": 1, "name": "Alice", "email": "alice@test.com", "role": "admin"},
    {"id": 2, "name": "Bob", "email": "bob@test.com", "role": "user"}
  ],
  "products": [
    {"id": 1, "name": "Widget", "price": 9.99, "stock": 100},
    {"id": 2, "name": "Gadget", "price": 24.99, "stock": 50}
  ],
  "orders": [
    {"id": 1, "userId": 1, "productId": 2, "quantity": 1, "status": "shipped"}
  ]
}
EOF

# Start server
bash scripts/mock.sh start-json db.json --port 3100

# Now you have full REST endpoints:
# GET/POST       /users, /products, /orders
# GET/PUT/DELETE  /users/:id, /products/:id, /orders/:id
# Filtering:      /users?role=admin
# Pagination:     /products?_page=1&_limit=10
# Sorting:        /products?_sort=price&_order=desc
# Full-text:      /users?q=alice
# Relationships:  /users/1/orders (if foreign key exists)
```

### Workflow 2: Mock from OpenAPI Spec (Prism)

**Use case:** Generate realistic responses from an OpenAPI/Swagger spec

```bash
# From a local spec file
bash scripts/mock.sh start-openapi ./openapi.yaml --port 4010

# From a remote URL
bash scripts/mock.sh start-openapi https://petstore3.swagger.io/api/v3/openapi.json --port 4010

# Prism generates realistic fake data matching your schema:
# String fields → realistic text
# Email fields → fake emails
# Number fields → random numbers in range
# Enum fields → random valid values
```

### Workflow 3: Quick Scaffold for Common APIs

**Use case:** Get pre-built mock data for common patterns

```bash
# E-commerce API (users, products, orders, reviews)
bash scripts/mock.sh scaffold ecommerce --port 3100

# Blog API (posts, comments, authors, tags)
bash scripts/mock.sh scaffold blog --port 3100

# Social API (users, posts, followers, likes, messages)
bash scripts/mock.sh scaffold social --port 3100

# Project management (projects, tasks, teams, sprints)
bash scripts/mock.sh scaffold project --port 3100
```

### Workflow 4: Custom Routes & Middleware

**Use case:** Add delays, errors, custom headers

```bash
# Add artificial latency (simulate slow network)
bash scripts/mock.sh start-json db.json --delay 500

# Start with custom routes file
bash scripts/mock.sh start-json db.json --routes routes.json

# routes.json example:
# {"/api/*": "/$1", "/auth/login": "/users/1"}
# This maps /api/users → /users and /auth/login → returns user 1
```

### Workflow 5: Record & Replay

**Use case:** Record real API responses, replay them locally

```bash
# Record responses from a real API
bash scripts/mock.sh record https://api.example.com/v1 --output recorded-api/

# Replay recorded responses
bash scripts/mock.sh start-json recorded-api/db.json --port 3100
```

## Configuration

### Port Configuration

```bash
# Default port: 3100
bash scripts/mock.sh start-json db.json --port 8080

# Bind to all interfaces (for Docker/remote access)
bash scripts/mock.sh start-json db.json --host 0.0.0.0
```

### CORS Configuration

```bash
# CORS is enabled by default for all origins
# To restrict:
bash scripts/mock.sh start-json db.json --cors "http://localhost:3000,http://localhost:5173"
```

### Routes File (URL Rewriting)

```json
{
  "/api/v1/*": "/$1",
  "/auth/login": "/users/1",
  "/auth/me": "/users/1",
  "/search": "/products?q="
}
```

## Advanced Usage

### Run as Background Service

```bash
# Start in background
bash scripts/mock.sh start-json db.json --daemon

# Check status
bash scripts/mock.sh status

# Stop
bash scripts/mock.sh stop

# View logs
bash scripts/mock.sh logs
```

### Multiple Mock Servers

```bash
# Run several mocks simultaneously
bash scripts/mock.sh start-json api-v1.json --port 3100 --daemon --name api-v1
bash scripts/mock.sh start-json api-v2.json --port 3200 --daemon --name api-v2

# List running
bash scripts/mock.sh status

# Stop specific
bash scripts/mock.sh stop api-v1
```

### Generate Mock Data

```bash
# Generate N records for a resource
bash scripts/mock.sh generate users 100 --fields "name:name,email:email,age:int:18-65,role:enum:admin|user|viewer"

# Output: JSON array of 100 realistic users
# Pipe to file:
bash scripts/mock.sh generate users 100 --fields "name:name,email:email" > db.json
```

## Troubleshooting

### Issue: "Port already in use"

**Fix:**
```bash
# Find what's using the port
lsof -i :3100

# Kill it or use a different port
bash scripts/mock.sh start-json db.json --port 3200
```

### Issue: "json-server not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
npm install -g json-server@0.17.4
```

### Issue: CORS errors in browser

**Check:** CORS is enabled by default. If using a custom setup:
```bash
bash scripts/mock.sh start-json db.json --cors "*"
```

### Issue: Changes to db.json not reflected

**Note:** json-server watches the file by default. If running in daemon mode, restart:
```bash
bash scripts/mock.sh restart
```

## Dependencies

- `node` (18+)
- `npm`
- `json-server` (installed by install.sh)
- `@stoplight/prism-cli` (installed by install.sh, optional for OpenAPI mocking)
- `bash` (4.0+)
