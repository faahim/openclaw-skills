#!/bin/bash
# Recipe Manager — Install Dependencies
set -e

echo "📦 Installing Recipe Manager dependencies..."

# Check Python 3
if ! command -v python3 &>/dev/null; then
  echo "❌ Python 3 is required. Install it first:"
  echo "   Ubuntu/Debian: sudo apt-get install python3 python3-pip"
  echo "   Mac: brew install python3"
  exit 1
fi

# Install Python packages
pip3 install --quiet --upgrade recipe-scrapers 2>/dev/null || pip install --quiet --upgrade recipe-scrapers

# Create data directory
mkdir -p ~/.recipe-manager

# Initialize database
python3 "$(dirname "$0")/recipe.py" init

echo "✅ Recipe Manager installed!"
echo "   Database: ~/.recipe-manager/recipes.db"
echo ""
echo "Try: python3 $(dirname "$0")/recipe.py add --url 'https://www.allrecipes.com/recipe/228285/tandoori-chicken/'"
