# Listing Copy: Recipe Manager

## Metadata
- **Type:** Skill
- **Name:** recipe-manager
- **Display Name:** Recipe Manager
- **Categories:** [home, productivity]
- **Price:** $8
- **Dependencies:** [python3, pip, sqlite3]

## Tagline

"Save recipes from any URL, plan meals, and generate shopping lists — all local"

## Description

Tired of bookmarking recipes across dozens of websites only to lose track of them? Recipe Manager scrapes recipes from 500+ cooking sites (AllRecipes, BBC Good Food, Food Network, Serious Eats, and more), stores them in a local SQLite database, and lets you search, tag, and organize your collection.

Plan your weekly meals by assigning recipes to days, then generate a combined shopping list with ingredients automatically categorized (produce, protein, dairy, pantry, spices). Export your entire collection as JSON or a formatted markdown cookbook. No cloud accounts, no subscriptions — your recipes stay on your machine.

**What it does:**
- 🔗 Scrape recipes from 500+ cooking websites automatically
- 🏷️ Tag, search, and organize your recipe collection
- 📅 Weekly meal planning with day-by-day assignment
- 🛒 Auto-generated shopping lists with ingredient categorization
- 📤 Export as JSON backup or markdown cookbook
- 📥 Import from JSON (migrate from other tools)
- 🎲 Random recipe suggestions (optionally filtered by tag)
- 🔍 Full-text search across titles, ingredients, and instructions

## Quick Start Preview

```bash
# Install (one command)
bash scripts/install.sh

# Save a recipe from URL
python3 scripts/recipe.py add --url "https://www.budgetbytes.com/one-pot-creamy-cajun-chicken-pasta/" --tags "pasta,quick"

# Generate shopping list
python3 scripts/recipe.py shop --recipes "Cajun Chicken Pasta,Tandoori Chicken"
```

## Dependencies
- `python3` (3.8+)
- `recipe-scrapers` (Python package — auto-installed)
- `sqlite3` (bundled with Python)

## Installation Time
**2 minutes** — run install.sh, start saving recipes

## Pricing Justification

**Why $8:**
- LarryBrain utility range: $5-15
- Complexity: Medium (URL scraping, database, meal planning, shopping lists)
- Comparable apps: Paprika ($5 one-time), Mealime (freemium), CopyMeThat (free with limits)
- Our advantage: Local-first, no account needed, agent-integrated, 500+ site support
