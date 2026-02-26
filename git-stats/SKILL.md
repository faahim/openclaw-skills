---
name: git-stats
description: >-
  Analyze any git repository for contributor stats, code frequency, language breakdown, file hotspots, and commit trends.
categories: [dev-tools, analytics]
dependencies: [git, bash, curl]
---

# Git Stats & Insights

## What This Does

Analyze any git repository to get actionable insights: who's contributing what, which files change most (hotspots), language breakdown, commit frequency trends, and code churn metrics. Installs `scc` (Succinct Code Counter) for fast, accurate language analysis and uses `git log` for everything else.

**Example:** "Analyze my repo — show top contributors, busiest files, language breakdown, and commit trends for the last 90 days."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install scc (fast code counter — successor to cloc)
bash scripts/install-scc.sh

# Verify
scc --version
```

### 2. Analyze Current Repository

```bash
# Full analysis of current directory
bash scripts/git-stats.sh

# Analyze a specific repo
bash scripts/git-stats.sh --repo /path/to/repo

# Analyze with time range
bash scripts/git-stats.sh --since "3 months ago"
```

### 3. Output

```
═══════════════════════════════════════════════
  GIT STATS & INSIGHTS — myproject
  Period: 2025-12-01 to 2026-02-26
═══════════════════════════════════════════════

📊 LANGUAGE BREAKDOWN
──────────────────────────────────────────────
Language         Files    Lines     Code    Comments  Blanks
TypeScript         45    12340     9870        1230    1240
JavaScript         12     3200     2800         200     200
JSON                8      980      980           0       0
Markdown            5      420      310          60      50
CSS                 3      280      240          10      30
──────────────────────────────────────────────
Total              73    17220    14200        1500    1520

👥 TOP CONTRIBUTORS (by commits)
──────────────────────────────────────────────
  1. alice       142 commits  (+8,320 / -3,210)
  2. bob          87 commits  (+4,100 / -1,890)
  3. charlie      34 commits  (+1,200 / -450)

🔥 FILE HOTSPOTS (most changed files)
──────────────────────────────────────────────
  1. src/api/handler.ts        47 changes
  2. src/components/App.tsx     38 changes
  3. package.json               29 changes
  4. src/utils/helpers.ts       24 changes
  5. README.md                  19 changes

📈 COMMIT FREQUENCY (last 12 weeks)
──────────────────────────────────────────────
Week 01 (Dec 02): ████████████████ 32
Week 02 (Dec 09): ████████████ 24
Week 03 (Dec 16): ██████ 12
...
Week 12 (Feb 17): ████████████████████ 38

🔄 CODE CHURN (additions vs deletions)
──────────────────────────────────────────────
Total additions:  +13,620
Total deletions:   -5,550
Net growth:        +8,070
Churn ratio:       0.41 (healthy)
```

## Core Workflows

### Workflow 1: Full Repository Analysis

**Use case:** Get a complete picture of any repo

```bash
bash scripts/git-stats.sh --repo /path/to/repo --since "6 months ago"
```

### Workflow 2: Language Breakdown Only

**Use case:** Quick language stats (uses scc)

```bash
bash scripts/git-stats.sh --repo /path/to/repo --only languages
```

### Workflow 3: Contributor Report

**Use case:** See who's doing what

```bash
bash scripts/git-stats.sh --repo /path/to/repo --only contributors --since "30 days ago"
```

### Workflow 4: File Hotspots

**Use case:** Find files that change most (likely need refactoring)

```bash
bash scripts/git-stats.sh --repo /path/to/repo --only hotspots --top 20
```

### Workflow 5: Commit Trends

**Use case:** Track team velocity over time

```bash
bash scripts/git-stats.sh --repo /path/to/repo --only trends --weeks 24
```

### Workflow 6: Export to JSON

**Use case:** Feed into other tools or dashboards

```bash
bash scripts/git-stats.sh --repo /path/to/repo --format json > stats.json
```

### Workflow 7: Compare Branches

**Use case:** See what changed between branches

```bash
bash scripts/git-stats.sh --repo /path/to/repo --compare main..feature-branch
```

## Configuration

### Command-Line Options

```
--repo PATH        Repository path (default: current directory)
--since DATE       Start date (git date format: "3 months ago", "2025-01-01")
--until DATE       End date (default: now)
--only SECTION     Show only: languages|contributors|hotspots|trends|churn
--top N            Number of items to show (default: 10)
--weeks N          Weeks for trend chart (default: 12)
--format FORMAT    Output format: text|json|markdown (default: text)
--compare RANGE    Compare branches (e.g., main..develop)
--exclude PATTERN  Exclude paths (glob pattern, repeatable)
```

### Environment Variables

```bash
# Custom scc path (if not in PATH)
export SCC_PATH="/usr/local/bin/scc"

# Default exclusions
export GIT_STATS_EXCLUDE="node_modules,vendor,dist,.git"
```

## Advanced Usage

### Cron-Based Weekly Reports

```bash
# Add to crontab — weekly report every Monday at 9am
0 9 * * 1 cd /path/to/repo && bash /path/to/scripts/git-stats.sh --since "7 days ago" --format markdown >> /path/to/reports/weekly-$(date +\%Y-\%W).md
```

### Multi-Repo Analysis

```bash
# Analyze multiple repos
for repo in /home/projects/*/; do
  echo "=== $(basename $repo) ==="
  bash scripts/git-stats.sh --repo "$repo" --only languages
  echo
done
```

### Pipe to Agent

```bash
# Get JSON stats for agent processing
bash scripts/git-stats.sh --format json | jq '.contributors | sort_by(-.commits) | .[0:5]'
```

## Troubleshooting

### Issue: "scc: command not found"

**Fix:**
```bash
bash scripts/install-scc.sh
# Or install manually:
# Linux: curl -sL https://github.com/boyter/scc/releases/latest/download/scc_Linux_x86_64.tar.gz | tar xz -C /usr/local/bin/
# Mac: brew install scc
```

### Issue: "not a git repository"

**Fix:** Make sure you're in a git repo or use `--repo /path/to/repo`

### Issue: Slow on large repos

**Fix:** Use `--since` to limit the time range:
```bash
bash scripts/git-stats.sh --since "3 months ago"
```

## Dependencies

- `git` (2.0+)
- `bash` (4.0+)
- `scc` (installed by install-scc.sh)
- `awk`, `sort`, `head` (standard Unix tools)
- Optional: `jq` (for JSON output processing)
