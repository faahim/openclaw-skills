# Listing Copy: Git Stats & Insights

## Metadata
- **Type:** Skill
- **Name:** git-stats
- **Display Name:** Git Stats & Insights
- **Categories:** [dev-tools, analytics]
- **Price:** $10
- **Dependencies:** [git, bash, scc]

## Tagline

Analyze any git repo — contributors, hotspots, language breakdown, commit trends, and code churn

## Description

**The problem:** Understanding what's happening in a codebase shouldn't require expensive tools or complex dashboards. You need quick, actionable insights — who's contributing, which files are changing most, and whether the codebase is growing healthily.

**The solution:** Git Stats & Insights analyzes any git repository using `scc` (fast code counter) and `git log` to produce comprehensive reports. Language breakdown, contributor rankings, file hotspots, commit frequency trends, and code churn metrics — all from one command, with text, JSON, or markdown output.

**What it does:**
- 📊 Accurate language breakdown (files, lines, code vs comments)
- 👥 Contributor rankings with additions/deletions per author
- 🔥 File hotspots — find files that change too often
- 📈 Commit frequency trends (weekly bar charts)
- 🔄 Code churn analysis with health indicators
- 🔀 Branch comparison stats
- 📤 JSON export for dashboards and further processing
- ⏱️ Time-range filtering (last 30 days, 3 months, etc.)

**Who it's for:** Developers, tech leads, and engineering managers who want quick repo insights without setting up GitHub Insights, GitPrime, or similar SaaS tools.

## Quick Start Preview

```bash
# Full analysis
bash scripts/git-stats.sh --repo /path/to/project

# Last 30 days, JSON output
bash scripts/git-stats.sh --since "30 days ago" --format json
```

## Core Capabilities

1. Language breakdown — Files, lines, code, comments, blanks per language
2. Contributor stats — Commits + lines added/deleted per author
3. File hotspots — Most-changed files (refactoring candidates)
4. Commit trends — Weekly commit frequency with visual bar chart
5. Code churn — Addition/deletion ratio with health indicator
6. Branch comparison — Diff stats between any two branches
7. Time filtering — Analyze any date range
8. JSON export — Feed into dashboards or CI pipelines
9. Auto-installs scc — One-command dependency setup
10. Zero config — Works out of the box on any git repo

## Dependencies
- `git` (2.0+)
- `bash` (4.0+)
- `scc` (auto-installed via install-scc.sh)
- `python3` (for JSON parsing in scc output)

## Installation Time
**3 minutes** — Run install script, analyze first repo
