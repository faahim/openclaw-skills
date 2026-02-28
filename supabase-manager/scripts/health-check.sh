#!/bin/bash
# Supabase Health Check — verify local stack and project status
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok() { echo -e "  ${GREEN}✅${NC} $1"; }
fail() { echo -e "  ${RED}❌${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠️${NC} $1"; }

echo "🔍 Supabase Health Check"
echo "========================"
ERRORS=0

# 1. CLI installed?
echo ""
echo "📦 CLI"
if command -v supabase &>/dev/null; then
  ok "Supabase CLI: $(supabase --version 2>/dev/null | head -1)"
else
  fail "Supabase CLI not installed"
  ((ERRORS++))
fi

# 2. Docker running?
echo ""
echo "🐳 Docker"
if command -v docker &>/dev/null; then
  if docker info &>/dev/null 2>&1; then
    ok "Docker is running"
    CONTAINERS=$(docker ps --filter "name=supabase" --format '{{.Names}}' 2>/dev/null | wc -l)
    if [ "$CONTAINERS" -gt 0 ]; then
      ok "Supabase containers running: $CONTAINERS"
      docker ps --filter "name=supabase" --format '    {{.Names}}: {{.Status}}' 2>/dev/null
    else
      warn "No Supabase containers running (run 'supabase start')"
    fi
  else
    fail "Docker not running"
    ((ERRORS++))
  fi
else
  fail "Docker not installed"
  ((ERRORS++))
fi

# 3. Project initialized?
echo ""
echo "📁 Project"
if [ -f "supabase/config.toml" ]; then
  ok "Project initialized (supabase/config.toml found)"
  
  # Count migrations
  MIGRATIONS=$(find supabase/migrations -name "*.sql" 2>/dev/null | wc -l)
  ok "Migrations: $MIGRATIONS"
  
  # Check seed file
  if [ -f "supabase/seed.sql" ]; then
    ok "Seed file exists"
  else
    warn "No seed.sql (optional)"
  fi
  
  # Check edge functions
  FUNCTIONS=$(find supabase/functions -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
  ok "Edge functions: $FUNCTIONS"
  
  # Check if linked to remote
  if supabase status -o json 2>/dev/null | jq -e '.SUPABASE_URL' &>/dev/null; then
    ok "Local stack accessible"
  fi
else
  warn "No Supabase project in current directory"
fi

# 4. Auth check
echo ""
echo "🔑 Authentication"
if [ -f "$HOME/.supabase/access-token" ] || [ -n "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  ok "Authenticated (token found)"
else
  warn "Not logged in (run 'supabase login')"
fi

echo ""
echo "========================"
if [ "$ERRORS" -eq 0 ]; then
  echo -e "${GREEN}All checks passed!${NC}"
else
  echo -e "${RED}$ERRORS issue(s) found${NC}"
fi
