#!/usr/bin/env bash
# ============================================================
# Generate /.well-known/assetlinks.json for Digital Asset Links
# ============================================================
# Without this file hosted at:
#    https://meow-meow.co.in/.well-known/assetlinks.json
# ...the TWA will show a Chrome address bar at the top instead of
# running fullscreen. This file proves the app and the website
# belong to the same owner.
# ============================================================

set -e
cd "$(dirname "$0")"

if [ ! -f "android.keystore" ]; then
  echo "❌ android.keystore not found. Run build.sh first."
  exit 1
fi

PACKAGE_ID="app.lovable.meowmeow.twa"

# Extract SHA-256 from keystore
SHA256=$(keytool -list -v -keystore android.keystore -alias android 2>/dev/null \
  | grep "SHA256:" | head -1 | awk '{print $2}')

if [ -z "$SHA256" ]; then
  echo "❌ Could not extract SHA-256 from keystore."
  exit 1
fi

# Write assetlinks.json
cat > assetlinks.json <<EOF
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "$PACKAGE_ID",
      "sha256_cert_fingerprints": ["$SHA256"]
    }
  }
]
EOF

echo "✅ Generated assetlinks.json"
echo ""
echo "📤 Deploy this file to your web origin so it is reachable at:"
echo "   https://meow-meow.co.in/.well-known/assetlinks.json"
echo ""
echo "   For a Lovable-hosted project: place it at"
echo "   public/.well-known/assetlinks.json   (then redeploy)"
echo ""
echo "🔍 After deploying, verify with:"
echo "   curl https://meow-meow.co.in/.well-known/assetlinks.json"
echo ""
echo "📋 Or use Google's verifier:"
echo "   https://developers.google.com/digital-asset-links/tools/generator"
echo ""
cat assetlinks.json
