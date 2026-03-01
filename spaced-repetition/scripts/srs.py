#!/usr/bin/env python3
"""Spaced Repetition Engine — CLI flashcard system with SM-2 algorithm."""

import argparse
import csv
import json
import os
import sqlite3
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

DEFAULT_DB = os.environ.get("SRS_DB_PATH",
    os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "srs", "cards.db"))

def get_db(db_path=None):
    path = db_path or DEFAULT_DB
    os.makedirs(os.path.dirname(path), exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("""CREATE TABLE IF NOT EXISTS decks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        created_at TEXT DEFAULT (datetime('now')))""")
    conn.execute("""CREATE TABLE IF NOT EXISTS cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deck_id INTEGER NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        tags TEXT DEFAULT '',
        easiness REAL DEFAULT 2.5,
        interval INTEGER DEFAULT 0,
        repetitions INTEGER DEFAULT 0,
        due_date TEXT DEFAULT (date('now')),
        last_reviewed TEXT,
        review_count INTEGER DEFAULT 0,
        correct_count INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')))""")
    conn.execute("""CREATE TABLE IF NOT EXISTS reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id INTEGER NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
        quality INTEGER NOT NULL,
        reviewed_at TEXT DEFAULT (datetime('now')))""")
    conn.execute("""CREATE TABLE IF NOT EXISTS config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL)""")
    conn.commit()
    return conn

def get_config(conn, key, default=None):
    row = conn.execute("SELECT value FROM config WHERE key=?", (key,)).fetchone()
    return row["value"] if row else default

def set_config(conn, key, value):
    conn.execute("INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)", (key, str(value)))
    conn.commit()

# SM-2 algorithm
def sm2(quality, easiness, interval, repetitions):
    """Returns (new_easiness, new_interval, new_repetitions)."""
    if quality < 0 or quality > 5:
        raise ValueError("Quality must be 0-5")
    new_easiness = max(1.3, easiness + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)))
    if quality < 2:
        return new_easiness, 1, 0
    if repetitions == 0:
        new_interval = 1
    elif repetitions == 1:
        new_interval = 6
    else:
        new_interval = max(1, round(interval * new_easiness))
    return new_easiness, new_interval, repetitions + 1

# ── Commands ──

def cmd_deck_create(args):
    conn = get_db()
    try:
        conn.execute("INSERT INTO decks (name) VALUES (?)", (args.name,))
        conn.commit()
        did = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
        print(f"✅ Deck '{args.name}' created (id: {did})")
    except sqlite3.IntegrityError:
        print(f"❌ Deck '{args.name}' already exists", file=sys.stderr)
        sys.exit(1)

def cmd_deck_list(args):
    conn = get_db()
    rows = conn.execute("""SELECT d.id, d.name, COUNT(c.id) as total,
        SUM(CASE WHEN c.due_date <= date('now') THEN 1 ELSE 0 END) as due,
        SUM(CASE WHEN c.repetitions = 0 THEN 1 ELSE 0 END) as new
        FROM decks d LEFT JOIN cards c ON c.deck_id = d.id
        GROUP BY d.id ORDER BY d.id""").fetchall()
    if not rows:
        print("No decks yet. Create one: srs deck create 'My Deck'")
        return
    print(f"{'ID':<4} {'Deck':<30} {'Total':<7} {'Due':<6} {'New':<5}")
    print("─" * 52)
    for r in rows:
        print(f"{r['id']:<4} {r['name']:<30} {r['total']:<7} {r['due'] or 0:<6} {r['new'] or 0:<5}")

def cmd_deck_delete(args):
    conn = get_db()
    conn.execute("PRAGMA foreign_keys=ON")
    cur = conn.execute("DELETE FROM decks WHERE id=?", (args.deck_id,))
    conn.commit()
    if cur.rowcount:
        print(f"✅ Deck {args.deck_id} deleted")
    else:
        print(f"❌ Deck {args.deck_id} not found", file=sys.stderr)

def cmd_card_add(args):
    conn = get_db()
    conn.execute("INSERT INTO cards (deck_id, front, back, tags) VALUES (?, ?, ?, ?)",
                 (args.deck_id, args.front, args.back, args.tags or ""))
    conn.commit()
    print(f"✅ Card added to deck {args.deck_id}: {args.front[:40]}")

def cmd_card_import(args):
    conn = get_db()
    count = 0
    with open(args.csv_file, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        for row in reader:
            if len(row) < 2:
                continue
            front, back = row[0].strip(), row[1].strip()
            tags = row[2].strip() if len(row) > 2 else ""
            if not front or not back:
                continue
            conn.execute("INSERT INTO cards (deck_id, front, back, tags) VALUES (?, ?, ?, ?)",
                         (args.deck_id, front, back, tags))
            count += 1
    conn.commit()
    deck = conn.execute("SELECT name FROM decks WHERE id=?", (args.deck_id,)).fetchone()
    name = deck["name"] if deck else f"deck {args.deck_id}"
    print(f"✅ Imported {count} cards into '{name}'")

def cmd_card_search(args):
    conn = get_db()
    q = f"%{args.query}%"
    rows = conn.execute("SELECT id, deck_id, front, back, tags, due_date FROM cards WHERE front LIKE ? OR back LIKE ? OR tags LIKE ?",
                        (q, q, q)).fetchall()
    if not rows:
        print("No cards found.")
        return
    for r in rows:
        print(f"[{r['id']}] deck:{r['deck_id']} | {r['front']} → {r['back']} | due:{r['due_date']} | tags:{r['tags']}")

def cmd_card_edit(args):
    conn = get_db()
    updates, vals = [], []
    if args.front:
        updates.append("front=?"); vals.append(args.front)
    if args.back:
        updates.append("back=?"); vals.append(args.back)
    if args.tags is not None:
        updates.append("tags=?"); vals.append(args.tags)
    if not updates:
        print("Nothing to update. Use --front, --back, or --tags")
        return
    vals.append(args.card_id)
    conn.execute(f"UPDATE cards SET {','.join(updates)} WHERE id=?", vals)
    conn.commit()
    print(f"✅ Card {args.card_id} updated")

def cmd_card_delete(args):
    conn = get_db()
    conn.execute("DELETE FROM cards WHERE id=?", (args.card_id,))
    conn.commit()
    print(f"✅ Card {args.card_id} deleted")

def cmd_review(args):
    conn = get_db()
    today = datetime.now().strftime("%Y-%m-%d")
    max_new = int(get_config(conn, "max_new_cards", "20"))
    max_reviews = get_config(conn, "max_reviews", None)

    if args.all:
        where = "WHERE c.due_date <= ?"
        params = [today]
    else:
        where = "WHERE c.deck_id = ? AND c.due_date <= ?"
        params = [args.deck_id, today]

    rows = conn.execute(f"""SELECT c.*, d.name as deck_name FROM cards c
        JOIN decks d ON d.id = c.deck_id {where}
        ORDER BY c.repetitions ASC, c.due_date ASC""", params).fetchall()

    if not rows:
        print("🎉 No cards due! Come back later.")
        return

    # Limit new cards
    new_count = 0
    filtered = []
    for r in rows:
        if r["repetitions"] == 0:
            if new_count < max_new:
                filtered.append(r)
                new_count += 1
        else:
            filtered.append(r)
    if max_reviews:
        filtered = filtered[:int(max_reviews)]

    total = len(filtered)
    print(f"📚 Review session: {total} cards due\n")

    correct = 0
    for i, card in enumerate(filtered):
        print(f"── Card {i+1}/{total} ── Deck: {card['deck_name']} ──")
        print(f"\n  Front: {card['front']}\n")
        try:
            input("  Press Enter to show answer...")
        except (EOFError, KeyboardInterrupt):
            print("\n\n⏸  Session paused.")
            break
        print(f"\n  Back: {card['back']}\n")

        quality = None
        while quality is None:
            try:
                raw = input("  Rate (0-5): 0=forgot 1=hard 2=ok 3=good 4=easy 5=perfect\n  > ").strip()
                q = int(raw)
                if 0 <= q <= 5:
                    quality = q
                else:
                    print("  Enter 0-5")
            except (ValueError, EOFError, KeyboardInterrupt):
                print("\n⏸  Session paused.")
                return

        new_e, new_i, new_r = sm2(quality, card["easiness"], card["interval"], card["repetitions"])
        new_due = (datetime.now() + timedelta(days=new_i)).strftime("%Y-%m-%d")

        conn.execute("""UPDATE cards SET easiness=?, interval=?, repetitions=?,
            due_date=?, last_reviewed=datetime('now'), review_count=review_count+1,
            correct_count=correct_count+? WHERE id=?""",
            (new_e, new_i, new_r, new_due, 1 if quality >= 2 else 0, card["id"]))
        conn.execute("INSERT INTO reviews (card_id, quality) VALUES (?, ?)", (card["id"], quality))
        conn.commit()

        if quality >= 2:
            correct += 1
        print(f"  → Next review: {new_due} ({new_i} day{'s' if new_i != 1 else ''})")
        print()

    print(f"\n✅ Session complete! {correct}/{total} correct ({round(correct/total*100)}%)")

def cmd_status(args):
    conn = get_db()
    today = datetime.now().strftime("%Y-%m-%d")

    if getattr(args, 'json_out', False):
        rows = conn.execute("""SELECT d.id, d.name, COUNT(c.id) as total,
            SUM(CASE WHEN c.due_date <= ? THEN 1 ELSE 0 END) as due,
            SUM(CASE WHEN c.repetitions = 0 THEN 1 ELSE 0 END) as new
            FROM decks d LEFT JOIN cards c ON c.deck_id = d.id
            GROUP BY d.id""", (today,)).fetchall()
        print(json.dumps([dict(r) for r in rows], indent=2))
        return

    if getattr(args, 'due_count', False):
        row = conn.execute("SELECT COUNT(*) as c FROM cards WHERE due_date <= ?", (today,)).fetchone()
        print(row["c"])
        return

    rows = conn.execute("""SELECT d.id, d.name, COUNT(c.id) as total,
        SUM(CASE WHEN c.due_date <= ? THEN 1 ELSE 0 END) as due,
        SUM(CASE WHEN c.repetitions = 0 THEN 1 ELSE 0 END) as new
        FROM decks d LEFT JOIN cards c ON c.deck_id = d.id
        GROUP BY d.id""", (today,)).fetchall()

    if not rows:
        print("No decks yet. Create one: srs deck create 'My Deck'")
        return

    print("📊 Spaced Repetition Status\n")
    print(f"  {'Deck':<30} {'Total':<7} {'Due':<6} {'New':<5}")
    print(f"  {'─'*30} {'─'*5}   {'─'*4}  {'─'*3}")
    total_due = 0
    for r in rows:
        due = r["due"] or 0
        total_due += due
        print(f"  {r['name']:<30} {r['total']:<7} {due:<6} {r['new'] or 0:<5}")
    print(f"\n  Total due: {total_due} cards")

def cmd_stats(args):
    conn = get_db()
    deck = conn.execute("SELECT * FROM decks WHERE id=?", (args.deck_id,)).fetchone()
    if not deck:
        print(f"❌ Deck {args.deck_id} not found"); sys.exit(1)

    cards = conn.execute("SELECT * FROM cards WHERE deck_id=?", (args.deck_id,)).fetchall()
    total = len(cards)
    if total == 0:
        print(f"📈 {deck['name']} — No cards yet"); return

    new = sum(1 for c in cards if c["repetitions"] == 0)
    learning = sum(1 for c in cards if 0 < c["repetitions"] <= 3 and c["interval"] < 21)
    mature = sum(1 for c in cards if c["interval"] >= 21)
    relearning = total - new - learning - mature

    print(f"\n📈 {deck['name']} — Progress Report\n")
    print(f"  Cards by stage:")
    for label, count, icon in [("New", new, "🆕"), ("Learning", learning, "📖"),
                                ("Mature", mature, "✅"), ("Relearning", relearning, "🔄")]:
        pct = round(count / total * 100)
        print(f"    {icon} {label+':':<14} {count} ({pct}%)")

    # Last 7 days
    reviews = conn.execute("""SELECT date(reviewed_at) as d, COUNT(*) as cnt,
        SUM(CASE WHEN quality >= 2 THEN 1 ELSE 0 END) as correct
        FROM reviews r JOIN cards c ON c.id = r.card_id
        WHERE c.deck_id = ? AND reviewed_at >= datetime('now', '-7 days')
        GROUP BY date(reviewed_at) ORDER BY d""", (args.deck_id,)).fetchall()

    if reviews:
        print(f"\n  Review history (last 7 days):")
        max_cnt = max(r["cnt"] for r in reviews)
        for r in reviews:
            bar = "█" * max(1, round(r["cnt"] / max(max_cnt, 1) * 20))
            pct = round(r["correct"] / r["cnt"] * 100) if r["cnt"] > 0 else 0
            print(f"    {r['d']}: {bar} {r['cnt']} reviews ({pct}% correct)")

    total_reviews = conn.execute("SELECT COUNT(*) as c, SUM(CASE WHEN quality>=2 THEN 1 ELSE 0 END) as correct FROM reviews r JOIN cards c ON c.id=r.card_id WHERE c.deck_id=?", (args.deck_id,)).fetchone()
    if total_reviews["c"] > 0:
        retention = round(total_reviews["correct"] / total_reviews["c"] * 100)
        print(f"\n  Average retention: {retention}%")
        print(f"  Total reviews: {total_reviews['c']}")

def cmd_export(args):
    conn = get_db()
    fmt = getattr(args, 'format', 'anki') or 'anki'
    output = args.output

    cards = conn.execute("SELECT front, back, tags FROM cards WHERE deck_id=?", (args.deck_id,)).fetchall()
    if not cards:
        print("No cards to export"); return

    if fmt == "anki":
        with open(output, "w", encoding="utf-8") as f:
            for c in cards:
                f.write(f"{c['front']}\t{c['back']}\t{c['tags']}\n")
        print(f"✅ Exported {len(cards)} cards to {output} (Anki tab-separated format)")
        print(f"   Import in Anki: File → Import → select {output}")
    elif fmt == "csv":
        with open(output, "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(["front", "back", "tags"])
            for c in cards:
                w.writerow([c["front"], c["back"], c["tags"]])
        print(f"✅ Exported {len(cards)} cards to {output} (CSV)")
    elif fmt == "json":
        data = [{"front": c["front"], "back": c["back"], "tags": c["tags"]} for c in cards]
        with open(output, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"✅ Exported {len(cards)} cards to {output} (JSON)")

def cmd_config_set(args):
    conn = get_db()
    set_config(conn, args.key, args.value)
    print(f"✅ Config {args.key} = {args.value}")

def cmd_config_get(args):
    conn = get_db()
    val = get_config(conn, args.key)
    if val is None:
        print(f"Config '{args.key}' not set")
    else:
        print(f"{args.key} = {val}")

# ── Argument Parser ──

def main():
    parser = argparse.ArgumentParser(prog="srs", description="Spaced Repetition Engine — SM-2 flashcards")
    sub = parser.add_subparsers(dest="command")

    # deck
    deck = sub.add_parser("deck", help="Manage decks")
    deck_sub = deck.add_subparsers(dest="deck_cmd")
    dc = deck_sub.add_parser("create", help="Create a deck")
    dc.add_argument("name")
    dl = deck_sub.add_parser("list", help="List decks")
    dd = deck_sub.add_parser("delete", help="Delete a deck")
    dd.add_argument("deck_id", type=int)

    # card
    card = sub.add_parser("card", help="Manage cards")
    card_sub = card.add_subparsers(dest="card_cmd")
    ca = card_sub.add_parser("add", help="Add a card")
    ca.add_argument("deck_id", type=int)
    ca.add_argument("front")
    ca.add_argument("back")
    ca.add_argument("--tags", default="")
    ci = card_sub.add_parser("import", help="Import cards from CSV")
    ci.add_argument("deck_id", type=int)
    ci.add_argument("csv_file")
    cs = card_sub.add_parser("search", help="Search cards")
    cs.add_argument("query")
    ce = card_sub.add_parser("edit", help="Edit a card")
    ce.add_argument("card_id", type=int)
    ce.add_argument("--front")
    ce.add_argument("--back")
    ce.add_argument("--tags")
    cdel = card_sub.add_parser("delete", help="Delete a card")
    cdel.add_argument("card_id", type=int)

    # review
    rev = sub.add_parser("review", help="Review due cards")
    rev.add_argument("deck_id", type=int, nargs="?")
    rev.add_argument("--all", action="store_true", help="Review all decks")

    # status
    st = sub.add_parser("status", help="Show review status")
    st.add_argument("--json", dest="json_out", action="store_true")
    st.add_argument("--due-count", dest="due_count", action="store_true")

    # stats
    stats = sub.add_parser("stats", help="Deck statistics")
    stats.add_argument("deck_id", type=int)

    # export
    exp = sub.add_parser("export", help="Export deck")
    exp.add_argument("deck_id", type=int)
    exp.add_argument("--format", choices=["anki", "csv", "json"], default="anki")
    exp.add_argument("--output", "-o", required=True)

    # config
    cfg = sub.add_parser("config", help="Settings")
    cfg_sub = cfg.add_subparsers(dest="config_cmd")
    cset = cfg_sub.add_parser("set")
    cset.add_argument("key")
    cset.add_argument("value")
    cget = cfg_sub.add_parser("get")
    cget.add_argument("key")

    args = parser.parse_args()

    handlers = {
        ("deck", "create"): cmd_deck_create,
        ("deck", "list"): cmd_deck_list,
        ("deck", "delete"): cmd_deck_delete,
        ("card", "add"): cmd_card_add,
        ("card", "import"): cmd_card_import,
        ("card", "search"): cmd_card_search,
        ("card", "edit"): cmd_card_edit,
        ("card", "delete"): cmd_card_delete,
    }

    if args.command == "review":
        if not args.deck_id and not args.all:
            print("Specify deck_id or --all"); sys.exit(1)
        cmd_review(args)
    elif args.command == "status":
        cmd_status(args)
    elif args.command == "stats":
        cmd_stats(args)
    elif args.command == "export":
        cmd_export(args)
    elif args.command in ("deck", "card"):
        sub_cmd = getattr(args, f"{args.command}_cmd", None)
        handler = handlers.get((args.command, sub_cmd))
        if handler:
            handler(args)
        else:
            parser.parse_args([args.command, "-h"])
    elif args.command == "config":
        if args.config_cmd == "set":
            cmd_config_set(args)
        elif args.config_cmd == "get":
            cmd_config_get(args)
        else:
            parser.parse_args(["config", "-h"])
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
