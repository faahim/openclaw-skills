---
name: notion-integration
description: >-
  Connect to Notion API — create pages, query databases, manage blocks, and export content from the terminal.
categories: [productivity, data]
dependencies: [curl, jq, bash]
---

# Notion Integration

## What This Does

Manage your Notion workspace from the command line. Create pages, query databases, update properties, search content, and export pages to Markdown — all through simple bash scripts that wrap the Notion API.

**Example:** "Query my task database for items due this week, create a new page in my notes, export a page as Markdown."

## Quick Start (5 minutes)

### 1. Get Your Notion API Key

1. Go to https://www.notion.so/my-integrations
2. Click **"New integration"**
3. Name it (e.g., "OpenClaw Bot"), select your workspace
4. Copy the **Internal Integration Secret** (starts with `ntn_` or `secret_`)
5. **Share pages/databases** with your integration (click ••• → Connections → your integration)

### 2. Configure

```bash
# Set your API key
export NOTION_API_KEY="ntn_your_secret_here"

# Optional: save to ~/.openclaw/env for persistence
echo 'export NOTION_API_KEY="ntn_your_secret_here"' >> ~/.openclaw/env
```

### 3. Test Connection

```bash
bash scripts/notion.sh me
# Output: Shows your bot user info
```

### 4. Search Your Workspace

```bash
bash scripts/notion.sh search "Meeting Notes"
# Output: Lists matching pages and databases
```

## Core Workflows

### Workflow 1: Search Workspace

```bash
# Search for pages and databases
bash scripts/notion.sh search "project plan"

# Search with filter (page or database)
bash scripts/notion.sh search "tasks" --filter database
```

### Workflow 2: Query a Database

```bash
# List all items in a database
bash scripts/notion.sh query-db <database-id>

# Query with filter (items where Status = "In Progress")
bash scripts/notion.sh query-db <database-id> --status "In Progress"

# Query with date filter (due this week)
bash scripts/notion.sh query-db <database-id> --due-this-week
```

**How to find database ID:** Open the database as a full page in Notion. The URL looks like:
`https://www.notion.so/<workspace>/<database-id>?v=...`
Copy the 32-character hex ID (add dashes: 8-4-4-4-12 format).

### Workflow 3: Create a Page

```bash
# Create a simple page in a parent page
bash scripts/notion.sh create-page <parent-page-id> "My New Page" "This is the content of my page."

# Create a database entry with properties
bash scripts/notion.sh create-entry <database-id> \
  --title "Fix login bug" \
  --status "In Progress" \
  --priority "High" \
  --due "2026-03-10"
```

### Workflow 4: Read a Page

```bash
# Get page content as readable text
bash scripts/notion.sh read-page <page-id>

# Export page to Markdown
bash scripts/notion.sh export-md <page-id> > output.md
```

### Workflow 5: Update a Page

```bash
# Update page properties
bash scripts/notion.sh update-props <page-id> \
  --status "Done" \
  --priority "Low"

# Append content to a page
bash scripts/notion.sh append <page-id> "New paragraph to add."

# Append a to-do item
bash scripts/notion.sh append-todo <page-id> "Buy groceries" --checked false
```

### Workflow 6: List Databases

```bash
# List all databases shared with your integration
bash scripts/notion.sh list-databases
```

## Configuration

### Environment Variables

```bash
# Required
export NOTION_API_KEY="ntn_your_secret_here"

# Optional: default database for quick operations
export NOTION_DEFAULT_DB="<database-id>"

# Optional: Notion API version (default: 2022-06-28)
export NOTION_API_VERSION="2022-06-28"
```

### Common Database Setups

**Task Tracker:**
```bash
# Query tasks due today
bash scripts/notion.sh query-db $NOTION_DEFAULT_DB --due-today

# Mark task as done
bash scripts/notion.sh update-props <page-id> --status "Done"
```

**Reading List:**
```bash
# Add a book
bash scripts/notion.sh create-entry <db-id> \
  --title "Atomic Habits" \
  --author "James Clear" \
  --status "To Read"
```

**Meeting Notes:**
```bash
# Create meeting note with date
bash scripts/notion.sh create-page <parent-id> \
  "Standup $(date +%Y-%m-%d)" \
  "## Attendees\n\n## Discussion\n\n## Action Items"
```

## Advanced Usage

### Batch Operations

```bash
# Export all pages in a database to Markdown files
bash scripts/notion.sh export-db <database-id> ./exports/

# Create multiple entries from a CSV
while IFS=, read -r title status priority; do
  bash scripts/notion.sh create-entry <db-id> \
    --title "$title" --status "$status" --priority "$priority"
done < tasks.csv
```

### Using with OpenClaw Cron

```bash
# Daily task summary via cron
# In your OpenClaw cron job:
TASKS=$(bash scripts/notion.sh query-db $NOTION_DEFAULT_DB --due-today)
echo "📋 Tasks due today:\n$TASKS"
```

### Raw API Access

```bash
# Make any Notion API call
bash scripts/notion.sh raw POST /v1/pages '{"parent":{"database_id":"..."},"properties":{...}}'

# Get raw JSON response
bash scripts/notion.sh raw GET /v1/pages/<page-id> | jq .
```

## Troubleshooting

### Issue: "Could not find object with ID"

**Fix:** Make sure you've shared the page/database with your integration:
1. Open the page in Notion
2. Click ••• (three dots) → **Connections**
3. Add your integration

### Issue: "API token is invalid"

**Fix:**
1. Check token starts with `ntn_` or `secret_`
2. Verify: `echo $NOTION_API_KEY`
3. Re-copy from https://www.notion.so/my-integrations

### Issue: "Could not find property"

**Fix:** Property names are case-sensitive. Check exact names:
```bash
bash scripts/notion.sh get-schema <database-id>
```

### Issue: Rate limited (429)

The script automatically retries with exponential backoff (up to 3 retries).

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests to Notion API)
- `jq` (JSON parsing)
- Optional: `pandoc` (for richer Markdown export)
