# Listing Copy: Notion Integration

## Metadata
- **Type:** Skill
- **Name:** notion-integration
- **Display Name:** Notion Integration
- **Categories:** [productivity, data]
- **Price:** $12
- **Dependencies:** [curl, jq, bash]

## Tagline

Manage your Notion workspace from the terminal — create pages, query databases, and export content.

## Description

Notion is where your notes, tasks, and wikis live — but switching to the browser every time you need to add an entry or check a database breaks your flow. What if your OpenClaw agent could talk to Notion directly?

Notion Integration wraps the full Notion API into simple bash commands. Search your workspace, query databases with filters (status, due dates, priority), create pages and database entries, append content, update properties, and export pages to Markdown — all without leaving the terminal.

**What it does:**
- 🔍 Search pages and databases across your workspace
- 📊 Query databases with status, priority, and date filters
- ✏️ Create pages and database entries with properties
- 📄 Read and export pages as Markdown
- ✅ Append paragraphs, to-dos, and blocks to any page
- 🔄 Update page properties (status, priority, due dates)
- 📦 Batch export entire databases to Markdown files
- 🛠️ Raw API access for any custom operation
- ⏱️ Built-in rate limit handling with automatic retries

Perfect for developers and power users who manage projects, notes, or content in Notion and want their OpenClaw agent to interact with it programmatically.

## Quick Start Preview

```bash
# Search your workspace
bash scripts/notion.sh search "Meeting Notes"

# Query tasks due this week
bash scripts/notion.sh query-db <database-id> --due-this-week

# Create a new page
bash scripts/notion.sh create-page <parent-id> "Daily Log" "Today's notes go here."

# Export page as Markdown
bash scripts/notion.sh export-md <page-id> > notes.md
```

## Core Capabilities

1. Workspace search — Find pages and databases by keyword
2. Database queries — Filter by status, priority, due dates
3. Page creation — Create pages with titles and content blocks
4. Database entries — Add entries with typed properties
5. Content reading — Extract page content as readable text
6. Markdown export — Export individual pages or entire databases
7. Property updates — Change status, priority, due dates
8. Content appending — Add paragraphs, to-dos, and blocks
9. Schema inspection — View database property types and options
10. Raw API access — Make any Notion API call directly
11. Rate limit handling — Automatic retries with exponential backoff
12. Batch operations — Export databases, create from CSV

## Dependencies
- `bash` (4.0+)
- `curl`
- `jq`

## Installation Time
**5 minutes** — Set API key, share pages with integration, run first command.
