#!/usr/bin/env python3
"""
Anki Flashcard Generator — Creates .apkg decks from CSV, JSON, or text input.
Requires: pip install genanki
"""

import argparse
import csv
import json
import random
import sys
import os

try:
    import genanki
except ImportError:
    print("Error: genanki not installed. Run: pip3 install genanki", file=sys.stderr)
    sys.exit(1)


def make_model_id():
    return random.randrange(1 << 30, 1 << 31)


def basic_model(name="Basic", font_size=20):
    return genanki.Model(
        make_model_id(),
        name,
        fields=[
            {"name": "Front"},
            {"name": "Back"},
        ],
        templates=[
            {
                "name": "Card 1",
                "qfmt": f'<div style="font-size:{font_size}px;text-align:center;">{{{{Front}}}}</div>',
                "afmt": f'<div style="font-size:{font_size}px;text-align:center;">{{{{FrontSide}}}}<hr id="answer">{{{{Back}}}}</div>',
            },
        ],
    )


def reverse_model(name="Basic (and reversed)", font_size=20):
    return genanki.Model(
        make_model_id(),
        name,
        fields=[
            {"name": "Front"},
            {"name": "Back"},
        ],
        templates=[
            {
                "name": "Card 1",
                "qfmt": f'<div style="font-size:{font_size}px;text-align:center;">{{{{Front}}}}</div>',
                "afmt": f'<div style="font-size:{font_size}px;text-align:center;">{{{{FrontSide}}}}<hr id="answer">{{{{Back}}}}</div>',
            },
            {
                "name": "Card 2 (Reverse)",
                "qfmt": f'<div style="font-size:{font_size}px;text-align:center;">{{{{Back}}}}</div>',
                "afmt": f'<div style="font-size:{font_size}px;text-align:center;">{{{{FrontSide}}}}<hr id="answer">{{{{Front}}}}</div>',
            },
        ],
    )


def cloze_model(name="Cloze", font_size=20):
    return genanki.Model(
        make_model_id(),
        name,
        model_type=genanki.Model.CLOZE,
        fields=[
            {"name": "Text"},
            {"name": "Extra"},
        ],
        templates=[
            {
                "name": "Cloze",
                "qfmt": f'<div style="font-size:{font_size}px;text-align:center;">{{{{cloze:Text}}}}</div>',
                "afmt": f'<div style="font-size:{font_size}px;text-align:center;">{{{{cloze:Text}}}}<br>{{{{Extra}}}}</div>',
            },
        ],
    )


def parse_csv(filepath):
    cards = []
    with open(filepath, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            front = row.get("front", "").strip()
            back = row.get("back", "").strip()
            tags_str = row.get("tags", "")
            tags = tags_str.split() if tags_str else []
            if front:
                cards.append({"front": front, "back": back, "tags": tags})
    return cards


def parse_json(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)
    cards = []
    for item in data:
        front = item.get("front", "").strip()
        back = item.get("back", "").strip()
        tags = item.get("tags", [])
        if isinstance(tags, str):
            tags = tags.split()
        if front:
            cards.append({"front": front, "back": back, "tags": tags})
    return cards


def parse_text(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    blocks = content.split("---")
    cards = []
    for block in blocks:
        lines = [l for l in block.strip().split("\n") if l.strip()]
        if len(lines) >= 2:
            front = lines[0].strip()
            back = "\n".join(lines[1:]).strip()
            cards.append({"front": front, "back": back, "tags": []})
        elif len(lines) == 1:
            cards.append({"front": lines[0].strip(), "back": "", "tags": []})
    return cards


def parse_stdin():
    content = sys.stdin.read().strip()
    if not content:
        return []
    # Try JSON first
    try:
        data = json.loads(content)
        cards = []
        for item in data:
            front = item.get("front", "").strip()
            back = item.get("back", "").strip()
            tags = item.get("tags", [])
            if isinstance(tags, str):
                tags = tags.split()
            if front:
                cards.append({"front": front, "back": back, "tags": tags})
        return cards
    except (json.JSONDecodeError, TypeError):
        pass
    # Fall back to text format
    blocks = content.split("---")
    cards = []
    for block in blocks:
        lines = [l for l in block.strip().split("\n") if l.strip()]
        if len(lines) >= 2:
            cards.append({"front": lines[0].strip(), "back": "\n".join(lines[1:]).strip(), "tags": []})
        elif len(lines) == 1:
            cards.append({"front": lines[0].strip(), "back": "", "tags": []})
    return cards


def parse_input(filepath):
    if filepath == "-":
        return parse_stdin()
    ext = os.path.splitext(filepath)[1].lower()
    if ext == ".csv":
        return parse_csv(filepath)
    elif ext == ".json":
        return parse_json(filepath)
    else:
        return parse_text(filepath)


def main():
    parser = argparse.ArgumentParser(description="Generate Anki .apkg decks from CSV, JSON, or text files")
    parser.add_argument("--input", "-i", required=True, help="Input file (CSV, JSON, TXT) or - for stdin")
    parser.add_argument("--output", "-o", required=True, help="Output .apkg file")
    parser.add_argument("--deck", "-d", default="Generated Deck", help="Deck name")
    parser.add_argument("--tags", "-t", default="", help="Default tags (comma-separated)")
    parser.add_argument("--cloze", action="store_true", help="Use cloze deletion model")
    parser.add_argument("--reverse", action="store_true", help="Generate reverse cards")
    parser.add_argument("--model", "-m", default="Basic", help="Model name")
    parser.add_argument("--font-size", type=int, default=20, help="Font size in px")

    args = parser.parse_args()

    # Parse input
    cards = parse_input(args.input)
    if not cards:
        print("Error: No cards found in input", file=sys.stderr)
        sys.exit(1)

    # Default tags
    default_tags = [t.strip() for t in args.tags.split(",") if t.strip()]

    # Create model
    if args.cloze:
        model = cloze_model(args.model, args.font_size)
    elif args.reverse:
        model = reverse_model(args.model, args.font_size)
    else:
        model = basic_model(args.model, args.font_size)

    # Create deck
    deck_id = random.randrange(1 << 30, 1 << 31)
    deck = genanki.Deck(deck_id, args.deck)

    # Add cards
    for card in cards:
        tags = list(set(default_tags + card.get("tags", [])))
        if args.cloze:
            note = genanki.Note(
                model=model,
                fields=[card["front"], card.get("back", "")],
                tags=tags,
            )
        else:
            note = genanki.Note(
                model=model,
                fields=[card["front"], card.get("back", "")],
                tags=tags,
            )
        deck.add_note(note)

    # Write package
    package = genanki.Package(deck)
    package.write_to_file(args.output)

    print(f"✅ Generated {len(cards)} cards → {args.output}")
    print(f"   Deck: {args.deck}")
    if args.cloze:
        print("   Type: Cloze deletion")
    elif args.reverse:
        print(f"   Type: Bidirectional ({len(cards) * 2} total cards)")
    else:
        print("   Type: Basic")
    if default_tags:
        print(f"   Tags: {', '.join(default_tags)}")


if __name__ == "__main__":
    main()
