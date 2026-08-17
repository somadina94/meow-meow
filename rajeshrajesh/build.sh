#!/usr/bin/env bash
# ============================================================
# MeowMeow TWA — One-Command Build Script
# ============================================================
# Produces: android/app/build/outputs/bundle/release/app-release.aab
# Requires: Node.js 18+, JDK 17, Android SDK 34, Bubblewrap CLI
# ============================================================

set -e
cd "$(dirname "$0")"

echo "🐱 MeowMeow TWA build starting..."

# 1. Verify Bubblewrap is installed
if ! command -v bubblewrap &> /dev/null; then
  echo "❌ Bubblewrap CLI not found. Installing globally..."
  npm install -g @bubblewrap/cli
fi

# 2. Verify Java 17
JAVA_MAJOR=$(java -version 2>&1 | head -1 | awk -F'"' '{print $2}' | cut -d'.' -f1)
if [ "$JAVA_MAJOR" -lt 17 ]; then
  echo "❌ JDK 17+ required. Found Java $JAVA_MAJOR. Install OpenJDK 17."
  exit 1
fi

# 3. Verify ANDROID_HOME
if [ -z "$ANDROID_HOME" ]; then
  echo "❌ ANDROID_HOME is not set. Install Android SDK and export ANDROID_HOME."
  exit 1
fi

# 4. Generate keystore if missing
if [ ! -f "android.keystore" ]; then
  echo "🔑 No keystore found — generating one (you will be prompted for passwords)..."
  keytool -genkey -v \
    -keystore android.keystore \
    -alias android \
    -keyalg RSA -keysize 2048 -validity 10000
  echo ""
  echo "⚠️  IMPORTANT: Back up android.keystore and your passwords."
  echo "    Losing them means you can NEVER update your Play Store app."
  echo ""
fi

# 5. Initialize android/ project from twa-manifest.json (idempotent)
if [ ! -d "android" ]; then
  echo "🏗  Initializing native Android project from twa-manifest.json..."
  bubblewrap init --manifest=./twa-manifest.json --directory=./android
else
  echo "♻️  android/ already exists — running bubblewrap update..."
  (cd android && bubblewrap update)
fi

# 6. Build the signed App Bundle (.aab) for Play Store + APK for sideloading
echo "📦 Building release bundle..."
(cd android && bubblewrap build --skipPwaValidation)

# 7. Print SHA-256 fingerprint needed for Digital Asset Links
echo ""
echo "✅ Build complete!"
echo ""
echo "📱 Outputs:"
echo "   • AAB (Play Store):  rajeshrajesh/android/app/build/outputs/bundle/release/app-release.aab"
echo "   • APK (sideload):    rajeshrajesh/android/app-release-signed.apk"
echo ""
echo "🔐 Your signing fingerprint (needed for assetlinks.json):"
keytool -list -v -keystore android.keystore -alias android 2>/dev/null \
  | grep "SHA256:" | head -1
echo ""
echo "👉 Next: bash generate-assetlinks.sh"
