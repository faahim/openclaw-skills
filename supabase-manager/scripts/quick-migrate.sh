#!/bin/bash
# Quick migration helper — create a migration from a description
# Usage: bash quick-migrate.sh "create posts table with title, body, author_id"

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: bash quick-migrate.sh <migration-name>"
  echo "Example: bash quick-migrate.sh create_posts_table"
  exit 1
fi

MIGRATION_NAME=$(echo "$1" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g')

if ! [ -f "supabase/config.toml" ]; then
  echo "❌ No supabase project found. Run 'supabase init' first."
  exit 1
fi

supabase migration new "$MIGRATION_NAME"

MIGRATION_FILE=$(ls -t supabase/migrations/*.sql | head -1)

echo "✅ Created: $MIGRATION_FILE"
echo ""
echo "Edit this file with your SQL, then run:"
echo "  supabase db reset    # Apply locally"
echo "  supabase db push     # Push to production"
