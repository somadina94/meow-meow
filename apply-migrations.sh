#!/bin/bash
# Apply all Supabase migrations
# Usage: SUPABASE_DB_URL="postgresql://postgres:[PASSWORD]@localhost:5432/postgres" ./apply-migrations.sh

set -e

MIGRATIONS_DIR="./supabase/migrations"
DB_URL="${SUPABASE_DB_URL:-postgresql://postgres:YOUR_DB_PASSWORD@db.www.meow-meow.co.in:5432/postgres}"

echo "=== Applying Supabase Migrations ==="
echo "Project: supabase"
echo ""

# Count migrations
TOTAL=$(ls "$MIGRATIONS_DIR"/*.sql | wc -l)
echo "Found $TOTAL migration files"
echo ""

APPLIED=0
FAILED=0

for f in $(ls "$MIGRATIONS_DIR"/*.sql | sort); do
  FNAME=$(basename "$f")
  echo -n "Applying $FNAME ... "
  
  if psql "$DB_URL" -f "$f" -q 2>/dev/null; then
    echo "✓"
    APPLIED=$((APPLIED + 1))
  else
    echo "⚠ (may already exist)"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=== Done: $APPLIED applied, $FAILED skipped/failed ==="
