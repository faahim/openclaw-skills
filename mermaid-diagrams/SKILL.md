---
name: mermaid-diagrams
description: >-
  Render Mermaid diagrams (flowcharts, sequence diagrams, ERDs, Gantt charts) to PNG, SVG, or PDF from text definitions.
categories: [dev-tools, productivity]
dependencies: [node, npx]
---

# Mermaid Diagram Generator

## What This Does

Renders Mermaid diagram syntax into PNG, SVG, or PDF images. Supports flowcharts, sequence diagrams, class diagrams, entity-relationship diagrams, Gantt charts, pie charts, git graphs, and more. Your agent writes the diagram code — this skill turns it into a shareable image.

**Example:** Write a flowchart in Mermaid syntax → get a crisp PNG you can send, embed, or present.

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Install mermaid-cli globally (includes Chromium for rendering)
npm install -g @mermaid-js/mermaid-cli

# Verify installation
mmdc --version
```

If Chromium fails to download (e.g., ARM/Docker), install manually:

```bash
# Use system Chromium
apt-get install -y chromium-browser 2>/dev/null || brew install chromium 2>/dev/null

# Tell mermaid-cli to use it
export PUPPETEER_EXECUTABLE_PATH=$(which chromium-browser || which chromium)
```

### 2. Render Your First Diagram

```bash
# Create a diagram file
cat > /tmp/flow.mmd << 'EOF'
graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Do Something]
    B -->|No| D[Do Nothing]
    C --> E[End]
    D --> E
EOF

# Render to PNG
mmdc -i /tmp/flow.mmd -o /tmp/flow.png -b transparent

# Render to SVG
mmdc -i /tmp/flow.mmd -o /tmp/flow.svg
```

### 3. Inline Rendering (No Temp File)

```bash
echo 'graph LR; A-->B; B-->C; C-->A;' | mmdc -i - -o /tmp/cycle.png
```

## Core Workflows

### Workflow 1: Flowchart

```bash
cat > /tmp/diagram.mmd << 'EOF'
graph TD
    A[User Request] --> B{Authenticated?}
    B -->|Yes| C[Process Request]
    B -->|No| D[Return 401]
    C --> E{Valid Data?}
    E -->|Yes| F[Save to DB]
    E -->|No| G[Return 400]
    F --> H[Return 200]
EOF

mmdc -i /tmp/diagram.mmd -o /tmp/flowchart.png -w 1200
```

### Workflow 2: Sequence Diagram

```bash
cat > /tmp/diagram.mmd << 'EOF'
sequenceDiagram
    participant U as User
    participant A as API
    participant D as Database
    participant C as Cache

    U->>A: GET /users/123
    A->>C: Check cache
    alt Cache hit
        C-->>A: Return cached data
    else Cache miss
        A->>D: SELECT * FROM users WHERE id=123
        D-->>A: User data
        A->>C: Store in cache
    end
    A-->>U: JSON response
EOF

mmdc -i /tmp/diagram.mmd -o /tmp/sequence.png -w 1400
```

### Workflow 3: Entity-Relationship Diagram

```bash
cat > /tmp/diagram.mmd << 'EOF'
erDiagram
    USER ||--o{ ORDER : places
    USER {
        int id PK
        string name
        string email UK
    }
    ORDER ||--|{ LINE_ITEM : contains
    ORDER {
        int id PK
        date created_at
        string status
    }
    PRODUCT ||--o{ LINE_ITEM : "ordered in"
    PRODUCT {
        int id PK
        string name
        float price
    }
    LINE_ITEM {
        int quantity
        float subtotal
    }
EOF

mmdc -i /tmp/diagram.mmd -o /tmp/erd.png -w 1200
```

### Workflow 4: Gantt Chart

```bash
cat > /tmp/diagram.mmd << 'EOF'
gantt
    title Project Timeline
    dateFormat YYYY-MM-DD
    section Planning
        Requirements     :a1, 2026-03-01, 7d
        Design          :a2, after a1, 5d
    section Development
        Backend API     :b1, after a2, 14d
        Frontend UI     :b2, after a2, 14d
        Integration     :b3, after b1, 5d
    section Testing
        QA Testing      :c1, after b3, 7d
        Bug Fixes       :c2, after c1, 5d
    section Launch
        Deployment      :d1, after c2, 2d
EOF

mmdc -i /tmp/diagram.mmd -o /tmp/gantt.png -w 1600
```

### Workflow 5: Pie Chart

```bash
echo 'pie title Traffic Sources
    "Organic" : 45
    "Social" : 25
    "Direct" : 20
    "Referral" : 10' | mmdc -i - -o /tmp/pie.png
```

### Workflow 6: Git Graph

```bash
cat > /tmp/diagram.mmd << 'EOF'
gitGraph
    commit
    branch develop
    checkout develop
    commit
    commit
    branch feature
    checkout feature
    commit
    commit
    checkout develop
    merge feature
    checkout main
    merge develop
    commit tag: "v1.0"
EOF

mmdc -i /tmp/diagram.mmd -o /tmp/git.png -w 1200
```

### Workflow 7: Class Diagram

```bash
cat > /tmp/diagram.mmd << 'EOF'
classDiagram
    class User {
        +int id
        +String name
        +String email
        +login()
        +logout()
    }
    class Order {
        +int id
        +Date createdAt
        +float total
        +addItem()
        +checkout()
    }
    class Product {
        +int id
        +String name
        +float price
    }
    User "1" --> "*" Order : places
    Order "*" --> "*" Product : contains
EOF

mmdc -i /tmp/diagram.mmd -o /tmp/class.png
```

## Configuration

### Custom Theme

```bash
# Create config file for dark theme
cat > /tmp/mermaid-config.json << 'EOF'
{
  "theme": "dark",
  "themeVariables": {
    "primaryColor": "#4f46e5",
    "primaryTextColor": "#fff",
    "primaryBorderColor": "#6366f1",
    "lineColor": "#94a3b8",
    "secondaryColor": "#1e293b",
    "tertiaryColor": "#0f172a"
  }
}
EOF

# Render with custom theme
mmdc -i /tmp/diagram.mmd -o /tmp/dark-diagram.png -c /tmp/mermaid-config.json
```

### Available Themes

- `default` — Standard light theme
- `dark` — Dark background
- `forest` — Green tones
- `neutral` — Minimal grayscale

```bash
# Use built-in theme
mmdc -i /tmp/diagram.mmd -o /tmp/out.png -t forest
```

### Output Formats

```bash
# PNG (default, raster)
mmdc -i diagram.mmd -o out.png

# SVG (vector, scalable)
mmdc -i diagram.mmd -o out.svg

# PDF (for documents)
mmdc -i diagram.mmd -o out.pdf

# Custom width/height
mmdc -i diagram.mmd -o out.png -w 2000 -H 1200

# Transparent background
mmdc -i diagram.mmd -o out.png -b transparent

# Custom background color
mmdc -i diagram.mmd -o out.png -b '#1e1e2e'
```

### Batch Rendering

```bash
# Render all .mmd files in a directory
for f in diagrams/*.mmd; do
    mmdc -i "$f" -o "${f%.mmd}.png" -w 1200
    echo "✅ Rendered: ${f%.mmd}.png"
done
```

## Helper Script

Use `scripts/render.sh` for common operations:

```bash
# Quick render (auto-detects diagram type, sets good defaults)
bash scripts/render.sh /tmp/diagram.mmd /tmp/output.png

# With theme
bash scripts/render.sh /tmp/diagram.mmd /tmp/output.png dark

# Batch render directory
bash scripts/render.sh --batch /path/to/diagrams/ /path/to/output/
```

## Troubleshooting

### Issue: "Could not find Chromium"

**Fix:**
```bash
# Option 1: Let mermaid-cli download it
npx puppeteer browsers install chrome

# Option 2: Use system Chromium
export PUPPETEER_EXECUTABLE_PATH=$(which chromium-browser || which chromium || which google-chrome)
```

### Issue: "Error: Protocol error (Page.captureScreenshot)"

**Fix:** Increase timeout or use `--pdfFit` for large diagrams:
```bash
mmdc -i large-diagram.mmd -o out.png -w 3000 -H 2000
```

### Issue: Fonts look wrong

**Fix:** Install common fonts:
```bash
sudo apt-get install -y fonts-noto fonts-liberation 2>/dev/null
```

### Issue: Rendering on headless server / Docker

**Fix:**
```bash
# Create puppeteer config for no-sandbox
cat > /tmp/puppeteer-config.json << 'EOF'
{
  "args": ["--no-sandbox", "--disable-setuid-sandbox"]
}
EOF

mmdc -i diagram.mmd -o out.png -p /tmp/puppeteer-config.json
```

## Key Principles

1. **One diagram per file** — Keep .mmd files focused on a single diagram
2. **Width matters** — Set `-w` based on diagram complexity (800-2000px)
3. **SVG for docs** — Use SVG when embedding in markdown/HTML (scales perfectly)
4. **PNG for sharing** — Use PNG for Telegram, Slack, email
5. **Theme consistency** — Use a config file to keep all diagrams matching

## Dependencies

- `node` (16+)
- `npm` / `npx`
- `@mermaid-js/mermaid-cli` (npm package, installs Chromium)
- Optional: system Chromium (for environments where Puppeteer can't download)
