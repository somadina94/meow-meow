#!/usr/bin/env bash
# Build a release Android App Bundle (.aab) for the Play Store.
#
# Usage:
#   ./scripts/build_android.sh
#
# Requires:
#   - Flutter SDK installed and on PATH
#   - android/key.properties + signing keystore (see scripts/create_keystore.sh)
#   - android/app/google-services.json (download from Firebase console)
set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:-https://www.meow-meow.co.in:8443}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A}"

cd "$(dirname "$0")/.."

echo "▶ Cleaning previous build…"
flutter clean

echo "▶ Fetching dependencies…"
flutter pub get

echo "▶ Building Android App Bundle (release)…"
flutter build appbundle --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo
echo "✅ Build complete:"
echo "   build/app/outputs/bundle/release/app-release.aab"
echo
echo "Upload this .aab in Google Play Console → Production → Create new release."
