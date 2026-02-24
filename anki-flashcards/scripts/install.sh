#!/bin/bash
# Install dependencies for Anki Flashcard Generator
set -e

echo "Installing genanki..."
pip3 install genanki>=0.13.0 2>/dev/null || pip install genanki>=0.13.0

echo "✅ Dependencies installed. Ready to generate flashcards."
