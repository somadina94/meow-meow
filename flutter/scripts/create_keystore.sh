#!/usr/bin/env bash
# One-time helper: generate an Android upload keystore and the
# matching key.properties file consumed by android/app/build.gradle.
#
# Run once, then keep both files SAFE (never commit to git).
set -euo pipefail

cd "$(dirname "$0")/.."

KEYSTORE=android/app/upload-keystore.jks
KEYPROPS=android/key.properties

if [[ -f "$KEYSTORE" ]]; then
  echo "❌ Keystore already exists at $KEYSTORE — refusing to overwrite."
  exit 1
fi

read -rp "Key alias [upload]: " ALIAS
ALIAS=${ALIAS:-upload}
read -rsp "Keystore password: " STOREPASS; echo
read -rsp "Key password (leave blank to reuse): " KEYPASS; echo
KEYPASS=${KEYPASS:-$STOREPASS}

keytool -genkey -v -keystore "$KEYSTORE" \
  -keyalg RSA -keysize 2048 -validity 10000 -alias "$ALIAS" \
  -storepass "$STOREPASS" -keypass "$KEYPASS"

cat > "$KEYPROPS" <<EOF
storePassword=$STOREPASS
keyPassword=$KEYPASS
keyAlias=$ALIAS
storeFile=app/upload-keystore.jks
EOF

echo
echo "✅ Created $KEYSTORE and $KEYPROPS"
echo "   Both files are .gitignored. Back them up — losing them means you can"
echo "   never publish another update of this app under the same Play listing."
