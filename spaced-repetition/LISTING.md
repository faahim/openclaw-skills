# Listing Copy: Spaced Repetition Engine

## Metadata
- **Type:** Skill
- **Name:** spaced-repetition
- **Display Name:** Spaced Repetition Engine
- **Categories:** [education, productivity]
- **Price:** $8
- **Dependencies:** [python3, sqlite3]

## Tagline

CLI spaced repetition system — Learn anything with SM-2 optimized flashcard scheduling

## Description

Remembering what you study is harder than studying it. Without spaced repetition, you forget 80% within a week. Most SRS tools are bloated desktop apps or subscription services.

Spaced Repetition Engine is a zero-dependency CLI flashcard system that runs entirely in your terminal. It uses the proven SM-2 algorithm to schedule reviews at the optimal moment — right before you'd forget. Create decks, bulk-import cards from CSV, review with quality ratings, and track your retention over time.

**What it does:**
- 📚 Create unlimited decks and flashcards
- 🧠 SM-2 algorithm schedules reviews at optimal intervals
- 📥 Bulk import cards from CSV files
- 📊 Track retention rates and review streaks
- 📤 Export to Anki-compatible format
- 🔍 Search and tag cards for organization
- 📈 Progress stats with visual review history
- ⚙️ Configurable new card limits and session sizes
- 💾 Single SQLite file — easy backup and sync
- 🖥️ JSON output mode for scripting

Perfect for developers, language learners, students, and anyone who wants to remember what they learn — without leaving the terminal.

## Quick Start Preview

```bash
python3 scripts/srs.py deck create "Japanese N5"
python3 scripts/srs.py card add 1 "犬" "いぬ (dog)"
python3 scripts/srs.py review 1
```

## Core Capabilities

1. Deck management — Create, list, delete flashcard decks
2. Card CRUD — Add, edit, search, tag, delete individual cards
3. CSV bulk import — Import hundreds of cards from CSV files
4. SM-2 scheduling — Scientifically proven spaced repetition algorithm
5. Interactive review — Terminal-based review with quality ratings (0-5)
6. Progress tracking — Retention rates, review counts, card stages
7. Visual statistics — Bar chart review history, stage breakdown
8. Anki export — Export to Anki-compatible tab-separated format
9. JSON/CSV export — Multiple export formats for flexibility
10. Configurable limits — Set max new cards and reviews per session
11. Pipe-friendly — JSON output and due-count flags for scripting
12. Zero dependencies — Only Python 3.6+ and built-in sqlite3

## Dependencies
- `python3` (3.6+)
- `sqlite3` (included with Python)

## Installation Time
**2 minutes** — chmod +x, start reviewing

## Pricing Justification

**Why $8:**
- LarryBrain median: $5-15
- Comparable tools: Anki (free but complex), Brainscape ($10/mo), Quizlet ($8/mo)
- Our advantage: One-time payment, zero dependencies, terminal-native, scriptable
- Complexity: Medium (SM-2 algorithm + SQLite + CLI interface)
