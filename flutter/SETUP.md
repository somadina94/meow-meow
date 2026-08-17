# Flutter App Setup — Meow Meow

Companion mobile app sharing the **same Supabase database, edge functions, and
RPCs** as the React web app. No backend or DB changes required.

---

## ⚠️ About `ios/` and `android/` folders

Flutter uses **one shared Dart codebase** (`lib/`). The `ios/` and `android/`
folders are platform-specific native shells (Xcode project + Gradle project)
that are **auto-generated** by `flutter create`. They are not hand-written
and are not in this repo — you generate them locally on your machine.

You do **not** maintain two parallel UIs. Same Dart code → both platforms.

---

## Local setup (one-time)

### 1. Install Flutter SDK
- https://docs.flutter.dev/get-started/install
- Verify: `flutter doctor`

### 2. Tooling per target
- **Android**: Android Studio + Android SDK + Java 17
- **iOS**: macOS + Xcode + CocoaPods (`sudo gem install cocoapods`)

### 3. Generate the Flutter project around this `lib/`
From the `flutter/` directory:

```bash
# Creates ios/, android/, web/, etc. — leaves lib/ untouched if it exists
flutter create --org com.meowmeow --project-name meow_meow .

# Install dependencies
flutter pub get

# Generate Freezed/JSON serialization code
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Wire Supabase credentials
Edit `lib/core/config/supabase_config.dart` and set:
- `SUPABASE_URL` → same as `VITE_SUPABASE_URL` in the web `.env`
- `SUPABASE_ANON_KEY` → same as `VITE_SUPABASE_PUBLISHABLE_KEY`

(Anon key is safe to ship in the binary — RLS protects everything.)

### 5. Run

```bash
# Android emulator or device
flutter run -d android

# iOS simulator (macOS only)
flutter run -d ios

# List available devices
flutter devices
```

### 6. Build release artifacts

```bash
# Android APK (sideload / Play Internal testing)
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (requires Apple Developer account + signing in Xcode)
flutter build ipa --release
```

---

## What's done

| Layer | Status |
|---|---|
| Database / RPCs / edge functions | ✅ Shared with web — zero changes |
| Auth, RLS, Storage, Realtime | ✅ Shared |
| Dart services (20+ files) | ✅ Including new payment / push-token / photo-verify / screenshot-protection |
| Models | ✅ Scaffolded (Freezed) |
| Router (`go_router`) | ✅ All routes wired |
| Theme system | ✅ Matches web tokens |
| Most screens | ✅ Built |
| **Razorpay recharge flow** | ✅ `recharge_screen.dart` + `payment_service.dart` |
| **KYC 9-section form** | ✅ `kyc_screen.dart` writes to `women_kyc` |
| **Agora WebRTC video calls** | ✅ Wired in `video_call_screen.dart` |
| **FCM push registration** | ✅ Auto-registers on sign-in via `push_token_service.dart` |
| **AI photo verification client** | ✅ `photo_verification_service.dart` calls `verify-photo` |
| **Screenshot protection (Android FLAG_SECURE / iOS detect)** | ✅ Auto-enabled on chat & call screens |

## Phase-2 platform setup (still required locally)

These can't be done from Lovable — they need files only your machine has.

1. **Agora App ID**
   - Sign up at https://agora.io (free dev tier).
   - Pass at build time:
     `flutter run --dart-define=AGORA_APP_ID=<your-app-id>`
   - Production: mint short-lived tokens via an edge function instead of the empty token.

2. **Razorpay**
   - The `razorpay-payment` and `razorpay-webhook` edge functions already
     exist server-side and use the existing `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` secrets.
   - No client config needed — `payment_service.dart` reads `key_id` from the edge response.

3. **Firebase (FCM)**
   - Create a Firebase project, add Android + iOS apps.
   - Download `google-services.json` → `android/app/`
   - Download `GoogleService-Info.plist` → `ios/Runner/`
   - Add the Firebase plugins via `flutter pub run flutterfire configure` (recommended).

4. **Android permissions** (auto-merged by plugins, but verify in `android/app/src/main/AndroidManifest.xml`):
   - `INTERNET`, `CAMERA`, `RECORD_AUDIO`, `BLUETOOTH_CONNECT`,
     `ACCESS_NETWORK_STATE`, `MODIFY_AUDIO_SETTINGS`, `WAKE_LOCK`,
     `POST_NOTIFICATIONS`.

5. **iOS Info.plist** — add usage descriptions:
   - `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`,
     `NSPhotoLibraryUsageDescription`, push notification entitlement.

## What's still TODO (Phase 3 — optional polish)

- Swap empty Agora token for a token-server edge function (security hardening).
- Realtime chat wiring inside `chat_screen.dart` is in place; verify on a device.
- Private group calls (50 flower rooms) — share the same Agora engine pattern.
- Native deep linking for incoming-call notifications.

---

## Drift discipline (critical)

> **All business logic — billing, idempotency, mutual exclusion, month-end
> rollover, content moderation — lives in Postgres functions or edge
> functions. Never duplicate it in Dart or React. Both clients are thin
> shells over the same backend.**

If you change a price, a rule, or a workflow, change the **RPC / edge
function**, never the client. This is what keeps web + Flutter in sync.

---

## Debugging

- **App won't compile after `flutter pub get`**: run
  `flutter pub run build_runner build --delete-conflicting-outputs`
  to regenerate Freezed/JSON code.
- **Auth session not persisting**: check `flutter_secure_storage`
  permissions in `ios/Runner/Info.plist` (Keychain) and Android
  manifest.
- **Realtime not firing**: confirm RLS policies allow the user to
  `select` from the table they're subscribing to.
- **Slow first launch on iOS**: normal — Flutter compiles ahead-of-time.
