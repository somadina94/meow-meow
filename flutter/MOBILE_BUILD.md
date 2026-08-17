# Mobile build & release guide

This Flutter project ships a single Dart codebase to **both** iOS and Android.

## One-time setup

### 1. Install Flutter SDK
```bash
# macOS / Linux
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.19.0-stable.zip -o flutter.zip
unzip flutter.zip && export PATH="$PWD/flutter/bin:$PATH"
flutter doctor
```

### 2. Generate platform shells (only if `ios/` or `android/` are missing)
The repo already contains the customised shells. If they're ever wiped:
```bash
cd flutter
flutter create . --platforms=ios,android --org com.meowmeow
```
Then re-apply `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle`, `ios/Runner/Info.plist`, and `ios/Podfile` from this repo.

### 3. Firebase Cloud Messaging (push notifications)
1. Create a Firebase project at https://console.firebase.google.com
2. Add an Android app (package: `com.meowmeow.app`) → download `google-services.json` → place in `android/app/`
3. Add an iOS app (bundle id: `com.meowmeow.app`) → download `GoogleService-Info.plist` → place in `ios/Runner/`
4. Enable Cloud Messaging in the Firebase console.

### 4. Android signing keystore (one time, irreversible)
```bash
./scripts/create_keystore.sh
```
Back up `android/app/upload-keystore.jks` and `android/key.properties` to a password manager. Losing them means you can never update the app under the same Play listing.

### 5. iOS code signing (Mac only)
1. Apple Developer account ($99/yr).
2. Open `ios/Runner.xcworkspace` in Xcode.
3. **Signing & Capabilities** → select your Team, set bundle ID `com.meowmeow.app`.
4. Add capabilities: **Push Notifications**, **Background Modes** (Voice over IP, Audio, Remote notifications).

## Building releases

### Android App Bundle for Play Store
```bash
./scripts/build_android.sh
# → build/app/outputs/bundle/release/app-release.aab
```
Upload the `.aab` in **Google Play Console → Production → Create new release**.

### iOS IPA for App Store
```bash
./scripts/build_ios.sh
# → build/ios/ipa/*.ipa
```
Upload using **Transporter.app** or `xcrun altool`, then submit for review in **App Store Connect**.

## Supabase configuration in the app

Credentials are passed at build time via `--dart-define` (see scripts) — the anon key is publishable so checking it into the repo is safe, but `--dart-define` lets you swap environments (staging/prod) without code changes.

The app talks **directly** to your hosted Supabase project (database + edge functions + auth + storage + realtime) — there is no intermediate server.

## OAuth deep links (Google sign-in)

URL scheme `io.supabase.meowmeow://login-callback/` is registered for both platforms.
In your Supabase dashboard → **Authentication → URL Configuration**, add:
```
io.supabase.meowmeow://login-callback/
```
to the **Redirect URLs** allow-list.

## Versioning each release

Bump `version: 1.0.0+1` in `pubspec.yaml`:
- The part before `+` is `versionName` (shown to users).
- The part after `+` is `versionCode` / `CFBundleVersion` — must increment for every store upload.

```yaml
version: 1.0.1+2   # next release
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Pod install` fails on Apple Silicon | `cd ios && arch -x86_64 pod install` |
| WebRTC crash on Android <6 | minSdkVersion is already 23 — older devices unsupported |
| Push notifications silent | Verify `google-services.json` / `GoogleService-Info.plist` are present and FCM is enabled in Firebase |
| Google sign-in returns to browser, not app | Confirm redirect URL in Supabase allow-list matches the scheme exactly |
