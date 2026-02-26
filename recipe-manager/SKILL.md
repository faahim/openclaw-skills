---
name: recipe-manager
description: >-
  Save, organize, and search recipes from URLs or manual entry. Generate shopping lists, plan meals, export collections.
categories: [home, productivity]
dependencies: [python3, pip, sqlite3]
---

# Recipe Manager

## What This Does

Scrape recipes from any URL (AllRecipes, BBC Good Food, NYT Cooking, etc.), store them in a local SQLite database, search by ingredient or tag, generate shopping lists for meal plans, and export your collection. No cloud service — your recipes stay local.

**Example:** "Save this AllRecipes URL, tag it 'weeknight', add it to this week's meal plan, generate a combined shopping list."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. Add Your First Recipe (from URL)

```bash
python3 scripts/recipe.py add --url "https://www.allrecipes.com/recipe/228285/tandoori-chicken/"
# Output:
# ✅ Saved: Tandoori Chicken
#    Servings: 6 | Prep: 15 min | Cook: 30 min
#    Ingredients: 12 | Tags: indian, chicken, grill
```

### 3. Add a Recipe Manually

```bash
python3 scripts/recipe.py add \
  --title "Quick Pasta" \
  --servings 2 \
  --prep-time 5 \
  --cook-time 15 \
  --ingredients "200g spaghetti|2 cloves garlic|100g bacon|2 eggs|50g parmesan|salt|pepper" \
  --instructions "Boil pasta. Fry bacon and garlic. Mix eggs and parmesan. Combine all, toss off heat." \
  --tags "pasta,quick,italian"
```

### 4. Search Recipes

```bash
# By ingredient
python3 scripts/recipe.py search --ingredient "chicken"

# By tag
python3 scripts/recipe.py search --tag "weeknight"

# Full-text search
python3 scripts/recipe.py search --query "pasta carbonara"
```

## Core Workflows

### Workflow 1: Save Recipe from URL

```bash
python3 scripts/recipe.py add --url "https://www.bbcgoodfood.com/recipes/easy-chicken-fajitas" --tags "mexican,weeknight"
```

Supports 100+ recipe sites via `recipe-scrapers` library including:
- AllRecipes, BBC Good Food, Food Network, Epicurious
- NYT Cooking, Serious Eats, Bon Appetit, Tasty
- Jamie Oliver, Minimalist Baker, Budget Bytes
- And many more

### Workflow 2: Meal Planning

```bash
# Create a meal plan for the week
python3 scripts/recipe.py plan --week

# Add recipes to specific days
python3 scripts/recipe.py plan --add "Tandoori Chicken" --day monday
python3 scripts/recipe.py plan --add "Quick Pasta" --day tuesday
python3 scripts/recipe.py plan --add "Easy Chicken Fajitas" --day wednesday

# View the plan
python3 scripts/recipe.py plan --show
# Output:
# 📅 Meal Plan: Feb 24 - Mar 2
# ┌──────────┬──────────────────────┐
# │ Monday   │ Tandoori Chicken     │
# │ Tuesday  │ Quick Pasta          │
# │ Wednesday│ Easy Chicken Fajitas │
# │ Thursday │ (empty)              │
# │ Friday   │ (empty)              │
# └──────────┴──────────────────────┘
```

### Workflow 3: Generate Shopping List

```bash
# From meal plan
python3 scripts/recipe.py shop --from-plan

# From specific recipes
python3 scripts/recipe.py shop --recipes "Tandoori Chicken,Quick Pasta"

# Scale for different servings
python3 scripts/recipe.py shop --recipes "Tandoori Chicken" --servings 4

# Output:
# 🛒 Shopping List (3 recipes, 8 servings total)
#
# PRODUCE
#   • 3 cloves garlic
#   • 1 lime
#   • 2 bell peppers
#   • 1 onion
#
# PROTEIN
#   • 600g chicken thighs
#   • 100g bacon
#
# DAIRY
#   • 2 eggs
#   • 50g parmesan
#   • 150ml yogurt
#
# PANTRY
#   • 200g spaghetti
#   • tortillas (8)
#   • tandoori spice mix
#   • salt, pepper, olive oil
```

### Workflow 4: Export & Import

```bash
# Export all recipes as JSON
python3 scripts/recipe.py export --format json > my-recipes.json

# Export as markdown cookbook
python3 scripts/recipe.py export --format markdown > cookbook.md

# Import from JSON backup
python3 scripts/recipe.py import --file my-recipes.json
```

### Workflow 5: List & Browse

```bash
# List all recipes
python3 scripts/recipe.py list

# List by tag
python3 scripts/recipe.py list --tag "italian"

# Show recipe details
python3 scripts/recipe.py show "Tandoori Chicken"

# Random recipe suggestion
python3 scripts/recipe.py random
python3 scripts/recipe.py random --tag "quick"
```

### Workflow 6: Delete & Edit

```bash
# Delete a recipe
python3 scripts/recipe.py delete "Quick Pasta"

# Re-tag a recipe
python3 scripts/recipe.py tag "Tandoori Chicken" --add "favorites" --remove "grill"
```

## Configuration

### Database Location

By default, recipes are stored at `~/.recipe-manager/recipes.db`. Override with:

```bash
export RECIPE_DB="$HOME/my-recipes/recipes.db"
```

### Ingredient Categories

Edit `scripts/categories.json` to customize how ingredients are grouped in shopping lists:

```json
{
  "produce": ["garlic", "onion", "pepper", "tomato", "lime", "lemon", "cilantro"],
  "protein": ["chicken", "beef", "pork", "bacon", "salmon", "shrimp", "tofu"],
  "dairy": ["egg", "milk", "cream", "cheese", "butter", "yogurt", "parmesan"],
  "pantry": ["salt", "pepper", "oil", "flour", "sugar", "rice", "pasta", "spaghetti"],
  "spices": ["cumin", "paprika", "cinnamon", "oregano", "basil", "chili"],
  "other": []
}
```

## Troubleshooting

### Issue: "No module named 'recipe_scrapers'"

```bash
pip3 install recipe-scrapers --upgrade
```

### Issue: URL not supported

Not all recipe sites are supported. Fallback:
```bash
# Add manually with ingredients from the page
python3 scripts/recipe.py add --title "Recipe Name" --ingredients "..." --instructions "..."
```

### Issue: Duplicate recipes

```bash
# Check for duplicates
python3 scripts/recipe.py list --duplicates

# Merge duplicates (keeps the one with more data)
python3 scripts/recipe.py merge "Recipe Name"
```

## Dependencies

- `python3` (3.8+)
- `pip3` (for installing recipe-scrapers)
- `sqlite3` (bundled with Python)
- `recipe-scrapers` (Python package — installed by install.sh)
