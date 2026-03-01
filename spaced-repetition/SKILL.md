---
name: spaced-repetition
description: >-
  CLI spaced repetition system with SM-2 algorithm. Create decks, review cards on schedule, track progress, export to Anki.
categories: [education, productivity]
dependencies: [python3, sqlite3]
---

# Spaced Repetition Engine

## What This Does

A command-line spaced repetition system that uses the SM-2 algorithm to schedule flashcard reviews at optimal intervals. Create decks, add cards, review due cards, track your learning progress, and export to Anki-compatible format.

**Example:** "Create a Japanese vocabulary deck, add 50 cards, review 10 due cards today, export progress to Anki."

## Quick Start (2 minutes)

### 1. Install

```bash
# No external dependencies beyond Python 3.6+ and sqlite3 (both pre-installed on most systems)
chmod +x scripts/srs.py

# Optional: symlink for convenience
sudo ln -sf "$(pwd)/scripts/srs.py" /usr/local/bin/srs
```

### 2. Create Your First Deck

```bash
python3 scripts/srs.py deck create "Spanish Vocabulary"

# Output:
# ✅ Deck 'Spanish Vocabulary' created (id: 1)
```

### 3. Add Cards

```bash
python3 scripts/srs.py card add 1 "Hola" "Hello"
python3 scripts/srs.py card add 1 "Gracias" "Thank you"
python3 scripts/srs.py card add 1 "Por favor" "Please"

# Bulk import from CSV
python3 scripts/srs.py card import 1 cards.csv
```

### 4. Start Reviewing

```bash
python3 scripts/srs.py review 1

# Output:
# 📚 Deck: Spanish Vocabulary | Due: 3 cards
#
# ┌─────────────────────────┐
# │  Front: Hola            │
# └─────────────────────────┘
#
# Press Enter to show answer...
#
# ┌─────────────────────────┐
# │  Back: Hello            │
# └─────────────────────────┘
#
# Rate (0-5): 0=forgot 1=hard 2=ok 3=good 4=easy 5=perfect
# > 4
#
# ✅ Next review: 2026-03-02 (1 day)
# Remaining: 2 cards
```

## Core Workflows

### Workflow 1: Daily Review

```bash
# See what's due across all decks
python3 scripts/srs.py status

# Output:
# 📊 Spaced Repetition Status
# ┌──────────────────────┬───────┬──────┬─────────┐
# │ Deck                 │ Total │ Due  │ New     │
# ├──────────────────────┼───────┼──────┼─────────┤
# │ Spanish Vocabulary   │ 50    │ 12   │ 5       │
# │ Japanese Kanji       │ 100   │ 8    │ 10      │
# │ Programming Concepts │ 30    │ 3    │ 0       │
# └──────────────────────┴───────┴──────┴─────────┘
# Total due: 23 cards

# Review a specific deck
python3 scripts/srs.py review 1

# Review all due cards across decks
python3 scripts/srs.py review --all
```

### Workflow 2: Bulk Import Cards

```bash
# CSV format: front,back (or front,back,tags)
cat > vocab.csv << 'EOF'
Perro,Dog,animals
Gato,Cat,animals
Casa,House,places
Libro,Book,objects
EOF

python3 scripts/srs.py card import 1 vocab.csv

# Output:
# ✅ Imported 4 cards into 'Spanish Vocabulary'
```

### Workflow 3: Track Progress

```bash
python3 scripts/srs.py stats 1

# Output:
# 📈 Spanish Vocabulary — Progress Report
#
# Cards by stage:
#   🆕 New:        5 (10%)
#   📖 Learning:   15 (30%)
#   ✅ Mature:     25 (50%)
#   🔄 Relearning: 5 (10%)
#
# Review history (last 7 days):
#   Mon: ████████ 20 reviews (85% correct)
#   Tue: ██████ 15 reviews (90% correct)
#   Wed: ████████████ 30 reviews (88% correct)
#   Thu: (no reviews)
#   Fri: ██████████ 25 reviews (92% correct)
#   Sat: ████ 10 reviews (80% correct)
#   Sun: ██████ 15 reviews (87% correct)
#
# Average retention: 87%
# Longest streak: 5 days
# Total reviews: 115
```

### Workflow 4: Export to Anki

```bash
# Export deck to Anki-compatible TSV
python3 scripts/srs.py export 1 --format anki --output spanish.txt

# Output:
# ✅ Exported 50 cards to spanish.txt (Anki tab-separated format)
# Import in Anki: File → Import → select spanish.txt
```

### Workflow 5: Search and Edit Cards

```bash
# Search cards
python3 scripts/srs.py card search "hola"

# Edit a card
python3 scripts/srs.py card edit 1 --front "¡Hola!" --back "Hello! (greeting)"

# Delete a card
python3 scripts/srs.py card delete 5

# Tag cards
python3 scripts/srs.py card tag 1 "greetings"
```

## Configuration

### Database Location

```bash
# Default: ~/.local/share/srs/cards.db
# Override with environment variable:
export SRS_DB_PATH="/path/to/custom/cards.db"
```

### Review Settings

```bash
# Set max new cards per session (default: 20)
python3 scripts/srs.py config set max_new_cards 10

# Set max reviews per session (default: unlimited)
python3 scripts/srs.py config set max_reviews 50

# Set new card interval (default: 1 day)
python3 scripts/srs.py config set new_interval 1
```

## SM-2 Algorithm

The engine uses the SM-2 (SuperMemo 2) algorithm:

1. **New cards** start with interval = 1 day, easiness = 2.5
2. After each review, you rate 0-5:
   - **0-1**: Card resets (relearning), interval = 1 day
   - **2**: Interval stays the same (hard recall)
   - **3**: Interval × easiness factor (good recall)
   - **4-5**: Interval × easiness factor + bonus (easy recall)
3. **Easiness factor** adjusts based on performance (min 1.3)
4. Cards graduate from New → Learning → Mature based on interval length

## Advanced Usage

### Run as OpenClaw Cron

```bash
# Daily reminder at 9am to review cards
# In OpenClaw cron, add a systemEvent:
# "Check SRS status: run python3 /path/to/scripts/srs.py status and remind to review if cards are due"
```

### Backup & Sync

```bash
# Backup database
cp ~/.local/share/srs/cards.db ~/backups/srs-$(date +%Y%m%d).db

# The database is a single SQLite file — easy to sync via Dropbox/Syncthing/rsync
```

### Pipe-friendly Output

```bash
# JSON output for scripting
python3 scripts/srs.py status --json

# Output due count only
python3 scripts/srs.py status --due-count
```

## Troubleshooting

### Issue: "python3: command not found"

```bash
# Install Python 3
sudo apt-get install python3  # Debian/Ubuntu
brew install python3           # macOS
```

### Issue: Database locked

```bash
# Only one review session at a time. Kill stale processes:
fuser ~/.local/share/srs/cards.db
```

## Dependencies

- `python3` (3.6+) — pre-installed on most systems
- `sqlite3` — included with Python

No pip packages required. Zero external dependencies.
