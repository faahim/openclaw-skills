---
name: graphviz-diagrams
description: >-
  Generate architecture diagrams, flowcharts, and dependency graphs as PNG/SVG images from DOT language using Graphviz.
categories: [design, dev-tools]
dependencies: [graphviz, bash]
---

# Graphviz Diagram Generator

## What This Does

Generates professional diagrams (architecture, flowcharts, dependency graphs, state machines, ERDs) as PNG/SVG images directly from text descriptions using Graphviz. Your agent describes the diagram in DOT language, this skill renders it to an actual image file.

**Example:** "Generate an architecture diagram of a microservices system with 5 services" → produces a PNG/SVG you can share or embed.

## Quick Start (2 minutes)

### 1. Install Graphviz

```bash
bash scripts/install.sh
```

### 2. Generate Your First Diagram

```bash
bash scripts/render.sh --type flowchart --output my-diagram.png <<'DOT'
digraph {
  rankdir=LR
  node [shape=box style=filled fillcolor="#e8f4fd" fontname="Arial"]
  
  Start -> "Process Data" -> "Validate" -> End
  "Validate" -> "Handle Error" [label="invalid"]
  "Handle Error" -> "Process Data" [label="retry"]
}
DOT
```

### 3. Use Templates

```bash
# List available templates
bash scripts/render.sh --list-templates

# Generate from template
bash scripts/render.sh --template microservices --output arch.png \
  --var "services=API Gateway,Auth Service,User Service,Order Service,Payment Service"
```

## Core Workflows

### Workflow 1: Architecture Diagram

**Use case:** Visualize system architecture

```bash
bash scripts/render.sh --type architecture --output system-arch.svg <<'DOT'
digraph architecture {
  rankdir=TB
  node [shape=box style="filled,rounded" fontname="Arial" fontsize=11]
  edge [fontname="Arial" fontsize=9]
  
  subgraph cluster_frontend {
    label="Frontend" style=filled fillcolor="#f0f9ff"
    web [label="React App" fillcolor="#93c5fd"]
    mobile [label="Mobile App" fillcolor="#93c5fd"]
  }
  
  subgraph cluster_backend {
    label="Backend" style=filled fillcolor="#f0fdf4"
    api [label="API Gateway" fillcolor="#86efac"]
    auth [label="Auth Service" fillcolor="#86efac"]
    users [label="User Service" fillcolor="#86efac"]
    orders [label="Order Service" fillcolor="#86efac"]
  }
  
  subgraph cluster_data {
    label="Data Layer" style=filled fillcolor="#fef9c3"
    postgres [label="PostgreSQL" shape=cylinder fillcolor="#fde68a"]
    redis [label="Redis Cache" shape=cylinder fillcolor="#fde68a"]
    queue [label="RabbitMQ" shape=cylinder fillcolor="#fde68a"]
  }
  
  web -> api [label="HTTPS"]
  mobile -> api [label="HTTPS"]
  api -> auth
  api -> users
  api -> orders
  users -> postgres
  orders -> postgres
  auth -> redis
  orders -> queue
}
DOT
```

### Workflow 2: Flowchart

**Use case:** Document a process or decision tree

```bash
bash scripts/render.sh --type flowchart --output deploy-flow.png <<'DOT'
digraph deploy {
  node [shape=box style="filled,rounded" fillcolor="#dbeafe" fontname="Arial"]
  
  start [label="Push to main" shape=oval fillcolor="#bbf7d0"]
  tests [label="Run Tests"]
  pass [label="Tests Pass?" shape=diamond fillcolor="#fef08a"]
  build [label="Build Docker Image"]
  deploy_staging [label="Deploy to Staging"]
  smoke [label="Smoke Tests Pass?" shape=diamond fillcolor="#fef08a"]
  deploy_prod [label="Deploy to Production"]
  notify_fail [label="Notify Team" fillcolor="#fecaca"]
  done [label="Done" shape=oval fillcolor="#bbf7d0"]
  
  start -> tests -> pass
  pass -> build [label="yes"]
  pass -> notify_fail [label="no"]
  build -> deploy_staging -> smoke
  smoke -> deploy_prod [label="yes"]
  smoke -> notify_fail [label="no"]
  deploy_prod -> done
}
DOT
```

### Workflow 3: Entity Relationship Diagram

**Use case:** Database schema visualization

```bash
bash scripts/render.sh --type erd --output schema.png <<'DOT'
digraph erd {
  node [shape=record style=filled fillcolor="#f8fafc" fontname="Arial" fontsize=10]
  edge [fontname="Arial" fontsize=9]
  
  users [label="{users|id: serial PK\l|email: varchar\l|name: varchar\l|created_at: timestamp\l}"]
  orders [label="{orders|id: serial PK\l|user_id: int FK\l|total: decimal\l|status: varchar\l|created_at: timestamp\l}"]
  products [label="{products|id: serial PK\l|name: varchar\l|price: decimal\l|stock: int\l}"]
  order_items [label="{order_items|id: serial PK\l|order_id: int FK\l|product_id: int FK\l|quantity: int\l}"]
  
  users -> orders [label="1:N"]
  orders -> order_items [label="1:N"]
  products -> order_items [label="1:N"]
}
DOT
```

### Workflow 4: Dependency Graph

**Use case:** Visualize project or package dependencies

```bash
# Generate from package.json
bash scripts/deps-graph.sh --input package.json --output deps.png

# Generate from requirements.txt
bash scripts/deps-graph.sh --input requirements.txt --output deps.png
```

### Workflow 5: State Machine

**Use case:** Document state transitions

```bash
bash scripts/render.sh --type state --output order-states.svg <<'DOT'
digraph states {
  rankdir=LR
  node [shape=circle style=filled fillcolor="#dbeafe" fontname="Arial" fontsize=10 width=1.2]
  edge [fontname="Arial" fontsize=9]
  
  created [fillcolor="#bbf7d0"]
  processing [fillcolor="#fef08a"]
  shipped [fillcolor="#e9d5ff"]
  delivered [fillcolor="#bbf7d0"]
  cancelled [fillcolor="#fecaca"]
  
  created -> processing [label="payment received"]
  processing -> shipped [label="packed & sent"]
  shipped -> delivered [label="confirmed receipt"]
  created -> cancelled [label="timeout/cancel"]
  processing -> cancelled [label="refund requested"]
}
DOT
```

## Templates

Built-in templates for common diagrams:

### Generate from template

```bash
# Microservices architecture
bash scripts/render.sh --template microservices --output arch.png \
  --var "services=API,Auth,Users,Orders,Notifications"

# CI/CD pipeline
bash scripts/render.sh --template cicd --output pipeline.png \
  --var "stages=Build,Test,Deploy Staging,Integration Tests,Deploy Prod"

# Network topology
bash scripts/render.sh --template network --output network.png \
  --var "nodes=Firewall,Load Balancer,Web Server 1,Web Server 2,Database"
```

## Batch Generation

```bash
# Render all .dot files in a directory
bash scripts/render.sh --batch ./diagrams/ --format svg --output-dir ./images/

# Watch directory and auto-render on changes
bash scripts/render.sh --watch ./diagrams/ --format png --output-dir ./images/
```

## Configuration

### Output Formats

```bash
# PNG (default, best for sharing)
bash scripts/render.sh --format png --dpi 300 --output diagram.png < input.dot

# SVG (scalable, best for web/docs)
bash scripts/render.sh --format svg --output diagram.svg < input.dot

# PDF (best for print)
bash scripts/render.sh --format pdf --output diagram.pdf < input.dot
```

### Styling

```bash
# Dark theme
bash scripts/render.sh --theme dark --output diagram.png < input.dot

# Custom background
bash scripts/render.sh --bg "#1e1e2e" --output diagram.png < input.dot
```

## Troubleshooting

### Issue: "dot: command not found"

**Fix:**
```bash
bash scripts/install.sh
```

### Issue: Diagram looks cramped

**Fix:** Add spacing attributes:
```dot
graph [nodesep=0.8 ranksep=1.0]
```

### Issue: Labels overlapping

**Fix:** Use `rankdir=LR` for horizontal layout or increase node width:
```dot
node [width=2.0]
```

## Dependencies

- `graphviz` (dot, neato, fdp, sfdp, circo, twopi engines)
- `bash` (4.0+)
- Optional: `inotifywait` (for --watch mode)
