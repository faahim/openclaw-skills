---
name: anki-flashcards
description: >-
  Generate Anki-compatible flashcard decks (.apkg) from text, notes, or structured data.
categories: [education, productivity]
dependencies: [python3, pip]
---

# Anki Flashcard Generator

## What This Does

Converts text, notes, CSV, or structured content into ready-to-import Anki flashcard decks (.apkg format). Supports basic cards, cloze deletions, reverse cards, and tagged organization. The agent creates real binary Anki deck files — not just text exports.

**Example:** "Turn my biology notes into 50 flashcards with tags, export as deck.apkg, ready to import into Anki."

## Quick Start (3 minutes)

### 1. Install Dependencies

```bash
pip3 install genanki>=0.13.0 2>/dev/null || pip install genanki>=0.13.0
```

### 2. Generate a Deck from CSV

```bash
# Create a simple CSV with front,back columns
cat > /tmp/cards.csv << 'EOF'
front,back
"What is photosynthesis?","The process by which plants convert sunlight into energy"
"What is mitochondria?","The powerhouse of the cell"
"What is DNA?","Deoxyribonucleic acid — carries genetic instructions"
EOF

python3 scripts/generate.py --input /tmp/cards.csv --output /tmp/biology-deck.apkg --deck "Biology 101"
```

### 3. Import into Anki

Open Anki → File → Import → Select the .apkg file. Done.

## Core Workflows

### Workflow 1: CSV to Deck

**Use case:** Convert a spreadsheet of Q&A pairs into flashcards.

```bash
# CSV format: front,back[,tags]
python3 scripts/generate.py \
  --input cards.csv \
  --output my-deck.apkg \
  --deck "My Study Deck" \
  --tags "exam,chapter1"
```

### Workflow 2: JSON to Deck

**Use case:** Generate cards from structured data.

```bash
# JSON format: [{"front": "...", "back": "...", "tags": ["tag1"]}]
python3 scripts/generate.py \
  --input cards.json \
  --output my-deck.apkg \
  --deck "Vocabulary"
```

### Workflow 3: Cloze Deletions

**Use case:** Fill-in-the-blank cards for memorization.

```bash
# Use {{c1::word}} syntax in the front field
cat > /tmp/cloze.csv << 'EOF'
front,back
"{{c1::Mitochondria}} is the powerhouse of the cell",""
"The capital of {{c1::France}} is {{c2::Paris}}",""
EOF

python3 scripts/generate.py \
  --input /tmp/cloze.csv \
  --output /tmp/cloze-deck.apkg \
  --deck "Cloze Cards" \
  --cloze
```

### Workflow 4: Reverse Cards (Bidirectional)

**Use case:** Learn in both directions (e.g., vocabulary).

```bash
python3 scripts/generate.py \
  --input vocab.csv \
  --output vocab-deck.apkg \
  --deck "Spanish Vocab" \
  --reverse
```

This creates TWO cards per entry: front→back AND back→front.

### Workflow 5: Plain Text to Cards

**Use case:** Quick card generation from freeform text.

```bash
# Text format: lines separated by --- or blank lines
# Each block: first line = front, rest = back
cat > /tmp/notes.txt << 'EOF'
What is TCP?
Transmission Control Protocol — reliable, ordered delivery of data packets over IP networks.
---
What is UDP?
User Datagram Protocol — connectionless, fast but unreliable data transmission.
---
What is HTTP?
Hypertext Transfer Protocol — application layer protocol for distributed hypermedia systems.
EOF

python3 scripts/generate.py \
  --input /tmp/notes.txt \
  --output /tmp/networking.apkg \
  --deck "Networking Basics"
```

## Configuration

### Command Line Options

```
--input FILE       Input file (CSV, JSON, or TXT)
--output FILE      Output .apkg file path
--deck NAME        Deck name (shown in Anki)
--tags TAG1,TAG2   Default tags for all cards
--cloze            Enable cloze deletion mode
--reverse          Generate reverse cards (bidirectional)
--model NAME       Card model name (default: "Basic")
--font-size N      Front/back font size in px (default: 20)
```

### CSV Format

```csv
front,back,tags
"Question text","Answer text","tag1 tag2"
```

### JSON Format

```json
[
  {
    "front": "Question text",
    "back": "Answer text",
    "tags": ["tag1", "tag2"]
  }
]
```

### Text Format

```
Question on first line
Answer on subsequent lines
---
Next question
Next answer
```

## Advanced Usage

### Batch Generation

```bash
# Generate multiple decks from a directory of CSVs
for f in decks/*.csv; do
  name=$(basename "$f" .csv)
  python3 scripts/generate.py --input "$f" --output "output/${name}.apkg" --deck "$name"
done
```

### Custom Styling

```bash
python3 scripts/generate.py \
  --input cards.csv \
  --output styled.apkg \
  --deck "Styled Deck" \
  --font-size 24
```

### Pipe from Agent

The agent can generate card content dynamically and pipe it:

```bash
# Agent generates JSON, pipes to generator
echo '[{"front":"What is Rust?","back":"A systems programming language focused on safety and performance"}]' | \
  python3 scripts/generate.py --input - --output /tmp/rust.apkg --deck "Rust Lang"
```

## Troubleshooting

### Issue: "No module named 'genanki'"

```bash
pip3 install genanki
```

### Issue: "UnicodeDecodeError"

Ensure your input file is UTF-8 encoded:
```bash
file -i cards.csv  # Check encoding
iconv -f latin1 -t utf-8 cards.csv > cards-utf8.csv
```

### Issue: Cards not showing in Anki

- Make sure you imported the .apkg file (File → Import)
- Check the deck name in Anki's deck browser
- If updating, Anki won't duplicate cards with same content

## Dependencies

- `python3` (3.8+)
- `genanki` (pip package — generates Anki deck files)
- `csv` (stdlib)
- `json` (stdlib)
