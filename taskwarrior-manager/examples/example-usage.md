# Taskwarrior Manager — Examples

## Personal GTD Setup

```bash
# Create inbox, next-actions, waiting, someday projects
bash scripts/run.sh bulk-add inbox "Process email" "Review bookmarks" "Sort downloads"
bash scripts/run.sh bulk-add next-actions "Call dentist" "Fix leaky faucet" "Update resume"
bash scripts/run.sh bulk-add waiting "Amazon delivery" "Contractor quote"
bash scripts/run.sh bulk-add someday "Learn Rust" "Build a bookshelf" "Visit Japan"
```

## Developer Sprint

```bash
# Sprint tasks with due dates
bash scripts/run.sh add "Setup CI/CD pipeline" project:sprint-14 priority:H due:monday +backend
bash scripts/run.sh add "Write unit tests for auth" project:sprint-14 priority:H due:tuesday +backend +testing
bash scripts/run.sh add "Design settings page" project:sprint-14 priority:M due:wednesday +frontend
bash scripts/run.sh add "Code review: payments module" project:sprint-14 priority:H due:thursday +review
bash scripts/run.sh add "Sprint retrospective notes" project:sprint-14 priority:L due:friday +meeting

# Check sprint progress
bash scripts/run.sh list project:sprint-14
bash scripts/run.sh burndown weekly
```

## CSV Import Format

Create `tasks.csv`:

```csv
description,priority,due
Setup monitoring,H,2026-03-01
Write documentation,M,2026-03-05
Update dependencies,L,2026-03-10
```

Import:

```bash
bash scripts/run.sh import-csv tasks.csv --project devops
```

## Daily Workflow

```bash
# Morning: Review what matters
bash scripts/run.sh daily-review

# During day: Add tasks as they come
bash scripts/run.sh add "Fix bug #123" project:webapp priority:H +bug
bash scripts/run.sh add "Reply to Sarah's email" project:work due:today

# Complete tasks
bash scripts/run.sh done 5
bash scripts/run.sh done 8

# Evening: Check what got done
bash scripts/run.sh completed-today
bash scripts/run.sh summary
```
