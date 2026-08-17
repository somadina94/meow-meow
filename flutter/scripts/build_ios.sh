#!/usr/bin/env bash
# Build a release iOS archive (.ipa) for the App Store.
#
# Usage (must run on macOS with Xcode):
#   ./scripts/build_ios.sh
#
# Requires:
#   - Mac with Xcode 14+ installed
#   - Apple Developer account + signing certificate + provisioning profile
#   - ios/Runner/GoogleService-Info.plist (download from Firebase console)
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "❌ iOS builds require macOS with Xcode."
  exit 1
fi

SUPABASE_URL="${SUPABASE_URL:-https://www.meow-meow.co.in:8443}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A}"

cd "$(dirname "$0")/.."

echo "▶ Cleaning previous build…"
flutter clean

echo "▶ Fetching dependencies…"
flutter pub get

echo "▶ Installing CocoaPods…"
cd ios && pod install --repo-update && cd ..

echo "▶ Building iOS archive (release)…"
flutter build ipa --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo
echo "✅ Build complete:"
echo "   build/ios/ipa/*.ipa"
echo
echo "Upload using Transporter.app or:"
echo "   xcrun altool --upload-app -f build/ios/ipa/*.ipa -u <apple-id> -p <app-password>"
