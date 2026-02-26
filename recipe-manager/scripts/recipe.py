#!/usr/bin/env python3
"""Recipe Manager — Save, organize, search recipes. Generate shopping lists & meal plans."""

import argparse
import json
import os
import random
import sqlite3
import sys
import textwrap
from datetime import datetime, timedelta
from pathlib import Path

DB_PATH = os.environ.get("RECIPE_DB", os.path.expanduser("~/.recipe-manager/recipes.db"))
CATEGORIES_PATH = os.path.join(os.path.dirname(__file__), "categories.json")


def get_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_db():
    conn = get_db()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS recipes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            url TEXT,
            servings INTEGER,
            prep_time TEXT,
            cook_time TEXT,
            total_time TEXT,
            ingredients TEXT NOT NULL,
            instructions TEXT,
            image_url TEXT,
            source TEXT,
            created_at TEXT DEFAULT (datetime('now')),
            updated_at TEXT DEFAULT (datetime('now'))
        );
        CREATE TABLE IF NOT EXISTS tags (
            recipe_id INTEGER,
            tag TEXT NOT NULL,
            FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
            UNIQUE(recipe_id, tag)
        );
        CREATE TABLE IF NOT EXISTS meal_plan (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            recipe_id INTEGER,
            day_date TEXT NOT NULL,
            meal_type TEXT DEFAULT 'dinner',
            FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
        );
        CREATE VIRTUAL TABLE IF NOT EXISTS recipes_fts USING fts5(
            title, ingredients, instructions, content=recipes, content_rowid=id
        );
        CREATE TRIGGER IF NOT EXISTS recipes_ai AFTER INSERT ON recipes BEGIN
            INSERT INTO recipes_fts(rowid, title, ingredients, instructions)
            VALUES (new.id, new.title, new.ingredients, new.instructions);
        END;
        CREATE TRIGGER IF NOT EXISTS recipes_ad AFTER DELETE ON recipes BEGIN
            INSERT INTO recipes_fts(recipes_fts, rowid, title, ingredients, instructions)
            VALUES ('delete', old.id, old.title, old.ingredients, old.instructions);
        END;
    """)
    conn.commit()
    conn.close()
    print("✅ Database initialized at", DB_PATH)


def scrape_url(url):
    try:
        from recipe_scrapers import scrape_me
    except ImportError:
        print("❌ recipe-scrapers not installed. Run: pip3 install recipe-scrapers")
        sys.exit(1)

    scraper = scrape_me(url)
    return {
        "title": scraper.title(),
        "servings": scraper.yields(),
        "prep_time": str(scraper.prep_time()) if hasattr(scraper, "prep_time") else None,
        "cook_time": str(scraper.cook_time()) if hasattr(scraper, "cook_time") else None,
        "total_time": str(scraper.total_time()) if hasattr(scraper, "total_time") else None,
        "ingredients": scraper.ingredients(),
        "instructions": scraper.instructions(),
        "image_url": scraper.image() if hasattr(scraper, "image") else None,
        "source": url,
    }


def add_recipe(args):
    conn = get_db()

    if args.url:
        print(f"🔍 Scraping {args.url}...")
        try:
            data = scrape_url(args.url)
        except Exception as e:
            print(f"❌ Failed to scrape URL: {e}")
            sys.exit(1)

        title = args.title or data["title"]
        ingredients = "\n".join(data["ingredients"]) if isinstance(data["ingredients"], list) else data["ingredients"]
        instructions = data.get("instructions", "")
        servings_raw = data.get("servings", "")
        try:
            servings = int("".join(c for c in str(servings_raw) if c.isdigit())) if servings_raw else None
        except (ValueError, TypeError):
            servings = None
        prep_time = data.get("prep_time")
        cook_time = data.get("cook_time")
        total_time = data.get("total_time")
        image_url = data.get("image_url")
        source = data.get("source")
    else:
        if not args.title:
            print("❌ --title is required when not using --url")
            sys.exit(1)
        title = args.title
        ingredients = (args.ingredients or "").replace("|", "\n")
        instructions = args.instructions or ""
        servings = args.servings
        prep_time = args.prep_time
        cook_time = args.cook_time
        total_time = None
        image_url = None
        source = None

    cursor = conn.execute(
        """INSERT INTO recipes (title, url, servings, prep_time, cook_time, total_time, ingredients, instructions, image_url, source)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (title, args.url, servings, prep_time, cook_time, total_time, ingredients, instructions, image_url, source),
    )
    recipe_id = cursor.lastrowid

    tags = []
    if args.tags:
        tags = [t.strip().lower() for t in args.tags.split(",") if t.strip()]
    for tag in tags:
        conn.execute("INSERT OR IGNORE INTO tags (recipe_id, tag) VALUES (?, ?)", (recipe_id, tag))

    conn.commit()
    conn.close()

    ing_count = len([l for l in ingredients.split("\n") if l.strip()])
    tag_str = ", ".join(tags) if tags else "none"
    print(f"✅ Saved: {title}")
    print(f"   Servings: {servings or '?'} | Prep: {prep_time or '?'} | Cook: {cook_time or '?'}")
    print(f"   Ingredients: {ing_count} | Tags: {tag_str}")


def list_recipes(args):
    conn = get_db()
    if args.tag:
        rows = conn.execute(
            """SELECT r.* FROM recipes r JOIN tags t ON r.id = t.recipe_id WHERE t.tag = ? ORDER BY r.title""",
            (args.tag.lower(),),
        ).fetchall()
    elif getattr(args, "duplicates", False):
        rows = conn.execute(
            "SELECT * FROM recipes WHERE LOWER(title) IN (SELECT LOWER(title) FROM recipes GROUP BY LOWER(title) HAVING COUNT(*) > 1) ORDER BY title"
        ).fetchall()
    else:
        rows = conn.execute("SELECT * FROM recipes ORDER BY title").fetchall()

    if not rows:
        print("📭 No recipes found.")
        return

    print(f"📚 {len(rows)} recipe(s):\n")
    for r in rows:
        tags = conn.execute("SELECT tag FROM tags WHERE recipe_id = ?", (r["id"],)).fetchall()
        tag_str = ", ".join(t["tag"] for t in tags) if tags else ""
        print(f"  • {r['title']}" + (f"  [{tag_str}]" if tag_str else ""))
    conn.close()


def search_recipes(args):
    conn = get_db()
    rows = []

    if args.ingredient:
        rows = conn.execute(
            "SELECT * FROM recipes WHERE LOWER(ingredients) LIKE ? ORDER BY title",
            (f"%{args.ingredient.lower()}%",),
        ).fetchall()
    elif args.tag:
        rows = conn.execute(
            "SELECT r.* FROM recipes r JOIN tags t ON r.id = t.recipe_id WHERE t.tag = ? ORDER BY r.title",
            (args.tag.lower(),),
        ).fetchall()
    elif args.query:
        rows = conn.execute(
            "SELECT r.* FROM recipes r JOIN recipes_fts f ON r.id = f.rowid WHERE recipes_fts MATCH ? ORDER BY rank",
            (args.query,),
        ).fetchall()

    if not rows:
        print("🔍 No recipes found.")
        return

    print(f"🔍 Found {len(rows)} recipe(s):\n")
    for r in rows:
        tags = conn.execute("SELECT tag FROM tags WHERE recipe_id = ?", (r["id"],)).fetchall()
        tag_str = ", ".join(t["tag"] for t in tags) if tags else ""
        print(f"  • {r['title']}" + (f"  [{tag_str}]" if tag_str else ""))
    conn.close()


def show_recipe(args):
    conn = get_db()
    r = conn.execute("SELECT * FROM recipes WHERE LOWER(title) LIKE ?", (f"%{args.title.lower()}%",)).fetchone()
    if not r:
        print(f"❌ Recipe '{args.title}' not found.")
        return

    tags = conn.execute("SELECT tag FROM tags WHERE recipe_id = ?", (r["id"],)).fetchall()
    tag_str = ", ".join(t["tag"] for t in tags) if tags else "none"

    print(f"\n{'='*50}")
    print(f"🍽️  {r['title']}")
    print(f"{'='*50}")
    print(f"Servings: {r['servings'] or '?'} | Prep: {r['prep_time'] or '?'} | Cook: {r['cook_time'] or '?'}")
    print(f"Tags: {tag_str}")
    if r["url"]:
        print(f"Source: {r['url']}")
    print(f"\n📋 Ingredients:")
    for line in (r["ingredients"] or "").split("\n"):
        if line.strip():
            print(f"  • {line.strip()}")
    print(f"\n📝 Instructions:")
    print(textwrap.indent(r["instructions"] or "(none)", "  "))
    print()
    conn.close()


def random_recipe(args):
    conn = get_db()
    if args.tag:
        rows = conn.execute(
            "SELECT r.* FROM recipes r JOIN tags t ON r.id = t.recipe_id WHERE t.tag = ?",
            (args.tag.lower(),),
        ).fetchall()
    else:
        rows = conn.execute("SELECT * FROM recipes").fetchall()

    if not rows:
        print("📭 No recipes to pick from.")
        return

    r = random.choice(rows)
    print(f"🎲 Random pick: {r['title']}")
    print(f"   Servings: {r['servings'] or '?'} | Cook: {r['cook_time'] or '?'}")
    if r["url"]:
        print(f"   Source: {r['url']}")
    conn.close()


def delete_recipe(args):
    conn = get_db()
    r = conn.execute("SELECT * FROM recipes WHERE LOWER(title) LIKE ?", (f"%{args.title.lower()}%",)).fetchone()
    if not r:
        print(f"❌ Recipe '{args.title}' not found.")
        return

    conn.execute("DELETE FROM tags WHERE recipe_id = ?", (r["id"],))
    conn.execute("DELETE FROM meal_plan WHERE recipe_id = ?", (r["id"],))
    conn.execute("DELETE FROM recipes WHERE id = ?", (r["id"],))
    conn.commit()
    conn.close()
    print(f"🗑️  Deleted: {r['title']}")


def tag_recipe(args):
    conn = get_db()
    r = conn.execute("SELECT * FROM recipes WHERE LOWER(title) LIKE ?", (f"%{args.title.lower()}%",)).fetchone()
    if not r:
        print(f"❌ Recipe '{args.title}' not found.")
        return

    if args.add:
        for tag in args.add.split(","):
            conn.execute("INSERT OR IGNORE INTO tags (recipe_id, tag) VALUES (?, ?)", (r["id"], tag.strip().lower()))
        print(f"🏷️  Added tags: {args.add}")

    if args.remove:
        for tag in args.remove.split(","):
            conn.execute("DELETE FROM tags WHERE recipe_id = ? AND tag = ?", (r["id"], tag.strip().lower()))
        print(f"🏷️  Removed tags: {args.remove}")

    conn.commit()
    conn.close()


def meal_plan(args):
    conn = get_db()

    if args.add and args.day:
        r = conn.execute("SELECT * FROM recipes WHERE LOWER(title) LIKE ?", (f"%{args.add.lower()}%",)).fetchone()
        if not r:
            print(f"❌ Recipe '{args.add}' not found.")
            return

        # Calculate date for the given day name
        today = datetime.now()
        days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        target_idx = days.index(args.day.lower())
        current_idx = today.weekday()
        delta = (target_idx - current_idx) % 7
        target_date = (today + timedelta(days=delta)).strftime("%Y-%m-%d")

        conn.execute(
            "INSERT INTO meal_plan (recipe_id, day_date, meal_type) VALUES (?, ?, ?)",
            (r["id"], target_date, args.meal or "dinner"),
        )
        conn.commit()
        print(f"✅ Added '{r['title']}' to {args.day.title()} ({target_date})")

    elif args.show or args.week:
        today = datetime.now()
        start = today - timedelta(days=today.weekday())
        end = start + timedelta(days=6)

        rows = conn.execute(
            """SELECT mp.day_date, r.title FROM meal_plan mp
               JOIN recipes r ON mp.recipe_id = r.id
               WHERE mp.day_date BETWEEN ? AND ?
               ORDER BY mp.day_date""",
            (start.strftime("%Y-%m-%d"), end.strftime("%Y-%m-%d")),
        ).fetchall()

        print(f"\n📅 Meal Plan: {start.strftime('%b %d')} - {end.strftime('%b %d')}\n")
        days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        plan = {}
        for row in rows:
            plan.setdefault(row["day_date"], []).append(row["title"])

        for i, day_name in enumerate(days):
            day_date = (start + timedelta(days=i)).strftime("%Y-%m-%d")
            meals = plan.get(day_date, ["(empty)"])
            print(f"  {day_name:12s} │ {', '.join(meals)}")
        print()
    conn.close()


def shopping_list(args):
    conn = get_db()
    ingredients = []

    if args.from_plan:
        today = datetime.now()
        start = today - timedelta(days=today.weekday())
        end = start + timedelta(days=6)
        rows = conn.execute(
            """SELECT r.ingredients, r.servings FROM meal_plan mp
               JOIN recipes r ON mp.recipe_id = r.id
               WHERE mp.day_date BETWEEN ? AND ?""",
            (start.strftime("%Y-%m-%d"), end.strftime("%Y-%m-%d")),
        ).fetchall()
        for row in rows:
            for line in (row["ingredients"] or "").split("\n"):
                if line.strip():
                    ingredients.append(line.strip())
    elif args.recipes:
        for name in args.recipes.split(","):
            r = conn.execute(
                "SELECT * FROM recipes WHERE LOWER(title) LIKE ?", (f"%{name.strip().lower()}%",)
            ).fetchone()
            if r:
                for line in (r["ingredients"] or "").split("\n"):
                    if line.strip():
                        ingredients.append(line.strip())

    conn.close()

    if not ingredients:
        print("🛒 No ingredients found.")
        return

    # Load categories
    cats = {"produce": [], "protein": [], "dairy": [], "pantry": [], "spices": [], "other": []}
    if os.path.exists(CATEGORIES_PATH):
        with open(CATEGORIES_PATH) as f:
            cats = json.load(f)

    # Categorize ingredients
    categorized = {k: [] for k in cats}
    categorized["other"] = []

    for ing in ingredients:
        placed = False
        for cat, keywords in cats.items():
            if cat == "other":
                continue
            for kw in keywords:
                if kw.lower() in ing.lower():
                    categorized[cat].append(ing)
                    placed = True
                    break
            if placed:
                break
        if not placed:
            categorized["other"].append(ing)

    print(f"\n🛒 Shopping List ({len(ingredients)} items)\n")
    for cat, items in categorized.items():
        if items:
            print(f"  {cat.upper()}")
            for item in items:
                print(f"    • {item}")
            print()


def export_recipes(args):
    conn = get_db()
    rows = conn.execute("SELECT * FROM recipes ORDER BY title").fetchall()

    if args.format == "json":
        recipes = []
        for r in rows:
            tags = conn.execute("SELECT tag FROM tags WHERE recipe_id = ?", (r["id"],)).fetchall()
            recipes.append({
                "title": r["title"],
                "url": r["url"],
                "servings": r["servings"],
                "prep_time": r["prep_time"],
                "cook_time": r["cook_time"],
                "ingredients": (r["ingredients"] or "").split("\n"),
                "instructions": r["instructions"],
                "tags": [t["tag"] for t in tags],
            })
        print(json.dumps(recipes, indent=2))
    elif args.format == "markdown":
        for r in rows:
            tags = conn.execute("SELECT tag FROM tags WHERE recipe_id = ?", (r["id"],)).fetchall()
            tag_str = ", ".join(t["tag"] for t in tags) if tags else ""
            print(f"# {r['title']}\n")
            if tag_str:
                print(f"*Tags: {tag_str}*\n")
            print(f"Servings: {r['servings'] or '?'} | Prep: {r['prep_time'] or '?'} | Cook: {r['cook_time'] or '?'}\n")
            if r["url"]:
                print(f"Source: {r['url']}\n")
            print("## Ingredients\n")
            for line in (r["ingredients"] or "").split("\n"):
                if line.strip():
                    print(f"- {line.strip()}")
            print(f"\n## Instructions\n\n{r['instructions'] or ''}\n")
            print("---\n")
    conn.close()


def import_recipes(args):
    with open(args.file) as f:
        recipes = json.load(f)

    conn = get_db()
    count = 0
    for recipe in recipes:
        ingredients = "\n".join(recipe.get("ingredients", []))
        cursor = conn.execute(
            """INSERT INTO recipes (title, url, servings, prep_time, cook_time, ingredients, instructions)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (
                recipe["title"],
                recipe.get("url"),
                recipe.get("servings"),
                recipe.get("prep_time"),
                recipe.get("cook_time"),
                ingredients,
                recipe.get("instructions", ""),
            ),
        )
        for tag in recipe.get("tags", []):
            conn.execute("INSERT OR IGNORE INTO tags (recipe_id, tag) VALUES (?, ?)", (cursor.lastrowid, tag))
        count += 1

    conn.commit()
    conn.close()
    print(f"✅ Imported {count} recipes.")


def main():
    parser = argparse.ArgumentParser(description="Recipe Manager")
    sub = parser.add_subparsers(dest="command")

    # init
    sub.add_parser("init", help="Initialize database")

    # add
    p = sub.add_parser("add", help="Add a recipe")
    p.add_argument("--url", help="URL to scrape")
    p.add_argument("--title", help="Recipe title")
    p.add_argument("--servings", type=int)
    p.add_argument("--prep-time")
    p.add_argument("--cook-time")
    p.add_argument("--ingredients", help="Pipe-separated list")
    p.add_argument("--instructions")
    p.add_argument("--tags", help="Comma-separated tags")

    # list
    p = sub.add_parser("list", help="List recipes")
    p.add_argument("--tag")
    p.add_argument("--duplicates", action="store_true")

    # search
    p = sub.add_parser("search", help="Search recipes")
    p.add_argument("--ingredient")
    p.add_argument("--tag")
    p.add_argument("--query")

    # show
    p = sub.add_parser("show", help="Show recipe details")
    p.add_argument("title")

    # random
    p = sub.add_parser("random", help="Random recipe")
    p.add_argument("--tag")

    # delete
    p = sub.add_parser("delete", help="Delete a recipe")
    p.add_argument("title")

    # tag
    p = sub.add_parser("tag", help="Add/remove tags")
    p.add_argument("title")
    p.add_argument("--add")
    p.add_argument("--remove")

    # plan
    p = sub.add_parser("plan", help="Meal planning")
    p.add_argument("--add", help="Recipe to add")
    p.add_argument("--day", help="Day of week")
    p.add_argument("--meal", help="Meal type (breakfast/lunch/dinner)")
    p.add_argument("--show", action="store_true")
    p.add_argument("--week", action="store_true")

    # shop
    p = sub.add_parser("shop", help="Generate shopping list")
    p.add_argument("--from-plan", action="store_true")
    p.add_argument("--recipes", help="Comma-separated recipe names")
    p.add_argument("--servings", type=int)

    # export
    p = sub.add_parser("export", help="Export recipes")
    p.add_argument("--format", choices=["json", "markdown"], default="json")

    # import
    p = sub.add_parser("import", help="Import recipes from JSON")
    p.add_argument("--file", required=True)

    args = parser.parse_args()

    if args.command == "init":
        init_db()
    elif args.command == "add":
        add_recipe(args)
    elif args.command == "list":
        list_recipes(args)
    elif args.command == "search":
        search_recipes(args)
    elif args.command == "show":
        show_recipe(args)
    elif args.command == "random":
        random_recipe(args)
    elif args.command == "delete":
        delete_recipe(args)
    elif args.command == "tag":
        tag_recipe(args)
    elif args.command == "plan":
        meal_plan(args)
    elif args.command == "shop":
        shopping_list(args)
    elif args.command == "export":
        export_recipes(args)
    elif args.command == "import":
        import_recipes(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
