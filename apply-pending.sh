#!/bin/bash
# =============================================================================
# Apply pending Supabase migrations locally
# Run: bash apply-pending.sh YOUR_DB_PASSWORD
# OR:  SUPABASE_DB_PASSWORD=xxx bash apply-pending.sh
# =============================================================================

DB_PASS="${1:-$SUPABASE_DB_PASSWORD}"

if [ -z "$DB_PASS" ]; then
  echo "Usage: bash apply-pending.sh YOUR_DB_PASSWORD"
  exit 1
fi

DB_URL="postgresql://postgres:${DB_PASS}@localhost:5432/postgres"

echo "Applying 3 pending migrations..."

for f in \
  "supabase/migrations/20260313000001_wallet_only_half_rule_validation.sql" \
  "supabase/migrations/20260313100000_fix_transactions_statements_billing.sql" \
  "supabase/migrations/20260314000000_consistency_fix.sql"; do
  echo ""
  echo "→ Applying: $(basename $f)"
  psql "$DB_URL" -f "$f" 2>&1
  if [ $? -eq 0 ]; then
    echo "✅ Done"
  else
    echo "❌ Failed — check error above"
    exit 1
  fi
done

echo ""
echo "✅ All 3 migrations applied successfully"
