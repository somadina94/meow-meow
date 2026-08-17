#!/bin/bash
# Push migrations using Supabase CLI
# Prerequisites: npm install -g supabase  OR  brew install supabase/tap/supabase

echo "Pushing migrations to local Supabase..."
supabase db push

echo "Done!"
